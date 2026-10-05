"""Ondokuz Mayıs Üniversitesi (Samsun): günün menüsü her sayfada bulunan 'Günün Yemeği' penceresinde, içinde tüm ayı gösteren bir tablo olarak
yayınlanıyor: 'TARİH | 1.YEMEK | 2.YEMEK | 3.YEMEK | 4.YEMEK' (hafta sonu ve tatil satırları boş). Tek öğün (öğle) yayınlanır; kalori ve fiyat yok.
"""
import re
from datetime import date

from ..model import baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.omu.edu.tr/tr/omude-yasam/beslenme"


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-10-01': {'lunch': {'items': [{'name': 'Brokoli Çorba'}, ...]}}, ...}; boş (hafta sonu/tatil) satırlar atlanır."""
    tablo = re.search(r"<table class='gununyemegi'.*?</table>", sayfa, re.S)
    sonuc = {}
    for satir in re.findall(r"<tr>(.*?)</tr>", tablo.group(0) if tablo else "", re.S):
        hucreler = [etiket_temizle(h) for h in re.findall(r"<td[^>]*>(.*?)</td>", satir, re.S)]
        m = re.fullmatch(r"(\d{2})\.(\d{2})\.(\d{4})", hucreler[0]) if hucreler else None
        ogeler = [{"name": baslik_yap_serbest(kisaltma_ac(h))} for h in hucreler[1:] if h]
        if m and ogeler:
            try:
                sonuc[date(int(m.group(3)), int(m.group(2)), int(m.group(1))).isoformat()] = {"lunch": gun_icerigi(ogeler)}
            except ValueError:
                pass
    return sonuc


class OndokuzMayis(Universite):
    id = "omu"
    ad = "Ondokuz Mayıs Üniversitesi"
    kisa = "OMÜ"
    sehir = "Samsun"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
