"""Tekirdağ NKÜ: SKS tarihli menü penceresi; açık vejetaryen ana yemek."""
import re
from datetime import date
from ..model import etiket_temizle
from ._son_ortak import HtmlUniversitesi, oge
from .base import saat_duzenle

SAYFA_URL = "https://sks.nku.edu.tr/YemekListesi/0/s/6200/7411"
SAAT_URL = "https://sks.nku.edu.tr/YemekSaatleri/0/s/14804/19073"
FIYAT_URL = "https://sks.nku.edu.tr/YemekFiyatlari_i%C3%A7erik/0/s/14798/19059"


def sayfa_menu(sayfa):
    sonuc={}
    for blok in re.split(r'<li\b[^>]*class="yemek-gun\b[^\"]*"[^>]*>',sayfa)[1:]:
        m=re.search(r'<time\b[^>]*datetime="(\d{4}-\d{2}-\d{2})"',blok)
        if not m:
            continue
        try:
            t=date.fromisoformat(m[1])
        except ValueError:
            continue
        liste=re.search(r'<ul\b[^>]*>(.*?)</ul>',blok,re.S)
        normal,alternatif=[],None
        for attrs,li in re.findall(r'<li\b([^>]*)>(.*?)</li>',liste[1] if liste else '',re.S):
            if 'vejetaryen' in attrs:
                alternatif=oge(re.sub(r'<small\b[^>]*>.*?</small>','',li,flags=re.S))
            else:
                o=oge(li)
                if o:
                    normal.append(o)
        if normal:
            gun={'lunch':{'items':normal}}
            if alternatif and len(normal)==4:
                vegan=[o.copy() for o in normal]
                vegan[1]=alternatif
                gun['vegetarian']={'items':vegan}
            sonuc[t.isoformat()]=gun
    return sonuc


class TekirdagNamikKemal(HtmlUniversitesi):
    id, ad, kisa, sehir = "nku", "Tekirdağ Namık Kemal Üniversitesi", "NKÜ", "Tekirdağ"
    kaynak = SAYFA_URL
    birikimli = True
    ayristir=staticmethod(sayfa_menu)

    def saatler(self):
        try:
            metin=etiket_temizle(self.indir(SAAT_URL).decode('utf-8-sig'))
        except Exception:
            return {}
        m=re.search(r'Öğrenci[^\d]{0,80}(\d{1,2}[.:]\d{2}\s*[-–]\s*\d{1,2}[.:]\d{2})',metin,re.I)
        saat=saat_duzenle(m[1]) if m else None
        return {'lunch':saat} if saat else {}

    def fiyatlar(self):
        try:
            metin=etiket_temizle(self.indir(FIYAT_URL).decode('utf-8-sig'))
        except Exception:
            return []
        m=re.search(r'ÖĞRENCİ\s+Öğrenci\s+(\d+),\d+',metin)
        return [{'label':'Öğrenci','tl':int(m[1])}] if m else []
