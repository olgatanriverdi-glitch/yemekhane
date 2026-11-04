"""Batman: öğrenci sekmesindeki aylık tarihli card-food HTML kartları."""
import re
from ..model import gun_icerigi
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL='https://batman.edu.tr/yemek-listesi'


def sayfa_menu(sayfa):
    sonuc={}
    for kart in re.split(r'<div\b[^>]*class="card-food(?:\s[^\"]*)?"[^>]*>',sayfa)[1:]:
        t=tarih(kart.split('class="card-food-right"',1)[0])
        liste=re.search(r'<ul\b[^>]*class="list-group"[^>]*>(.*?)</ul>',kart,re.S)
        if not t or not liste:
            continue
        items=[o for o in (oge(re.sub(r'\bTERB\.','Terbiyeli',li)) for li in re.findall(r'<li\b[^>]*>(.*?)</li>',liste[1],re.S)) if o]
        if items:
            sonuc[t.isoformat()]={'lunch':gun_icerigi(items)}
    return sonuc


class BatmanUniversitesi(HtmlUniversitesi):
    id,ad,kisa,sehir='batman','Batman Üniversitesi','BATÜ','Batman'
    kaynak=SAYFA_URL
    birikimli=True
    ayristir=staticmethod(sayfa_menu)
