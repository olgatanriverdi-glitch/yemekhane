"""Yozgat Bozok: aylık özet HTML; gluten yıldızları yemek adına alınmaz."""
import re
from ..model import etiket_temizle
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL='https://yemek.bozok.edu.tr/'


def sayfa_menu(sayfa):
    sonuc={}
    for tablo in re.findall(r'<table\b[^>]*class="uf-table uf-table-week"[^>]*>(.*?)</table>',sayfa,re.S):
        for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',tablo,re.S):
            h=re.findall(r'<td\b[^>]*>(.*?)</td>',row,re.S)
            t=tarih(h[0]) if len(h)==7 else None
            if not t:
                continue
            items=[o for o in (oge(re.sub(r'<span\b[^>]*class="uf-star"[^>]*>.*?</span>','',x,flags=re.S)) for x in h[1:6]) if o]
            if items:
                menu={'items':items}
                k=re.search(r'(\d+)\s*kcal',etiket_temizle(h[-1]))
                if k:
                    menu['kcal']=int(k[1])
                sonuc[t.isoformat()]={'lunch':menu}
    return sonuc


class YozgatBozok(HtmlUniversitesi):
    id,ad,kisa,sehir='bozok','Yozgat Bozok Üniversitesi','YOBÜ','Yozgat'
    kaynak=SAYFA_URL
    birikimli=True
    ayristir=staticmethod(sayfa_menu)
