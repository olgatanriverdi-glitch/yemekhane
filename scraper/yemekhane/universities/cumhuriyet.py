"""Sivas Cumhuriyet Üniversitesi: aylık menü cumhuriyet.edu.tr/yemeklistesi/index.php sayfasında hafta içi sütunlu bir takvim ızgarası olarak yayınlanıyor.
Her hücrede 'GG-AA-YYYY' başlığı ve 4 yemek (`<br>` ile ayrılmış) bulunur; kalori yoktur. İçinde bulunulan günün hücresi tarih yerine 'BUGÜN' yazar
(tarih komşu hücrelerden bulunur). Tatil günlerinde hücrede 'RESMİ TATİL' yazar.
"""
import re
from datetime import date, timedelta

from ..model import TR_KUCUK, baslik_yap_serbest, bugun_tr, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.cumhuriyet.edu.tr/yemeklistesi/index.php"


def is_gunu_ekle(d: date, adim: int) -> date:
    d += timedelta(days=adim)
    while d.weekday() >= 5:
        d += timedelta(days=adim)
    return d


def sayfa_menu(sayfa: str, bugun: date) -> dict:
    """{'2026-10-01': {'lunch': {...}}, ...} (yalnızca öğle yemeği yayınlanır); tatil günü: {'lunch': {'items': [], 'note': 'Resmi tatil'}}."""
    kayitlar = []          # [(tarih | None, [satırlar])] ızgara sırasıyla
    for hucre in re.split(r'<div class="mitem[^"]*men-item"[^>]*>', sayfa)[1:]:
        m = re.search(r"<h4[^>]*>\s*(.*?)\s*</h4>(.*?)(?:<small|</div>)", hucre, re.S)
        if not m:
            continue
        etiket = etiket_temizle(m.group(1))
        d = re.fullmatch(r"(\d{2})-(\d{2})-(\d{4})", etiket)
        try:
            tarih = date(int(d.group(3)), int(d.group(2)), int(d.group(1))) if d else None
        except ValueError:
            continue
        if tarih is None and etiket.translate(TR_KUCUK).lower() != "bugün":
            continue
        satirlar = [etiket_temizle(p) for p in re.split(r"<br\s*/?>", m.group(2))]
        kayitlar.append((tarih, [s for s in satirlar if s]))
    sonuc = {}
    onceki = None
    for i, (tarih, satirlar) in enumerate(kayitlar):
        if tarih is None:         # 'BUGÜN' hücresi: önceki hücrenin ertesi iş günü, yoksa sonraki hücrenin önceki iş günü
            sonraki = next((t for t, _ in kayitlar[i + 1:] if t), None)
            tarih = is_gunu_ekle(onceki, 1) if onceki else is_gunu_ekle(sonraki, -1) if sonraki else bugun
        onceki = tarih
        if satirlar and all("tatil" in s.translate(TR_KUCUK).lower() for s in satirlar):
            sonuc[tarih.isoformat()] = {"lunch": {"items": [], "note": "Resmi tatil"}}
        elif satirlar:
            sonuc[tarih.isoformat()] = {"lunch": gun_icerigi([{"name": baslik_yap_serbest(kisaltma_ac(s))} for s in satirlar])}
    return sonuc


class SivasCumhuriyet(Universite):
    id = "cumhuriyet"
    ad = "Sivas Cumhuriyet Üniversitesi"
    kisa = "CÜ"
    sehir = "Sivas"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"), self.bugun or bugun_tr())
