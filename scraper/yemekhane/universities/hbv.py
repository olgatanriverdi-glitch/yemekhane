"""Ankara Hacı Bayram Veli Üniversitesi: günlük menü yemek.hacibayram.edu.tr sayfasında yayınlanıyor; sayfa verisini
`/load-menu` adresinden JSON olarak çekiyor: [{"menu_date": "2026-10-01", "food_list": ["Yayla Çorba (105 Kcal)", ...], "total_calorie": 976}, ...].
Hafta içi tek öğün (öğle) yayınlanır; hafta sonu ve tatil günleri listede yoktur.
"""
import json
import re

from .base import Universite, indir

SAYFA_URL = "https://yemek.hacibayram.edu.tr/"
MENU_URL = SAYFA_URL + "load-menu"
# Öğrenci ücreti yalnızca PDF olarak yayınlanıyor (hacibayram.edu.tr/sks/yemekhane -> 'Yemek Ücretleri'): "17.08.2026 tarihinden itibaren: öğrenci 50 TL".
# Okul ücreti değiştirince burası elle güncellenmeli.
OGRENCI_UCRETI = 50

OGE = re.compile(r"^(.*?)\s*\(\s*(\d+)\s*k\s*cal\s*\)\s*$", re.I)       # 'Yayla Çorba (105 Kcal)'


def yemek_ogesi(metin: str):
    metin = re.sub(r"\s+", " ", (metin or "").replace("\xa0", " ")).strip()
    m = OGE.match(metin)
    ad, kcal = (m.group(1), int(m.group(2))) if m else (metin, None)
    ad = re.sub(r"\s*\+\s*", " + ", ad).strip(" /-")
    if not ad:
        return None
    oge = {"name": ad}
    if kcal:
        oge["kcal"] = kcal
    return oge


def sayfa_menu(govde: str) -> dict:
    """{'2026-10-01': {'lunch': {'items': [...], 'kcal': 976}}, ...}"""
    sonuc = {}
    for kayit in json.loads(govde):
        tarih = (kayit.get("menu_date") or "")[:10]
        ogeler = [o for o in (yemek_ogesi(y) for y in kayit.get("food_list") or []) if o]
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", tarih) or not ogeler:
            continue
        gun = {"items": ogeler}
        if all("kcal" in o for o in ogeler):
            gun["kcal"] = sum(o["kcal"] for o in ogeler)
        sonuc[tarih] = {"lunch": gun}
    return sonuc


class HaciBayramVeli(Universite):
    id = "hbv"
    ad = "Ankara Hacı Bayram Veli Üniversitesi"
    kisa = "AHBVÜ"
    sehir = "Ankara"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(MENU_URL).decode("utf-8", "ignore"))

    def fiyatlar(self) -> list:
        return [{"label": "Öğrenci (Öğle Yemeği)", "tl": OGRENCI_UCRETI}]
