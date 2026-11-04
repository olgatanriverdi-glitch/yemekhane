"""Kırşehir Ahi Evran: SKS'nin tarihli HTML tablosu, tek liste (öğle).
'Aylık Liste' başlığına rağmen yaklaşık iki haftalık pencere yayınlanır.
Kalori parantezinden sonraki alerjenler yemek adına katılmaz; kapanmayan
parantez ve '170kcalgluten' gibi kaynak yazımları da ayrıştırılır.
"""
import re
from datetime import date

from ..model import ay_no, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://idari.ahievran.edu.tr/sksdb/yemek/yemek-listesi/tr/118"
FIYAT_URL = "https://idari.ahievran.edu.tr/sksdb/sayfa/PersonelVeOgrenciYemekFiyatlariListesi/tr/2496"


def sayfa_fiyatlar(sayfa: str) -> list:
    sonuc = []
    for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", sayfa, re.S | re.I):
        h = [etiket_temizle(h) for h in re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)]
        if len(h) != 5 or h[1] not in ("Öğrenci", "Öğrenci İkinci Yemek"):
            continue
        for i, label in ((4, "Öğrenci (Rezervasyonlu)"), (3, "Öğrenci (Rezervasyonsuz)" if h[1] == "Öğrenci" else "Öğrenci (İkinci Yemek)")):
            m = re.fullmatch(r"(\d+(?:[.,]\d+)?)\s*₺", h[i])
            if m:
                sonuc.append({"label": label, "tl": float(m.group(1).replace(",", "."))})
    return sonuc


def yemek_ogesi(hucre):
    metin = etiket_temizle(hucre)
    k = re.search(r"\(\s*(\d+)\s*kcal", metin, re.I)
    ad = (metin[:k.start()] if k else metin).strip(" .-–")
    if not ad:
        return None
    oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
    if k and int(k.group(1)) > 0:
        oge["kcal"] = int(k.group(1))
    return oge


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", sayfa, re.S | re.I):
        hucreler = re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)
        if len(hucreler) != 5:
            continue
        b = re.match(r"^(\d{1,2})\s+(\S+)\s+(\d{4})\b", etiket_temizle(hucreler[0]))
        if not b or not ay_no(b.group(2)):
            continue
        try:
            tarih = date(int(b.group(3)), ay_no(b.group(2)), int(b.group(1))).isoformat()
        except ValueError:
            continue
        ogeler = [o for o in (yemek_ogesi(h) for h in hucreler[1:]) if o]
        if not ogeler:
            continue
        if all("tatil" in o["name"].lower() for o in ogeler):
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogun = gun_icerigi(ogeler)
        sonuc[tarih] = {"lunch": ogun}
    return sonuc


class KirsehirAhiEvran(Universite):
    id = "ahievran"
    ad = "Kırşehir Ahi Evran Üniversitesi"
    kisa = "KAEÜ"
    sehir = "Kırşehir"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("Kırşehir Ahi Evran: yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Kırşehir Ahi Evran: tarihli yemek tablosu bulunamadı")
        return sonuc

    def fiyatlar(self) -> list:
        try:
            return sayfa_fiyatlar(self.indir(FIYAT_URL).decode("utf-8"))
        except Exception:
            return []
