"""OKÜ: tarih, dört yemek ve toplam kalorili aylık HTML. Son dolu ay alınır."""
import re
from ..model import etiket_temizle
from ._son_ortak import HtmlUniversitesi, oge, son_ay, tarih

SAYFA_URL = "https://www6.osmaniye.edu.tr/yemekmenu"


def sayfa_menu(sayfa):
    sonuc = {}
    tablo = re.search(r'<table\b[^>]*id="yemek"[^>]*>(.*?)</table>', sayfa, re.S)
    for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", tablo[1] if tablo else "", re.S):
        h = re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S)
        t = tarih(h[0]) if len(h) == 6 else None
        if not t:
            continue
        items = [o for o in (oge(x) for x in h[1:5]) if o]
        if not items:
            continue
        menu = {"items": items}
        toplam = etiket_temizle(h[5])
        if toplam.isdigit() and int(toplam) > 0:
            menu["kcal"] = int(toplam)
        sonuc[t.isoformat()] = {"lunch": menu}
    return son_ay(sonuc)


class OsmaniyeKorkutAta(HtmlUniversitesi):
    id, ad, kisa, sehir = "osmaniye", "Osmaniye Korkut Ata Üniversitesi", "OKÜ", "Osmaniye"
    kaynak = SAYFA_URL
    ayristir = staticmethod(sayfa_menu)
