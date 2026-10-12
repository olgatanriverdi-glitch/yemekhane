"""Bursa Uludağ Üniversitesi: uludag.edu.tr/yemek sayfası (SKDB) Öğrenci / Vejetaryen / Personel sekmelerini günlük, haftalık ve aylık görünümde verir.
Aylık görünümde her sekme 'Öğle Yemeği' ve 'Akşam Yemeği' başlıklı kart ızgarasıdır: `<small>1.10.2026</small>` tarihli kartta her yemek ayrı `<p>`,
sonunda alerjen numaraları '(1,3,4)'. Tatil kartında yalnızca 'RESMİ TATİL' yazar. Kalori yayınlanmaz.
Eşleme: Öğrenci öğle -> lunch, Öğrenci akşam -> dinner, Vejetaryen öğle -> vegetarian (vejetaryen akşam ve personel menüsü alınmaz).
"""
import re
from datetime import date

from ..model import TR_KUCUK, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://uludag.edu.tr/yemek"
ALERJEN = re.compile(r"\s*\((?:\s*\d+\s*,?)+\s*\)\s*$")
BASLIK = re.compile(r'<h5 class="mt-n1 mb-0"[^>]*>\s*([^<]+?)\s*</h5>')


def yemek_adi(metin: str) -> str:
    return baslik_yap_serbest(kisaltma_ac(ALERJEN.sub("", etiket_temizle(metin)).strip()))


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-10-12': {'lunch': {...}, 'dinner': {...}, 'vegetarian': {...}}, ...}; tatil günü: {'items': [], 'note': 'Resmi tatil'}."""
    bas = sayfa.find("aylik")
    sayfa = sayfa[bas:] if bas >= 0 else sayfa
    sonuc = {}
    grup = None          # 'ogrenci' | 'vejetaryen' | 'personel'
    ogun = None
    # başlıklar ve kartlar belge sırasıyla taranır
    for m in re.finditer(r'<h5 class="mt-n1 mb-0"[^>]*>\s*([^<]+?)\s*</h5>|<div class="card h-100">(.*?)(?=<div class="card h-100">|<h5 class="mt-n1 mb-0"|\Z)', sayfa, re.S):
        if m.group(1):
            b = m.group(1).translate(TR_KUCUK).lower()
            if "yemek menüsü" in b:
                grup = "vejetaryen" if "vejetaryen" in b else "personel" if "personel" in b else "ogrenci"
                ogun = None
            elif b.startswith("öğle"):
                ogun = "ogle"
            elif b.startswith("akşam"):
                ogun = "aksam"
            continue
        tur = {("ogrenci", "ogle"): "lunch", ("ogrenci", "aksam"): "dinner", ("vejetaryen", "ogle"): "vegetarian"}.get((grup, ogun))
        d = re.search(r"<small[^>]*>\s*(\d{1,2})\.(\d{1,2})\.(\d{4})\s*</small>", m.group(2))
        if not tur or not d:
            continue
        try:
            tarih = date(int(d.group(3)), int(d.group(2)), int(d.group(1)))
        except ValueError:
            continue
        adlar = [yemek_adi(p) for p in re.findall(r"<p>(.*?)</p>", m.group(2), re.S)]
        adlar = [a for a in adlar if a]
        if not adlar:
            continue
        if all("tatil" in a.translate(TR_KUCUK).lower() for a in adlar):
            gun = {"items": [], "note": "Resmi tatil"}
        else:
            gun = gun_icerigi([{"name": a} for a in adlar])
        sonuc.setdefault(tarih.isoformat(), {})[tur] = gun
    return sonuc


class BursaUludag(Universite):
    id = "uludag"
    ad = "Bursa Uludağ Üniversitesi"
    kisa = "BUÜ"
    sehir = "Bursa"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
