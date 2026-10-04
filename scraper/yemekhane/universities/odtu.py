"""Orta Doğu Teknik Üniversitesi: Kafeterya Müdürlüğü aylık tabldot menüsünü kafeterya.metu.edu.tr sitesinde PDF olarak yayınlıyor;
PDF'in içinde metin yok, taranmış JPEG sayfalar var. Her sayfada 'tarih | öğle yemeği + kalori | akşam yemeği + kalori' tablosu bulunur
(her gün 4 kalem ve altında toplam kalori).

Menüyü iki yoldan elde ederiz:
  1. `elle_veri/odtu.json`: görselden elle okunup girilmiş günler (toplam kaloriyle doğrulanmış).
  2. Tesseract kuruluysa (GitHub Actions'ta kurulu) PDF'teki sayfalar okunur. Okunan her gün, kalemlerin kalorileri toplam kaloriye eşitse kabul edilir,
     aksi halde atılır: yanlış okunmuş bir rakam menüde yer almaz. Elle girilmiş günler öncelikli; OCR yalnızca elle girilmemiş günleri doldurur ve
     çakışan günlerde elle girilenle ne kadar örtüştüğü loga yazılır (OCR'ın güvenilirliğini izlemek için).
"""
import html
import re
import urllib.parse
from datetime import date

from .. import elle, ocr
from .base import Universite, indir, saat_duzenle

ANA_SAYFA = "https://kafeterya.metu.edu.tr/"
SAAT_URL = ANA_SAYFA + "yemek-saatleri"
FIYAT_URL = ANA_SAYFA + "tabldot-yemek-fiyatlari"

RAKAM = re.compile(r"^\d{2,4}$")
TARIH = re.compile(r"(\d{1,2})\s*[.,]\s*(\d{1,2})\s*[.,]\s*(20\d{2})")
TARIH_SINIRI = 0.19         # sayfa genişliğinin bu kadarından soldaki sözcükler tarih sütunudur
KISALTMALAR = [
    (re.compile(r"\bZyt\.\s*", re.I), "Zeytinyağlı "),
    (re.compile(r"\bYoğ\.\s*", re.I), "Yoğurtlu "),
    (re.compile(r"\bMerc\.\s*", re.I), "Mercimek "),
]
YAZIM = {"Ezolin Çorba": "Ezogelin Çorba"}      # okulun listedeki bilinen yazım hatalarına karşı


