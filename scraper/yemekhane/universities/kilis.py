"""Kilis 7 Aralık SKS: aylık öğle tablosu; kalori yayınlanmaz.

Hafta sonları ve 29 Ekim'in boş hücreleri atlanır; açıkça yazılmayan tatil
notu üretilmez. Tarih hücresi ay ve yılı içerir. İlk doğrulama Ekim 2026.
"""
import re
from datetime import date

from ..model import TR_KUCUK, ay_no, baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir, saat_duzenle

SAYFA_URL = "https://sks.kilis.edu.tr/tr/page/5088"
BILGI_URL = "https://sks.kilis.edu.tr/tr/page/5065"


def yemek_adi(ad: str) -> str:
    ad = re.sub(r"\bçor\.$", "çorba", ad, flags=re.I)
    ad = re.sub(r"\bbol\.\s*", "bolonez ", ad, flags=re.I)
    ad = re.sub(r"\bz\.\s*y\.?\s*", "zeytinyağlı ", ad, flags=re.I)
    for kalip, duzgun in ((r"\bsoye\b", "sote"), (r"\bşekerparre\b", "şekerpare"),
                          (r"\bbörrek\b", "börek"), (r"\bfasülye\b", "fasulye")):
        ad = re.sub(kalip, duzgun, ad, flags=re.I)
    return baslik_yap_serbest(kisaltma_ac(ad.strip(" .-")))


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for tablo in re.findall(r"<table\b[^>]*>(.*?)</table>", sayfa, re.S | re.I):
        if "ÖĞLE YEMEK MENÜSÜ" not in etiket_temizle(tablo):
            continue
        for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", tablo, re.S | re.I):
            h = [etiket_temizle(x) for x in re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)]
            if len(h) != 5:
                continue
            t = re.fullmatch(r"(\d{1,2})\s+(\S+)\s+(\d{4})\s+\S+", h[0])
            ay = ay_no(t.group(2)) if t else None
            if not ay:
                continue
            try:
                tarih = date(int(t.group(3)), ay, int(t.group(1))).isoformat()
            except ValueError:
                continue
            adlar = [a for a in h[1:] if a.strip(" .-–")]
            if not adlar:
                continue
            if all("tatil" in a.translate(TR_KUCUK).lower() for a in adlar):
                ogun = {"items": [], "note": "Resmi tatil"}
            else:
                ogun = {"items": [{"name": yemek_adi(a)} for a in adlar]}
            if tarih in sonuc and sonuc[tarih] != {"lunch": ogun}:
                raise ValueError("Kilis 7 Aralık: %s için çelişen menüler var" % tarih)
            sonuc[tarih] = {"lunch": ogun}
    return sonuc


class Kilis7Aralik(Universite):
    id = "kilis"
    ad = "Kilis 7 Aralık Üniversitesi"
    kisa = "KİYÜ"
    sehir = "Kilis"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("Kilis 7 Aralık: SKS yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Kilis 7 Aralık: tarihli aylık öğle menüsü bulunamadı")
        return sonuc

    def saatler(self) -> dict:
        try:
            metin = etiket_temizle(self.indir(BILGI_URL).decode("utf-8-sig"))
        except Exception:
            return {}
        m = re.search(r"Yemek Saatleri\s+Öğrenci\s*:\s*([\d.\s:–—-]+)", metin, re.I)
        saat = saat_duzenle(m.group(1)) if m else None
        return {"lunch": saat} if saat else {}
