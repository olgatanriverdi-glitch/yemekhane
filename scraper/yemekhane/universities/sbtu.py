"""Sivas Bilim ve Teknoloji Üniversitesi: aylık menü www.sivas.edu.tr/yemek-listesi sayfasında haftalara bölünmüş kartlar olarak yayınlanıyor.
Her öğün türü ayrı bir sekmedir (şimdilik yalnızca 'Öğlen Yemeği'); kartta 'Perşembe 01 Ekim 2026 12:00' başlığı ve kaloriyle birlikte yemekler bulunur:
`<span class="badge">262/285 kal</span>BİBER DOLMASI/ŞİNİTZEL` (seçmeli yemek 'a/b' ve kalorileri 'x/y' yazılır; ekmek de listededir).
"""
import re
from datetime import date

from ..model import ay_no, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.sivas.edu.tr/yemek-listesi"


def ogun_turu(sekme: str):
    s = sekme.replace("İ", "i").replace("I", "ı").lower()
    for anahtar, tur in (("kahvaltı", "breakfast"), ("öğle", "lunch"), ("akşam", "dinner"), ("vejetaryen", "vegetarian"), ("vegan", "vegetarian")):
        if anahtar in s:
            return tur
    return None


def oge_ayikla(li: str) -> list:
    """'<span class="badge">262/285 kal</span>BİBER DOLMASI/ŞİNİTZEL' -> iki öğe (kalorileri ayrı ayrı); sayılar uyuşmazsa kalorisiz."""
    k = re.search(r'<span class="badge">\s*([\d/]+)\s*kal\s*</span>', li, re.I)
    ad = etiket_temizle(re.sub(r'<span class="badge">.*?</span>', "", li, flags=re.S))
    parcalar = [p.strip() for p in ad.split("/") if p.strip()]
    kaloriler = [int(x) for x in k.group(1).split("/") if x] if k else []
    ogeler = []
    for i, parca in enumerate(parcalar):
        oge = {"name": baslik_yap_serbest(kisaltma_ac(parca))}
        if len(kaloriler) == len(parcalar) and kaloriler[i] > 0:
            oge["kcal"] = kaloriler[i]
        ogeler.append(oge)
    return ogeler


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-10-01': {'lunch': {'items': [...], 'kcal': 798}}, ...}. Seçmeli yemek olan günlerde günün toplam kalorisi yazılmaz."""
    sekmeler = {kimlik: ogun_turu(ad) for kimlik, ad in re.findall(r'<a href="#([\w-]+)" data-toggle="tab">(.*?)</a>', sayfa, re.S)}
    sonuc = {}
    for kimlik, govde in re.findall(r'<div class="tab-pane[^"]*" id="([\w-]+)">(.*?)(?=<div class="tab-pane|<!-- Footer|\Z)', sayfa, re.S):
        tur = sekmeler.get(kimlik)
        if not tur:
            continue
        for baslik, kart in re.findall(r'yemekhane-title[^>]*>\s*(.*?)\s*</span>(.*?)(?=yemekhane-title|\Z)', govde, re.S):
            m = re.search(r"(\d{1,2})\s+(\S+)\s+(\d{4})", etiket_temizle(baslik))
            ay = ay_no(m.group(2)) if m else None
            if not ay:
                continue
            try:
                tarih = date(int(m.group(3)), ay, int(m.group(1))).isoformat()
            except ValueError:
                continue
            ogeler, secmeli = [], False
            for li in re.findall(r"<li[^>]*>(.*?)</li>", kart, re.S):
                parcalar = oge_ayikla(li)
                ogeler += parcalar
                secmeli = secmeli or len(parcalar) > 1
            if ogeler:
                gun = gun_icerigi(ogeler)
                if secmeli:
                    gun.pop("kcal", None)             # 'a/b' seçmeli yemekte iki kalori da toplama girerdi
                sonuc.setdefault(tarih, {})[tur] = gun
    return sonuc


class SivasBilimTeknoloji(Universite):
    id = "sbtu"
    ad = "Sivas Bilim ve Teknoloji Üniversitesi"
    kisa = "SBTÜ"
    sehir = "Sivas"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
