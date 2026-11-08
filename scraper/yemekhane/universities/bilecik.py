"""BŞEÜ: beş sütunlu aylık metin PDF; parçalanmış tarihler birleştirilir."""
import re
from ..model import etiket_temizle
from ._son_pdf import BaglantiliPdfUniversitesi, sutun_menu
from .base import saat_duzenle

SAYFA_URL="https://bilecik.edu.tr/sks/Icerik/Yemek_Men%C3%BCs%C3%BC_cc6e6"
SAAT_URL="https://bilecik.edu.tr/sks/Icerik/Yemek_Saatleri"
FIYAT_URL="https://bilecik.edu.tr/sks/Icerik/Yemek_%C3%9Ccretleri_67696"


def pdf_menu(veri):
    sonuc=sutun_menu(veri,(35,174,334,475,617,773))
    for gun in sonuc.values():
        for o in gun['lunch']['items']:
            o['name']=re.sub(r'\bP\.P\s*Üre\b','Patates Püresi',o['name'],flags=re.I)
            o['name']=re.sub(r'\s*\+\s*',' + ',o['name'])
    return sonuc


class BilecikSeyhEdebali(BaglantiliPdfUniversitesi):
    id, ad, kisa, sehir = "bilecik", "Bilecik Şeyh Edebali Üniversitesi", "BŞEÜ", "Bilecik"
    kaynak=SAYFA_URL
    ayristir=staticmethod(pdf_menu)
    baglanti_uygun=staticmethod(lambda ad:'aylık menü' in ad)

    def saatler(self):
        try:
            metin=etiket_temizle(self.indir(SAAT_URL).decode('utf-8-sig'))
        except Exception:
            return {}
        m=re.search(r'Eğitim-Öğretim Dönemi\s+([\d.:– -]+)',metin)
        saat=saat_duzenle(m[1]) if m else None
        return {'lunch':saat} if saat else {}

    def fiyatlar(self):
        try:
            metin=etiket_temizle(self.indir(FIYAT_URL).decode('utf-8-sig'))
        except Exception:
            return []
        sonuc=[]
        for etiket in ('Lisans ve Ön Lisans Öğrencisi','Yüksek Lisans ve Doktora Öğrencisi'):
            m=re.search(etiket+r'\s+(\d+),\d+\s*TL',metin)
            if m:
                sonuc.append({'label':etiket,'tl':int(m[1])})
        return sonuc