def temiz(metin: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", metin)).replace("\xa0", " ")).strip()


def ad_duzelt(ad: str) -> str:
    ad = re.sub(r"[|_\[\]{}]", " ", ad)
    for kalip, yerine in KISALTMALAR:
        ad = kalip.sub(yerine, ad)
    ad = re.sub(r"\s+", " ", ad).strip(" -–.,")
    return YAZIM.get(ad, ad)


def pdf_baglantisi(sayfa: str):
    """Ana sayfadaki 'Aylık Menü' bağlantısının PDF adresi (yoksa None)."""
    for m in re.finditer(r'<a [^>]*href="([^"]+)"[^>]*>(.*?)</a>', sayfa, flags=re.S | re.I):
        if "aylık menü" in temiz(m.group(2)).lower() and m.group(1).lower().split("?")[0].endswith(".pdf"):
            return urllib.parse.urljoin(ANA_SAYFA, m.group(1))
    return None


def pdf_gorselleri(pdf: bytes) -> list:
    """PDF'in içindeki JPEG (DCTDecode) görsellerini sayfa sırasıyla çıkarır. Başka biçimli görseller atlanır."""
    sonuc = []
    for m in re.finditer(rb"<<(?:(?!>>\s*stream).)*?/Subtype\s*/Image(?:(?!>>\s*stream).)*?>>\s*stream\r?\n", pdf, flags=re.S):
        if b"/DCTDecode" not in m.group(0):
            continue
        son = pdf.find(b"endstream", m.end())
        if son > 0:
            sonuc.append(pdf[m.end():son].rstrip(b"\r\n"))
    return sonuc


def satirlara_ayir(kelimeler):
    """Sözcükleri düşey ortalarına göre satırlara, her satırı soldan sağa sıralar."""
    if not kelimeler:
        return []
    medyan = sorted(k.yuk for k in kelimeler)[len(kelimeler) // 2]
    satirlar = []
    for k in sorted(kelimeler, key=lambda k: k.my):
        if satirlar and abs(k.my - satirlar[-1]["y"]) <= 0.6 * medyan:
            s = satirlar[-1]
            s["kelimeler"].append(k)
            s["y"] += (k.my - s["y"]) / len(s["kelimeler"])
        else:
            satirlar.append({"y": k.my, "kelimeler": [k]})
    return [sorted(s["kelimeler"], key=lambda k: k.sol) for s in satirlar]


def _ad(kelimeler) -> str:
    return ad_duzelt(" ".join(k.metin for k in kelimeler if re.search(r"[^\W\d_]", k.metin)))


def _sayi(k):
    """Sözcük yalnızca rakamlardan oluşuyorsa (tablo çizgisi gibi kenar işaretleri atılarak) sayısı, değilse None."""
    metin = k.metin.strip("|[](){}_.,:;!'\" ")
    return int(metin) if RAKAM.match(metin) else None


def satir_coz(satir, sinir):
    """Tablo satırı: ('oge', öğle adı, öğle kcal, akşam adı, akşam kcal) | ('toplam', öğle, akşam) | None (diğer satırlar)."""
    sag = [k for k in satir if k.mx > sinir]
    sayilar = [k for k in sag if _sayi(k) is not None]
    if len(sayilar) != 2:
        return None
    n1, n2 = sayilar
    ogle = _ad([k for k in sag if k.mx < n1.sol])
    aksam = _ad([k for k in sag if n1.sag < k.mx < n2.sol])
    if not ogle and not aksam:
        return ("toplam", _sayi(n1), _sayi(n2))
    if ogle and aksam:
        return ("oge", ogle, _sayi(n1), aksam, _sayi(n2))
    return None


def blok_tarihi(kelimeler, ilk_satir, toplam_satiri, sinir):
    ust = min(k.ust for k in ilk_satir) - 5
    alt = max(k.ust + k.yuk for k in toplam_satiri) + 5
    metin = " ".join(k.metin for k in sorted(kelimeler, key=lambda k: (round(k.my / 8), k.sol)) if k.mx < sinir and ust <= k.my <= alt)
    m = TARIH.search(metin)
    if not m:
        return None
    try:
        return date(int(m.group(3)), int(m.group(2)), int(m.group(1))).isoformat()
    except ValueError:
        return None


def tablo_ayikla(kelimeler, genislik) -> dict:
    """OCR sözcüklerinden {'2026-10-01': {'lunch': {...}, 'dinner': {...}}}. Yalnızca kalemleri toplam kaloriyi tutan günler döner."""
    sinir = TARIH_SINIRI * genislik
    sonuc, bekleyen = {}, []
    for satir in satirlara_ayir(kelimeler):
        c = satir_coz(satir, sinir)
        if c is None:
            continue
        if c[0] == "oge":
            bekleyen.append((satir, c))
            continue
        ogle = [(c_[1], c_[2]) for _, c_ in bekleyen]
        aksam = [(c_[3], c_[4]) for _, c_ in bekleyen]
        if 3 <= len(bekleyen) <= 6 and sum(k for _, k in ogle) == c[1] and sum(k for _, k in aksam) == c[2]:
            tarih = blok_tarihi(kelimeler, bekleyen[0][0], satir, sinir)
            if tarih:
                sonuc[tarih] = {
                    "lunch": {"items": [{"name": a, "kcal": k} for a, k in ogle], "kcal": c[1]},
                    "dinner": {"items": [{"name": a, "kcal": k} for a, k in aksam], "kcal": c[2]},
                }
        bekleyen = []
    return sonuc


def saat_ayikla(sayfa: str) -> dict:
    """'Öğle Yemeği: 11.30 - 14.00 ... Hafta Sonu Öğle Yemeği: 12.00 - 14.00' -> hafta içi saatleri."""
    sonuc = {}
    adlar = {"öğle yemeği": "lunch", "akşam yemeği": "dinner"}
    for m in re.finditer(r"(hafta sonu\s+)?(öğle yemeği|akşam yemeği)\s*:\s*([\d.: –—-]+)", temiz(sayfa), flags=re.I):
        tur = adlar.get(m.group(2).lower())
        saat = saat_duzenle(m.group(3))
        if not m.group(1) and tur and saat:
            sonuc.setdefault(tur, saat)
    return sonuc


def ucret_ayikla(sayfa: str) -> list:
    """Ücret tablosundaki 'Öğrenci' satırı (öğle ve akşam aynı fiyat)."""
    for tr in re.findall(r"<tr.*?</tr>", sayfa, flags=re.S | re.I):
        h = [temiz(td) for td in re.findall(r"<t[dh].*?</t[dh]>", tr, flags=re.S | re.I)]
        if len(h) >= 2 and h[0].lower() == "öğrenci":
            m = re.match(r"(\d+)[,.]\d+", h[1])
            if m:
                tl = int(m.group(1))
                return [{"label": "Öğrenci (Öğle Yemeği)", "tl": tl}, {"label": "Öğrenci (Akşam Yemeği)", "tl": tl}]
    return []


def karsilastir(ocr_gunleri: dict, elle_gunleri: dict):
    """Ortak günlerde adları ve kaloriler aynı olanların sayısı: (örtüşen gün, ortak gün)."""
    ortak = sorted(set(ocr_gunleri) & set(elle_gunleri))

    def imza(gun):
        return {o: [(i["name"].lower(), i.get("kcal")) for i in v["items"]] for o, v in gun.items()}
    return sum(1 for t in ortak if imza(ocr_gunleri[t]) == imza(elle_gunleri[t])), len(ortak)


class OrtaDoguTeknik(Universite):
    id = "odtu"
    ad = "Orta Doğu Teknik Üniversitesi"
    kisa = "ODTÜ"
    sehir = "Ankara"
    kaynak = ANA_SAYFA

    def __init__(self, indirici=indir, okuyucu=None):
        self.indir = indirici
        self.okuyucu = okuyucu or ocr          # testte sahte OCR verilebilir

    def pdf_menusu(self) -> dict:
        if not self.okuyucu.kullanilabilir():
            print("UYARI: tesseract kurulu değil; ODTÜ menüsü yalnızca elle girilmiş verilerden alınıyor")
            return {}
        baglanti = pdf_baglantisi(self.indir(ANA_SAYFA).decode("utf-8", "ignore"))
        if not baglanti:
            print("UYARI: ODTÜ ana sayfasında 'Aylık Menü' PDF bağlantısı bulunamadı")
            return {}
        gorseller = pdf_gorselleri(self.indir(baglanti))
        sonuc = {}
        for resim in gorseller:
            for psm in (6, 11):            # iki farklı sayfa çözümleme kipi; ilk geçerli okuma kazanır
                okunan = self.okuyucu.kelimeler(resim, psm)
                if okunan:
                    genislik, _, kelimeler = okunan
                    for tarih, gun in tablo_ayikla(kelimeler, genislik).items():
                        sonuc.setdefault(tarih, gun)
        print("ODTÜ OCR: %d görsel okundu, %d gün doğrulandı (%s)" % (len(gorseller), len(sonuc), baglanti))
        return sonuc

    def menuler(self) -> dict:
        gunler = elle.yukle(self.id)
        try:
            okunan = self.pdf_menusu()
        except Exception as e:
            print("UYARI: ODTÜ aylık menü PDF'i okunamadı:", e)
            okunan = {}
        if okunan and gunler:
            ayni, ortak = karsilastir(okunan, gunler)
            print("ODTÜ OCR: elle girilenle ortak %d günün %d tanesi birebir aynı" % (ortak, ayni))
        for tarih, gun in okunan.items():
            gunler.setdefault(tarih, gun)
        return gunler

    def saatler(self) -> dict:
        try:
            return saat_ayikla(self.indir(SAAT_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: ODTÜ saatleri alınamadı:", e)
            return {}

    def fiyatlar(self) -> list:
        try:
            return ucret_ayikla(self.indir(FIYAT_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: ODTÜ fiyatları alınamadı:", e)
            return []
