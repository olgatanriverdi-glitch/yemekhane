"""Ankara Müzik ve Güzel Sanatlar Üniversitesi: haftalık öğle menüsü mgu.edu.tr/mgu-yemek-menusu sayfasında HTML tablo olarak yayınlanıyor.
Her tablonun başlığı '28 Eylül - 02 Ekim Haftası' (yıl yazmaz), ilk satırı gün adları (Pazartesi..Cuma), sonraki satırlar çorba, ana yemek,
yan yemek ve 'Ayran/Salata' gibi 4. satırdır. Kalori yayınlanmaz. Öğrenci yemekhanesi yalnızca öğle yemeği verir.
"""
import html
import re
from datetime import date, timedelta

from .base import Universite, indir, saat_duzenle

MENU_URL = "https://www.mgu.edu.tr/mgu-yemek-menusu/"
YEMEKHANE_URL = "https://www.mgu.edu.tr/yemekhane/"

AYLAR = {"ocak": 1, "şubat": 2, "mart": 3, "nisan": 4, "mayıs": 5, "haziran": 6,
         "temmuz": 7, "ağustos": 8, "eylül": 9, "ekim": 10, "kasım": 11, "aralık": 12}
GUNLER = {"pazartesi": 0, "salı": 1, "çarşamba": 2, "perşembe": 3, "cuma": 4, "cumartesi": 5, "pazar": 6}
BASLIK = re.compile(r"(\d{1,2})\s+([^\W\d_]+)\s*[-–]\s*(\d{1,2})\s+([^\W\d_]+)\s+haftas", re.I)


def _kucuk(metin: str) -> str:
    return metin.replace("İ", "i").replace("I", "ı").lower()


def temiz(h: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", h)).replace("\xa0", " ")).strip()


def hafta_araligi(baslik: str, bugun: date):
    """'28 Eylül - 02 Ekim Haftası' -> (date(2026,9,28), date(2026,10,2)); yıl bugüne en yakın olandan seçilir."""
    m = BASLIK.search(temiz(baslik))
    if not m:
        return None
    g1, a1, g2, a2 = int(m.group(1)), AYLAR.get(_kucuk(m.group(2))), int(m.group(3)), AYLAR.get(_kucuk(m.group(4)))
    if not a1 or not a2:
        return None
    adaylar = []
    for yil in (bugun.year - 1, bugun.year, bugun.year + 1):
        try:
            bas = date(yil, a1, g1)
            son = date(yil + (1 if a2 < a1 else 0), a2, g2)
        except ValueError:
            continue
        if bas <= son <= bas + timedelta(days=7):
            adaylar.append((abs((bas - bugun).days), bas, son))
    return min(adaylar)[1:] if adaylar else None


def yemek_ogeleri(hucre: str) -> list:
    """'Ayran/Salata' -> [Ayran, Salata]; '-' ve boş hücreler atlanır."""
    sonuc = []
    for parca in temiz(hucre).split("/"):
        ad = parca.strip(" -–")
        if ad:
            sonuc.append({"name": ad})
    return sonuc


def sayfa_menu(sayfa: str, bugun: date = None) -> dict:
    """{'2026-10-05': {'lunch': {'items': [...]}}, ...}. Başlığı 'Haftası' ile bitmeyen tablolar (personel ücretleri) atlanır."""
    bugun = bugun or date.today()
    sonuc = {}
    for tablo in re.findall(r"<table.*?</table>", sayfa, flags=re.S | re.I):
        baslik = re.search(r"<th[^>]*>(.*?)</th>", tablo, flags=re.S | re.I)
        aralik = hafta_araligi(baslik.group(1), bugun) if baslik else None
        if not aralik:
            continue
        haftagunu_tarih = {}
        d = aralik[0]
        while d <= aralik[1]:
            haftagunu_tarih[d.weekday()] = d
            d += timedelta(days=1)
        satirlar = [[temiz(td) for td in re.findall(r"<t[dh][^>]*>.*?</t[dh]>", tr, flags=re.S | re.I)]
                    for tr in re.findall(r"<tr[^>]*>.*?</tr>", tablo, flags=re.S | re.I)]
        satirlar = [s for s in satirlar if s]
        # ilk <td> satırı gün adlarıdır (<th> başlık satırı ayrı); gün adı olmayan tablo menü tablosu değildir
        gun_satiri = next((s for s in satirlar if all(_kucuk(h) in GUNLER for h in s if h)), None)
        if not gun_satiri:
            continue
        govde = satirlar[satirlar.index(gun_satiri) + 1:]
        for sutun, ad in enumerate(gun_satiri):
            tarih = haftagunu_tarih.get(GUNLER.get(_kucuk(ad)))
            if tarih is None:
                continue
            hucreler = [s[sutun] if sutun < len(s) else "" for s in govde]
            if any("tatil" in _kucuk(h) for h in hucreler):
                sonuc[tarih.isoformat()] = {"lunch": {"items": [], "note": "Tatil"}}
                continue
            ogeler = [o for h in hucreler for o in yemek_ogeleri(h)]
            if ogeler:
                sonuc[tarih.isoformat()] = {"lunch": {"items": ogeler}}
    return sonuc


def ayrintilar(sayfa: str) -> dict:
    """Yemekhane sayfasından öğrenci saati ve ücreti: {'saat': '11:30–13:30', 'ucret': 40} (bulunamayan anahtar yazılmaz)."""
    metin = temiz(sayfa)
    sonuc = {}
    m = re.search(r"öğrenci yemekhanesinde saat\s*([\d.:]+\s*[-–—]\s*[\d.:]+)", metin, re.I)
    if m and saat_duzenle(m.group(1)):
        sonuc["saat"] = saat_duzenle(m.group(1))
    m = re.search(r"öğrencileri için yemek fiyatı\s*(\d+)\s*TL", metin, re.I)
    if m:
        sonuc["ucret"] = int(m.group(1))
    return sonuc


class AnkaraMuzikGuzelSanatlar(Universite):
    id = "mgu"
    ad = "Ankara Müzik ve Güzel Sanatlar Üniversitesi"
    kisa = "MGÜ"
    sehir = "Ankara"
    kaynak = MENU_URL

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun
        self._ayrinti = None

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(MENU_URL).decode("utf-8", "ignore"), self.bugun)

    def _ayrintilar(self) -> dict:
        if self._ayrinti is None:
            try:
                self._ayrinti = ayrintilar(self.indir(YEMEKHANE_URL).decode("utf-8", "ignore"))
            except Exception as e:
                print("UYARI: MGÜ yemekhane bilgisi alınamadı:", e)
                self._ayrinti = {}
        return self._ayrinti

    def saatler(self) -> dict:
        saat = self._ayrintilar().get("saat")
        return {"lunch": saat} if saat else {}

    def fiyatlar(self) -> list:
        ucret = self._ayrintilar().get("ucret")
        return [{"label": "Öğrenci (Öğle Yemeği)", "tl": ucret}] if ucret else []
