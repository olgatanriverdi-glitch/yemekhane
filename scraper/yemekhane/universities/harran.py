"""Harran SKS: aylık HTML tablosunda yemek ve kalori satırları dönüşümlüdür.
İki 'SEÇMELİ ANA YEMEK' ve üç yardımcı yemek öğle listesi olarak alınır.
Ana yemeklerin ikisi birlikte yenmediğinden kalorileri toplanmaz; her
kalemin kalorisi korunur. Boş ayraçlar atlanır, resmî tatil not olarak kalır.
"""
import re
from datetime import date

from ..model import TR_KUCUK, baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.harran.edu.tr/idari/daire-baskanliklari/saglik-kultur-ve-spor-daire-baskanligi/baglantilar/yemek-menusu"


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for tablo in re.findall(r"<table\b[^>]*>(.*?)</table>", sayfa, re.S | re.I):
        if "SEÇMELİ ANA YEMEK" not in etiket_temizle(tablo):
            continue
        satirlar = [[etiket_temizle(h) for h in re.findall(r"<td\b[^>]*>(.*?)</td>", s, re.S | re.I)]
                    for s in re.findall(r"<tr\b[^>]*>(.*?)</tr>", tablo, re.S | re.I)]
        for i, hucreler in enumerate(satirlar):
            if len(hucreler) != 6:
                continue
            t = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", hucreler[0])
            if not t:
                continue
            try:
                tarih = date(int(t.group(3)), int(t.group(2)), int(t.group(1)))
            except ValueError:
                continue
            adlar = [a for a in hucreler[1:] if a and a != "-"]
            if not adlar:
                continue
            if all("tatil" in a.translate(TR_KUCUK).lower() for a in adlar):
                sonuc[tarih.isoformat()] = {"lunch": {"items": [], "note": "Resmi tatil"}}
                continue
            kaloriler = satirlar[i + 1] if i + 1 < len(satirlar) else []
            # Kalori satırının ilk hücresi gün adıdır; yeni tarih satırı olamaz.
            if len(kaloriler) != 6 or re.search(r"\d", kaloriler[0]):
                kaloriler = [""] * 6
            ogeler = []
            for ad, kcal in zip(hucreler[1:], kaloriler[1:]):
                if not ad or ad == "-":
                    continue
                oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
                if kcal.isdigit() and int(kcal) > 0:
                    oge["kcal"] = int(kcal)
                ogeler.append(oge)
            sonuc[tarih.isoformat()] = {"lunch": {"items": ogeler}}
    return sonuc


class HarranUniversitesi(Universite):
    id = "harran"
    ad = "Harran Üniversitesi"
    kisa = "HRÜ"
    sehir = "Şanlıurfa"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("Harran: SKS yemek menüsü indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Harran: tarihli seçmeli yemek tablosu bulunamadı")
        return sonuc
