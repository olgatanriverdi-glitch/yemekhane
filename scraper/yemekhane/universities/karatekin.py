"""Çankırı Karatekin: HTML arşivindeki en son dolu ay, tek liste (öğle).

Ana sayfa yıllarca menüyü tek yanıtla verir. Portalın Kasım sayfası boşken
arşivdeki Ekim 2026 listesi kullanılabilir. Seçenekli ana yemek tek kalem
olarak korunur; kaynaktaki tek kalori iki seçeneğin toplamı sayılmaz.
"""
import re
from datetime import date

from ..model import TR_KUCUK, ay_no, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.karatekin.edu.tr/yemek-listesi"


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for kart in re.findall(r'<article\b[^>]*class=[\'"]food-menu-day-card[\'"][^>]*>(.*?)</article>', sayfa, re.S | re.I):
        baslik = re.search(r'<h2\b[^>]*class=[\'"]food-menu-day-heading[\'"][^>]*>(.*?)</h2>', kart, re.S | re.I)
        t = re.fullmatch(r"(\d{1,2})\s+(\S+)\s+\S+\s+(\d{4})", etiket_temizle(baslik.group(1))) if baslik else None
        ay = ay_no(t.group(2)) if t else None
        if not ay:
            continue
        try:
            tarih = date(int(t.group(3)), ay, int(t.group(1))).isoformat()
        except ValueError:
            continue
        ogeler = []
        for li in re.findall(r"<li\b[^>]*>(.*?)</li>", kart, re.S | re.I):
            a = re.search(r'<a\b[^>]*class=[\'"]food-menu-day-item-name[\'"][^>]*>(.*?)</a>', li, re.S | re.I)
            ad = etiket_temizle(a.group(1)).strip(" .-") if a else ""
            if not ad:
                continue
            oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
            k = re.search(r"(\d+)\s*kcal\b", etiket_temizle(re.sub(r"<a\b.*?</a>", "", li, flags=re.S | re.I)), re.I)
            if k and int(k.group(1)) > 0:
                oge["kcal"] = int(k.group(1))
            ogeler.append(oge)
        if not ogeler:
            continue
        if all("tatil" in o["name"].translate(TR_KUCUK).lower() for o in ogeler):
            ogun = {"items": [], "note": "Tatil"}
        else:
            ogun = gun_icerigi(ogeler)
            toplam = re.search(r'<p\b[^>]*class=[\'"]food-menu-day-total[\'"][^>]*>(.*?)</p>', kart, re.S | re.I)
            k = re.search(r"Toplam:\s*(\d+)\s*kcal", etiket_temizle(toplam.group(1)), re.I) if toplam else None
            if k and int(k.group(1)) > 0:
                ogun["kcal"] = int(k.group(1))
        sonuc[tarih] = {"lunch": ogun}
    son_ay = max(sonuc)[:7] if sonuc else None
    return {t: g for t, g in sonuc.items() if t[:7] == son_ay}


class CankiriKaratekin(Universite):
    id = "karatekin"
    ad = "Çankırı Karatekin Üniversitesi"
    kisa = "ÇAKÜ"
    sehir = "Çankırı"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("Çankırı Karatekin: aylık yemek arşivi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Çankırı Karatekin: tarihli aylık yemek kartları bulunamadı")
        return sonuc
