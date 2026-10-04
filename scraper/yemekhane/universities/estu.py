"""Eskişehir Teknik Üniversitesi: öğrenci yemekhanesinin aylık menüsü Sağlık, Kültür ve Spor sitesinin 'Yemekhaneler' sayfasında
(`YEMEKHANE: Yemek Menüsü (Ekim-2026)`) Word'den üretilmiş metin tabanlı bir PDF olarak yayınlanıyor. ('Akademik Kulüp' haftalık menüsü
à la carte bir personel restoranıdır, alınmaz.) PDF, her hafta için 5 gün sütunu içerir; sütunda yemek adı | miktar | kalori satırları vardır.
Adı '*' ile biten satır, kendinden önceki ana yemeğin etsiz karşılığıdır ('*ETSİZ' açıklaması): normal menüde yer almaz, vejetaryen menüde ana yemek yerine geçer.
Tatil günlerinin sütununda 'RESMİ TATİL' / '29 EKİM CUMHURİYET BAYRAMI' yazar.
"""
import html
import re
import urllib.parse
from collections import defaultdict
from datetime import date, timedelta

from .. import pdf
from ..model import baslik_yap_serbest
from .base import Universite, indir

SAYFA_URL = "https://saglikkulturspor.eskisehir.edu.tr/tr/Icerik/Detay/yemekhaneler"

BASLIK = re.compile(r"^(\d{2})\.(\d{2})\.(\d{4})\s+\S+$")           # '01.10.2026 Perşembe'
MIKTAR = re.compile(r"^\d+\s*(gr|g|ml)\b", re.I)                     # '200 gr.', '90 gr. +Garn.', '200 ml.'
KALORI = re.compile(r"^\d{1,4}$")
SUTUN_PAYI = 38          # gün başlığının sol kenardan uzaklığı: yemek adı sütunu başlıktan bu kadar önce başlar (pt)
SATIR_ARALIGI = 1.5      # aynı satırdaki hücrelerin y farkı en çok bu kadar olabilir


def _kucuk(metin: str) -> str:
    return metin.replace("İ", "i").replace("I", "ı").lower()


