"""Kafkas SKS: dört haftalık gerçek metin PDF'i, yalnız normal menü.

Tek TJ dizisi birden fazla sütunun yemeklerini/kalorilerini kapsar. Yerleri
CID yazı tipinin /W genişlikleriyle hesaplanır; komşu günler birleştirilmez.
İkinci sayfa glutensizdir, alınmaz. İlk doğrulama 19 Ekim–13 Kasım 2026.
"""
import html
import re
from datetime import date
from urllib.parse import quote, unquote, urljoin

from .. import pdf as pdfmod
from ..model import baslik_yap_serbest, gun_icerigi, kisaltma_ac, etiket_temizle
from .base import Universite, indir

SAYFA_URL = "https://www.kafkas.edu.tr/skdb"
SAYI = rb"[-+]?\d+(?:\.\d+)?"


def pdf_baglantisi(sayfa):
    for url, ad in re.findall(r'<a\b[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>', sayfa, re.S | re.I):
        if etiket_temizle(ad) == "Yemek Listesi" and unquote(url).lower().endswith(".pdf"):
            return quote(urljoin(SAYFA_URL, html.unescape(unquote(url))), safe=":/()")
    return None


def _normal_sayfa(veri):
    """İlk sayfanın CID metnini büyük TJ sütun boşluklarından ayırır.

    Genel PDF okuyucusunu değiştirmeden bu kaynağın dolaylı /W sözlüğünü
    kullanır. Koordinatlar kaynakta y aşağı artacak biçimde yazılmıştır.
    """
    nes = pdfmod.nesneler(veri)
    sayfa = next((s for s, _ in nes.values() if re.search(rb"/Type\s*/Page\b", s)), b"")
    icerik = re.search(rb"/Contents\s*\[?\s*(\d+) 0 R", sayfa)
    kaynak = re.search(rb"/Resources\s+(\d+) 0 R", sayfa)
    if not icerik or not kaynak:
        return []
    fontlar = {}
    for ad, no in re.findall(rb"/(F\d+)\s+(\d+) 0 R", nes[int(kaynak[1])][0]):
        sozluk = nes[int(no)][0]
        cmap = re.search(rb"/ToUnicode\s+(\d+) 0 R", sozluk)
        w = re.search(rb"/W\s+(\d+) 0 R", sozluk)
        if not cmap or not w:
            continue
        genislik = {}
        for bas, son, deger, dizi in re.findall(rb"(\d+)\s+(?:(\d+)\s+(" + SAYI + rb")|\[([^]]+)\])", nes[int(w[1])][0]):
            if dizi:
                genislik.update((int(bas) + i, float(v)) for i, v in enumerate(re.findall(SAYI, dizi)))
            else:
                genislik.update((c, float(deger)) for c in range(int(bas), int(son) + 1))
        fontlar[ad] = (pdfmod.cmap_oku(nes[int(cmap[1])][1]), genislik)
    sonuc = []
    for blok in re.findall(rb"BT\b(.*?)\bET", nes[int(icerik[1])][1] or b"", re.S):
        f = re.search(rb"/(F\d+)\s+(" + SAYI + rb")\s+Tf", blok)
        m = re.search(rb"1 0\s+" + SAYI + rb"\s+-1\s+(" + SAYI + rb")\s+(" + SAYI + rb")\s+Tm", blok)
        if not f or not m or f[1] not in fontlar:
            continue
        cmap, genislik = fontlar[f[1]]
        boyut, x, y = float(f[2]), float(m[1]), float(m[2])
        for dizi in re.findall(rb"\[(.*?)\]\s*TJ", blok, re.S):
            bas, metin = x, ""
            for hx, ara in re.findall(rb"<([0-9A-Fa-f]+)>|(" + SAYI + rb")", dizi):
                if hx:
                    for i in range(0, len(hx), 4):
                        kod = int(hx[i:i + 4], 16)
                        metin += cmap.get(kod, "")
                        x += genislik.get(kod, 1000) * boyut / 1000
                else:
                    aralik = float(ara)
                    if aralik < -1000:
                        if metin.strip():
                            sonuc.append((bas, y, boyut, metin.strip()))
                        metin = ""
                    x -= aralik * boyut / 1000
                    if not metin:
                        bas = x
            if metin.strip():
                sonuc.append((bas, y, boyut, metin.strip()))
    return sonuc


