"""Gaziantep Üniversitesi: www.gaziantep.edu.tr/yemek/ sayfasının altındaki '<Ay> <Yıl> Yemek Listesi' tablosu (hafta sütunlu takvim). Her gün hücresi
`<div class="badge ...">05 Ekim</div>` başlığı ve `<div class="small pb-2"><a ...>YEMEK ADI (266 kcal)</a></div>` satırlarıdır; hücre boşsa hafta sonu/tatildir.
Ay ve yıl tablonun üstündeki başlıktan okunur. Öğe adlarında parantez içinde ek olabilir: 'MEYVE (ŞEFTALİ 72 kcal)' -> 'Meyve (Şeftali)', 72 kcal. Tek öğün (öğle).
"""
import re
from datetime import date

from ..model import ay_no, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.gaziantep.edu.tr/yemek/"
KCAL = re.compile(r"\(\s*([^()]*?)\s*(\d+)\s*kcal\s*\)\s*$", re.I)


def yemek_ogesi(metin: str):
    metin = etiket_temizle(metin)
    m = KCAL.search(metin)
    ad = metin[:m.start()].strip() if m else metin
    if m and m.group(1):
        ad = "%s (%s)" % (ad, m.group(1))
    ad = baslik_yap_serbest(kisaltma_ac(ad.strip(" -/")))
    if not ad:
        return None
    oge = {"name": ad}
    if m:
        oge["kcal"] = int(m.group(2))
    return oge


def sayfa_menu(sayfa: str) -> dict:
    b = re.search(r"<b>\s*(\S+)\s+(\d{4})\s*</b>\s*Yemek Listesi", sayfa)
    ay_yil = (ay_no(b.group(1)), int(b.group(2))) if b else (None, None)
    if not ay_yil[0]:
        return {}
    tablo = sayfa[b.end():]
    sonuc = {}
    for hucre in re.split(r'<td class="day"[^>]*>', tablo)[1:]:
        h = re.match(r'\s*<div class="badge[^"]*">\s*(\d{1,2})\s+(\S+?)\s*</div>', hucre)
        if not h or ay_no(h.group(2)) != ay_yil[0]:
            continue
        try:
            tarih = date(ay_yil[1], ay_yil[0], int(h.group(1)))
        except ValueError:
            continue
        ogeler = [o for o in (yemek_ogesi(x) for x in re.findall(r'<div class="small pb-2">(.*?)</div>', hucre, re.S)) if o]
        if ogeler:
            sonuc[tarih.isoformat()] = {"lunch": gun_icerigi(ogeler)}
    return sonuc


class GaziantepUniversitesi(Universite):
    id = "gaziantep"
    ad = "Gaziantep Üniversitesi"
    kisa = "GAÜN"
    sehir = "Gaziantep"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
