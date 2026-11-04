"""GİBTÜ: Windows-1254 kodlu, bugünden başlayan HTML menü penceresi."""
import re
from ._son_ortak import HtmlUniversitesi,oge,tarih

SAYFA_URL='https://www.gibtu.edu.tr/yemeklistesi.aspx'


def sayfa_menu(sayfa):
    sonuc={}
    for kart in re.split(r'<div class="card-title center-align">',sayfa)[1:]:
        t=tarih(kart.split('</div>',1)[0])
        if not t:
            continue
        items=[o for o in (oge(x) for x in re.findall(r'<div class="col s12 m12 l12"[^>]*>(.*?)</div>',kart,re.S)) if o]
        if items:
            sonuc[t.isoformat()]={'lunch':{'items':items}}
    return sonuc


class GaziantepIslamBilimTeknoloji(HtmlUniversitesi):
    id,ad,kisa,sehir='gibtu','Gaziantep İslam Bilim ve Teknoloji Üniversitesi','GİBTÜ','Gaziantep'
    kaynak=SAYFA_URL
    kodlama='cp1254'
    birikimli=True
    ayristir=staticmethod(sayfa_menu)
