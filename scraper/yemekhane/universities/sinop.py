"""Sinop SKS: aylık HTML tablosu, öğün toplam kalorisi, tek liste (öğle).

'Bilgi Yok' boş gündür; hafta sonunun 'TATİL' kaydı not olarak korunur.
26 Kasım'da kaynak yalnız üç yemek yayınlar, eksik yemek uydurulmaz.
"""
import re
from datetime import date

from ..model import TR_KUCUK, ay_no, baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sksdb.sinop.edu.tr/yemek-listesi/"


def sayfa_menu(sayfa: str) -> dict:
    tablo = re.search(r'<table\b[^>]*id=[\'"]yemek-listesi[\'"][^>]*>(.*?)</table>', sayfa, re.S | re.I)
    if not tablo:
        return {}
    sonuc = {}
    for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", tablo.group(1), re.S | re.I):
        h = [etiket_temizle(x) for x in re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)]
        if len(h) != 4:
            continue
        t = re.fullmatch(r"(\d{1,2})\s+(\S+)\s+(\d{4})", h[0])
        ay = ay_no(t.group(2)) if t else None
        if not ay:
            continue
        try:
            tarih = date(int(t.group(3)), ay, int(t.group(1))).isoformat()
        except ValueError:
            continue
        metin = h[2].translate(TR_KUCUK).lower()
        if not metin or metin in {"-", "bilgi yok", "menü yok"}:
            continue
        if "tatil" in metin:
            ogun = {"items": [], "note": "Tatil"}
        else:
            adlar = [a.strip(" .-") for a in h[2].split(",")]
            ogeler = [{"name": baslik_yap_serbest(kisaltma_ac(re.sub(r"\bmevye\b", "meyve", a, flags=re.I)))}
                      for a in adlar if a]
            if not ogeler:
                continue
            ogun = {"items": ogeler}
            if h[3].isdigit() and int(h[3]) > 0:
                ogun["kcal"] = int(h[3])
        sonuc[tarih] = {"lunch": ogun}
    return sonuc


class SinopUniversitesi(Universite):
    id = "sinop"
    ad = "Sinop Üniversitesi"
    kisa = "SİNÜ"
    sehir = "Sinop"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("Sinop: SKS yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Sinop: tarihli aylık yemek tablosu bulunamadı")
        return sonuc
