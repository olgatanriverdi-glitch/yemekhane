"""Galatasaray Üniversitesi: aylık menüler gsu.edu.tr/tr/kesfet/kampuste-yasam/yemek-menusu sayfasında dört PDF olarak yayınlanıyor
(öğlen, akşam, öğlen vegan, akşam vegan). Bunlar Excel'den üretilmiş metin tabanlı PDF'lerdir ama düzenleri düzensizdir:
sayfa üzerinde haftalar kronolojik sırada değildir, her satır tek metin parçasında 'ADI 215 ADI 180 ...' biçiminde gelir ve uzun satırlar x ekseninde
birkaç parçaya bölünebilir. Yalnızca ÖĞLEN PDF'i alınır: akşam PDF'inde bazı harfler metne hiç çıkmıyor (örn. 'MATARÇRBA'), vegan PDF'lerinin düzeni farklıdır.

Öğlen PDF'inde her hafta bloğu 'tarih başlığı' (5.10.2026 6.10.2026 ...) ile başlar; satırlar başlığın y konumundan sabit uzaklıklarda sıralanır:
çorba +29.8, ana yemek +44.7, yan yemek +59.6, tatlı +89.3 (meyve satırı salata adlarıyla karıştığı için alınmaz). Bir satırın girdi sayısı o haftanın
gün sayısına eşit değilse (boş hücre, bölünmüş satır) o hafta güvenle eşleştirilemeyeceği için atlanır; yanlış güne yanlış yemek yazılmaz.
"""
import html
import re
from datetime import date

from .. import pdf
from ..model import baslik_yap_serbest
from .base import Universite, indir

SAYFA_URL = "https://gsu.edu.tr/tr/kesfet/kampuste-yasam/yemek-menusu"
TARIHLER = re.compile(r"^\d{1,2}\.\d{1,2}\.\d{4}(?:\s+\d{1,2}\.\d{1,2}\.\d{4})*$")
SATIRLAR = (("çorba", 29.8), ("ana yemek", 44.7), ("yan yemek", 59.6), ("tatlı", 89.3))
Y_TOLERANS = 2.2
YEMEK_PUNTO_USTU = 11.5
ATLA = re.compile(r"^(DİYET|ZY)\b")               # diyet ve zeytinyağlı yemek listeleri aynı y konumuna basılıyor, normal menüde değil
KISALTMALAR = (("ŞEH.", "ŞEHRİYELİ "), ("DOM.SOS.", "DOMATES SOSLU "), ("KIR.", "KIRMIZI "), ("ZY.", "ZEYTİNYAĞLI "))


def _kucuk(metin: str) -> str:
    return metin.replace("İ", "i").replace("I", "ı").lower()


def temiz(h: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", h)).replace("\xa0", " ")).strip()


def ogle_pdf_baglantisi(sayfa: str):
    """'Ekim Ayı Öğlen Yemek Menüsü' (vegan olmayan) PDF bağlantısı."""
    for m in re.finditer(r'<a [^>]*href="([^"]+\.pdf)"[^>]*>(.*?)</a>', sayfa, flags=re.S | re.I):
        ad = _kucuk(temiz(m.group(2)))
        if "öğlen" in ad and "vegan" not in ad:
            return m.group(1)
    return None


def girdiler(metin: str) -> list:
    """'MERCİMEK ÇORBA 215 KAZDAĞI ÇORBASI  180' -> [('MERCİMEK ÇORBA', 215), ('KAZDAĞI ÇORBASI', 180)]; diyet/zeytinyağlı girdileri atılır."""
    sonuc = []
    for ad, kcal in re.findall(r"([^\d]+?)\s*(\d{2,4})(?=\s|$)", metin):
        ad = re.sub(r"\s+", " ", ad).strip(" .")
        if ad and not ATLA.match(ad):
            sonuc.append((ad, int(kcal)))
    return sonuc


def yemek_adi(ad: str) -> str:
    for kisa, uzun in KISALTMALAR:
        ad = ad.replace(kisa, uzun)
    return re.sub(r"\s+", " ", baslik_yap_serbest(ad)).strip()


def _bant(kelimeler, y: float) -> str:
    """y konumundaki satırın metni; yemek satırları 10.9 punto, başlık/imza/sabit garnitür yazıları farklı boydadır ve karışmasın diye alınmaz."""
    parca = [k for k in kelimeler if abs(k[1] - y) <= Y_TOLERANS and k[2] < YEMEK_PUNTO_USTU]
    return " ".join(k[3].strip() for k in sorted(parca, key=lambda k: k[0]))


def sayfa_menu(kelimeler) -> dict:
    """PDF'in konumlu metninden {'2026-10-05': {'lunch': {'items': [...], 'kcal': n}}, ...}"""
    sonuc = {}
    for x, y, _, metin in kelimeler:
        if not TARIHLER.match(metin.strip()):
            continue
        gunler = [date(int(a[2]), int(a[1]), int(a[0])) for a in (t.split(".") for t in metin.split())]
        satirlar = [girdiler(_bant(kelimeler, y + uzaklik)) for _, uzaklik in SATIRLAR]
        if any(len(s) != len(gunler) for s in satirlar):
            continue                                            # güvenle eşleştirilemeyen hafta
        for sira, gun in enumerate(gunler):
            ogeler = [{"name": yemek_adi(s[sira][0]), "kcal": s[sira][1]} for s in satirlar]
            sonuc[gun.isoformat()] = {"lunch": {"items": ogeler, "kcal": sum(o["kcal"] for o in ogeler)}}
    return sonuc


class GalatasarayUniversitesi(Universite):
    id = "gsu"
    ad = "Galatasaray Üniversitesi"
    kisa = "GSÜ"
    sehir = "İstanbul"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        baglanti = ogle_pdf_baglantisi(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
        if not baglanti:
            raise RuntimeError("GSÜ yemek menüsü sayfasında öğlen PDF'i bulunamadı")
        # sayfanın parçaları birkaç içerik akışına bölünmüş olabilir (tarih başlığı bir akışta, satırlar öbüründe): hepsi birlikte işlenir
        kelimeler = [k for akis in pdf.sayfa_metinleri(self.indir(baglanti)) for k in akis]
        return sayfa_menu(kelimeler)
