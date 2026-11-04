"""Bartın: formun t/yemek1..4 sabitleri; JavaScript çalıştırılmadan okunur."""
import ast
import re
from ..model import gun_icerigi
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL='https://form.bartin.edu.tr/rapor/form/yemek-menu.html'


def sayfa_menu(sayfa):
    sonuc={}
    fn=re.search(r'function\s+tabloverileriEkle\s*\(\s*\)\s*\{(.*?)\n\}',sayfa,re.S)
    if not fn:
        return {}
    for d,blok in re.findall(r"\bt\s*=\s*['\"](\d{2}/\d{2}/\d{4})['\"];(.*?)(?=\bt\s*=\s*['\"]\d{2}/|$)",fn[1],re.S):
        t=tarih(d)
        items=[]
        for literal in re.findall(r'\byemek[1-4]\s*=\s*((?:"(?:[^"\\]|\\.)*")|(?:\'(?:[^\'\\]|\\.)*\'))\s*;',blok):
            try:
                metin=ast.literal_eval(literal)
            except (ValueError,SyntaxError):
                continue
            # Kaynak virgülle birden çok yan yemek ayırır; '/' seçenekleri aynı kalemdir.
            for ad in metin.split(','):
                o=oge(ad)
                if o:
                    items.append(o)
        if t and items:
            sonuc[t.isoformat()]={'lunch':gun_icerigi(items)}
    return sonuc


class BartinUniversitesi(HtmlUniversitesi):
    id,ad,kisa,sehir='bartin','Bartın Üniversitesi','BARÜ','Bartın'
    kaynak=SAYFA_URL
    ayristir=staticmethod(sayfa_menu)
