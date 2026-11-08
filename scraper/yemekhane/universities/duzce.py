"""Düzce: yemek-menusu sayfasında data-menu-date tarihli aylık HTML kartları.
Ana yemek seçenekleri tek öğle listesinde korunur; 'veya' ayıracı yemek
adına katılmaz. Kaynak bunları vejetaryen öğün olarak etiketlemez. Kalori yok.
"""
import re
from datetime import date

from ..model import baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://duzce.edu.tr/sayfa/1B29/yemek-menusu"


def yemek_adi(metin: str) -> str:
    metin = re.sub(r"\bbarbunya\s+p\.", "barbunya pilaki", metin, flags=re.I)
    metin = re.sub(r"\bplilaki\b", "pilaki", metin, flags=re.I)
    metin = re.sub(r"\bnap\.", "napoliten", metin, flags=re.I)
    return baslik_yap_serbest(kisaltma_ac(metin.strip(" .-")))


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for tarih_metni, govde in re.findall(r'<article\b[^>]*\bdata-menu-date="(\d{4}-\d{2}-\d{2})"[^>]*>(.*?)</article>', sayfa, re.S):
        try:
            tarih = date.fromisoformat(tarih_metni)
        except ValueError:
            continue
        ogeler = []
        for li in re.findall(r"<li\b[^>]*>(.*?)</li>", govde, re.S):
            li = re.sub(r'<span\b[^>]*class="choice-divider"[^>]*>.*?</span>', "", li, flags=re.S)
            ad = yemek_adi(etiket_temizle(li))
            if ad:
                ogeler.append({"name": ad})
        if not ogeler:
            continue
        if all("tatil" in o["name"].lower() for o in ogeler):
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogun = gun_icerigi(ogeler)
        sonuc[tarih.isoformat()] = {"lunch": ogun}
    return sonuc


class DuzceUniversitesi(Universite):
    id = "duzce"
    ad = "Düzce Üniversitesi"
    kisa = "DÜ"
    sehir = "Düzce"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("Düzce: aylık yemek menüsü indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Düzce: data-menu-date içeren yemek kartı bulunamadı")
        return sonuc
