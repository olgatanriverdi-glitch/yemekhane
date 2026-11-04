"""Aydın Adnan Menderes Üniversitesi: www.adu.edu.tr/tr/yemek-listesi sayfası 'Bu Hafta' ve 'Önümüzdeki Hafta' kartlarını verir. Her gün
`<div class="badge ...">26.10.2026 Pazartesi<b></b></div>` başlığı ve altındaki `<div class="col-lg-6 text-center">YEMEK</div>` hücreleridir (boş hücreler atılır);
kalori yayınlanmaz, tek öğün (öğle). Hafta boşsa 'Bugün'e ait herhangi bir yemek listesi bulunamadı' yazar. Sayfa yalnızca iki haftayı gösterir: `birikimli = True`.
"""
import re
from datetime import date

from ..model import baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.adu.edu.tr/tr/yemek-listesi"


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    parcalar = re.split(r'<div class="badge[^"]*">\s*(\d{1,2})\.(\d{1,2})\.(\d{4})\b[^<]*(?:<b></b>)?\s*</div>', sayfa)
    for i in range(1, len(parcalar) - 3, 4):
        try:
            tarih = date(int(parcalar[i + 2]), int(parcalar[i + 1]), int(parcalar[i]))
        except ValueError:
            continue
        govde = re.split(r'<h4|<div class="card', parcalar[i + 3])[0]       # sonraki kart/hafta başlığına taşma
        ogeler = []
        for h in re.findall(r'<div class="col-lg-6 text-center">(.*?)</div>', govde, re.S):
            ad = etiket_temizle(h).strip(" .-")
            if ad:
                ogeler.append({"name": baslik_yap_serbest(kisaltma_ac(ad))})
        if ogeler:
            sonuc[tarih.isoformat()] = {"lunch": gun_icerigi(ogeler)}
    return sonuc


class AydinAdnanMenderes(Universite):
    id = "adu"
    ad = "Aydın Adnan Menderes Üniversitesi"
    kisa = "ADÜ"
    sehir = "Aydın"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
