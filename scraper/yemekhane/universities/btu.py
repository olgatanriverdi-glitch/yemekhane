"""BTÜ SKS ana sayfasındaki Yemek Listesi bağlantısı: metin tabanlı PDF.

Tarih satırlarının orta noktaları günleri, beş yemek sütunu ve son kalori
sütunu kalemleri ayırır. Sarılmış satırlar aynı hücrede birleştirilir.
İlk doğrulama Ekim 2026 düzeniyledir; PDF sütunları değişirse kontrol gerekir.
Ana yemek hücresindeki '/' seçenekleri korunur, ayrı öğün üretilmez.
"""
import html
import re
from datetime import date
from urllib.parse import unquote, urljoin, urlsplit, urlunsplit

from .. import pdf as pdfmod
from ..model import baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir, saat_duzenle

SAYFA_URL = "https://sks.btu.edu.tr/tr"
SAAT_URL = "https://sks.btu.edu.tr/tr/sayfa/detay/4398/beslenme"
# Ekim PDF'inin hücre sınırları; ilk sütun başlığına göre yatay kayma desteklenir.
SINIRLAR = (170.0, 305.0, 470.0, 615.0, 710.0, 800.0)


def pdf_baglantisi(sayfa: str):
    for url, govde in re.findall(r'<a\b[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>', sayfa, re.S | re.I):
        url = html.unescape(url)
        if etiket_temizle(govde) == "Yemek Listesi" and unquote(url).lower().split("?")[0].endswith(".pdf"):
            parcalar = urlsplit(urljoin(SAYFA_URL, url))
            return urlunsplit(parcalar._replace(path=re.sub(r"/{2,}", "/", parcalar.path)))
    return None


def yemek_adi(metin):
    metin = re.sub(r"\s+", " ", metin).strip(" .-")
    metin = re.sub(r"\s*([/\-])\s*", r"\1", metin)
    metin = re.sub(r"\bGRN\.", "GARNİTÜR", metin)
    return baslik_yap_serbest(kisaltma_ac(metin))


def fiyat_pdf_baglantisi(sayfa: str):
    m = re.search(r'Yemek Ücretleri katkı payı tablosu.*?<a\b[^>]*href=[\'"]([^\'"]+\.pdf)[\'"]', sayfa, re.S)
    if not m:
        return None
    p = urlsplit(urljoin(SAAT_URL, html.unescape(m.group(1))))
    return urlunsplit(p._replace(path=re.sub(r"/{2,}", "/", p.path)))


def pdf_fiyatlar(veri: bytes) -> list:
    sonuc = []
    for sayfa in pdfmod.sayfa_metinleri(veri):
        satirlar = pdfmod.satirlari_birlestir(sayfa)
        for ad, _, _, y, _ in satirlar:
            if ad.strip() not in ("ÖĞRENCİ", "PERSONEL", "DİĞER"):
                continue
            for metin, _, _, sy, _ in satirlar:
                m = re.fullmatch(r"\s*(\d+(?:[.,]\d+)?)\s*TL\s*", metin)
                if m and abs(sy - y) < 1:
                    sonuc.append({"label": baslik_yap_serbest(ad.strip()), "tl": float(m.group(1).replace(",", "."))})
    return sonuc


def pdf_menu(veri: bytes) -> dict:
    sonuc = {}
    for sayfa in pdfmod.sayfa_metinleri(veri):
        satirlar = pdfmod.satirlari_birlestir(sayfa, bosluk=1.2)
        kap = next((s for s in satirlar if s[0].strip() == "1.KAP YEMEK"), None)
        if kap is None:
            continue
        sinirlar = [x + kap[1] - 203.8 for x in SINIRLAR]
        tarihler = []
        for metin, x, _, y, _ in satirlar:
            t = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", metin.strip())
            if not t or x >= sinirlar[0]:
                continue
            try:
                tarihler.append((date(int(t.group(3)), int(t.group(2)), int(t.group(1))), y))
            except ValueError:
                pass
        tarihler.sort(key=lambda t: -t[1])
        for i, (tarih, y) in enumerate(tarihler):
            ust = (tarihler[i - 1][1] + y) / 2 if i else y + 15
            alt = (tarihler[i + 1][1] + y) / 2 if i + 1 < len(tarihler) else y - 15
            hucreler = [[] for _ in range(6)]
            for s in sorted(satirlar, key=lambda s: (-s[3], s[1])):
                metin, x, _, sy, _ = s
                if not (alt < sy <= ust) or x < sinirlar[0]:
                    continue
                sutun = sum(x >= b for b in sinirlar) - 1
                hucreler[sutun].append(metin)
            adlar = [yemek_adi(" ".join(h)) for h in hucreler[:5]]
            adlar = [a for a in adlar if a]
            if not adlar:
                continue  # boş hafta sonu satırı
            if all("tatil" in a.lower() for a in adlar):
                ogun = {"items": [], "note": "Resmi tatil"}
            else:
                ogun = {"items": [{"name": a} for a in adlar]}
                kcal = re.fullmatch(r"\s*(\d+)\s*[Kk]?[Kk][Aa][Ll]\s*", " ".join(hucreler[5]))
                if kcal and int(kcal.group(1)) > 0:
                    ogun["kcal"] = int(kcal.group(1))
            sonuc[tarih.isoformat()] = {"lunch": ogun}
    return sonuc


class BursaTeknik(Universite):
    id = "btu"
    ad = "Bursa Teknik Üniversitesi"
    kisa = "BTÜ"
    sehir = "Bursa"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici
        self.bilgi = None

    def _bilgi_sayfasi(self):
        if self.bilgi is None:
            try:
                self.bilgi = self.indir(SAAT_URL).decode("utf-8")
            except Exception:
                self.bilgi = ""
        return self.bilgi

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("BTÜ: SKS yemek sayfası indirilemedi: %s" % e) from e
        url = pdf_baglantisi(sayfa)
        if not url:
            raise RuntimeError("BTÜ: güncel Yemek Listesi PDF bağlantısı bulunamadı")
        try:
            sonuc = pdf_menu(self.indir(url))
        except Exception as e:
            raise RuntimeError("BTÜ: yemek PDF'i indirilemedi veya okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("BTÜ: PDF'te tarihli yemek tablosu bulunamadı")
        return sonuc

    def saatler(self) -> dict:
        m = re.search(r"Öğrenci yemek servis saatleri\s+(.+?)\(\s*Öğrenci Yemekhanesi", etiket_temizle(self._bilgi_sayfasi()))
        saat = saat_duzenle(m.group(1)) if m else None
        return {"lunch": saat} if saat else {}

    def fiyatlar(self) -> list:
        try:
            url = fiyat_pdf_baglantisi(self._bilgi_sayfasi())
            return pdf_fiyatlar(self.indir(url)) if url else []
        except Exception:
            return []
