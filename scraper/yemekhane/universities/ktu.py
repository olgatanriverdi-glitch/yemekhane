"""Karadeniz Teknik Üniversitesi (Trabzon): menü sks.ktu.edu.tr/yemeklistesi sayfasında (ktu.edu.tr/sks/yemeklistesi bu sayfayı iframe ile gösterir) bir tablo olarak
yayınlanıyor: 'Gün | 1. Yemek | 2. Yemek | 3. Yemek | 4. Yemek | Kalorisi' (son sütun anlamsız, '-5000'). Hücreler 'Ad 274 Kcal (1,4)' biçimindedir: kalori ve
alerjen kodları ('(1,4)') ayıklanır; '/' ile ayrılan seçenekler ('Etli Kuru Fasulye 274 Kcal / (sy) Etli Bezelye 258 Kcal') ayrı öğe olur ('(sy)' ve '(vejetaryen)' işaretleri atılır).
Kampüs yemekhaneleri için tek bir liste yayınlanır; tek öğün (öğle) sayılır. Sayfa yalnızca yakın haftaları gösterir (geçmiş haftalar kayar), bu yüzden eklenti
`birikimli`dir: önceki çalıştırmalarda okunan günler korunur.
"""
import re
from datetime import date

from ..model import baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sks.ktu.edu.tr/yemeklistesi"
KALORI = re.compile(r"(\d+)\s*kcal", re.I)
ALERJEN = re.compile(r"\(\s*\d+(?:\s*,\s*\d+)*\s*\)")
ISARET = re.compile(r"\(\s*(?:sy|vejetaryen)\s*\)", re.I)


def hucre_ogeleri(hucre: str) -> list:
    """'Tulumba Tatlısı 296 Kcal (1,3,12) / Cacık 100 Kcal (4)' -> [{'name': 'Tulumba Tatlısı', 'kcal': 296}, {'name': 'Cacık', 'kcal': 100}]"""
    ogeler = []
    for parca in hucre.split("/"):
        parca = ISARET.sub(" ", ALERJEN.sub(" ", parca))
        m = KALORI.search(parca)
        ad = re.sub(r"\s+", " ", KALORI.sub(" ", parca)).strip(" -")
        if not ad:
            continue
        oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
        if m and int(m.group(1)) > 0:
            oge["kcal"] = int(m.group(1))
        ogeler.append(oge)
    return ogeler


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-10-01': {'lunch': {'items': [...]}}, ...}. Seçenekli (a / b) günlerde günün toplam kalorisi yazılmaz."""
    sonuc = {}
    for satir in re.findall(r"<tr[^>]*>(.*?)</tr>", sayfa, re.S):
        hucreler = [etiket_temizle(h) for h in re.findall(r"<td[^>]*>(.*?)</td>", satir, re.S)]
        m = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", hucreler[0]) if hucreler else None
        if not m or len(hucreler) < 5:
            continue
        ogeler, secenekli = [], False
        for h in hucreler[1:5]:
            parcalar = hucre_ogeleri(h)
            ogeler += parcalar
            secenekli = secenekli or len(parcalar) > 1
        if not ogeler:
            continue
        gun = gun_icerigi(ogeler)
        if secenekli:
            gun.pop("kcal", None)
        try:
            sonuc[date(int(m.group(3)), int(m.group(2)), int(m.group(1))).isoformat()] = {"lunch": gun}
        except ValueError:
            pass
    return sonuc


class KaradenizTeknik(Universite):
    id = "ktu"
    ad = "Karadeniz Teknik Üniversitesi"
    kisa = "KTÜ"
    sehir = "Trabzon"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
