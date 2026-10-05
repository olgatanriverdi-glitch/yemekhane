"""Atatürk Üniversitesi (Erzurum): Sağlık Kültür ve Spor Daire Başkanlığı ana sayfasında yalnızca 'Bugün' ve 'Yarın' için iki kart yayınlanıyor:
`<strong>05 Ekim 2026 Pazartesi</strong>` ve her kartta 'Merkez Yemekhane Menüsü' ile 'Konuk Evi 2 Menü' blokları (`<span>KIRMIZI MERCİMEK ÇORBA</span><strong>200 gr</strong>`).
Öğrenci yemekhanesi Merkez Yemekhane'dir (öğle yemeği); gramajlar atılır, kalori yok. Sayfa geçmiş tutmadığı için eklenti `birikimli`dir
(önceki çalıştırmalarda okunan günler korunur; robot günde 3 kez çalıştığından her gün yakalanır).
"""
import re
from datetime import date

from ..model import ay_no, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://atauni.edu.tr/saglik-kultur-ve-spor-daire-baskanligi/"


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-10-05': {'lunch': {'items': [{'name': 'Kırmızı Mercimek Çorba'}, ...]}}, ...} (yalnızca Merkez Yemekhane)."""
    sonuc = {}
    for kart in re.split(r'<div class="hy-yemek-slide[^"]*">', sayfa)[1:]:
        m = re.search(r"<strong>\s*(\d{1,2})\s+(\S+)\s+(\d{4})[^<]*</strong>", kart)
        ay = ay_no(m.group(2)) if m else None
        if not ay:
            continue
        for baslik, govde in re.findall(r"<h3>\s*(.*?)\s*</h3>(.*?)(?=<div class=\"hy-menu-block\"|\Z)", kart, re.S):
            if "merkez" not in etiket_temizle(baslik).lower():
                continue
            ogeler = [{"name": baslik_yap_serbest(kisaltma_ac(etiket_temizle(a)))}
                      for a in re.findall(r"<span>(.*?)</span>\s*<strong>[^<]*</strong>", govde, re.S) if etiket_temizle(a)]
            if ogeler:
                try:
                    sonuc[date(int(m.group(3)), ay, int(m.group(1))).isoformat()] = {"lunch": gun_icerigi(ogeler)}
                except ValueError:
                    pass
    return sonuc


class AtaturkUniversitesi(Universite):
    id = "atauni"
    ad = "Atatürk Üniversitesi"
    kisa = "ATAUNİ"
    sehir = "Erzurum"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
