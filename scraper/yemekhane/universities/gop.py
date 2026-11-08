"""Tokat Gaziosmanpaşa: Sosyal Tesisler sayfasının aylık metin PDF'i.

Öğrenci yemekhanesinin listesi alınır; kafe/restoran listesi kullanılmaz.
PDF başlığında yıl yoktur: gün/hafta günü eşleşmeleriyle yakın yıl seçilir.
Beş sütun, dört yemek ve yazılı toplam kalori (Kasım 2026 düzeni).
"""
import html
import re
from datetime import date
from urllib.parse import quote, unquote, urljoin, urlsplit, urlunsplit

from .. import pdf as pdfmod
from ..model import ay_no, baslik_yap_serbest, bugun_tr, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sosyaltesisler.gop.edu.tr/arasayfa_detay.aspx?arasayfaID=16"
GUNLER = ("PAZARTESİ", "SALI", "ÇARŞAMBA", "PERŞEMBE", "CUMA")


def pdf_baglantilari(sayfa, bugun):
    sonuc = []
    for url, govde in re.findall(r'<a\b[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>', sayfa, re.S | re.I):
        ad = etiket_temizle(govde)
        m = re.fullmatch(r"(\S+) AYI YEMEK MENÜSÜ", ad, re.I)
        ay = ay_no(m.group(1)) if m else None
        if not ay or not unquote(url).lower().endswith(".pdf"):
            continue
        p = urlsplit(urljoin(SAYFA_URL, html.unescape(url)))
        # Resmî sayfadaki eski http bağlantısı aynı sunucuda HTTPS ile çalışır.
        url = urlunsplit(p._replace(scheme="https", path=quote(unquote(p.path), safe="/()")))
        sonuc.append((ay, url))
    return sorted(set(sonuc), key=lambda o: (bugun.month - o[0]) % 12)


def pdf_menu(veri, ay, bugun):
    sonuc = {}
    for sayfa in pdfmod.sayfa_metinleri(veri):
        basliklar = []
        for x, y, boyut, metin in sayfa:
            if not re.fullmatch(r"\d{1,2}", metin.strip()) or boyut < 8.5:
                continue
            gun = next((t.strip() for xx, yy, _, t in sayfa if abs(yy - y) < 1 and x < xx < x + 100 and t.strip() in GUNLER), None)
            if gun:
                basliklar.append((int(metin), GUNLER.index(gun), x, y))
        if not basliklar:
            continue
        yillar = []
        for yil in range(bugun.year - 1, bugun.year + 2):
            try:
                if all(date(yil, ay, g).weekday() == h for g, h, _, _ in basliklar):
                    yillar.append(yil)
            except ValueError:
                continue
        if not yillar:
            continue
        yil = min(yillar, key=lambda y: abs((date(y, ay, 1) - bugun).days))
        sutunlar = sorted(set(x for _, _, x, _ in basliklar))
        for gun, _, x, ust in basliklar:
            sutun = sutunlar.index(x)
            sag = sutunlar[sutun + 1] - 3 if sutun + 1 < len(sutunlar) else x + 142
            altlar = [yy for _, _, xx, yy in basliklar if abs(xx - x) < 1 and yy < ust]
            alt = max(altlar) if altlar else 95
            alan = [(xx, yy, b, t.strip()) for xx, yy, b, t in sayfa if x - 3 <= xx < sag and alt < yy < ust and t.strip()]
            # Uzun yemek adları 6.72 puntoya iner ve yarım birim yükselir;
            # satırları yazı boyundan değil soldaki 1–4 numaralarından bul.
            satirlar = [yy for xx, yy, b, t in alan if t in {"1", "2", "3", "4"} and abs(xx - x) < 8 and b >= 7.5]
            ogeler = []
            for yy in sorted(satirlar, reverse=True):
                hucre = sorted((xx, t) for xx, y, _, t in alan if abs(y - yy) < 1)
                ad = re.sub(r"\s+", " ", " ".join(t for _, t in hucre if not t.isdigit())).strip()
                kaloriler = [int(t) for _, t in hucre if t.isdigit() and int(t) > 4]
                if not ad:
                    continue
                oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
                if len(kaloriler) == 1:
                    oge["kcal"] = kaloriler[0]
                ogeler.append(oge)
            if not ogeler:
                continue
            ogun = {"items": ogeler}
            toplamlar = [int(t) for _, _, b, t in alan if 6.5 <= b < 7.5 and t.isdigit() and int(t) > 0]
            if len(toplamlar) == 1:
                ogun["kcal"] = toplamlar[0]
            sonuc[date(yil, ay, gun).isoformat()] = {"lunch": ogun}
    return sonuc


class TokatGaziosmanpasa(Universite):
    id = "gop"
    ad = "Tokat Gaziosmanpaşa Üniversitesi"
    kisa = "TOGÜ"
    sehir = "Tokat"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self):
        bugun = self.bugun or bugun_tr()
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
            baglantilar = pdf_baglantilari(sayfa, bugun)
        except Exception as e:
            raise RuntimeError("Tokat Gaziosmanpaşa: aylık menü sayfası indirilemedi: %s" % e) from e
        if not baglantilar:
            raise RuntimeError("Tokat Gaziosmanpaşa: aylık yemek PDF bağlantısı bulunamadı")
        ay, url = baglantilar[0]
        try:
            sonuc = pdf_menu(self.indir(url), ay, bugun)
        except Exception as e:
            raise RuntimeError("Tokat Gaziosmanpaşa: aylık yemek PDF'i okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("Tokat Gaziosmanpaşa: PDF'te tarihli yemek menüsü bulunamadı")
        return sonuc
