"""Niğde Ömer Halisdemir: aylık HTML tablosu, tek liste (öğle).

Son yemeğe bitişik sayı öğün toplamıdır; ardından gelen '--' yer
tutucuları yemek değildir. Kalem kalorileri kaynakta yayınlanmaz.
"""
import re
from datetime import date

from ..model import TR_KUCUK, baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.ohu.edu.tr/yemekmenu"


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for satir in re.findall(r'<tr\b[^>]*class=[\'"]cart_table_item[\'"][^>]*>(.*?)</tr>', sayfa, re.S | re.I):
        h = [etiket_temizle(x) for x in re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)]
        if len(h) != 2:
            continue
        t = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", h[0])
        if not t:
            continue
        try:
            tarih = date(int(t.group(3)), int(t.group(2)), int(t.group(1))).isoformat()
        except ValueError:
            continue
        k = re.search(r"\s+(\d+)\s*(?:--\s*)*$", h[1])
        metin = h[1][:k.start()] if k else re.sub(r"(?:--\s*)+$", "", h[1])
        adlar = [a.strip(" .-") for a in metin.split(",")]
        adlar = [a for a in adlar if a and a.translate(TR_KUCUK).lower() not in {"bilgi yok", "menü yok"}]
        if not adlar:
            continue
        if all("tatil" in a.translate(TR_KUCUK).lower() for a in adlar):
            ogun = {"items": [], "note": "Tatil"}
        else:
            ogeler = []
            for ad in adlar:
                ad = re.sub(r"\bgarni\.\s*", "garnitürlü ", ad, flags=re.I)
                ogeler.append({"name": baslik_yap_serbest(kisaltma_ac(ad))})
            ogun = {"items": ogeler}
            if k and int(k.group(1)) > 0:
                ogun["kcal"] = int(k.group(1))
        sonuc[tarih] = {"lunch": ogun}
    return sonuc


class NigdeOmerHalisdemir(Universite):
    id = "ohu"
    ad = "Niğde Ömer Halisdemir Üniversitesi"
    kisa = "NÖHÜ"
    sehir = "Niğde"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("Niğde Ömer Halisdemir: yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Niğde Ömer Halisdemir: tarihli aylık yemek listesi bulunamadı")
        return sonuc
