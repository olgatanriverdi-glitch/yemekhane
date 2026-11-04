"""KMÜ: başlıkta yıl/ay, satırdaki erişilebilir tarih ve dört yemekli HTML."""
import re
from datetime import date
from ..model import ay_no,etiket_temizle
from ._son_ortak import HtmlUniversitesi,oge

SAYFA_URL='https://kmu.edu.tr/yemekhane'


def sayfa_menu(sayfa):
    baslik=re.search(r'<h1\b[^>]*>(.*?)</h1>',sayfa,re.S)
    m=re.search(r'(\d{4})\s+Yılı\s+(\S+)\s+Ayı',etiket_temizle(baslik[1])) if baslik else None
    if not m or not ay_no(m[2]):
        return {}
    yil,ay=int(m[1]),ay_no(m[2])
    sonuc={}
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',sayfa,re.S):
        h=re.findall(r'<td\b[^>]*>(.*?)</td>',row,re.S)
        if len(h)!=3:
            continue
        d=re.search(r'class="gun-num"[^>]*>\s*(\d+)\s*</span>',h[0])
        if not d:
            continue
        try:
            t=date(yil,ay,int(d[1]))
        except ValueError:
            continue
        items=[o for o in (oge(x) for x in re.findall(r'<li\b[^>]*>(.*?)</li>',h[1],re.S)) if o]
        if items:
            menu={'items':items}
            k=re.search(r'class="kcal-num"[^>]*>\s*(\d+)\s*</span>',h[2])
            if k:
                menu['kcal']=int(k[1])
            sonuc[t.isoformat()]={'lunch':menu}
    return sonuc


class KaramanogluMehmetbey(HtmlUniversitesi):
    id,ad,kisa,sehir='kmu','Karamanoğlu Mehmetbey Üniversitesi','KMÜ','Karaman'
    kaynak=SAYFA_URL
    ayristir=staticmethod(sayfa_menu)
