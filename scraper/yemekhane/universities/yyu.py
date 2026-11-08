"""Van Yüzüncü Yıl: yemek-listesi sayfasındaki tarihli HTML kartları.
Gün başına dört kalem ve kalem kalorisi yayınlanır, tek liste öğle sayılır.
Yalnızca birkaç gün/hafta görüldüğü için geçmiş build tarafından biriktirilir.
"""
import re
from datetime import date

from ..model import ay_no, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.yyu.edu.tr/yemek-listesi"


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for kart in re.split(r'<div\b[^>]*class="card-food"[^>]*>', sayfa)[1:]:
        t = re.search(r"<span\b[^>]*>\s*(\d{1,2})\s+(\S+)\s+(\d{4})\s*</span>", kart)
        if not t or not ay_no(t.group(2)):
            continue
        try:
            tarih = date(int(t.group(3)), ay_no(t.group(2)), int(t.group(1)))
        except ValueError:
            continue
        liste = re.search(r"<ul\b[^>]*>(.*?)</ul>", kart, re.S)
        if not liste:
            continue
        ogeler = []
        for li in re.findall(r"<li\b[^>]*>(.*?)</li>", liste.group(1), re.S):
            k = re.search(r"<span\b[^>]*>\s*(\d+)\s*kcal\s*</span>", li, re.I)
            ad = etiket_temizle(re.sub(r"<span\b[^>]*>.*?</span>", "", li, flags=re.S)).strip(" .-")
            if not ad:
                continue
            oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
            if k and int(k.group(1)) > 0:
                oge["kcal"] = int(k.group(1))
            ogeler.append(oge)
        if not ogeler:
            continue
        if all("tatil" in o["name"].lower() for o in ogeler):
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogun = gun_icerigi(ogeler)
        sonuc[tarih.isoformat()] = {"lunch": ogun}
    return sonuc


class VanYuzuncuYil(Universite):
    id = "yyu"
    ad = "Van Yüzüncü Yıl Üniversitesi"
    kisa = "YYÜ"
    sehir = "Van"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("Van YYÜ: yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Van YYÜ: tarihli yemek kartı bulunamadı")
        return sonuc
