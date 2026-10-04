"""Mimar Sinan Güzel Sanatlar Üniversitesi: aylık menü, msgsu.edu.tr medya kütüphanesine yüklenen metin tabanlı bir PDF'tir
(`2026-Ekim-Ayi-Menu.pdf`). Dosya adı her ay değiştiği için WordPress REST API'sinde ('wp-json/wp/v2/media?search=menu') en yeni 'menü' PDF'i aranır.
PDF'te her hafta için: tarih satırı (01/10/2026 ...), günlük toplam kalori satırı ('1170 kcal') ve 4 yemek satırı (çorba, ana yemek, pilav/makarna, salata-tatlı-içecek) vardır;
gün sütunları tarihlerin x konumundan bulunur. Bayram/tatil günlerinde sütunda 'CUMHURİYET BAYRAMI' yazar; 'YARIM GÜN' yazan günde menü yoktur.
Yalnızca öğle yemeği yayınlanır; öğrenci ücreti ve servis saati sayfada yazmıyor.
"""
import json
import re
from datetime import date

from .. import pdf
from ..model import baslik_yap_serbest
from .base import Universite, indir

MEDYA_URL = "https://msgsu.edu.tr/wp-json/wp/v2/media?search=menu&per_page=20&orderby=date&order=desc"
TARIH = re.compile(r"^(\d{2})/(\d{2})/(\d{4})$")
KCAL = re.compile(r"^(\d{3,4})\s*kcal$", re.I)
SATIR_ARALIGI = 2.0


def _kucuk(metin: str) -> str:
    return metin.replace("İ", "i").replace("I", "ı").lower()


def en_yeni_menu_pdf(govde: str):
    """WordPress medya listesinden en yeni (liste tarihe göre azalan sırada) menü PDF'inin adresi; yoksa None."""
    try:
        kayitlar = json.loads(govde)
    except ValueError:
        return None
    for k in kayitlar:
        adres = k.get("source_url", "")
        if adres.lower().endswith(".pdf") and "menu" in _kucuk(adres).replace("ü", "u") and "yonerge" not in adres.lower():
            return adres
    return None


def _satirlar(kelimeler):
    satirlar = []
    for k in sorted(kelimeler, key=lambda k: -k[1]):
        if satirlar and abs(satirlar[-1][0] - k[1]) <= SATIR_ARALIGI:
            satirlar[-1][1].append(k)
        else:
            satirlar.append([k[1], [k]])
    return [(y, sorted(s)) for y, s in satirlar]


def yemek_ogeleri(hucre: str) -> list:
    """'HAMBURGER/elma dilim patates' -> [Hamburger, Elma Dilim Patates]"""
    sonuc = []
    for p in hucre.split("/"):
        ad = re.sub(r"\s+", " ", baslik_yap_serbest(p.strip()))
        if ad:
            sonuc.append({"name": ad})
    return sonuc


def sayfa_menu(kelimeler) -> dict:
    """PDF sayfasının konumlu metninden {'2026-10-01': {'lunch': {'items': [...], 'kcal': 1170}}, ...}"""
    satirlar = _satirlar(kelimeler)
    tarih_satirlari = [(i, [(k[0], date(int(m.group(3)), int(m.group(2)), int(m.group(1)))) for k in s for m in [TARIH.match(k[3].strip())] if m])
                       for i, (y, s) in enumerate(satirlar)]
    tarih_satirlari = [(i, t) for i, t in tarih_satirlari if t]
    # gün sütunları: her haftanın gününün tarih belirteci x konumunun ortancası (hafta içi 0-4)
    konumlar = {}
    for _, t in tarih_satirlari:
        for x, d in t:
            konumlar.setdefault(d.weekday(), []).append(x)
    if not konumlar:
        return {}
    x_gun = {g: sorted(v)[len(v) // 2] for g, v in konumlar.items() if g < 5}
    if len(x_gun) < 2:
        return {}
    gunler = sorted(x_gun)
    sinirlar = {g: (((x_gun[gunler[i - 1]] + x_gun[g]) / 2) if i else float("-inf"),
                    ((x_gun[g] + x_gun[gunler[i + 1]]) / 2) if i + 1 < len(gunler) else float("inf")) for i, g in enumerate(gunler)}
    sonuc = {}
    for sira, (i, t) in enumerate(tarih_satirlari):
        son = tarih_satirlari[sira + 1][0] if sira + 1 < len(tarih_satirlari) else len(satirlar)
        govde = satirlar[i + 1:son]
        for _, d in t:
            if d.weekday() not in sinirlar:
                continue
            sol, sag = sinirlar[d.weekday()]
            hucreler = [[k[3].strip() for k in s if sol <= k[0] < sag] for _, s in govde]
            kcal = next((int(KCAL.match(h).group(1)) for satir in hucreler for h in satir if KCAL.match(h)), None)
            yemekler = [h for satir in hucreler for h in satir if not KCAL.match(h)]
            if any("bayram" in _kucuk(h) or "tatil" in _kucuk(h) for h in yemekler):
                bayram = next(h for h in yemekler if "bayram" in _kucuk(h) or "tatil" in _kucuk(h))
                sonuc[d.isoformat()] = {"lunch": {"items": [], "note": baslik_yap_serbest(bayram)}}
            elif kcal and yemekler:
                ogeler = [o for h in yemekler for o in yemek_ogeleri(h)]
                sonuc[d.isoformat()] = {"lunch": {"items": ogeler, "kcal": kcal}}
    return sonuc


class MimarSinanGuzelSanatlar(Universite):
    id = "msgsu"
    ad = "Mimar Sinan Güzel Sanatlar Üniversitesi"
    kisa = "MSGSÜ"
    sehir = "İstanbul"
    kaynak = "https://msgsu.edu.tr/ogrenci/kampuste-yasam/beslenme/"

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        adres = en_yeni_menu_pdf(self.indir(MEDYA_URL).decode("utf-8", "ignore"))
        if not adres:
            raise RuntimeError("MSGSÜ medya kütüphanesinde menü PDF'i bulunamadı")
        sonuc = {}
        for sayfa in pdf.sayfa_metinleri(self.indir(adres)):
            sonuc.update(sayfa_menu(sayfa))
        return sonuc
