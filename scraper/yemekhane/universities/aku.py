"""Afyon Kocatepe: SKS yemek-listesi sayfasındaki güncel metin PDF'i.
PDF'te her hafta '02-06 KASIM 2026' gibi tarih aralığı ve beş gün sütunu
vardır; günler başlıklardan, yemekler PDF koordinatlarından bulunur.
Dosya adı sabitlenmez. Tek liste öğle sayılır. İlk doğrulama Kasım 2026.
"""
import html
import re
from datetime import date, timedelta
from urllib.parse import unquote, urljoin

from .. import pdf as pdfmod
from ..model import ay_no, baslik_yap_serbest, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://skultur.aku.edu.tr/2025/08/29/yemek-listesi/"
HAFTA = re.compile(r"^(\d{1,2})\s*[-–]\s*(\d{1,2})\s+(\S+)\s+(\d{4})$")
GUNLER = ("PAZARTESİ", "SALI", "ÇARŞAMBA", "PERŞEMBE", "CUMA")
KALEM = re.compile(r"^(.+?)\s*\((\d+)\s*kcal\)\s*$", re.I)


def pdf_baglantisi(sayfa: str):
    for url in re.findall(r"<iframe\b[^>]*src=['\"]([^'\"]+)['\"]", sayfa, re.I):
        url = html.unescape(url)
        if unquote(url).lower().split("?")[0].endswith(".pdf"):
            return urljoin(SAYFA_URL, url)
    for url in re.findall(r"<a\b[^>]*href=['\"]([^'\"]+)['\"]", sayfa, re.I):
        url = html.unescape(url)
        dosya = unquote(url).lower().split("?")[0]
        if dosya.endswith(".pdf") and ("menu" in dosya or "yemek" in dosya):
            return urljoin(SAYFA_URL, url)
    return None


def pdf_menu(veri: bytes) -> dict:
    sonuc = {}
    for sayfa in pdfmod.sayfa_metinleri(veri):
        satirlar = pdfmod.satirlari_birlestir(sayfa, bosluk=1.0)
        haftalar = []
        for metin, _, _, y, _ in satirlar:
            h = HAFTA.fullmatch(metin.strip())
            if not h or not ay_no(h.group(3)):
                continue
            try:
                ilk = date(int(h.group(4)), ay_no(h.group(3)), int(h.group(1)))
                son = date(ilk.year, ilk.month, int(h.group(2)))
            except ValueError:
                continue
            if ilk.weekday() == 0 and (son - ilk).days == 4:
                haftalar.append((ilk, y))
        haftalar.sort(key=lambda h: -h[1])
        for i, (ilk, ust) in enumerate(haftalar):
            alt = haftalar[i + 1][1] if i + 1 < len(haftalar) else float("-inf")
            alan = [s for s in satirlar if alt < s[3] < ust]
            basliklar = sorted([s for s in alan if s[0].strip() in GUNLER], key=lambda s: s[1])
            if [s[0].strip() for s in basliklar] != list(GUNLER):
                continue
            ogeler = [[] for _ in GUNLER]
            for metin, x, _, y, _ in sorted(alan, key=lambda s: -s[3]):
                k = KALEM.fullmatch(metin.strip())
                if not k or y >= min(s[3] for s in basliklar):
                    continue
                sutun = min(range(5), key=lambda n: abs(basliklar[n][1] - x))
                oge = {"name": baslik_yap_serbest(kisaltma_ac(k.group(1).strip()))}
                if int(k.group(2)) > 0:
                    oge["kcal"] = int(k.group(2))
                ogeler[sutun].append(oge)
            for n, kalemler in enumerate(ogeler):
                if kalemler:
                    sonuc[(ilk + timedelta(days=n)).isoformat()] = {"lunch": gun_icerigi(kalemler)}
    return sonuc


class AfyonKocatepe(Universite):
    id = "aku"
    ad = "Afyon Kocatepe Üniversitesi"
    kisa = "AKÜ"
    sehir = "Afyonkarahisar"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("Afyon Kocatepe: SKS yemek listesi indirilemedi: %s" % e) from e
        url = pdf_baglantisi(sayfa)
        if not url:
            raise RuntimeError("Afyon Kocatepe: güncel yemek PDF bağlantısı bulunamadı")
        try:
            sonuc = pdf_menu(self.indir(url))
        except Exception as e:
            raise RuntimeError("Afyon Kocatepe: yemek PDF'i okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("Afyon Kocatepe: PDF'te tarih aralıklı menü bulunamadı")
        return sonuc
