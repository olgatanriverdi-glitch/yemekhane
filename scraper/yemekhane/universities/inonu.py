"""İnönü Üniversitesi: www.inonu.edu.tr/yemek sayfası Vue ile çizilir; veriyi `https://panel.inonu.edu.tr/servlet/food?type=list&date=YYYY-MM-DD` JSON'u verir
(gün başına bir istek). Kayıt: `{"food_name": "Tavuk İncik", "food_desc": "250 kalori", "food_type": "G", ...}`; `G` (ya da boş) = günün yemeği (öğle),
başka `food_type` değerleri (özel/ek menü) alınmaz. Menü yoksa `[]` döner (hafta sonu, tatil). Bugünden 2 gün öncesinden 3 hafta sonrasına bakılır; sayfa tarih
arşivi tutmadığından `birikimli = True`. Bir günün isteği hata verirse o gün atlanır.
"""
import json
import re
from datetime import timedelta

from ..model import baslik_yap_serbest, bugun_tr, gun_icerigi, kisaltma_ac
from .base import Universite, indir

API_URL = "https://panel.inonu.edu.tr/servlet/food?type=list&date="
GERI, ILERI = 2, 21


def gun_menu(kayitlar: list):
    """JSON kayıt listesi -> öğle öğünü ({'items': [...], 'kcal': N}); yemek yoksa None."""
    ogeler = []
    for k in kayitlar if isinstance(kayitlar, list) else []:
        if not isinstance(k, dict) or (k.get("food_type") or "G") != "G":
            continue
        ad = re.sub(r"\s+", " ", str(k.get("food_name") or "")).strip(" .-")
        if not ad:
            continue
        oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
        m = re.search(r"(\d+)", str(k.get("food_desc") or ""))
        if m and int(m.group(1)) > 0:
            oge["kcal"] = int(m.group(1))
        ogeler.append(oge)
    return gun_icerigi(ogeler) if ogeler else None


class InonuUniversitesi(Universite):
    id = "inonu"
    ad = "İnönü Üniversitesi"
    kisa = "İnÜ"
    sehir = "Malatya"
    kaynak = "https://www.inonu.edu.tr/yemek"
    birikimli = True

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self) -> dict:
        bugun = self.bugun or bugun_tr()
        sonuc, hata = {}, 0
        for fark in range(-GERI, ILERI + 1):
            gun = bugun + timedelta(days=fark)
            try:
                menu = gun_menu(json.loads(self.indir(API_URL + gun.isoformat()).decode("utf-8", "ignore")))
            except Exception:
                hata += 1
                if hata > 5 and not sonuc:          # panel tümden kapalıysa 24 kez beklemeden bırak
                    raise
                continue
            if menu:
                sonuc[gun.isoformat()] = {"lunch": menu}
        return sonuc
