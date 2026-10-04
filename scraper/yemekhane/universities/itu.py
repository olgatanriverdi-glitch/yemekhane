"""İstanbul Teknik Üniversitesi: günün menüsü İTÜ ana sayfasındaki 'Yemekhane Menüsü' çerçevesinde (bilgiekrani.itu.edu.tr) gösteriliyor.
Çerçevenin kaynağı `yemek-menu.aspx?tip=<öğün>&&value=<gün.ay.yıl>` adresidir; tip `itu-ogle-yemegi-genel` ya da `itu-aksam-yemegi-genel`.
Yanıttaki tabloda satırlar: Çorba | Ana Yemek | Yan Yemek | Tatlı-Salata-Meyve-İçecek (birkaç satır) | Garnitür. Menü yaklaşık 2 hafta ileriye yayınlanır,
yayınlanmamış günlerde tablo boş gelir. Kalori yalnızca her yemeğin ayrı 'besin değerleri' penceresinde var, alınmıyor.
Servis saatleri ve öğrenci ücreti sks.itu.edu.tr'de tablo olarak yayınlanıyor.
"""
import html
import re
import time
from datetime import date, timedelta

from ..model import baslik_yap_serbest
from .base import Universite, indir, saat_duzenle

MENU_URL = "https://bilgiekrani.itu.edu.tr/ExternalPages/sks/yemek-menu-v2/uzerinde-calisilan/yemek-menu.aspx"
SAAT_URL = "https://sks.itu.edu.tr/yemek-saatleri"
FIYAT_URL = "https://sks.itu.edu.tr/yemek-fiyatlari"
TIPLER = {"lunch": "itu-ogle-yemegi-genel", "dinner": "itu-aksam-yemegi-genel"}
ILERI_GUN = 40
GERI_GUN = 1
ART_ARDA_BOS = 7


def _kucuk(metin: str) -> str:
    return metin.replace("İ", "i").replace("I", "ı").lower()


def temiz(h: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", h)).replace("\xa0", " ")).strip()


def menu_url(tarih: date, tip: str) -> str:
    return "%s?tip=%s&&value=%d.%d.%d" % (MENU_URL, tip, tarih.day, tarih.month, tarih.year)


def sayfa_ogun(sayfa: str):
    """Menü sayfasından {'items': [...]} ya da None (menü yayınlanmamış)."""
    ogeler = []
    for ad in re.findall(r'id="rpYemekMenu_hpBesinDegerleri_\d+"[^>]*>(.*?)</a>', sayfa, flags=re.S):
        ad = temiz(ad)
        if ad:
            ogeler.append({"name": baslik_yap_serbest(ad)})
    return {"items": ogeler} if ogeler else None


def tablolar(sayfa: str):
    for tablo in re.findall(r"<table.*?</table>", sayfa, flags=re.S | re.I):
        yield [[temiz(td) for td in re.findall(r"<t[dh].*?</t[dh]>", tr, flags=re.S | re.I)]
               for tr in re.findall(r"<tr.*?</tr>", tablo, flags=re.S | re.I)]


def saat_ayikla(sayfa: str) -> dict:
    """Öğrenci yemekhanesi satırı: hafta içi öğle ve akşam saatleri."""
    for satirlar in tablolar(sayfa):
        for s in satirlar:
            if len(s) >= 3 and "öğrenci yemekhanesi" in _kucuk(s[0]) and "personel" not in _kucuk(s[0]):
                sonuc = {}
                for tur, hucre in (("lunch", s[1]), ("dinner", s[2])):
                    saat = saat_duzenle(hucre)
                    if saat:
                        sonuc[tur] = saat
                return sonuc
    return {}


def ucret_ayikla(sayfa: str) -> list:
    """'Öğrenci' satırı: [öğrenci öğle, personel öğle, öğrenci akşam] sütunlarından öğrenci öğle ve akşam fiyatı."""
    for satirlar in tablolar(sayfa):
        for s in satirlar:
            if len(s) >= 4 and _kucuk(s[0]) == "öğrenci":
                ogle, aksam = (re.match(r"(\d+)[,.]\d+", h) for h in (s[1], s[3]))
                sonuc = []
                if ogle:
                    sonuc.append({"label": "Öğrenci (Öğle Yemeği)", "tl": int(ogle.group(1))})
                if aksam:
                    sonuc.append({"label": "Öğrenci (Akşam Yemeği)", "tl": int(aksam.group(1))})
                return sonuc
    return []


class IstanbulTeknik(Universite):
    id = "itu"
    ad = "İstanbul Teknik Üniversitesi"
    kisa = "İTÜ"
    sehir = "İstanbul"
    kaynak = "https://sks.itu.edu.tr/"

    def __init__(self, indirici=indir, bugun=None, bekle=0.15):
        self.indir = indirici
        self.bugun = bugun
        self.bekle = bekle

    def menuler(self) -> dict:
        bugun = self.bugun or date.today()
        sonuc, bos = {}, 0
        for k in range(-GERI_GUN, ILERI_GUN + 1):
            gun_tarihi = bugun + timedelta(days=k)
            gun = {}
            for tur, tip in TIPLER.items():
                try:
                    ogun = sayfa_ogun(self.indir(menu_url(gun_tarihi, tip)).decode("utf-8", "ignore"))
                except Exception as e:
                    print("UYARI: İTÜ %s %s alınamadı: %s" % (gun_tarihi, tur, e))
                    ogun = None
                if ogun:
                    gun[tur] = ogun
                if self.bekle:
                    time.sleep(self.bekle)
            if gun:
                sonuc[gun_tarihi.isoformat()] = gun
                bos = 0
            else:
                bos += 1
                if sonuc and bos >= ART_ARDA_BOS:
                    break
        return sonuc

    def saatler(self) -> dict:
        try:
            return saat_ayikla(self.indir(SAAT_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: İTÜ saatleri alınamadı:", e)
            return {}

    def fiyatlar(self) -> list:
        try:
            return ucret_ayikla(self.indir(FIYAT_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: İTÜ fiyatları alınamadı:", e)
            return []
