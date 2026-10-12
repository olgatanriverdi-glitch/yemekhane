"""Pamukkale Üniversitesi: www.pau.edu.tr/pau/tr/yemekMenuleri sayfası güncel haftanın (5 iş günü) menüsünü sekmeli HTML olarak verir (ASP.NET).
Her gün sekmesinde yemekhane bloklarıdır (`<span class="hallName">Yemekhane</span>`): öğün başlığı (`<h6 class="ogunN">Öğle</h6>`) ve
`<li>YEMEK <i class='calorie'><span>150</span> cal</i></li>` satırları. Eşleme: 'Yemekhane' Öğle (ve Akşam varsa) -> lunch/dinner, 'Vejetaryen' Öğle -> vegetarian;
Turuncu Salon, Konuk Evi, Tekno Kafe, Havuzbaşı gibi personel/à la carte bloklar alınmaz. Sayfa yalnızca bu haftayı gösterir: `birikimli = True`.
"""
import re
from datetime import date

from ..model import baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.pau.edu.tr/pau/tr/yemekMenuleri"
_PAU_KISALTMA = re.compile(r"\bzy\.\s*", re.I)


def yemek_ogesi(ad: str, kcal: str):
    ad = _PAU_KISALTMA.sub("zeytinyağlı ", etiket_temizle(ad)).strip(" .-")
    if not ad:
        return None
    oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
    if kcal.isdigit() and int(kcal) > 0:
        oge["kcal"] = int(kcal)
    return oge


def sayfa_menu(sayfa: str) -> dict:
    tarihler = re.findall(r'class="thatDay">\s*(\d{2})\.(\d{2})\.(\d{4})\s*</span>', sayfa)
    paneller = re.split(r'<div class="tab-pane[^"]*" id="day-\d+"', sayfa)[1:]
    sonuc = {}
    for t, panel in zip(tarihler, paneller):
        try:
            tarih = date(int(t[2]), int(t[1]), int(t[0]))
        except ValueError:
            continue
        for blok in re.split(r'<span id="[^"]*lblBirimAdi" class="hallName">', panel)[1:]:
            salon = etiket_temizle(blok.split("</span>")[0])
            for og in re.split(r'<h6 class="ogun\d+">', blok)[1:]:
                ogun_adi = etiket_temizle(og.split("</h6>")[0]).lower()
                if salon == "Yemekhane" and ogun_adi.startswith("öğle"):
                    tur = "lunch"
                elif salon == "Yemekhane" and ogun_adi.startswith("akşam"):
                    tur = "dinner"
                elif salon == "Vejetaryen" and ogun_adi.startswith("öğle"):
                    tur = "vegetarian"
                else:
                    continue
                ogeler = []
                for li in re.findall(r"<li>(.*?)</li>", og, re.S):
                    k = re.search(r"<span>(\d*)</span>\s*cal", li)
                    o = yemek_ogesi(re.sub(r"<i .*?</i>|<input[^>]*>", "", li, flags=re.S), k.group(1) if k else "")
                    if o:
                        ogeler.append(o)
                if ogeler:
                    sonuc.setdefault(tarih.isoformat(), {})[tur] = gun_icerigi(ogeler)
    return sonuc


class PamukkaleUniversitesi(Universite):
    id = "pamukkale"
    ad = "Pamukkale Üniversitesi"
    kisa = "PAÜ"
    sehir = "Denizli"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(SAYFA_URL).decode("utf-8", "ignore"))
