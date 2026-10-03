"""Gazi Üniversitesi SKS: haftalık öğle menüsü mediko.gazi.edu.tr sitesinde HTML tablo olarak yayınlanıyor.

Tablo her hafta için şu satırlardan oluşuyor: tarih başlığı, çorba, ana yemek, '*' ile başlayan etsiz ana yemek, yan yemek,
tatlı/meyve ve 'Kalori:NNNN'. Tatil günlerinde hücrelerde 'TATİL' yazıyor.
"""
import html
import re
from datetime import date

from ..model import baslik_yap, toplam_kalori
from .base import Universite, indir

MENU_URL = "https://mediko.gazi.edu.tr/view/page/20412/yemek-listesi"
UCRET_URL = "https://mediko.gazi.edu.tr/view/page/264777"

AYLAR = {"ocak": 1, "şubat": 2, "mart": 3, "nisan": 4, "mayıs": 5, "haziran": 6,
         "temmuz": 7, "ağustos": 8, "eylül": 9, "ekim": 10, "kasım": 11, "aralık": 12}
TARIH = re.compile(r"(\d{1,2})\s+(" + "|".join(AYLAR) + r")\s+(\d{4})", re.I)

# Okulun listede kısalttığı sözcükler
KISALTMALAR = [
    (re.compile(r"\bŞeh\.\s*li\b", re.I), "Şehriyeli"),
    (re.compile(r"\bZyt\.\s*lı\b", re.I), "Zeytinyağlı"),
    (re.compile(r"\bZyt\.", re.I), "Zeytinyağlı "),
    (re.compile(r"\bPat\.", re.I), "Patates "),
]


ETLI = re.compile(r"kıymalı|etli|tavuk|döner|köfte")


def _kucuk(metin: str) -> str:
    return metin.replace("İ", "i").replace("I", "ı").lower()


def hucre_metni(h: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", h)).replace("\xa0", " ")).strip()


def yemek_adi(metin: str) -> str:
    """'*Etsiz Karnabahar' -> 'Etsiz Karnabahar'; kısaltmaları açar, baş harfleri düzeltir."""
    metin = metin.strip().lstrip("*").strip()
    for kalip, yerine in KISALTMALAR:
        metin = kalip.sub(yerine, metin)
    return baslik_yap(metin)


def tablolar(sayfa: str):
    """Sayfadaki tüm tabloları satır / hücre metinleri listesine çevirir."""
    for tablo in re.findall(r"<table.*?</table>", sayfa, flags=re.S | re.I):
        yield [[hucre_metni(td) for td in re.findall(r"<t[dh].*?</t[dh]>", tr, flags=re.S | re.I)]
               for tr in re.findall(r"<tr.*?</tr>", tablo, flags=re.S | re.I)]


def hafta_tarihleri(satir):
    """Satırdaki hücrelerin tamamı 'gün Ay yıl' ise ISO tarih listesi, değilse None."""
    sonuc = []
    for h in satir:
        m = TARIH.search(h)
        if not m:
            return None
        sonuc.append(date(int(m.group(3)), AYLAR[_kucuk(m.group(2))], int(m.group(1))).isoformat())
    return sonuc or None


def gun_menusu(hucreler, kalori):
    """Bir günün hücreleri (çorba, ana, etsiz ana, yan, tatlı...) -> (öğle, vejetaryen) ya da None (tatil / boş)."""
    dolu = [h for h in hucreler if h.strip("* ")]
    if any(_kucuk(h).strip("* ") == "tatil" for h in hucreler):
        return {"items": [], "note": "Tatil"}, None          # uygulama "Tatil: yemek yok" gösterir
    if not dolu:
        return None
    ogle = [{"name": yemek_adi(h)} for h in hucreler if h.strip("* ") and not h.startswith("*")]
    gun = {"items": ogle}
    k = toplam_kalori(kalori or "")
    if k:
        gun["kcal"] = k
    # Etsiz seçenek: '*' ile başlayan ana yemek varsa vejetaryen menü = ana yemek hariç tüm satırlar
    yildizli = any(h.startswith("*") and h.strip("* ") for h in hucreler)
    etsiz_ana = len(hucreler) > 1 and _kucuk(hucreler[1]).startswith("etsiz")
    veg = None
    if yildizli or etsiz_ana:
        sira = [h for i, h in enumerate(hucreler) if h.strip("* ") and (i != 1 or etsiz_ana)]     # 1. sıra: etli ana yemek
        sira = [h for h in sira if h.startswith("*") or not ETLI.search(_kucuk(h))]               # ortak yan yemek etliyse çıkar
        veg = {"items": [{"name": yemek_adi(h)} for h in sira]}
    return gun, veg


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-10-05': {'lunch': {...}, 'vegetarian': {...}}, ...}"""
    sonuc = {}
    for satirlar in tablolar(sayfa):
        i = 0
        while i < len(satirlar):
            tarihler = hafta_tarihleri(satirlar[i])
            if not tarihler:
                i += 1
                continue
            govde = []
            i += 1
            while i < len(satirlar) and hafta_tarihleri(satirlar[i]) is None:
                govde.append(satirlar[i])
                i += 1
            kalori = next((s for s in govde if s and _kucuk(s[0]).startswith("kalori")), [])
            yemekler = [s for s in govde if s and not _kucuk(s[0]).startswith("kalori")]
            for sutun, tarih in enumerate(tarihler):
                hucreler = [s[sutun] if sutun < len(s) else "" for s in yemekler]
                kal = kalori[sutun] if sutun < len(kalori) else ""
                bulunan = gun_menusu(hucreler, kal)
                if not bulunan:
                    continue
                gun, veg = bulunan
                sonuc[tarih] = {"lunch": gun}
                if veg:
                    sonuc[tarih]["vegetarian"] = veg
    return sonuc


def ucret_ayikla(sayfa: str) -> list:
    """Ücret tablosundan öğrenci fiyatı: [{'label': 'Öğrenci (Öğle Yemeği)', 'tl': 50}]."""
    for satirlar in tablolar(sayfa):
        for s in satirlar:
            if len(s) >= 2 and _kucuk(s[0]).startswith("üniversitemiz öğrenci"):
                m = re.search(r"(\d+)", s[1])
                if m:
                    return [{"label": "Öğrenci (Öğle Yemeği)", "tl": int(m.group(1))}]
    return []


class GaziUniversitesi(Universite):
    id = "gazi"
    ad = "Gazi Üniversitesi"
    kisa = "GÜ"
    sehir = "Ankara"
    kaynak = MENU_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(MENU_URL).decode("utf-8", "ignore"))

    def fiyatlar(self) -> list:
        try:
            return ucret_ayikla(self.indir(UCRET_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: Gazi fiyatları alınamadı:", e)
            return []