def yemek_adi(ad):
    ad = re.sub(r"\bEZO\s+GELİN\b", "EZOGELİN", ad)
    ad = ad.replace("ÇOIRBASI", "ÇORBASI").replace("ŞEKRPARE", "ŞEKERPARE")
    return baslik_yap_serbest(kisaltma_ac(ad.strip(" .-")))


def pdf_menu(veri):
    sayfa = _normal_sayfa(veri)
    basliklar = []
    for x, y, _, t in sayfa:
        m = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", t)
        if m and y < min((yy for _, yy, _, s in sayfa if s == "YEMEKHANE SORUMLUSU"), default=float("inf")):
            try:
                basliklar.append((date(int(m[3]), int(m[2]), int(m[1])).isoformat(), x, y))
            except ValueError:
                pass
    if not basliklar:
        return {}
    ustler = sorted({round(y) for _, _, y in basliklar})
    son = min((y for _, y, _, s in sayfa if s == "YEMEKHANE SORUMLUSU"), default=max(ustler) + 125)
    sonuc = {}
    for n, ust in enumerate(ustler):
        alt = ustler[n + 1] if n + 1 < len(ustler) else son
        gunler = sorted((x, t) for t, x, y in basliklar if abs(y - ust) < 1)
        # Kalori başlıkları hücrenin sağındadır; tarih metni hücrede ortalıdır.
        saglar = sorted(x + 40 for x, y, _, t in sayfa if t == "Kalori" and abs(y - (ust - 7.3)) < 1)
        if len(saglar) < len(gunler):
            # Tatil hücrelerinde kalori başlığı yoktur: ilk haftanın ızgarası.
            saglar = sorted(x + 40 for x, y, _, t in sayfa if t == "Kalori" and abs(y - (ustler[0] - 7.3)) < 1)
        if len(saglar) != len(gunler):
            raise ValueError("Kafkas: PDF gün/kalori sütunları eşleşmiyor")
        for i, (_, tarih) in enumerate(gunler):
            sol, sag = (saglar[i - 1] if i else 55), saglar[i]
            alan = [(x, y, t) for x, y, _, t in sayfa if sol < x <= sag and ust + 10 < y < alt - 5]
            metin = " ".join(t for _, _, t in alan)
            if "TATİL" in metin:
                sonuc[tarih] = {"lunch": {"items": [], "note": "Yarım gün / Resmi tatil" if "YARIM" in metin else "Resmi tatil"}}
                continue
            satirlar = {}
            for x, y, t in alan:
                yy = next((yy for yy in satirlar if abs(yy - y) < 1), y)
                satirlar.setdefault(yy, []).append((x, t))
            ogeler, toplam = [], None
            for y in sorted(satirlar):
                t = " ".join(s for _, s in sorted(satirlar[y]))
                k = re.fullmatch(r"(.+?)\s+(\d+)", t)
                if k:
                    ogeler.append({"name": yemek_adi(k[1]), "kcal": int(k[2])})
                elif t.isdigit():
                    toplam = int(t)
            if ogeler:
                ogun = gun_icerigi(ogeler)
                if toplam is not None:
                    ogun["kcal"] = toplam
                sonuc[tarih] = {"lunch": ogun}
    return sonuc


class KafkasUniversitesi(Universite):
    id = "kafkas"
    ad = "Kafkas Üniversitesi"
    kisa = "KAÜ"
    sehir = "Kars"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self):
        try:
            url = pdf_baglantisi(self.indir(SAYFA_URL).decode("utf-8-sig"))
        except Exception as e:
            raise RuntimeError("Kafkas: SKS menü sayfası indirilemedi: %s" % e) from e
        if not url:
            raise RuntimeError("Kafkas: Yemek Listesi PDF bağlantısı bulunamadı")
        try:
            sonuc = pdf_menu(self.indir(url))
        except Exception as e:
            raise RuntimeError("Kafkas: yemek PDF'i okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("Kafkas: PDF'te tarihli normal yemek menüsü bulunamadı")
        return sonuc
