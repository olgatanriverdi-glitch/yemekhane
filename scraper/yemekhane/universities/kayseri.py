"""Kayseri: SKS'nin öğrenci ve personel yemekhanesi haftalık HTML listesi.
Gün başlığı ve arkasındaki ul eşleştirilir. Kalori yoktur; tek liste öğle
sayılır. Yalnızca hafta yayınlandığından geçmiş günler biriktirilir.
"""
import re
from datetime import date

from ..model import TR_KUCUK, baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir, saat_duzenle

SAYFA_URL = "https://sksd.kayseri.edu.tr/tr/i/1-2/yemek-listesi"


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    basliklar = list(re.finditer(r"<b\b[^>]*>\s*(\d{1,2})\.(\d{1,2})\.(\d{4})\s+[^<]*</b>", sayfa, re.I))
    for i, b in enumerate(basliklar):
        try:
            tarih = date(int(b.group(3)), int(b.group(2)), int(b.group(1))).isoformat()
        except ValueError:
            continue
        son = basliklar[i + 1].start() if i + 1 < len(basliklar) else len(sayfa)
        alan = sayfa[b.end():son]
        # Son günün ardından gelen servis/rezervasyon açıklamaları yemek değildir.
        alan = re.split(r"YEMEKHANE HİZMET|YEMEKHANE REZERVASYONU", alan, maxsplit=1)[0]
        liste = re.search(r"<ul\b[^>]*>(.*?)</ul>", alan, re.S | re.I)
        if not liste:
            continue
        adlar = [etiket_temizle(a).strip(" .-") for a in re.findall(r"<li\b[^>]*>(.*?)</li>", liste.group(1), re.S | re.I)]
        adlar = [a for a in adlar if a]
        if not adlar:
            continue
        if all("tatil" in a.translate(TR_KUCUK).lower() for a in adlar):
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogun = {"items": [{"name": baslik_yap_serbest(kisaltma_ac(a))} for a in adlar]}
        sonuc[tarih] = {"lunch": ogun}
    return sonuc


class KayseriUniversitesi(Universite):
    id = "kayseri"
    ad = "Kayseri Üniversitesi"
    kisa = "KAYÜ"
    sehir = "Kayseri"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici
        self.sayfa = ""

    def menuler(self) -> dict:
        try:
            self.sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("Kayseri: haftalık yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(self.sayfa)
        if not sonuc:
            raise RuntimeError("Kayseri: tarihli öğrenci yemek listesi bulunamadı")
        return sonuc

    def saatler(self) -> dict:
        for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", self.sayfa, re.S | re.I):
            hucreler = re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)
            if len(hucreler) >= 2 and etiket_temizle(hucreler[0]) == "ÖĞRENCİ":
                saat = saat_duzenle(etiket_temizle(hucreler[1]))
                if saat:
                    return {"lunch": saat}
        return {}
