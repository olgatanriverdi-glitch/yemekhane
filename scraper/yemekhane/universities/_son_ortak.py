"""Yeni metin kaynaklarının küçük, standart kütüphaneli yardımcıları."""
import re
from datetime import date

from ..model import ay_no, baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir


def tarih(metin):
    metin = etiket_temizle(metin)
    m = re.search(r"\b(\d{1,2})[./](\d{1,2})[./](\d{4})\b", metin)
    if m:
        try:
            return date(int(m[3]), int(m[2]), int(m[1]))
        except ValueError:
            pass
    m = re.search(r"\b(\d{1,2})\s+(\S+)\s+(\d{4})\b", metin)
    if m and ay_no(m[2]):
        try:
            return date(int(m[3]), ay_no(m[2]), int(m[1]))
        except ValueError:
            pass
    return None


def oge(metin):
    metin = etiket_temizle(metin)
    k = re.search(r"\(?\s*~?\s*(\d+)\s*(?:kkal|kcal|cal|kalori|kal)\s*\)?", metin, re.I)
    ad = re.sub(r"\(?\s*~?\s*\d+\s*(?:kkal|kcal|cal|kalori|kal)\s*\)?", "", metin, flags=re.I)
    ad = re.sub(r"\([A-Z](?:\s*,\s*[A-Z])*\)", "", ad)
    ad = re.sub(r"\bKZT\.", "Kızartması", ad, flags=re.I)
    ad = re.sub(r"\bKIZ\.", "Kızartması", ad, flags=re.I)
    ad = re.sub(r"\bGARN\.", "Garnitür", ad, flags=re.I)
    ad = baslik_yap_serbest(kisaltma_ac(re.sub(r"\s+", " ", ad).strip(" .~/-")))
    if not ad or re.fullmatch(r"[-–\d\s.]+", ad) or re.search(r"^(?:Toplam|Kalori|Henüz|Hazırlanıyor|Bilgi Yok)", ad, re.I):
        return None
    sonuc = {"name": ad}
    if k and int(k[1]) > 0 and len(re.findall(r"\d+\s*(?:kkal|kcal|cal|kalori|kal)", metin, re.I)) == 1:
        sonuc["kcal"] = int(k[1])
    return sonuc


def son_ay(sonuc):
    ay = max(sonuc)[:7] if sonuc else ""
    return {t: g for t, g in sonuc.items() if t.startswith(ay)}


class HtmlUniversitesi(Universite):
    kodlama = "utf-8-sig"
    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self):
        try:
            sayfa = self.indir(self.kaynak).decode(self.kodlama)
        except Exception as e:
            raise RuntimeError("%s: yemek listesi indirilemedi: %s" % (self.ad, e)) from e
        self.sayfa = sayfa
        sonuc = self.ayristir(sayfa)
        if not sonuc:
            raise RuntimeError("%s: tarihli yemek menüsü bulunamadı" % self.ad)
        return sonuc
