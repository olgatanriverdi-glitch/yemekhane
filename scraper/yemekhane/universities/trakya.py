"""Trakya: Merkez Kampüsler aylık HTML kartları, tek öğün (öğle).
Kalori yemek başına değil, kartın sonundaki öğün toplamıdır. Hastanenin ve
ilçe kampüslerinin menüleri alınmaz; ana adres varsayılan merkez listesidir.
"""
import re
from datetime import date

from ..model import baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.trakya.edu.tr/yemeklistesi"


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for kart in re.split(r'<div\b[^>]*class="[^"]*\bmitem\b[^"]*"[^>]*>', sayfa)[1:]:
        h = re.search(r"<h4\b[^>]*>\s*(\d{1,2})\.(\d{1,2})\.(\d{4})\s*</h4>", kart)
        if not h:
            continue
        try:
            tarih = date(int(h.group(3)), int(h.group(2)), int(h.group(1)))
        except ValueError:
            continue
        govde = re.split(r"<small\b|</div>", kart[h.end():], maxsplit=1)[0]
        adlar = [etiket_temizle(a).strip(" .-") for a in re.split(r"<br\s*/?>", govde)]
        ogeler = [{"name": baslik_yap_serbest(kisaltma_ac(a))} for a in adlar if a]
        if not ogeler:
            continue
        if all("tatil" in o["name"].lower() for o in ogeler):
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogun = {"items": ogeler}
            k = re.search(r"<small\b[^>]*>\s*(\d+)\s*Kal\s*</small>", kart, re.I)
            if k and int(k.group(1)) > 0:
                ogun["kcal"] = int(k.group(1))
        sonuc[tarih.isoformat()] = {"lunch": ogun}
    return sonuc


class TrakyaUniversitesi(Universite):
    id = "trakya"
    ad = "Trakya Üniversitesi"
    kisa = "TÜ"
    sehir = "Edirne"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("Trakya: merkez kampüs yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Trakya: aylık merkez kampüs menüsü bulunamadı")
        return sonuc
