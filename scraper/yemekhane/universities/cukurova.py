"""Çukurova Üniversitesi Merkezi Kafeterya: yemekhane.cu.edu.tr ana sayfasındaki 'Aylık Liste' bölümü (sayfa Windows-1254 kodlu). Her gün bir sütundur:
`<a href="default.asp?ymk=N">5.10.2026<br><br>Pazartesi</a>`, altında `<li><a ... >Yemek<br>235 Kalori</a></li>` satırları ve 'Toplam 670 Kalori'.
Tek öğün (öğle) yayınlanır. Hafta sonu sütunları yoktur; liste ayın başlarında önceki haftadan başlayabilir.
"""
import re
from datetime import date

from ..model import baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://yemekhane.cu.edu.tr/"


def sayfa_menu(veri: bytes) -> dict:
    sayfa = veri.decode("cp1254", "replace")
    bas = sayfa.find('id="aylik_yemek_liste"')
    if bas < 0:
        return {}
    sonuc = {}
    for sutun in re.split(r'<FONT size="6">', sayfa[bas:], flags=re.I)[1:]:
        d = re.match(r'<a[^>]*>\s*(\d{1,2})\.(\d{1,2})\.(\d{4})', sutun)
        if not d:
            continue
        try:
            tarih = date(int(d.group(3)), int(d.group(2)), int(d.group(1)))
        except ValueError:
            continue
        ogeler = []
        for ad, kcal in re.findall(r"<li>\s*<a[^>]*>(.*?)<br>\s*(\d+)\s*Kalori\s*</a>", sutun, re.S | re.I):
            ad = etiket_temizle(ad)
            if ad:
                ogeler.append({"name": baslik_yap_serbest(kisaltma_ac(ad)), "kcal": int(kcal)})
        if ogeler:
            sonuc[tarih.isoformat()] = {"lunch": gun_icerigi(ogeler)}
    return sonuc


class CukurovaUniversitesi(Universite):
    id = "cukurova"
    ad = "Çukurova Üniversitesi"
    kisa = "ÇÜ"
    sehir = "Adana"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL))
