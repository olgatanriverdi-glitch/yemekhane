"""NEVÜ: aylik-menu sayfasına gömülmüş menuVerileri JSON dizisi.
JavaScript çalıştırılmaz. Dizinin son virgülü kaldırılıp json ile okunur;
yorum içindeki örnek tarihler alınmaz. Birkaç haftalık pencere biriktirilir.
Vejetaryen sekmesi kaynakta kapalı ve alanları '-' olduğundan yalnız öğle.
"""
import json
import re
from datetime import date

from ..model import TR_KUCUK, baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sks.nevsehir.edu.tr/tr/aylik-menu"
FIYAT_URL = "https://sks.nevsehir.edu.tr/tr/yemek-ucretleri"
ALANLAR = ("corba", "ana_yemek", "yardimci_yemek", "ek_yemek")


def sayfa_fiyatlar(sayfa: str) -> list:
    sonuc = []
    for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", sayfa, re.S | re.I):
        h = [etiket_temizle(h) for h in re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)]
        if len(h) != 2 or not h[0].startswith("ÖĞRENCİ"):
            continue
        m = re.fullmatch(r"\d+(?:[.,]\d+)?", h[1])
        if m:
            sonuc.append({"label": baslik_yap_serbest(h[0]), "tl": float(h[1].replace(",", "."))})
    return sonuc


def sayfa_menu(sayfa: str) -> dict:
    m = re.search(r"\b(?:var|let|const)\s+menuVerileri\s*=\s*(\[.*?\])\s*;", sayfa, re.S)
    if not m:
        return {}
    kayitlar = json.loads(re.sub(r",\s*\]$", "]", m.group(1)))
    sonuc = {}
    for k in kayitlar:
        if not isinstance(k, dict):
            continue
        try:
            gun, ay, yil = map(int, str(k.get("tarih", "")).split("."))
            tarih = date(yil, ay, gun).isoformat()
        except ValueError:
            continue
        adlar = [etiket_temizle(str(k.get(a) or "")).strip(" .-") for a in ALANLAR]
        adlar = [a for a in adlar if a]
        if not adlar:
            continue
        if all("tatil" in a.translate(TR_KUCUK).lower() for a in adlar):
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogun = {"items": [{"name": baslik_yap_serbest(kisaltma_ac(a))} for a in adlar]}
            kalori = str(k.get("kalori", ""))
            if kalori.isdigit() and int(kalori) > 0:
                ogun["kcal"] = int(kalori)
        sonuc[tarih] = {"lunch": ogun}
    return sonuc


class NevsehirHaciBektasVeli(Universite):
    id = "nevsehir"
    ad = "Nevşehir Hacı Bektaş Veli Üniversitesi"
    kisa = "NEVÜ"
    sehir = "Nevşehir"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("NEVÜ: yemek menüsü indirilemedi: %s" % e) from e
        try:
            sonuc = sayfa_menu(sayfa)
        except (ValueError, TypeError) as e:
            raise RuntimeError("NEVÜ: menuVerileri dizisi okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("NEVÜ: tarihli yemek menüsü bulunamadı")
        return sonuc

    def fiyatlar(self) -> list:
        try:
            return sayfa_fiyatlar(self.indir(FIYAT_URL).decode("utf-8"))
        except Exception:
            return []
