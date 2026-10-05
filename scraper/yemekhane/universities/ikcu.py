"""İzmir Katip Çelebi Üniversitesi: menü ikcu.edu.tr/yemeklistesi sayfasında yalnızca bugün ve yarın için, yılsız bir tarihle ('05' + 'Ekim') yayınlanıyor.
Her günde 'Ana Menü' (öğle) ve çoğu günde 'Vejetaryen Menü' listesi vardır; kalori yok. Sayfa geçmişi tutmadığı için eklenti `birikimli`dir
(önceki çalıştırmalarda okunan günler korunur).
"""
import re
from datetime import date

from ..model import ay_no, baslik_yap_serbest, bugun_tr, etiket_temizle, gun_icerigi, kisaltma_ac, yil_sec
from .base import Universite, indir

SAYFA_URL = "https://ikcu.edu.tr/yemeklistesi"


def menu_turu(baslik: str):
    b = baslik.replace("İ", "i").replace("I", "ı").lower()
    if "vejetaryen" in b or "vegan" in b:
        return "vegetarian"
    if "ana" in b:
        return "lunch"
    return None


def sayfa_menu(sayfa: str, bugun: date) -> dict:
    """{'2026-10-05': {'lunch': {...}, 'vegetarian': {...}}, ...}; yıl, bugüne en yakın yıl olarak seçilir."""
    sonuc = {}
    for blok in re.split(r'<div class="yemek-date">', sayfa)[1:]:
        gun = re.search(r'yemek-date-day">\s*(\d{1,2})\s*<', blok)
        ay = re.search(r'yemek-date-month">\s*(\S+)\s*<', blok)
        no = ay_no(ay.group(1)) if ay else None
        tarih = yil_sec(int(gun.group(1)), no, bugun) if gun and no else None
        if tarih is None:
            continue
        for liste in re.findall(r'<ul class="yemek-listesi">(.*?)</ul>', blok, re.S):
            satirlar = [etiket_temizle(li) for li in re.findall(r"<li[^>]*>(.*?)</li>", liste, re.S)]
            tur = menu_turu(satirlar[0]) if satirlar else None
            ogeler = [{"name": baslik_yap_serbest(kisaltma_ac(s))} for s in satirlar[1:] if s]
            if tur and ogeler:
                sonuc.setdefault(tarih.isoformat(), {})[tur] = gun_icerigi(ogeler)
    return sonuc


class IzmirKatipCelebi(Universite):
    id = "ikcu"
    ad = "İzmir Katip Çelebi Üniversitesi"
    kisa = "İKÇÜ"
    sehir = "İzmir"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"), self.bugun or bugun_tr())
