"""Boğaziçi Üniversitesi: aylık menü yemekhane.bogazici.edu.tr/aylik-menu/YYYY-AA adresinde takvim olarak yayınlanıyor (haftanın 7 günü).
Her gün hücresinde (`<td data-date="2026-10-01">`) öğle ve akşam için ayrı bir kutu vardır; kutuda çorba, ana yemek, vejetaryen/vegan ana yemek,
yardımcı yemekler (virgülle ayrılmış bağlantılar) ve seçmeliler bulunur. Takvim görünümünde kalori yok (günün sayfasında var, alınmıyor).
Vejetaryen menü öğle yemeğinin vegan alternatifidir (akşam vegan alternatifi uygulamada ayrı bir öğün olarak gösterilemediği için alınmıyor).
"""
import html
import re
from datetime import date

from .base import Universite, indir, saat_duzenle

BASE = "https://yemekhane.bogazici.edu.tr/"
SERVIS_URL = BASE + "yemek-servislerimiz"
OGUNLER = {"öğle yemeği": "lunch", "akşam yemeği": "dinner"}
ALANLAR = ("field-ccorba", "field-anaa-yemek", "field-yardimciyemek", "field-aperatiff")    # normal menü sırası
VEJ_ALANLAR = ("field-ccorba", "field-vejetarien", "field-yardimciyemek", "field-aperatiff")


def _kucuk(metin: str) -> str:
    return metin.replace("İ", "i").replace("I", "ı").lower()


def temiz(h: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", h)).replace("\xa0", " ")).strip()


def ay_url(yil: int, ay: int) -> str:
    return "%saylik-menu/%04d-%02d" % (BASE, yil, ay)


def _alan_ogeleri(kutu: str, alan: str) -> list:
    m = re.search(r'views-field-%s">\s*<div class="field-content">(.*?)</div>\s*</div>' % alan, kutu, re.S)
    if not m:
        return []
    baglantilar = re.findall(r"<a [^>]*>(.*?)</a>", m.group(1), re.S)
    adlar = [temiz(b) for b in baglantilar] if baglantilar else [temiz(p) for p in m.group(1).split(",")]
    return [{"name": a} for a in adlar if a]


def ay_menusu(sayfa: str) -> dict:
    """{'2026-10-01': {'lunch': {...}, 'dinner': {...}, 'vegetarian': {...}}, ...}"""
    sonuc = {}
    for hucre in re.finditer(r'<td id="aylik_menu-[^"]*"[^>]*data-date="(\d{4}-\d{2}-\d{2})"[^>]*>(.*?)</td>', sayfa, re.S):
        tarih, govde = hucre.groups()
        gun = {}
        for kutu in re.split(r'(?=<div class="item">)', govde)[1:]:
            ogun = re.search(r'views-field-field-yemek-saati">\s*<div class="field-content">(.*?)</div>', kutu, re.S)
            tur = OGUNLER.get(_kucuk(temiz(ogun.group(1)))) if ogun else None
            if not tur:
                continue
            ogeler = [o for alan in ALANLAR for o in _alan_ogeleri(kutu, alan)]
            if ogeler:
                gun[tur] = {"items": ogeler}
            if tur == "lunch":
                veg = [o for alan in VEJ_ALANLAR for o in _alan_ogeleri(kutu, alan)]
                if veg and veg != ogeler:
                    gun["vegetarian"] = {"items": veg}
        if gun:
            sonuc[tarih] = gun
    return sonuc


def saat_ayikla(sayfa: str) -> dict:
    """Servis saatleri tablosu: 'KUZEY KAMPÜS 07:30 – 09:30 11:30 – 14:30 17:00 – 19:15' (Kuzey Kampüs satırı)."""
    metin = temiz(sayfa)
    m = re.search(r"KUZEY KAMP[ÜU]S\s+(\d{1,2}[.:]\d{2}\s*[-–—]\s*\d{1,2}[.:]\d{2})\s+(\d{1,2}[.:]\d{2}\s*[-–—]\s*\d{1,2}[.:]\d{2})\s+(\d{1,2}[.:]\d{2}\s*[-–—]\s*\d{1,2}[.:]\d{2})", metin, re.I)
    if not m:
        return {}
    return {tur: saat_duzenle(h) for tur, h in zip(("breakfast", "lunch", "dinner"), m.groups())}


class BogaziciUniversitesi(Universite):
    id = "boun"
    ad = "Boğaziçi Üniversitesi"
    kisa = "BÜ"
    sehir = "İstanbul"
    kaynak = BASE

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self) -> dict:
        bugun = self.bugun or date.today()
        sonuc = {}
        yil, ay = bugun.year, bugun.month
        for _ in range(2):                                  # bu ay ve sonraki ay
            try:
                sonuc.update(ay_menusu(self.indir(ay_url(yil, ay)).decode("utf-8", "ignore")))
            except Exception as e:
                print("UYARI: Boğaziçi %04d-%02d alınamadı: %s" % (yil, ay, e))
            yil, ay = (yil + 1, 1) if ay == 12 else (yil, ay + 1)
        return sonuc

    def saatler(self) -> dict:
        try:
            saatler = saat_ayikla(self.indir(SERVIS_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: Boğaziçi saatleri alınamadı:", e)
            return {}
        return {t: s for t, s in saatler.items() if s and t != "breakfast"}
