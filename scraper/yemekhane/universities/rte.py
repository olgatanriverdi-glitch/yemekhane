"""RTEÜ: tarihli günlük HTML tablosu, birikimli."""
import re
from datetime import date
from ..model import etiket_temizle, gun_icerigi
from ._son_ortak import HtmlUniversitesi, oge

SAYFA_URL='https://erdogan.edu.tr/Website/Contents.aspx?LangID=1&PageID=1156'


def sayfa_menu(sayfa):
    sonuc={}
    for tablo in re.findall(r'<table\b.*?</table>',sayfa,re.S):
        m=re.search(r'<caption\b[^>]*>\s*(\d{4}-\d{2}-\d{2})\s+Tarihli Yemek Listesi',tablo)
        if not m:
            continue
        try:
            t=date.fromisoformat(m[1])
        except ValueError:
            continue
        items=[]
        for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',tablo,re.S):
            h=re.findall(r'<td\b[^>]*>(.*?)</td>',row,re.S)
            o=oge(h[0]) if len(h)==3 else None
            if o:
                k=re.fullmatch(r'(\d+)(?:,00)?',etiket_temizle(h[2]))
                if k and int(k[1])>0:
                    o['kcal']=int(k[1])
                items.append(o)
        if items:
            sonuc[t.isoformat()]={'lunch':gun_icerigi(items)}
    return sonuc


class RecepTayyipErdogan(HtmlUniversitesi):
    id,ad,kisa,sehir='rte','Recep Tayyip Erdoğan Üniversitesi','RTEÜ','Rize'
    kaynak=SAYFA_URL
    birikimli=True
    ayristir=staticmethod(sayfa_menu)
