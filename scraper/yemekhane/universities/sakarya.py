"""Sakarya Üniversitesi: menü menu.sabis.sakarya.edu.tr (SABİS) sitesinde herkese açık (giriş gerekmez). Aylık görünüm `POST /Home/GetirAylikMenu`
(year, month, diyetMi=false) ile HTML kart ızgarası döner: her kartın başlığı 'GG Ay Gün adı' (yıl yazmaz; bugüne en yakın yıl seçilir), gövdesinde
`<li ... title="Kalori: 160, İçerik: ">Yemek</li>` satırları. Okul öğün adı yazmaz (günde tek liste); öğle yemeği sayılır. Kalori 0 olan satır kalorisiz
sayılır (ör. 'Etsiz ... (merkez yemekhanede)'), böyle günde toplam kalori yazılmaz. Diyet menüsü ayrı bir görünümdür ve alınmaz.
"""
import html
import re
import urllib.parse
import urllib.request
from datetime import date

from ..model import ay_no, baslik_yap_serbest, bugun_tr, gun_icerigi, kisaltma_ac, yil_sec
from .base import UA, Universite

AYLIK_URL = "https://menu.sabis.sakarya.edu.tr/Home/GetirAylikMenu"

_KISALTMALAR = [(re.compile(p, re.I), r) for p, r in (
    (r"\bgar\.\s*", "garnitürlü "), (r"\bz\.\s*y\.\s*", "zeytinyağlı "), (r"\bç\.$", "Çorba"))]


def sabis_indir(url: str, veri=None, zaman_asimi: int = 30) -> bytes:
    govde = urllib.parse.urlencode(veri).encode() if veri is not None else None
    istek = urllib.request.Request(url, data=govde, headers={"User-Agent": UA})
    with urllib.request.urlopen(istek, timeout=zaman_asimi) as yanit:
        return yanit.read()


def yemek_adi(ad: str) -> str:
    ad = re.sub(r"\s+", " ", ad).strip()
    for kalip, yerine in _KISALTMALAR:
        ad = kalip.sub(yerine, ad)
    return baslik_yap_serbest(kisaltma_ac(ad))


def sayfa_menu(sayfa: str, bugun: date) -> dict:
    """{'2026-10-12': {'lunch': {'items': [{'name': 'Kırmızı Mercimek Çorba', 'kcal': 180}, ...], 'kcal': ...}}, ...}"""
    sonuc = {}
    parcalar = re.split(r'<div class="card-header[^"]*">', sayfa)[1:]
    for p in parcalar:
        baslik, _, govde = p.partition("</div>")
        m = re.match(r"\s*(\d{1,2})\s+(\S+)", html.unescape(baslik))
        ay = ay_no(m.group(2)) if m else None
        if not ay:
            continue
        tarih = yil_sec(int(m.group(1)), ay, bugun)
        if tarih is None:
            continue
        ogeler = []
        for title, ad in re.findall(r'<li[^>]*title="([^"]*)"[^>]*>(.*?)</li>', govde, re.S):
            ad = yemek_adi(html.unescape(re.sub(r"<[^>]+>", "", ad)))
            if not ad:
                continue
            oge = {"name": ad}
            k = re.search(r"Kalori:\s*(\d+)", html.unescape(title))
            if k and int(k.group(1)) > 0:
                oge["kcal"] = int(k.group(1))
            ogeler.append(oge)
        if ogeler:
            sonuc[tarih.isoformat()] = {"lunch": gun_icerigi(ogeler)}
    return sonuc


class SakaryaUniversitesi(Universite):
    id = "sakarya"
    ad = "Sakarya Üniversitesi"
    kisa = "SAÜ"
    sehir = "Sakarya"
    kaynak = "https://menu.sabis.sakarya.edu.tr/Home/AylikMenu"

    def __init__(self, indirici=sabis_indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self) -> dict:
        bugun = self.bugun or bugun_tr()
        aylar = [(bugun.year, bugun.month), (bugun.year + (bugun.month == 12), bugun.month % 12 + 1)]
        sonuc = {}
        for yil, ay in aylar:
            try:
                sayfa = self.indir(AYLIK_URL, {"year": yil, "month": ay, "diyetMi": "false"}).decode("utf-8", "ignore")
            except Exception as e:
                if (yil, ay) == aylar[0]:
                    raise
                print("UYARI: Sakarya %d-%02d okunamadı: %s" % (yil, ay, e))
                continue
            sonuc.update(sayfa_menu(sayfa, bugun))
        return sonuc
