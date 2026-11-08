"""Gümüşhane: Page/130 aylık JSON; gün başına beş isim yuvası."""
import calendar
import json
from datetime import date
from ._son_ortak import son_ay, oge
from .base import Universite, indir

SAYFA_URL='https://www.gumushane.edu.tr/sayfa/130/yemek-listesi'
API_URL='https://www.gumushane.edu.tr/api/Page/130'


def json_menu(kayit):
    sonuc={}
    for menu in kayit.get('yemekhanes',[]) if isinstance(kayit,dict) else []:
        try:
            yil,ay=int(menu['yemekhaneCreatedYear']),int(menu['yemekhaneCreatedMonth'])
            adlar=menu['yemekhaneTitle'][0]
            son=calendar.monthrange(yil,ay)[1]
        except (KeyError,ValueError,TypeError,IndexError):
            continue
        if not isinstance(adlar,list) or len(adlar)!=son*5:
            continue
        for g in range(1,son+1):
            items=[o for o in (oge(x) for x in adlar[(g-1)*5:g*5]) if o]
            if items:
                sonuc[date(yil,ay,g).isoformat()]={'lunch':{'items':items}}
    return son_ay(sonuc)


class GumushaneUniversitesi(Universite):
    id,ad,kisa,sehir='gumushane','Gümüşhane Üniversitesi','GŞÜ','Gümüşhane'
    kaynak=SAYFA_URL

    def __init__(self,indirici=indir):
        self.indir=indirici

    def menuler(self):
        try:
            veri=self.indir(API_URL)
        except Exception as e:
            raise RuntimeError('Gümüşhane: aylık JSON indirilemedi: %s'%e) from e
        try:
            sonuc=json_menu(json.loads(veri.decode('utf-8-sig')))
        except (ValueError,TypeError) as e:
            raise RuntimeError("Gümüşhane: yemek JSON'u okunamadı") from e
        if not sonuc:
            raise RuntimeError('Gümüşhane: tarihli menü bulunamadı')
        return sonuc
