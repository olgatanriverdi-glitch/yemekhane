"""Bitlis Eren: 10 günlük liste sayfasının tarihli HTML satırları."""
import re
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL='https://www.beu.edu.tr/YemekListesi'


def sayfa_menu(sayfa):
    sonuc={}
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',sayfa,re.S):
        h=re.findall(r'<td\b[^>]*>(.*?)</td>',row,re.S)
        t=tarih(h[0]) if len(h)==7 else None
        if not t:
            continue
        items=[o for o in (oge(x) for x in h[1:]) if o]
        if items:
            sonuc[t.isoformat()]={'lunch':{'items':items}}
    return sonuc


class BitlisEren(HtmlUniversitesi):
    id,ad,kisa,sehir='bitlis','Bitlis Eren Üniversitesi','BEÜ','Bitlis'
    kaynak=SAYFA_URL
    birikimli=True
    ayristir=staticmethod(sayfa_menu)
