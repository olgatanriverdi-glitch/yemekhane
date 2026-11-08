"""MTÜ: aylık PNG yerine resmî SKS günlük metin menüsü; birikimli."""
import re
from ._son_ortak import HtmlUniversitesi,oge,tarih

SAYFA_URL='https://sksdb.ozal.edu.tr/tr/yemek_listesi'


def sayfa_menu(sayfa):
    baslik=re.search(r'<h4\b[^>]*class="[^\"]*\bfood-date\b[^\"]*"[^>]*>(.*?)</h4>',sayfa,re.S)
    t=tarih(baslik[1]) if baslik else None
    if not t:
        return {}
    alan=sayfa[baslik.end():].split('<!--Üniversite Yemekhanesi Son-->',1)[0]
    items=[o for o in (oge(x) for x in re.findall(r'<div class="box__content">\s*<p>(.*?)</p>',alan,re.S)) if o]
    return {t.isoformat():{'lunch':{'items':items}}} if items else {}


class MalatyaTurgutOzal(HtmlUniversitesi):
    id,ad,kisa,sehir='mtu','Malatya Turgut Özal Üniversitesi','MTÜ','Malatya'
    kaynak=SAYFA_URL
    birikimli=True
    ayristir=staticmethod(sayfa_menu)
