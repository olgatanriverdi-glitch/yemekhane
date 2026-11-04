"""Kırklareli: resmî takvim textarea'sındaki JSON; JavaScript çalıştırılmaz."""
import html
import json
import re
from datetime import date
from ._son_ortak import HtmlUniversitesi, oge, son_ay

SAYFA_URL = "https://sks.klu.edu.tr/Takvimler/73-yemek-takvimi.klu"


def sayfa_menu(sayfa):
    m = re.search(r'<textarea\b[^>]*>(.*?)</textarea>',sayfa,re.S)
    if not m:
        return {}
    try:
        kayitlar=json.loads(html.unescape(m[1]))
    except (ValueError,TypeError) as e:
        raise RuntimeError("Kırklareli: yemek takvimi JSON'u okunamadı") from e
    sonuc={}
    for k in kayitlar if isinstance(kayitlar,list) else []:
        try:
            t=date.fromisoformat(str(k.get('start',''))[:10])
        except (ValueError,AttributeError):
            continue
        adlar=re.split(r',\s*\n|\r?\n',k.get('aciklama') or '')
        items=[o for o in (oge(re.sub(r'\bŞEH\s+', 'ŞEHRİYELİ ',x)) for x in adlar) if o]
        if items:
            sonuc[t.isoformat()]={'lunch': {'items':[], 'note':'Resmi tatil'} if all('tatil' in o['name'].lower() for o in items) else {'items':items}}
    return son_ay(sonuc)


class KirklareliUniversitesi(HtmlUniversitesi):
    id, ad, kisa, sehir = "klu", "Kırklareli Üniversitesi", "KLÜ", "Kırklareli"
    kaynak = SAYFA_URL
    ayristir = staticmethod(sayfa_menu)
