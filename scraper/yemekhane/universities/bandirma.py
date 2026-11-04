"""BANÜ: aylık metin PDF; altı kalem korunur, seçenekler toplanmaz."""
import html
import re
from urllib.parse import quote, unquote, urljoin
from .. import pdf
from ._son_pdf import BaglantiliPdfUniversitesi, sutun_menu
from .base import saat_duzenle

SAYFA_URL="https://sksdb.bandirma.edu.tr/tr/sksdb/s/Yemek-Menusu-2725"


def pdf_menu(veri):
    return sutun_menu(veri,(76,181,289,396,506,618),alt=100,kalori=True)


class BandirmaOnyediEylul(BaglantiliPdfUniversitesi):
    id, ad, kisa, sehir = "bandirma", "Bandırma Onyedi Eylül Üniversitesi", "BANÜ", "Balıkesir"
    kaynak=SAYFA_URL
    ayristir=staticmethod(pdf_menu)
    baglanti_uygun=staticmethod(lambda ad:'yemek' in ad and ('menü' in ad or 'listesi' in ad) and 'ücret' not in ad)

    def saatler(self):
        if not getattr(self,'pdf',None):
            return {}
        metin=' '.join(t for s in pdf.sayfa_metinleri(self.pdf) for _,_,_,t in s)
        sonuc={}
        for etiket,tur in [('Öğle','lunch'),('Akşam','dinner')]:
            m=re.search(etiket+r'\);[^\d]*(\d{1,2}[.:]\d{2}\s*[-–]\s*\d{1,2}[.:]\d{2})',metin)
            saat=saat_duzenle(m[1]) if m else None
            if saat:
                sonuc[tur]=saat
        return sonuc

    def fiyatlar(self):
        try:
            sayfa = getattr(self, 'sayfa', None) or self.indir(SAYFA_URL).decode('utf-8-sig')
            for url in re.findall(r'<a\b[^>]*href=[\'"]([^\'"]+)[\'"]', sayfa):
                ad = unquote(url).lower()
                if ad.endswith('.pdf') and 'ücret' in ad:
                    url = quote(urljoin(SAYFA_URL, html.unescape(unquote(url))), safe=':/()%')
                    metin = ' '.join(t for page in pdf.sayfa_metinleri(self.indir(url)) for _,_,_,t in page)
                    m = re.search(r'ÖĞRENCİ\s+(\d+),\d+\s*TL', metin)
                    if m:
                        return [{'label':'Öğrenci','tl':int(m[1])}]
        except Exception:
            return []
        return []
