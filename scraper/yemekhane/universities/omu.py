"""OMÜ: Günün Yemeği penceresinin dikey tarih/yemek tablosu, birikimli.
Eski aylık yatay tablo da okunur. Tek öğün (öğle); kalori/fiyat yok.
"""
import re
from datetime import date

from ..model import baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.omu.edu.tr/tr/omude-yasam/beslenme"


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-10-01': {'lunch': {'items': [{'name': 'Brokoli Çorba'}, ...]}}, ...}; boş (hafta sonu/tatil) satırlar atlanır."""
    tablo = re.search(r'''<table\b[^>]*class=["']gununyemegi["'][^>]*>.*?</table>''', sayfa, re.S)
    sonuc = {}
    dikey_tarih, dikey_ogeler = None, []
    for satir in re.findall(r"<tr>(.*?)</tr>", tablo.group(0) if tablo else "", re.S):
        hucreler = [etiket_temizle(h) for h in re.findall(r"<td[^>]*>(.*?)</td>", satir, re.S)]
        m = re.fullmatch(r"(\d{2})\.(\d{2})\.(\d{4})", hucreler[0]) if hucreler else None
        ogeler = [{"name": baslik_yap_serbest(kisaltma_ac(h))} for h in hucreler[1:] if h]
        if len(hucreler) == 2 and hucreler[0].strip().lower() == 'tarih':
            try:
                dikey_tarih = date.fromisoformat('-'.join(reversed(hucreler[1].split('.')))).isoformat()
            except ValueError:
                pass
        elif len(hucreler) == 2 and re.fullmatch(r'Yemek\s*\d+', hucreler[0], re.I) and hucreler[1]:
            dikey_ogeler += ogeler
        if m and ogeler:
            try:
                sonuc[date(int(m.group(3)), int(m.group(2)), int(m.group(1))).isoformat()] = {"lunch": gun_icerigi(ogeler)}
            except ValueError:
                pass
    if dikey_tarih and dikey_ogeler:
        sonuc[dikey_tarih] = {'lunch': gun_icerigi(dikey_ogeler)}
    return sonuc


class OndokuzMayis(Universite):
    id = "omu"
    ad = "Ondokuz Mayıs Üniversitesi"
    kisa = "OMÜ"
    sehir = "Samsun"
    kaynak = SAYFA_URL
    birikimli = True  # Yeni sayfa yalnız günün listesini verir; eski aylık biçim de okunur.

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
