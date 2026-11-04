"""Erzurum Teknik: bugünün ve ilerleyen günlerin HTML menüsü, birikimli."""
import html
import re
from ..model import ay_no, bugun_tr, etiket_temizle, gun_icerigi, yil_sec
from ._son_ortak import HtmlUniversitesi, oge

SAYFA_URL='https://servis.erzurum.edu.tr/yemeklistesi/'
GUNLER=('Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar')


def gun_tarihi(metin,bugun):
    m=re.search(r'(\d{1,2})\s+(\S+)\s+(\S+)',metin)
    if not m or not ay_no(m[2]):
        return None
    t=yil_sec(int(m[1]),ay_no(m[2]),bugun)
    return t if t and GUNLER[t.weekday()]==m[3] else None


def sayfa_menu(sayfa,bugun=None):
    bugun=bugun or bugun_tr()
    sayfa=html.unescape(sayfa)
    sonuc={}
    bugunku,_,gelecek=sayfa.partition('İlerleyen Günlerde')
    h=re.search(r'<h1\b[^>]*>Günün Menüsü,\s*(.*?)</h1>',bugunku,re.S)
    t=gun_tarihi(etiket_temizle(h[1]),bugun) if h else None
    items=[]
    for ad,detay in re.findall(r'<h3\b[^>]*>(.*?)</h3>(.*?)(?=<h3\b|$)',bugunku,re.S):
        k=re.search(r'\b(\d+)\s*kkal',etiket_temizle(detay))
        o=oge(ad)
        if o:
            if k:
                o['kcal']=int(k[1])
            items.append(o)
    if t and items:
        sonuc[t.isoformat()]={'lunch':gun_icerigi(items)}
    for ad,blok in re.findall(r'<h4\b[^>]*>(.*?)</h4>(.*?)(?=<h4\b|$)',gelecek,re.S):
        t=gun_tarihi(etiket_temizle(ad),bugun)
        items=[]
        if not t:
            continue
        for li in re.findall(r'<li\b[^>]*>(.*?)</li>',blok,re.S):
            a=re.search(r'<img\b[^>]*alt="([^\"]+)"',li)
            k=re.search(r'\b(\d+)\s*kkal',etiket_temizle(li))
            o=oge(a[1]) if a else None
            if o:
                if k:
                    o['kcal']=int(k[1])
                items.append(o)
        if items:
            sonuc[t.isoformat()]={'lunch':gun_icerigi(items)}
    return sonuc


class ErzurumTeknik(HtmlUniversitesi):
    id,ad,kisa,sehir='etu','Erzurum Teknik Üniversitesi','ETÜ','Erzurum'
    kaynak=SAYFA_URL
    birikimli=True
    ayristir=staticmethod(sayfa_menu)
