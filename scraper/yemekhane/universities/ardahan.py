"""Ardahan yemek otomasyonu: girişsiz GET /api/menus JSON arşivi.

Normal menünün en güncel ayı alınır. Çölyak listesi vejetaryen sayılmaz.
Kasım 2026'da henüz yalnız 2–4 Kasım yayınlanmıştır; API geçmiş ayları da
tuttuğundan günlük görünümün aksine kaynak birikim gerektirmez.
"""
import json
import re
from datetime import date

from ..model import baslik_yap_serbest, bugun_tr, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://yemek.ardahan.edu.tr/"
API_URL = SAYFA_URL + "api/menus"
ALANLAR = ("corba", "anaYemek", "yanYemek", "garnitur")


def kalori(deger):
    k = re.fullmatch(r"(\d+)(?:[.,]0+)?", str(deger or ""))
    return int(k[1]) if k and int(k[1]) > 0 else None


def json_menu(veri):
    if not isinstance(veri, list):
        raise ValueError("Ardahan: menü API'si kayıt listesi döndürmedi")
    sonuc = {}
    for k in veri:
        if not isinstance(k, dict) or k.get("type") != "normal":
            continue
        try:
            tarih = date.fromisoformat(str(k.get("date", ""))).isoformat()
        except ValueError:
            continue
        if k.get("isHoliday") is True:
            ogun = {"items": [], "note": baslik_yap_serbest(etiket_temizle(str(k.get("holidayType") or "Tatil")))}
        else:
            kaloriler = json.loads(k.get("calories_json") or "{}")
            if not isinstance(kaloriler, dict):
                raise ValueError("Ardahan: kalem kalorileri sözlük değil")
            ogeler = []
            for alan in ALANLAR:
                ad = etiket_temizle(str(k.get(alan) or "")).strip(" .-–")
                if not ad:
                    continue
                oge = {"name": baslik_yap_serbest(kisaltma_ac(re.sub(r"\s*/\s*", "/", ad)))}
                kcal = kalori(kaloriler.get(alan))
                if kcal is not None:
                    oge["kcal"] = kcal
                ogeler.append(oge)
            if not ogeler:
                continue
            ogun = gun_icerigi(ogeler)
            toplam = kalori(k.get("totalCalories"))
            if toplam is not None:
                ogun["kcal"] = toplam
        gun = {"lunch": ogun}
        if tarih in sonuc and sonuc[tarih] != gun:
            raise ValueError("Ardahan: %s için çelişen normal menüler var" % tarih)
        sonuc[tarih] = gun
    return sonuc


class ArdahanUniversitesi(Universite):
    id = "ardahan"
    ad = "Ardahan Üniversitesi"
    kisa = "ARÜ"
    sehir = "Ardahan"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self):
        try:
            ham = self.indir(API_URL)
        except Exception as e:
            raise RuntimeError("Ardahan: yemek otomasyonu JSON'u indirilemedi: %s" % e) from e
        try:
            sonuc = json_menu(json.loads(ham.decode("utf-8-sig")))
        except (ValueError, TypeError) as e:
            raise RuntimeError("Ardahan: yemek otomasyonu JSON'u okunamadı: %s" % e) from e
        bugun = self.bugun or bugun_tr()
        aylar = [t[:7] for t in sonuc if t[:7] <= bugun.strftime("%Y-%m")]
        if not aylar:
            raise RuntimeError("Ardahan: güncel veya önceki aylarda normal menü bulunamadı")
        ay = max(aylar)
        return {t: g for t, g in sonuc.items() if t.startswith(ay)}
