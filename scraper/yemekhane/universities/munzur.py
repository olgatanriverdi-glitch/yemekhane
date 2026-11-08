"""Munzur SKS: aylık HTML tablosu, tek liste (öğle), kalori yayınlanmaz.

Sayfanın masaüstü/mobil kopyaları birleştirilir. Boş satırlar gün değildir;
ayrı hücrelere yazılmış RESMİ / TATİL tek tatil notu olarak korunur.
"""
import re
from datetime import date

from ..model import TR_KUCUK, ay_no, baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sks.munzur.edu.tr/yemek-listesi"


def sayfa_menu(sayfa):
    sonuc = {}
    for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", sayfa, re.S | re.I):
        h = [etiket_temizle(x) for x in re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)]
        if len(h) != 5:
            continue
        t = re.fullmatch(r"(\d{1,2})\s+(\S+)\s+(\d{4})\s+\S+", h[0])
        ay = ay_no(t[2]) if t else None
        if not ay:
            continue
        try:
            tarih = date(int(t[3]), ay, int(t[1])).isoformat()
        except ValueError:
            continue
        adlar = [a.strip(" .-–") for a in h[1:] if a.strip(" .-–")]
        if not adlar:
            continue
        if "tatil" in " ".join(adlar).translate(TR_KUCUK).lower():
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogun = {"items": [{"name": baslik_yap_serbest(kisaltma_ac(a))} for a in adlar]}
        gun = {"lunch": ogun}
        if tarih in sonuc and sonuc[tarih] != gun:
            raise ValueError("Munzur: %s için çelişen aylık menü kopyaları var" % tarih)
        sonuc[tarih] = gun
    return sonuc


class MunzurUniversitesi(Universite):
    id = "munzur"
    ad = "Munzur Üniversitesi"
    kisa = "MÜ"
    sehir = "Tunceli"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self):
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("Munzur: aylık yemek listesi indirilemedi: %s" % e) from e
        try:
            sonuc = sayfa_menu(sayfa)
        except ValueError as e:
            raise RuntimeError("Munzur: aylık yemek tablosu okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("Munzur: tarihli aylık yemek tablosu bulunamadı")
        return sonuc
