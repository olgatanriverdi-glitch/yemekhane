"""AİÇÜ ana sayfa: tarihli menü penceresi; bitişik kalori/protein ayrılır."""
import re
from ..model import etiket_temizle
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL='https://www.agri.edu.tr/'


def sayfa_menu(sayfa):
    sonuc={}
    alan=re.search(r'<div class="yemekGunler">(.*?)<!--',sayfa,re.S)
    for ul in re.findall(r'<ul\b[^>]*>(.*?)</ul>',alan[1] if alan else sayfa,re.S):
        h=re.search(r'<h4\b[^>]*>(.*?)</h4>',ul,re.S)
        t=tarih(h[1]) if h else None
        if not t:
            continue
        items=[]
        toplam=None
        for li in re.findall(r'<li\b[^>]*>(.*?)</li>',ul,re.S):
            metin=etiket_temizle(li)
            if re.match('Protein:',metin,re.I):
                continue
            k=re.search(r'Kalori:\s*(\d+)\s*kcal',metin,re.I)
            if k:
                toplam=int(k[1])
                metin=metin[:k.start()]
            o=oge(metin)
            if o:
                items.append(o)
        if items:
            menu={'items':items}
            if toplam:
                menu['kcal']=toplam
            sonuc[t.isoformat()]={'lunch':menu}
    return sonuc


class AgriIbrahimCecen(HtmlUniversitesi):
    id,ad,kisa,sehir='agri','Ağrı İbrahim Çeçen Üniversitesi','AİÇÜ','Ağrı'
    kaynak=SAYFA_URL
    birikimli=True
    ayristir=staticmethod(sayfa_menu)
