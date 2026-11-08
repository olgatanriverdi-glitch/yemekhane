"""Hakkari: merkezi yemekhane aylık HTML; seçenek kalorileri notta korunur."""
import re
from datetime import date
from ..model import etiket_temizle
from ._son_ortak import HtmlUniversitesi, oge

SAYFA_URL='https://www.hakkari.edu.tr/yemek-listesi/1/merkezi-yemekhane'


def sayfa_menu(sayfa):
    sonuc={}
    for kart in re.findall(r'<article\b[^>]*class="meal-card\b[^\"]*"[^>]*>(.*?)</article>',sayfa,re.S):
        m=re.search(r'<time\b[^>]*datetime="(\d{4}-\d{2}-\d{2})"',kart)
        if not m:
            continue
        try:
            t=date.fromisoformat(m[1])
        except ValueError:
            continue
        items,notlar=[],[]
        for li in re.findall(r'<li\b[^>]*>(.*?)</li>',kart,re.S):
            a=re.search(r'<span\b[^>]*>(.*?)</span>',li,re.S)
            k=re.search(r'<strong\b[^>]*>(.*?)</strong>',li,re.S)
            o=oge(a[1]) if a else None
            if not o:
                continue
            kcal=etiket_temizle(k[1]).replace('kcal','').strip() if k else ''
            if kcal.isdigit() and int(kcal)>0:
                o['kcal']=int(kcal)
            elif re.fullmatch(r'\d+\s*/\s*\d+',kcal):
                notlar.append('%s: %s kcal'%(o['name'],kcal))
            items.append(o)
        if items:
            menu={'items':items}
            footer=re.search(r'<footer\b[^>]*class="meal-card__total"[^>]*>(.*?)</footer>',kart,re.S)
            k=re.findall(r'\d+',etiket_temizle(footer[1])) if footer else []
            if len(k)==1:
                menu['kcal']=int(k[0])
            elif k:
                notlar.append('Seçeneklere göre toplam: %s kcal'%' / '.join(k))
            if notlar:
                menu['note']='; '.join(notlar)
            sonuc[t.isoformat()]={'lunch':menu}
    return sonuc


class HakkariUniversitesi(HtmlUniversitesi):
    id,ad,kisa,sehir='hakkari','Hakkari Üniversitesi','HKÜ','Hakkâri'
    kaynak=SAYFA_URL
    ayristir=staticmethod(sayfa_menu)
