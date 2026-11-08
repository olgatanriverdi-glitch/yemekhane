"""Hitit: merkez yemekhanesinin birkaç günlük HTML penceresi; biriktirilir."""
import re
from ._son_ortak import HtmlUniversitesi, oge, tarih
from ..model import etiket_temizle
from .base import saat_duzenle

SAYFA_URL="https://hitit.edu.tr/tr/hitit/yemek-listesi"
SAAT_URL="https://hitit.edu.tr/tr/shmyo/yemek-hizmeti-uygulamalari-hakkinda"


def sayfa_menu(sayfa):
    sonuc={}
    for blok in re.split(r'id="yemeklist"',sayfa)[1:]:
        h=re.search(r'<h4\b[^>]*>(.*?)</h4>',blok,re.S)
        t=tarih(h[1]) if h else None
        liste=re.search(r'<ul\b[^>]*class="category-items"[^>]*>(.*?)</ul>',blok,re.S)
        if t and liste:
            items=[o for o in (oge(li) for li in re.findall(r'<li\b[^>]*>(.*?)</li>',liste[1],re.S)) if o]
            if items:
                sonuc[t.isoformat()]={'lunch':{'items':items}}
    return sonuc


class HititUniversitesi(HtmlUniversitesi):
    id, ad, kisa, sehir = "hitit", "Hitit Üniversitesi", "HİTÜ", "Çorum"
    kaynak=SAYFA_URL
    birikimli=True
    ayristir=staticmethod(sayfa_menu)

    def saatler(self):
        try:
            metin=etiket_temizle(self.indir(SAAT_URL).decode('utf-8-sig'))
        except Exception:
            return {}
        m=re.search(r'yemek hizmetinin\s+(\d{1,2}[.:]\d{2}\s*[-–]\s*\d{1,2}[.:]\d{2})',metin,re.I)
        saat=saat_duzenle(m[1]) if m else None
        return {'lunch':saat} if saat else {}
