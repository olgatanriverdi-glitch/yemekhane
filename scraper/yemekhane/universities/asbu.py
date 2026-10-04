"""Ankara Sosyal Bilimler Üniversitesi: aylık menü sksdb.asbu.edu.tr/tr/aylik-menu-0 sayfasında yalnızca düşük çözünürlüklü bir resim
(Excel tablosunun ekran görüntüsü) olarak yayınlanıyor; bu yüzden güvenle otomatik okunamıyor. Menü `elle_veri/asbu.json` dosyasına
resimden elle girilir (her ay, okul yeni resmi koyunca güncellenmeli). Saat ve öğrenci ücreti okulun sayfalarından otomatik okunur.

Resimdeki liste 'Normal ve Vejetaryen Yemek Menüsü'dür: her günde çorba, ana yemek, yan yemek, salata/ayran ve tatlı vardır; günün altında
'***' ile başlayan satır ana yemeğin etsiz karşılığıdır. Okulun 'Toplam Kalori' satırı bazı günlerde kalemlerin toplamıyla uyuşmuyor
(5 Ekim'de 1057 yazmış, kalemler 1159); bu yüzden günün kalorisi kalemlerin toplamı olarak hesaplanır.
"""
import html
import re

from .. import elle
from .base import Universite, indir, saat_duzenle

MENU_URL = "https://sksdb.asbu.edu.tr/tr/aylik-menu-0"
BESLENME_URL = "https://uo.asbu.edu.tr/tr/beslenme"


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

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return elle.yukle(self.id)

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
