"""Giresun: SKS sayfasındaki en güncel aylık metin PDF'i, tek öğün (öğle).

Her gün dört yemek ve bir toplam enerji hücresi vardır. Alternatif ana
yemeklerin farklı toplamları toplanmaz; aralık kaynak notuyla korunur.
Kasım 2026 PDF'inde her BT metin bloğu kendi konumundan başlar; ortak PDF
okuyucusuna bloklar ayrı verilerek önceki bloğun konumunun taşması önlenir.
"""
import html
import re
from datetime import date
from urllib.parse import quote, unquote, urljoin

from .. import pdf as pdfmod
from ..model import ay_no, baslik_yap_serbest, bugun_tr, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sksdb.giresun.edu.tr/"


def pdf_baglantisi(sayfa, bugun):
    adaylar = []
    for url, ad in re.findall(r'<a\b[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>', sayfa, re.S | re.I):
        m = re.fullmatch(r"(\S+) Ayı Yemek Menüsü", etiket_temizle(ad), re.I)
        ay = ay_no(m[1]) if m else None
        if ay and unquote(url).lower().endswith(".pdf"):
            url = quote(urljoin(SAYFA_URL, html.unescape(unquote(url))), safe=":/()")
            adaylar.append(((bugun.month - ay) % 12, url))
    return min(adaylar)[1] if adaylar else None


def pdf_parcalari(veri):
    nesneler = pdfmod.nesneler(veri)
    fontlar, adlar = {}, {}
    for no, (sozluk, _) in nesneler.items():
        m = re.search(rb"/ToUnicode\s+(\d+) 0 R", sozluk)
        if m and re.search(rb"/Type\s*/Font\b", sozluk):
            cmap = nesneler.get(int(m[1]), (b"", None))[1]
            if cmap:
                fontlar[no] = (pdfmod.cmap_oku(cmap), pdfmod.cmap_genislik(cmap))
        for m in re.finditer(rb"/Font\s*(?:<<(.*?)>>|(\d+) 0 R)", sozluk, re.S):
            kaynak = m[1] if m[1] is not None else nesneler.get(int(m[2]), (b"", None))[0]
            for ad, ref in re.findall(rb"/([\w+-]+)\s+(\d+) 0 R", kaynak):
                adlar[ad.decode()] = int(ref)
    sonuc = []
    for sozluk, akis in nesneler.values():
        if not akis or not pdfmod._icerik_akisi_mi(sozluk, akis):
            continue
        for blok in re.findall(rb"\bBT\b.*?\bET\b", akis, re.S):
            p = pdfmod._icerik(blok, adlar, fontlar)
            # Aynı hücrede iki satıra sarılmış ana yemek/kalori tek kalemdir.
            if len(p) > 1 and max(o[0] for o in p) - min(o[0] for o in p) < 35 and max(o[1] for o in p) - min(o[1] for o in p) < 40:
                x, y, boyut, _ = p[0]
                sonuc.append((x, y, boyut, " ".join(o[3] for o in p)))
            else:
                sonuc.extend(p)
    return sonuc


def yemek_adi(ad):
    ad = re.sub(r"\bz\.yağlı\b", "zeytinyağlı", ad, flags=re.I)
    ad = re.sub(r"\bizmir\s+köfte\b", "İzmir Köfte", ad, flags=re.I)
    ad = re.sub(r"\s*/\s*", "/", re.sub(r"\s+", " ", ad)).strip(" .-")
    return baslik_yap_serbest(kisaltma_ac(ad))


def pdf_menu(veri):
    parcalar = pdf_parcalari(veri)
    basliklar = []
    for x, y, _, metin in parcalar:
        m = re.match(r"^(\d{2})\.(\d{2})\.(\d{4})\s*[-–]", metin)
        if m:
            try:
                basliklar.append((date(int(m[3]), int(m[2]), int(m[1])), x, y))
            except ValueError:
                continue
    sonuc = {}
    for tarih, x, ust in basliklar:
        haftanin_gunleri = sorted((t, xx, yy) for t, xx, yy in basliklar if abs(yy - ust) < 1)
        haftanin_gunleri.sort(key=lambda o: o[1])
        enerjiler = sorted(xx for xx, yy, _, t in parcalar if t.strip() == "Enerji" and abs(yy - ust) < 1)
        if len(enerjiler) < len(haftanin_gunleri):
            continue
        sira = next(i for i, o in enumerate(haftanin_gunleri) if o[0] == tarih)
        sol = enerjiler[sira - 1] + 25 if sira else 0
        sag = enerjiler[sira] + 25
        altlar = [yy for _, _, yy in basliklar if yy < ust - 1]
        alt = max(altlar) if altlar else 100
        alan = sorted((y, xx, t.strip()) for xx, y, _, t in parcalar if sol <= xx < sag and alt < y < ust - 1 and t.strip())
        ogeler, kaloriler = [], []
        for _, _, t in sorted(alan, key=lambda o: (-o[0], o[1])):
            if re.fullmatch(r"[\d\s/]+K?KAL", t, re.I):
                kaloriler = [int(k) for k in re.findall(r"\d+", t) if int(k) > 0]
            elif t not in {"Enerji", "KKAL"}:
                ogeler.append({"name": yemek_adi(t)})
        if not ogeler:
            continue
        ogun = {"items": ogeler}
        if kaloriler and len(set(kaloriler)) == 1:
            ogun["kcal"] = kaloriler[0]
        elif kaloriler:
            ogun["note"] = "Ana yemek seçimine göre toplam kalori: %s kcal" % "/".join(map(str, kaloriler))
        sonuc[tarih.isoformat()] = {"lunch": ogun}
    return sonuc


class GiresunUniversitesi(Universite):
    id = "giresun"
    ad = "Giresun Üniversitesi"
    kisa = "GRÜ"
    sehir = "Giresun"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self):
        try:
            url = pdf_baglantisi(self.indir(SAYFA_URL).decode("utf-8-sig"), self.bugun or bugun_tr())
        except Exception as e:
            raise RuntimeError("Giresun: SKS yemek listesi sayfası indirilemedi: %s" % e) from e
        if not url:
            raise RuntimeError("Giresun: aylık yemek PDF bağlantısı bulunamadı")
        try:
            sonuc = pdf_menu(self.indir(url))
        except Exception as e:
            raise RuntimeError("Giresun: aylık yemek PDF'i okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("Giresun: PDF'te tarihli menü bulunamadı")
        return sonuc
