"""Hacettepe Üniversitesi: menü H.Ü. Beslenme Bilgi Sistemi'nde (beslenme.hacettepe.edu.tr) gün gün yayınlanıyor.

Sayfa `?date=YYYY-MM-DD&location_id=N` ile açılır; her gün için kahvaltı (sabah), öğle, akşam ve vegan bölümü vardır.
Yemekler `data-title / data-cal / data-category` özellikli kartlar, kahvaltı ise madde listesidir. İki kampüsün (Beytepe=1, Sıhhiye=2) menüsü aynıdır.
Menü yayınlanmamış günlerde kart yoktur ("Planlanmadı").
"""
import html
import re
import time
from datetime import date, timedelta

from .base import Universite, indir

BASE = "https://beslenme.hacettepe.edu.tr/"
ILERI_GUN = 40
GERI_GUN = 2
ART_ARDA_BOS = 10      # menü bittiyse bu kadar boş gün üst üste görünce dur

BOLUMLER = {"sabah": "breakfast", "ogle": "lunch", "aksam": "dinner", "vegan": "vegetarian"}
KISALTMALAR = [
    (re.compile(r"\bKaş\.\s*", re.I), "Kaşarlı "),
    (re.compile(r"\bKıy\.\s*", re.I), "Kıymalı "),
    (re.compile(r"\bZyt\.\s*", re.I), "Zeytinyağlı "),
    (re.compile(r"\bPat\.\s*", re.I), "Patates "),
]


def gun_url(tarih: str, kampus: int = 1) -> str:
    return "%s?date=%s&location_id=%d" % (BASE, tarih, kampus)


def yemek_adi(metin: str) -> str:
    metin = html.unescape(metin).replace("\xa0", " ")
    for kalip, yerine in KISALTMALAR:
        metin = kalip.sub(yerine, metin)
    return re.sub(r"\s+", " ", metin).strip()


def sayfa_gun(sayfa: str) -> dict:
    """Bir günün sayfasından {'lunch': {'items': [...], 'kcal': n}, ...}; menü yoksa {}."""
    gun = {}
    for m in re.finditer(r'<section id="(\w+)" class="tab-content[^"]*">(.*?)</section>', sayfa, flags=re.S):
        sid, govde = m.groups()
        tur = BOLUMLER.get(sid)
        if not tur:
            continue
        ogeler = []
        for kart in re.findall(r'<div class="menu-card"[^>]*>', govde, flags=re.S):
            ad = re.search(r'data-title="([^"]*)"', kart)
            if not ad or not yemek_adi(ad.group(1)):
                continue
            oge = {"name": yemek_adi(ad.group(1))}
            kal = re.search(r'data-cal="(\d+)"', kart)
            if kal and int(kal.group(1)) > 0:
                oge["kcal"] = int(kal.group(1))
            ogeler.append(oge)
        if not ogeler:     # kahvaltı: kart yok, madde listesi var
            liste = re.search(r'<ul class="kahvalti-items">(.*?)</ul>', govde, flags=re.S)
            if liste:
                for li in re.findall(r"<li>(.*?)</li>", liste.group(1), flags=re.S):
                    ad = yemek_adi(re.sub(r"<[^>]+>", "", li))
                    if ad:
                        ogeler.append({"name": ad})
        if not ogeler:
            continue
        veri = {"items": ogeler}
        if all("kcal" in o for o in ogeler):
            veri["kcal"] = sum(o["kcal"] for o in ogeler)
        gun[tur] = veri
    return gun


class HacettepeUniversitesi(Universite):
    id = "hacettepe"
    ad = "Hacettepe Üniversitesi"
    kisa = "HÜ"
    sehir = "Ankara"
    kaynak = BASE

    def __init__(self, indirici=indir, bugun=None, bekle=0.25):
        self.indir = indirici
        self.bugun = bugun
        self.bekle = bekle

    def menuler(self) -> dict:
        bugun = self.bugun or date.today()
        sonuc, bos = {}, 0
        for k in range(-GERI_GUN, ILERI_GUN + 1):
            tarih = (bugun + timedelta(days=k)).isoformat()
            try:
                gun = sayfa_gun(self.indir(gun_url(tarih)).decode("utf-8", "ignore"))
            except Exception as e:
                print("UYARI: Hacettepe %s alınamadı: %s" % (tarih, e))
                continue
            finally:
                if self.bekle:
                    time.sleep(self.bekle)
            if any(t in gun for t in ("lunch", "dinner", "vegetarian")):      # yalnızca şablon kahvaltı olan günler 'menü yok' sayılır
                sonuc[tarih] = gun
                bos = 0
            else:
                bos += 1
                if sonuc and bos >= ART_ARDA_BOS:
                    break
        return sonuc

    def fiyatlar(self) -> list:
        return []      # öğrenci ücreti yalnızca resim/PDF olarak yayınlanıyor, güvenle okunamıyor