def temiz(h: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", h)).replace("\xa0", " ")).strip()


def pdf_baglantisi(sayfa: str):
    """'Yemekhaneler' sayfasında metni 'Yemek Menüsü' ile başlayan PDF bağlantısı ('Haftalık Yemek Menüsü' akademik kulüptür)."""
    for m in re.finditer(r'<a [^>]*href="([^"]+)"[^>]*>(.*?)</a>', sayfa, flags=re.S | re.I):
        if _kucuk(temiz(m.group(2))).startswith("yemek menüsü") and ".pdf" in m.group(1).lower():
            return urllib.parse.urljoin(SAYFA_URL, m.group(1))
    return None


def yemek_adi(ad: str) -> str:
    ad = ad.strip().rstrip("*").strip()
    ad = re.sub(r"\s*\+\s*GARN\.?", " + Garnitür", ad, flags=re.I)
    ad = re.sub(r"\bZY\.\s*", "Zeytinyağlı ", ad, flags=re.I)
    return re.sub(r"\s+", " ", baslik_yap_serbest(ad)).strip()


def _satirlar(kelimeler):
    """[(x, y, metin)] -> y'si yakın olanlar aynı satırda, yukarıdan aşağıya, her satır soldan sağa."""
    satirlar = []
    for k in sorted(kelimeler, key=lambda k: -k[1]):
        if satirlar and abs(satirlar[-1][0] - k[1]) <= SATIR_ARALIGI:
            satirlar[-1][1].append(k)
        else:
            satirlar.append([k[1], [k]])
    return [sorted(s[1]) for s in satirlar]


def menu_olustur(ogeler: list) -> tuple:
    """[(ad_yıldızlı, kcal|None), ...] -> (normal menü kalemleri, vejetaryen kalemleri | None)."""
    yildizli = {i for i, (a, _) in enumerate(ogeler) if a.endswith("*")}
    normal = [(a, k) for i, (a, k) in enumerate(ogeler) if i not in yildizli]
    if not yildizli:
        return normal, None
    cikar = set()
    for i in sorted(yildizli):
        j = i - 1
        while j >= 0 and (j in yildizli or j in cikar):
            j -= 1
        if j >= 0:
            cikar.add(j)               # etsiz yemeğin yerine geçtiği (önceki) ana yemek
    return normal, [(a, k) for i, (a, k) in enumerate(ogeler) if i not in cikar]


def _ogun(kalemler: list) -> dict:
    ogeler = []
    for ad, kcal in kalemler:
        oge = {"name": yemek_adi(ad)}
        if kcal is not None:
            oge["kcal"] = kcal
        ogeler.append(oge)
    gun = {"items": ogeler}
    if ogeler and all("kcal" in o for o in ogeler):
        gun["kcal"] = sum(o["kcal"] for o in ogeler)
    return gun


def _medyan(sayilar):
    s = sorted(sayilar)
    return s[len(s) // 2]


def _sutun_izgarasi(basliklar) -> list:
    """Hafta içi günlerin (Pzt..Cum) sütun başlangıçları: aynı gün başlıklarının x ortancası. Hiç başlığı olmayan gün komşulardan tahmin edilir."""
    x = {g: _medyan([b[0] for b in basliklar if b[3] == g]) for g in range(5) if any(b[3] == g for b in basliklar)}
    if not x:
        return []
    aralik = _medyan([x[g + 1] - x[g] for g in range(4) if g in x and g + 1 in x] or [155.0])
    for g in range(5):
        if g not in x:
            x[g] = x[g - 1] + aralik if g - 1 in x else x[g + 1] - aralik
    return [x[g] for g in range(5)]


def tablo_menu(kelimeler) -> dict:
    """PDF sayfasının konumlu metninden {'2026-10-01': {'lunch': {...}, 'vegetarian': {...}}, ...}.
    Tarih başlığı olmayan sütunlar (örn. başlığı 'CUMHURİYET BAYRAMI' yazan gün) haftanın başlıklı günlerinden hesaplanır."""
    basliklar = []
    for x, y, _, m in kelimeler:
        b = BASLIK.match(m.strip())
        if b:
            d = date(int(b.group(3)), int(b.group(2)), int(b.group(1)))
            basliklar.append((x, y, d, d.weekday()))
    basliklar = [b for b in basliklar if b[3] < 5]
    izgara = _sutun_izgarasi(basliklar)
    if not izgara:
        return {}
    gruplar = []                                       # aynı hafta satırındaki başlıklar (y farkı 3 pt içinde)
    for b in sorted(basliklar, key=lambda b: -b[1]):
        if gruplar and abs(gruplar[-1][0] - b[1]) <= 3:
            gruplar[-1][1].append(b)
        else:
            gruplar.append([b[1], [b]])
    sonuc = {}
    for sira, (y0, uyeler) in enumerate(gruplar):
        alt = gruplar[sira + 1][0] + 3 if sira + 1 < len(gruplar) else float("-inf")
        pazartesi = uyeler[0][2] - timedelta(days=uyeler[0][3])
        baslik_satiri = [(x, y, m.strip()) for x, y, _, m in kelimeler if abs(y - y0) <= 3 and not BASLIK.match(m.strip())]
        govde = [(x, y, m.strip()) for x, y, _, m in kelimeler if alt < y < y0 - 3]
        for g in range(5):
            tarih = pazartesi + timedelta(days=g)
            sol = izgara[g] - SUTUN_PAYI
            sag = izgara[g + 1] - SUTUN_PAYI if g < 4 else float("inf")
            ogeler, tatil = [], None
            for x, _, m in baslik_satiri:                  # başlık satırında yazan tatil açıklaması
                if sol <= x < sag and re.search(r"tatil|bayram", _kucuk(m)):
                    tatil = m
            for satir in _satirlar([t for t in govde if sol <= t[0] < sag]):
                ad = " ".join(m for _, _, m in satir if not MIKTAR.match(m) and not KALORI.match(m) and m not in ("Miktar", "Kalori"))
                kcal = next((int(m) for _, _, m in satir if KALORI.match(m)), None)
                miktar = any(MIKTAR.match(m) for _, _, m in satir)
                if re.search(r"tatil|bayram", _kucuk(ad)):
                    tatil = tatil if tatil and "bayram" in _kucuk(tatil) else ad
                elif ad and (kcal is not None or miktar):
                    ogeler.append((ad, kcal))
            if ogeler:
                normal, veg = menu_olustur(ogeler)
                sonuc[tarih.isoformat()] = {"lunch": _ogun(normal)}
                if veg:
                    sonuc[tarih.isoformat()]["vegetarian"] = _ogun(veg)
            elif tatil:
                aciklama = baslik_yap_serbest(tatil) if "bayram" in _kucuk(tatil) else "Resmi tatil"
                sonuc[tarih.isoformat()] = {"lunch": {"items": [], "note": aciklama}}
    return sonuc


class EskisehirTeknik(Universite):
    id = "estu"
    ad = "Eskişehir Teknik Üniversitesi"
    kisa = "ESTÜ"
    sehir = "Eskişehir"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        baglanti = pdf_baglantisi(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
        if not baglanti:
            raise RuntimeError("ESTÜ 'Yemekhaneler' sayfasında 'Yemek Menüsü' PDF bağlantısı bulunamadı")
        sonuc = {}
        for sayfa in pdf.sayfa_metinleri(self.indir(baglanti)):
            sonuc.update(tablo_menu(sayfa))
        return sonuc
