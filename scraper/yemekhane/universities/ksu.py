"""KSÜ: yemeklistesi sitesindeki aylık article kartları; dört kalem, öğle."""
import re
from ..model import gun_icerigi
from ._son_ortak import HtmlUniversitesi, oge, son_ay, tarih

SAYFA_URL = "https://yemeklistesi.ksu.edu.tr/"


def sayfa_menu(sayfa):
    sonuc = {}
    for kart in re.findall(r"<article\b[^>]*>(.*?)</article>", sayfa, re.S):
        h = re.search(r"<h4\b[^>]*>(.*?)</h4>", kart, re.S)
        t = tarih(h[1]) if h else None
        if not t:
            continue
        items = [o for o in (oge(x) for x in re.findall(r"<li\b[^>]*>(.*?)</li>", kart, re.S)) if o]
        if items:
            sonuc[t.isoformat()] = {"lunch": gun_icerigi(items)}
    return son_ay(sonuc)


class KahramanmarasSutcuImam(HtmlUniversitesi):
    id, ad, kisa, sehir = "ksu", "Kahramanmaraş Sütçü İmam Üniversitesi", "KSÜ", "Kahramanmaraş"
    kaynak = SAYFA_URL
    ayristir = staticmethod(sayfa_menu)
