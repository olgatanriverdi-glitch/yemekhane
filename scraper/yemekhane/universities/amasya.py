"""Amasya: herkese açık yemek-listesi-public görünümünün aylık JSON'u.

Uygulamanın kendi okuma isteği '/api/hizli-menu/taslak?yil=...&ay=...';
giriş/çerez gerekmez. Adındaki 'taslak' nedeniyle yönetim yazma uçlarına
gidilmez. Günlerin dört yemek adı ve öğün toplam kalorisi okunur. Güncel
ay henüz boşsa önceki aya bakılır; aylık veriler birikimli değildir.
"""
import json
import re
from datetime import date

from ..model import TR_KUCUK, baslik_yap_serbest, bugun_tr, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://yemek.amasya.edu.tr/yemek-listesi-public"
API_URL = "https://yemek.amasya.edu.tr/api/hizli-menu/taslak"
ALANLAR = ("corbaYemekAdi", "anaYemekAdi", "diger1YemekAdi", "diger2YemekAdi")


def json_menu(veri: dict, yil=None, ay=None) -> dict:
    if not isinstance(veri, dict) or not isinstance(veri.get("gunler"), list):
        raise ValueError("Amasya: aylık menü API'sinin gunler listesi geçersiz")
    if (yil is not None and veri.get("yil") != yil) or (ay is not None and veri.get("ay") != ay):
        raise ValueError("Amasya: API yanıtındaki ay/yıl istenen dönemle eşleşmiyor")
    sonuc = {}
    for k in veri["gunler"]:
        if not isinstance(k, dict):
            continue
        try:
            tarih = date.fromisoformat(str(k.get("tarih", ""))[:10])
        except ValueError:
            continue
        if tarih.year != veri.get("yil") or tarih.month != veri.get("ay"):
            continue
        adlar = [etiket_temizle(str(k.get(a) or "")).strip(" .-–—") for a in ALANLAR]
        adlar = [a for a in adlar if a]
        if not adlar:
            continue
        if all("tatil" in a.translate(TR_KUCUK).lower() for a in adlar):
            ogun = {"items": [], "note": "Tatil"}
        else:
            ogun = {"items": [{"name": baslik_yap_serbest(kisaltma_ac(re.sub(r"\s*/\s*", "/", a)))} for a in adlar]}
            toplam = re.fullmatch(r"(\d+)(?:[.,]0+)?", str(k.get("toplamKalori") or ""))
            if toplam and int(toplam.group(1)) > 0:
                ogun["kcal"] = int(toplam.group(1))
        sonuc[tarih.isoformat()] = {"lunch": ogun}
    return sonuc


class AmasyaUniversitesi(Universite):
    id = "amasya"
    ad = "Amasya Üniversitesi"
    kisa = "AÜ"
    sehir = "Amasya"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self) -> dict:
        bugun = self.bugun or bugun_tr()
        aylar = [(bugun.year, bugun.month), (bugun.year - (bugun.month == 1), (bugun.month - 2) % 12 + 1)]
        hatalar = []
        for yil, ay in aylar:
            url = "%s?yil=%d&ay=%d" % (API_URL, yil, ay)
            try:
                ham = self.indir(url)
            except Exception as e:
                hatalar.append(e)
                continue
            try:
                sonuc = json_menu(json.loads(ham.decode("utf-8-sig")), yil, ay)
            except (ValueError, TypeError) as e:
                raise RuntimeError("Amasya: aylık yemek JSON'u okunamadı: %s" % e) from e
            if sonuc:
                return sonuc
        if len(hatalar) == len(aylar):
            raise RuntimeError("Amasya: aylık yemek JSON'u indirilemedi: %s" % hatalar[0]) from hatalar[0]
        raise RuntimeError("Amasya: güncel veya önceki ayda tarihli menü bulunamadı")
