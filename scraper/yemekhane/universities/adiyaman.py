"""Adıyaman SKS: günlük HTML'de öğle ve akşam sütunları.

Sıra resmî stil dosyasının mobil 'Öğle'/'Akşam' etiketleriyle doğrulandı.
Yalnız tarihli günler okunur ve biriktirilir. Boş 'kcal kcal' alanı kalori
sayılmaz; yayımlanmayan gün/öğün/kalori üretilmez.
"""
import re
from datetime import date
from html.parser import HTMLParser

from ..model import TR_KUCUK, baslik_yap_serbest, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sksdb.adiyaman.edu.tr/tr/yemekhane/yemek-menusu"


class _MenuOkuyucu(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.kokler = []
        self.yigin = []

    def handle_starttag(self, tag, attrs):
        if tag != "div":
            return
        a = dict(attrs)
        if not self.yigin and "mt-meals" not in a.get("class", "").split():
            return
        dugum = (a, [])
        if self.yigin:
            self.yigin[-1][1].append(dugum)
        else:
            self.kokler.append(dugum)
        self.yigin.append(dugum)

    def handle_endtag(self, tag):
        if tag == "div" and self.yigin:
            self.yigin.pop()

    def handle_data(self, data):
        if self.yigin:
            self.yigin[-1][1].append(data)


def _metin(dugum):
    if isinstance(dugum, str):
        return dugum
    return re.sub(r"\s+", " ", " ".join(_metin(p) for p in dugum[1])).strip()


def _cocuklar(dugum):
    return [p for p in dugum[1] if not isinstance(p, str)]


def sayfa_menu(sayfa: str) -> dict:
    okuyucu = _MenuOkuyucu()
    okuyucu.feed(sayfa)
    sonuc = {}
    for kok in okuyucu.kokler:
        for satir in _cocuklar(kok):
            if "item" not in satir[0].get("class", "").split():
                continue
            sutunlar = _cocuklar(satir)
            if len(sutunlar) != 3:
                continue
            t = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", _metin(sutunlar[0]))
            if not t:
                continue
            try:
                tarih = date(int(t.group(3)), int(t.group(2)), int(t.group(1))).isoformat()
            except ValueError:
                continue
            for tur, sutun in zip(("lunch", "dinner"), sutunlar[1:]):
                ogeler, kalori = [], None
                for hucre in _cocuklar(sutun):
                    metin = _metin(hucre).strip(" .-–")
                    if "calory" in hucre[0].get("class", "").split():
                        k = re.fullmatch(r"(\d+)\s*(?:kcal\s*)+", metin, re.I)
                        if k and int(k.group(1)) > 0:
                            kalori = int(k.group(1))
                    elif metin:
                        ogeler.append({"name": baslik_yap_serbest(kisaltma_ac(metin))})
                if not ogeler:
                    continue
                if all("tatil" in o["name"].translate(TR_KUCUK).lower() for o in ogeler):
                    ogun = {"items": [], "note": "Tatil"}
                else:
                    ogun = {"items": ogeler}
                    if kalori is not None:
                        ogun["kcal"] = kalori
                gun = sonuc.setdefault(tarih, {})
                if tur in gun and gun[tur] != ogun:
                    raise ValueError("Adıyaman: %s için çelişen %s menüleri var" % (tarih, tur))
                gun[tur] = ogun
    return sonuc


class AdiyamanUniversitesi(Universite):
    id = "adiyaman"
    ad = "Adıyaman Üniversitesi"
    kisa = "ADYÜ"
    sehir = "Adıyaman"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("Adıyaman: SKS yemek menüsü indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Adıyaman: tarihli öğle/akşam menüsü bulunamadı")
        return sonuc
