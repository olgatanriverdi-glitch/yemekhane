"""Karabük Üniversitesi: sks.karabuk.edu.tr ana sayfasındaki 'Aylık Yemek Listesi' bağlantısı (`/yuklenen/dosyalar/<sayı>.pdf`, ay değişince adı değişir) aylık tek sayfa
PDF'tir (gerçek metin). Düzen: 5 sütunlu hafta tablosu; her hücrede başlık ('5 EKİM  2026 PAZARTESİ') ve altında 'YEMEK(kalori)' satırları. Sığmayan uzun
adlar iki satıra bölünür (ilk satırda kalori yoktur; sonrakiyle birleştirilir), 'A(350)/B(435)' ve 'ÇİĞ KÖFTE (220)/TURŞU(50)' gibi satırlar birden çok kalemdir.
Başlık metni sütunda ortalı, yemekler sola yaslı olduğundan sütunlar yemeklerin x konumundan çıkarılıp başlık en yakın sütuna atanır. 'RESMİ TATİL' hücresi tatil günüdür.
Tek öğün (öğle). Ekim ve Kasım 2026 PDF'leriyle denendi; Kasım başlıkları GG.AA.YYYY biçimindedir.
"""
import re
from datetime import date

from .. import pdf as pdfmod
from ..model import TR_KUCUK, ay_no, baslik_yap_serbest, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sks.karabuk.edu.tr/index.aspx"
KOK_URL = "https://sks.karabuk.edu.tr"
BASLIK = re.compile(r"^(\d{1,2})\s+(\S+)\s+(\d{4})\s+\S+$")


def pdf_baglantisi(sayfa: str):
    m = re.search(r'href="(/yuklenen/dosyalar/[^"]+\.pdf)"[^>]*>\s*Aylık Yemek Listesi', sayfa)
    return KOK_URL + m.group(1) if m else None


def _ad(metin: str) -> str:
    metin = re.sub(r"\bŞEHR\.\s*", "ŞEHRİYELİ ", metin, flags=re.I)
    metin = re.sub(r"\bUS\.\s*", "USULÜ ", metin)
    metin = re.sub(r"\bKIZ\.", "KIZARTMASI", metin)
    metin = re.sub(r"\s*-\s+", "-", re.sub(r"\s+", " ", metin))
    return baslik_yap_serbest(kisaltma_ac(metin.strip(" .-/")))


def _kalemler(satir: str) -> list:
    """'A(350)/B(435)' -> iki kalem; kalori yoksa yalnız ad."""
    ogeler = []
    for parca in re.split(r"(?<=\))\s*/\s*", satir):
        m = re.match(r"^(.+?)\s*\(\s*(\d+)\s*\)\s*$", parca.strip())
        ad = _ad(m.group(1) if m else parca)
        if ad:
            ogeler.append({"name": ad, "kcal": int(m.group(2))} if m else {"name": ad})
    return ogeler


def pdf_menu(veri: bytes) -> dict:
    sayfalar = pdfmod.sayfa_metinleri(veri)
    if not sayfalar:
        return {}
    satirlar = [s for s in pdfmod.satirlari_birlestir(max(sayfalar, key=len), bosluk=1.0) if s[0].strip()]
    basliklar = []                                          # [(tarih, x, y)]
    diger = []                                              # [(metin, x, y)]
    for metin, x0, x1, y, _ in satirlar:
        b = BASLIK.match(re.sub(r"\s+", " ", metin.strip()))
        yeni = re.match(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})\s+\S+$', metin.strip())
        if yeni or (b and ay_no(b.group(2))):
            try:
                tarih = date(int(yeni.group(3)), int(yeni.group(2)), int(yeni.group(1))) if yeni else date(int(b.group(3)), ay_no(b.group(2)), int(b.group(1)))
                basliklar.append((tarih, x0, y))
            except ValueError:
                pass
        elif not re.search(r"[a-zçğıöşü]|YEMEK L[İI]STES[İI]", metin):          # imza satırları (Gıda Mühendisi, Daire Başkanı...) küçük harf içerir
            diger.append((metin.strip(), x0, y))
    if not basliklar:
        return {}
    # yakın sütun noktalarını (aynı sütunun satırları) birleştir
    kume = []
    for x in sorted(x for _, x, _ in diger):
        if not kume or x - kume[-1][-1] > 40:
            kume.append([x])
        else:
            kume[-1].append(x)
    sutunlar = [sum(k) / len(k) for k in kume]
    if not sutunlar:
        return {}

    def sutun(x):
        return min(range(len(sutunlar)), key=lambda i: abs(sutunlar[i] - x))

    hucre = {}                                              # (sütun, başlık_y) -> (tarih, [satırlar])
    for tarih, x, y in basliklar:
        hucre[(sutun(x), y)] = (tarih, [])
    for metin, x, y in sorted(diger, key=lambda o: -o[2]):
        s = sutun(x)
        ustler = [k for k in hucre if k[0] == s and k[1] > y]
        if not ustler:
            continue
        hucre[min(ustler, key=lambda k: k[1] - y)][1].append((y, metin))
    sonuc = {}
    for tarih, satirlar_ in hucre.values():
        birlesik, bekleyen = [], ""
        for _, metin in sorted(satirlar_, key=lambda o: -o[0]):
            bekleyen = (bekleyen + " " + metin).strip()
            if re.search(r"\(\s*\d+\s*\)\s*$", bekleyen) or re.search(r"\)\s*/", bekleyen):          # kalorisiz satır alt satırla devam eder
                birlesik.append(bekleyen)
                bekleyen = ""
        if bekleyen:
            birlesik.append(bekleyen)
        if len(birlesik) == 1 and "tatil" in birlesik[0].translate(TR_KUCUK).lower():
            sonuc[tarih.isoformat()] = {"lunch": {"items": [], "note": "Resmi tatil"}}
            continue
        ogeler = [o for satir in birlesik for o in _kalemler(satir)]
        if ogeler:
            sonuc[tarih.isoformat()] = {"lunch": gun_icerigi(ogeler)}
    return sonuc


class KarabukUniversitesi(Universite):
    id = "karabuk"
    ad = "Karabük Üniversitesi"
    kisa = "KBÜ"
    sehir = "Karabük"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        baglanti = pdf_baglantisi(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
        if not baglanti:
            raise RuntimeError("Karabük: 'Aylık Yemek Listesi' bağlantısı bulunamadı")
        return pdf_menu(self.indir(baglanti))
