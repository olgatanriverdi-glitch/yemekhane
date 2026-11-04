"""Süleyman Demirel Üniversitesi: w3.sdu.edu.tr/aylik-yemek-listesi (yemekhane.sdu.edu.tr buraya yönlenir) 'Tarih / Öğle / Akşam' sütunlu aylık tablo verir.
Tarih hücresi `<span>01.10.2026</span><br><span>Perşembe</span>`, öğün hücresi `<span>ÇORBA<br/>ANA YEMEK<br/>PİLAV<br/>AYRAN</span><span><br> (1000 kcal)</span>`:
parantezdeki kalori öğünün toplamıdır (kalem kalorisi yoktur). Menü yayınlanmayan günlerde ('-<br/>-<br/>-<br/>-', '(- kcal)') öğün atlanır. Öğle -> lunch, Akşam -> dinner.
"""
import re
from datetime import date

from ..model import baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://w3.sdu.edu.tr/aylik-yemek-listesi"


def ogun_icerigi(hucre: str):
    """Hücre HTML'i -> {'items': [...], 'kcal': N}; boş/'-' hücrede None."""
    govde = re.search(r"<span>(.*?)</span>", hucre, re.S)
    if not govde:
        return None
    adlar = [etiket_temizle(a).strip(" .-") for a in re.split(r"<br\s*/?>", govde.group(1))]
    ogeler = [{"name": baslik_yap_serbest(kisaltma_ac(a))} for a in adlar if a]
    if not ogeler:
        return None
    gun = {"items": ogeler}
    k = re.search(r"\(\s*(\d+)\s*kcal\s*\)", hucre)
    if k:
        gun["kcal"] = int(k.group(1))
    return gun


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for satir in re.findall(r"<tr>(.*?)</tr>", sayfa, re.S):
        hucreler = re.findall(r"<td>(.*?)</td>", satir, re.S)
        if len(hucreler) < 2:
            continue
        d = re.search(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", hucreler[0])
        if not d:
            continue
        try:
            tarih = date(int(d.group(3)), int(d.group(2)), int(d.group(1)))
        except ValueError:
            continue
        for tur, hucre in zip(("lunch", "dinner"), hucreler[1:3]):
            ogun = ogun_icerigi(hucre)
            if ogun:
                sonuc.setdefault(tarih.isoformat(), {})[tur] = ogun
    return sonuc


class SuleymanDemirel(Universite):
    id = "sdu"
    ad = "Süleyman Demirel Üniversitesi"
    kisa = "SDÜ"
    sehir = "Isparta"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
