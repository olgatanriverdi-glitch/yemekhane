"""Ankara Yıldırım Beyazıt Üniversitesi: haftalık menü aybu.edu.tr/sks üzerinde HTML olarak yayınlanıyor
(normal menü ve vejetaryen menü ayrı sayfalar). Her hafta 'GG.AA.YYYY - GG.AA.YYYY' başlığı ve gün sekmeleri içerir;
yemekler 'Ad 123 kkal' biçimindedir. Öğrenci yemekhanesi öğle yemeği verir.
"""
import html
import re
from datetime import date, timedelta

from .base import Universite, indir

MENU_URL = "https://aybu.edu.tr/sks/tr/sayfa/6265"
VEJETARYEN_URL = "https://aybu.edu.tr/sks/tr/sayfa/10423"
UCRET_URL = "https://aybu.edu.tr/beslenme/tr/sayfa/10304"

GUNLER = {"pazartesi": 0, "salı": 1, "çarşamba": 2, "perşembe": 3, "cuma": 4, "cumartesi": 5, "pazar": 6}
KISALTMALAR = [
    (re.compile(r"\bŞeh\.\s*", re.I), "Şehriyeli "),
    (re.compile(r"\bKızt\.", re.I), "Kızartma"),
    (re.compile(r"\bDomt\.", re.I), "Domatesli"),
    (re.compile(r"\bM\.suyu", re.I), "Meyve Suyu"),
    (re.compile(r"\bKarşık\b", re.I), "Karışık"),
]
OGE = re.compile(r"^(.*?)\s*(\d+)\s*k[a-zı]*\s*$", re.I)       # 'Çorba 165 kkal' (okulun 'kkakl' gibi yazım hatalarına dayanıklı)


def temiz(metin: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", metin)).replace("\xa0", " ")).strip()


def yemek_ogesi(metin: str):
    metin = temiz(metin)
    if not metin:
        return None
    m = OGE.match(metin)
    ad, kcal = (m.group(1), int(m.group(2))) if m else (metin, None)
    for kalip, yerine in KISALTMALAR:
        ad = kalip.sub(yerine, ad)
    ad = re.sub(r"\s+", " ", ad).strip(" /-")
    if not ad:
        return None
    oge = {"name": ad}
    if kcal:
        oge["kcal"] = kcal
    return oge


def tarih_araligi(metin: str):
    m = re.search(r"(\d{2})\.(\d{2})\.(\d{4})\s*-\s*(\d{2})\.(\d{2})\.(\d{4})", metin)
    if not m:
        return None
    g1, a1, y1, g2, a2, y2 = map(int, m.groups())
    return date(y1, a1, g1), date(y2, a2, g2)


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-10-05': {'items': [...], 'kcal': n}, ...}"""
    sonuc = {}
    pozisyonlar = [m.start() for m in re.finditer(r'<div class="sks-week[ "][^>]*id="week', sayfa)]
    for i, bas in enumerate(pozisyonlar):
        blok = sayfa[bas:pozisyonlar[i + 1] if i + 1 < len(pozisyonlar) else len(sayfa)]
        ara = re.search(r'sks-week-date[^>]*>([^<]*)<', blok)
        aralik = tarih_araligi(ara.group(1)) if ara else None
        if not aralik:
            continue
        gun_tarihleri = {}
        d = aralik[0]
        while d <= aralik[1]:
            gun_tarihleri[d.weekday()] = d
            d += timedelta(days=1)
        for kart in re.finditer(r'<div class="sks-menu-card-head">(.*?)</div>\s*<ul class="sks-menu-list">(.*?)</ul>', blok, flags=re.S):
            ad = temiz(kart.group(1)).lower().replace("i̇", "i")
            haftagunu = GUNLER.get(ad)
            if haftagunu is None or haftagunu not in gun_tarihleri:
                continue                # aralığın dışındaki (boş) günler
            ogeler = [o for o in (yemek_ogesi(li) for li in re.findall(r"<li>(.*?)</li>", kart.group(2), flags=re.S)) if o]
            if not ogeler:
                continue
            gun = {"items": ogeler}
            if all("kcal" in o for o in ogeler):
                gun["kcal"] = sum(o["kcal"] for o in ogeler)
            sonuc[gun_tarihleri[haftagunu].isoformat()] = gun
    return sonuc


def ucret_ayikla(sayfa: str) -> list:
    """Birim ücret tablosundan öğrenci ücreti: [{'label': 'Öğrenci (Öğle Yemeği)', 'tl': 50}]."""
    for tablo in re.findall(r"<table.*?</table>", sayfa, flags=re.S | re.I):
        for tr in re.findall(r"<tr.*?</tr>", tablo, flags=re.S | re.I):
            hucreler = [temiz(td) for td in re.findall(r"<t[dh].*?</t[dh]>", tr, flags=re.S | re.I)]
            if len(hucreler) >= 2 and hucreler[0].upper().startswith("ÖĞRENC"):
                m = re.search(r"(\d+)[,.]\d+\s*TL", hucreler[1])
                if m:
                    return [{"label": "Öğrenci (Öğle Yemeği)", "tl": int(m.group(1))}]
    return []


class AnkaraYildirimBeyazit(Universite):
    id = "aybu"
    ad = "Ankara Yıldırım Beyazıt Üniversitesi"
    kisa = "AYBÜ"
    sehir = "Ankara"
    kaynak = MENU_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        sonuc = {}
        for tarih, gun in sayfa_menu(self.indir(MENU_URL).decode("utf-8", "ignore")).items():
            sonuc[tarih] = {"lunch": gun}
        try:
            for tarih, gun in sayfa_menu(self.indir(VEJETARYEN_URL).decode("utf-8", "ignore")).items():
                if tarih in sonuc:
                    sonuc[tarih]["vegetarian"] = {"items": gun["items"]}
        except Exception as e:
            print("UYARI: AYBÜ vejetaryen menüsü alınamadı:", e)
        return sonuc

    def fiyatlar(self) -> list:
        try:
            return ucret_ayikla(self.indir(UCRET_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: AYBÜ fiyatları alınamadı:", e)
            return []
