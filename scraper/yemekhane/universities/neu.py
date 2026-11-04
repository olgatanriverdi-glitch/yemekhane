"""NEÜ Kampüs Kart'ın girişsiz aylık JSON menüsü.

API'de bir sonraki ayın ilk haftası da bulunabilir; tüm tarihli kayıtlar
korunur. 0 kalori bilinmeyendir. Öğün adı boş/kimliği 0 olan tek liste
öğle sayılır; özel/test menüleri ve tanınmayan öğünler alınmaz.
"""
import json
import re
from datetime import date

from ..model import TR_KUCUK, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

API_URL = "https://yemekhane-api.erbakan.edu.tr/api/webogrenci/aylikmenu"


def _kalori(deger):
    m = re.fullmatch(r"\s*(\d+)(?:[.,]0+)?\s*", str(deger or ""))
    return int(m.group(1)) if m and int(m.group(1)) > 0 else None


def json_menu(veri: dict) -> dict:
    if not isinstance(veri, dict) or veri.get("success") is False:
        raise ValueError("NEÜ: menü API'si başarılı yanıt vermedi")
    kayitlar = veri.get("data")
    if not isinstance(kayitlar, list):
        raise ValueError("NEÜ: menü API'sinin data listesi geçersiz")
    sonuc = {}
    for k in kayitlar:
        if not isinstance(k, dict) or k.get("ozelmenukodu") not in (None, 0, "0"):
            continue
        try:
            tarih = date.fromisoformat(str(k.get("tarih", ""))[:10]).isoformat()
        except ValueError:
            continue
        ad = str(k.get("ogun_adi") or "").strip().translate(TR_KUCUK).lower()
        tur = {"öğle": "lunch", "öğlen": "lunch", "akşam": "dinner", "vejetaryen": "vegetarian"}.get(ad)
        if not ad and k.get("ogun_id") in (None, 0, "0", 1, "1"):
            tur = "lunch"
        if not tur:
            continue
        ogeler = []
        for n in range(1, 6):
            yemek = etiket_temizle(str(k.get("yemek_adi%d" % n) or "")).strip(" .-")
            if not yemek:
                continue
            oge = {"name": baslik_yap_serbest(kisaltma_ac(yemek))}
            kcal = _kalori(k.get("yemek_kalori%d" % n))
            if kcal is not None:
                oge["kcal"] = kcal
            ogeler.append(oge)
        if not ogeler:
            continue
        if all("tatil" in o["name"].lower() for o in ogeler):
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogun = gun_icerigi(ogeler)
            toplam = _kalori(k.get("toplam_kalori"))
            if toplam is not None:
                ogun["kcal"] = toplam
        # Aynı tarihte birden fazla standart listeyi sessizce ezme.
        gun = sonuc.setdefault(tarih, {})
        if tur in gun and gun[tur] != ogun:
            raise ValueError("NEÜ: %s için birden fazla %s menüsü var" % (tarih, tur))
        gun[tur] = ogun
    return sonuc


class NecmettinErbakan(Universite):
    id = "neu"
    ad = "Necmettin Erbakan Üniversitesi"
    kisa = "NEÜ"
    sehir = "Konya"
    kaynak = "https://kampuskart.erbakan.edu.tr/"

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            ham = self.indir(API_URL)
        except Exception as e:
            raise RuntimeError("NEÜ: aylık yemek JSON'u indirilemedi: %s" % e) from e
        try:
            sonuc = json_menu(json.loads(ham.decode("utf-8-sig")))
        except (ValueError, TypeError) as e:
            raise RuntimeError("NEÜ: aylık yemek JSON'u okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("NEÜ: tarihli aylık yemek menüsü bulunamadı")
        return sonuc
