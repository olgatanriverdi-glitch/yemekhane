"""Erciyes: öğrenci menüsündeki açık öğlen/akşam kartları; boş öğün atlanır."""
import re
from ..model import etiket_temizle, gun_icerigi
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL='https://erciyes.edu.tr/tr/2/ogrenci-yemek-listesi'


def sayfa_menu(sayfa):
    sonuc={}
    for kart in re.split(r'<li\b[^>]*class="menu"[^>]*>',sayfa)[1:]:
        h=re.search(r'aria-label="([^\"]+Menüsü)"',kart)
        t=tarih(h[1]) if h else None
        if not t:
            continue
        tur='dinner' if 'Akşam' in h[1] else 'lunch'
        liste=re.search(r'<ul\b[^>]*aria-label="Yemekler ve Kalorileri"[^>]*>(.*?)</ul>',kart,re.S)
        items=[o for o in (oge(x) for x in re.findall(r'<li\b[^>]*>(.*?)</li>',liste[1] if liste else '',re.S)) if o]
        if items:
            menu=gun_icerigi(items)
            k=re.search(r'(\d+)\s*Kalori',etiket_temizle(kart[liste.end():]))
            if k and int(k[1])>0:
                menu['kcal']=int(k[1])
            sonuc.setdefault(t.isoformat(),{})[tur]=menu
    return sonuc


class ErciyesUniversitesi(HtmlUniversitesi):
    id,ad,kisa,sehir='erciyes','Erciyes Üniversitesi','ERÜ','Kayseri'
    kaynak=SAYFA_URL
    birikimli=True
    ayristir=staticmethod(sayfa_menu)
