"""Eskişehir Osmangazi Üniversitesi: menü yemekhane.ogu.edu.tr sitesinde HTML olarak yayınlanıyor (5 haftalık, yalnızca hafta içi).
  /Menu/1  Öğle/Akşam Yemeği - Standart Menü (öğle ve akşam aynı liste)
  /Menu/2  Öğle Yemeği - Vejetaryen Menü
  /Menu/3  Öğle Yemeği - Glutensiz Menü (uygulamada karşılığı olmadığı için alınmıyor)
Her hafta `<div class="row" id="20260928-20261004">` içinde gün panelleri bulunur; yemekler 'ADI Karbonhidrat: 18 gr' + '(175 kcal)' biçimindedir.
Tatil günlerinde panelde 'Tatil: Cumhuriyet Bayramı' yazar. Okulun sayfasında öğrenci ücreti ve servis saati yayınlanmıyor.
"""
import copy
import html
import re
from datetime import date, timedelta

from ..model import baslik_yap_serbest
from .base import Universite, indir

BASE = "https://yemekhane.ogu.edu.tr/"
GUNLER = {"pazartesi": 0, "salı": 1, "çarşamba": 2, "perşembe": 3, "cuma": 4, "cumartesi": 5, "pazar": 6}


def _kucuk(metin: str) -> str:
    return metin.replace("İ", "i").replace("I", "ı").lower()


def temiz(h: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", h)).replace("\xa0", " ")).strip()


def yemek_ogeleri(ad_html: str, kalori_html: str) -> list:
    """('ÇORBA Karbonhidrat: 18 gr', '(175 kcal)') -> [{'name': 'Çorba', 'kcal': 175}]; 'A/ B' iki öğe olur (kalori verilemez)."""
    ad = temiz(ad_html)
    ad = re.sub(r"\s*Karbonhidrat\s*:?.*$", "", ad, flags=re.I)         # '... Karbonhidrat: 18 gr' eki
    ad = re.sub(r"\s*\((yaz|kış)\)", "", ad, flags=re.I)                # 'Mevsim Salata (Yaz)'
    parcalar = [p.strip() for p in ad.split("/") if p.strip()]
    k = re.search(r"\((\d+)\s*kcal\)", kalori_html or "", re.I)
    if len(parcalar) == 1:
        oge = {"name": baslik_yap_serbest(parcalar[0])}
        if k and int(k.group(1)) > 0:
            oge["kcal"] = int(k.group(1))
        return [oge]
    return [{"name": baslik_yap_serbest(p)} for p in parcalar]


def gun_icerigi(ogeler: list) -> dict:
    gun = {"items": ogeler}
    if ogeler and all("kcal" in o for o in ogeler):
        gun["kcal"] = sum(o["kcal"] for o in ogeler)
    return gun


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-10-05': {'items': [...], 'kcal': n} | {'items': [], 'note': 'Tatil: ...'}}"""
    sonuc = {}
    for hafta in re.finditer(r'<div class="row" id="(\d{8})-(\d{8})">(.*?)(?=<div class="row" id="\d{8}-\d{8}">|<footer|\Z)', sayfa, re.S):
        bas = date(int(hafta.group(1)[:4]), int(hafta.group(1)[4:6]), int(hafta.group(1)[6:]))
        son = date(int(hafta.group(2)[:4]), int(hafta.group(2)[4:6]), int(hafta.group(2)[6:]))
        haftagunu = {}
        d = bas
        while d <= son:
            haftagunu[d.weekday()] = d
            d += timedelta(days=1)
        for panel in re.split(r'(?=<div class="col-md-2)', hafta.group(3))[1:]:
            baslik = re.search(r'yemek-menu-ay">\s*(.*?)\s*</span>', panel, re.S)
            if not baslik:
                continue
            m = re.match(r"(\d{1,2})\s+\S+\s+(\S+)", temiz(baslik.group(1)))
            tarih = haftagunu.get(GUNLER.get(_kucuk(m.group(2)))) if m else None
            if tarih is None or tarih.day != int(m.group(1)):
                continue
            tatil = re.search(r'yemek-menu-tatil">(.*?)</p>', panel, re.S)
            if tatil:
                sonuc[tarih.isoformat()] = {"items": [], "note": temiz(tatil.group(1))}
                continue
            ogeler = []
            for li in re.findall(r"<li>(.*?)</li>", panel, re.S):
                ad = re.search(r'<span class="yemek-menu-yemek">(.*?)</span>', li, re.S)
                if ad:
                    kalori = re.search(r'<span class="yemek-menu-kalori[^"]*">(.*?)</span>', li, re.S)
                    ogeler += yemek_ogeleri(ad.group(1), kalori.group(1) if kalori else "")
            if ogeler:
                sonuc[tarih.isoformat()] = gun_icerigi(ogeler)
    return sonuc


class EskisehirOsmangazi(Universite):
    id = "esogu"
    ad = "Eskişehir Osmangazi Üniversitesi"
    kisa = "ESOGÜ"
    sehir = "Eskişehir"
    kaynak = BASE

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        sonuc = {}
        for tarih, gun in sayfa_menu(self.indir(BASE + "Menu/1").decode("utf-8", "ignore")).items():
            # öğle ve akşam yemeği aynı liste; tatilde her iki öğün de boş
            sonuc[tarih] = {"lunch": gun, "dinner": copy.deepcopy(gun)}
        try:
            for tarih, gun in sayfa_menu(self.indir(BASE + "Menu/2").decode("utf-8", "ignore")).items():
                if tarih in sonuc and gun["items"]:
                    sonuc[tarih]["vegetarian"] = gun
        except Exception as e:
            print("UYARI: ESOGÜ vejetaryen menüsü alınamadı:", e)
        return sonuc
