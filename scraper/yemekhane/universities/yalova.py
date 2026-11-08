"""Yalova: aylık öğle HTML; tooltip içindeki malzemeler yemek sayılmaz."""
import re
from ..model import etiket_temizle, gun_icerigi
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL="https://menu.yalova.edu.tr/Home/"


def sayfa_menu(sayfa):
    sayfa=re.sub(r'\sdata-original-title="[^\"]*"','',sayfa)
    sonuc={}
    for baslik,blok in re.findall(r'<span>(\d{1,2}\s+\S+\s+\d{4}\s+[^<]*)</span>(.*?)(?=<span>\d{1,2}\s+\S+\s+\d{4}|<div class="copyright")',sayfa,re.S):
        t=tarih(baslik)
        if not t:
            continue
        items=[]
        toplam=None
        for li in re.findall(r'<li\b[^>]*>(.*?)</li>',blok,re.S):
            metin=etiket_temizle(li)
            if metin.startswith('Toplam Kalori'):
                k=re.search(r'\d+',metin)
                toplam=int(k[0]) if k else None
            else:
                o=oge(li)
                if o:
                    items.append(o)
        if items:
            menu=gun_icerigi(items)
            if toplam:
                menu['kcal']=toplam
            sonuc[t.isoformat()]={'lunch':menu}
    return sonuc


class YalovaUniversitesi(HtmlUniversitesi):
    id, ad, kisa, sehir = "yalova", "Yalova Üniversitesi", "YÜ", "Yalova"
    kaynak=SAYFA_URL
    ayristir=staticmethod(sayfa_menu)
