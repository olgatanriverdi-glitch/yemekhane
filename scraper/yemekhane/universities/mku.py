"""Hatay Mustafa Kemal: öğrenci yemekhanesinin aylık HTML kartları.

Havuzbaşı restoranı ayrı kaynaktır ve alınmaz. Tek yemekhane listesi öğle
sayılır; kalem kalorileri ve kartta yazılı günlük toplam korunur.
"""
import re
from datetime import date

from ..model import TR_KUCUK, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://yemekgosterim.mku.edu.tr/home/yemekhane"


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for kart in re.split(r'<div\b[^>]*class=[\'"]menu-card[\'"][^>]*>', sayfa, flags=re.I)[1:]:
        t = re.search(r'<div\b[^>]*class=[\'"]tarih[\'"][^>]*>\s*(\d{1,2})\.(\d{1,2})\.(\d{4})\s*</div>', kart, re.I)
        if not t:
            continue
        try:
            tarih = date(int(t.group(3)), int(t.group(2)), int(t.group(1))).isoformat()
        except ValueError:
            continue
        liste = re.search(r'<ul\b[^>]*class=[\'"]menu-list[\'"][^>]*>(.*?)</ul>', kart, re.S | re.I)
        if not liste:
            continue
        ogeler = []
        for li in re.findall(r"<li\b[^>]*>(.*?)</li>", liste.group(1), re.S | re.I):
            metin = etiket_temizle(li)
            k = re.search(r"\s*\((\d+)\s*kcal\)\s*$", metin, re.I)
            ad = (metin[:k.start()] if k else metin).strip(" .-–")
            if not ad:
                continue
            oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
            if k and int(k.group(1)) > 0:
                oge["kcal"] = int(k.group(1))
            ogeler.append(oge)
        if not ogeler:
            continue
        if all("tatil" in o["name"].translate(TR_KUCUK).lower() for o in ogeler):
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogun = gun_icerigi(ogeler)
            toplam = re.search(r"<strong\b[^>]*>\s*(\d+)\s*kcal\s*</strong>", kart, re.I)
            if toplam and int(toplam.group(1)) > 0:
                ogun["kcal"] = int(toplam.group(1))
        if tarih in sonuc and sonuc[tarih] != {"lunch": ogun}:
            raise ValueError("Hatay Mustafa Kemal: %s için çelişen menüler var" % tarih)
        sonuc[tarih] = {"lunch": ogun}
    return sonuc


class HatayMustafaKemal(Universite):
    id = "mku"
    ad = "Hatay Mustafa Kemal Üniversitesi"
    kisa = "HMKÜ"
    sehir = "Hatay"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("Hatay Mustafa Kemal: aylık yemekhane listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Hatay Mustafa Kemal: tarihli aylık yemekhane menüsü bulunamadı")
        return sonuc
