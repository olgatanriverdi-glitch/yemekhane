"""Alanya Alaaddin Keykubat Üniversitesi (Antalya): menü sksdb.alanya.edu.tr 'ALKÜ Yemek Menüsü' sayfasında yalnızca içinde bulunulan haftanın hafta içi günleri
için bir slayt (carousel) olarak yayınlanıyor: `<h4>05 Ekim 2026 Pazartesi</h4>` ve her yemek `<h6>Mercimek çorbası (166 kkal)</h6>`.
Eski haftalar sayfadan kalktığı için eklenti `birikimli`dir: önceki çalıştırmalarda okunan günler korunur.
"""
import re
from datetime import date

from ..model import ay_no, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sksdb.alanya.edu.tr/hizmetlerimiz/beslenme-hizmetleri/alku-yemek-menusu/"
KALORI = re.compile(r"\(\s*(\d+)\s*kkal\s*\)", re.I)


def oge_yap(metin: str):
    m = KALORI.search(metin)
    ad = KALORI.sub("", metin).strip(" /-–")
    if not ad:
        return None
    oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
    if m and int(m.group(1)) > 0:
        oge["kcal"] = int(m.group(1))
    return oge


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-10-05': {'lunch': {'items': [{'name': 'Mercimek Çorbası', 'kcal': 166}, ...], 'kcal': 779}}, ...}"""
    sonuc = {}
    for blok in re.findall(r'<div class="carousel-item[^"]*"[^>]*>(.*?)(?=<div class="carousel-item|</div>\s*</div>|\Z)', sayfa, re.S):
        baslik = re.search(r"<h4[^>]*>(.*?)</h4>", blok, re.S)
        m = re.match(r"(\d{1,2})\s+(\S+)\s+(\d{4})", etiket_temizle(baslik.group(1))) if baslik else None
        ay = ay_no(m.group(2)) if m else None
        if not ay:
            continue
        ogeler = [o for o in (oge_yap(etiket_temizle(h)) for h in re.findall(r"<h6[^>]*>(.*?)</h6>", blok, re.S)) if o]
        if ogeler:
            try:
                sonuc[date(int(m.group(3)), ay, int(m.group(1))).isoformat()] = {"lunch": gun_icerigi(ogeler)}
            except ValueError:
                pass
    return sonuc


class AlanyaAlaaddinKeykubat(Universite):
    id = "alku"
    ad = "Alanya Alaaddin Keykubat Üniversitesi"
    kisa = "ALKÜ"
    sehir = "Antalya"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
