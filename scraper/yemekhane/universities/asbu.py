"""ASBÜ: aylık düşük çözünürlüklü görselden girilmiş elle veri + günlük resmi JSON.
Günlük okumalar build tarafından biriktirilir. Saat/ücret okul sayfalarındandır.

Resimdeki liste 'Normal ve Vejetaryen Yemek Menüsü'dür: her günde çorba, ana yemek, yan yemek, salata/ayran ve tatlı vardır; günün altında
'***' ile başlayan satır ana yemeğin etsiz karşılığıdır. Okulun 'Toplam Kalori' satırı bazı günlerde kalemlerin toplamıyla uyuşmuyor
(5 Ekim'de 1057 yazmış, kalemler 1159); bu yüzden günün kalorisi kalemlerin toplamı olarak hesaplanır.
"""
import html
import json
import re
from datetime import date

from .. import elle
from ..model import baslik_yap_serbest, kisaltma_ac, gun_icerigi
from .base import Universite, indir, saat_duzenle

MENU_URL = "https://sksdb.asbu.edu.tr/tr/aylik-menu-0"
BESLENME_URL = "https://uo.asbu.edu.tr/tr/beslenme"
GUNLUK_URL = "https://webapi.asbu.edu.tr/webapi/Yemekhane/getGununYemegi"


def gunluk_menu(veri):
    """Günlük JSON: v- ana yemek, normal ana yemeğin vejetaryen karşılığıdır."""
    if not isinstance(veri, dict):
        return {}
    try:
        tarih = date.fromisoformat(str(veri.get('tarih', ''))[:10]).isoformat()
    except ValueError:
        return {}
    normal, vegan = [], []
    for yemek in veri.get('yemekIcerigi') or []:
        ad = str(yemek.get('yemekAdi') or '').strip()
        vej = bool(re.match(r'^v\s*-', ad, re.I))
        ad = re.sub(r'^v\s*-\s*', '', ad, flags=re.I)
        if not ad:
            continue
        oge = {'name': baslik_yap_serbest(kisaltma_ac(ad))}
        kalori = yemek.get('kalori')
        if isinstance(kalori, (int, float)) and kalori > 0:
            oge['kcal'] = kalori
        (vegan if vej else normal).append(oge)
    if not normal:
        return {}
    gun = {'lunch': gun_icerigi(normal)}
    if vegan and len(normal) >= 2:
        gun['vegetarian'] = gun_icerigi(normal[:1] + vegan + normal[2:])
    return {tarih: gun}


def temiz(h: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", h)).replace("\xa0", " ")).strip()


def saat_ayikla(sayfa: str) -> dict:
    """'Öğrenci: 11.30 - 13.30 ... Personel: 12.30 - 13.30' -> öğrenci saati."""
    m = re.search(r"Öğrenci\s*:\s*([\d.: –—-]+)", temiz(sayfa))
    saat = saat_duzenle(m.group(1)) if m else None
    return {"lunch": saat, "vegetarian": saat} if saat else {}


def ucret_ayikla(sayfa: str) -> list:
    """'... öğrenciler için belirlenen yemek ücreti 45 TL’dir.' -> öğrenci ücreti."""
    m = re.search(r"öğrenciler için belirlenen yemek ücreti\s*(\d+)\s*TL", temiz(sayfa), re.I)
    return [{"label": "Öğrenci (Öğle Yemeği)", "tl": int(m.group(1))}] if m else []


class AnkaraSosyalBilimler(Universite):
    id = "asbu"
    ad = "Ankara Sosyal Bilimler Üniversitesi"
    kisa = "ASBÜ"
    sehir = "Ankara"
    kaynak = MENU_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        sonuc = elle.yukle(self.id)
        try:
            yeni = gunluk_menu(json.loads(self.indir(GUNLUK_URL).decode('utf-8-sig')))
            # Günlük resmi JSON öğünü yeniler; elle girilmiş diğer öğünler korunur.
            for t, gun in yeni.items():
                sonuc.setdefault(t, {}).update(gun)
        except Exception as e:
            print('UYARI: ASBÜ günlük menüsü alınamadı:', e)
        return sonuc

    def saatler(self) -> dict:
        try:
            return saat_ayikla(self.indir(MENU_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: ASBÜ saatleri alınamadı:", e)
            return {}

    def fiyatlar(self) -> list:
        try:
            return ucret_ayikla(self.indir(BESLENME_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: ASBÜ fiyatları alınamadı:", e)
            return []
