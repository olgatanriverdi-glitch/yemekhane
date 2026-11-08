"""SUBÜ: merkez kampüsün aylık HTML takvimi, tek liste (öğle).

Tarih satırının altındaki satır aynı beş sütunun yemeklerini içerir. Yıl ve
ay üst başlıktan alınır. İlçe kampüslerinin farklı listesi karıştırılmaz;
merkez listesindeki etsiz seçenekler ayrı bir vejetaryen öğün sayılmaz.
"""
import re
from datetime import date

from ..model import TR_KUCUK, ay_no, baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sks.subu.edu.tr/tr/merkez-yemek-menusu"


def yemek_adi(metin):
    metin = re.sub(r"\bgar\.\s*", "garnitürlü ", metin, flags=re.I)
    metin = re.sub(r"\bç\.$", "Çorba", metin, flags=re.I)
    return baslik_yap_serbest(kisaltma_ac(metin.strip(" .-")))


def sayfa_menu(sayfa: str) -> dict:
    baslik = re.search(r"\b(\d{4})\s+(\S+)\s+AYI YEMEK MENÜSÜ", etiket_temizle(sayfa))
    ay = ay_no(baslik.group(2)) if baslik else None
    if not ay:
        return {}
    sonuc = {}
    for tablo in re.findall(r"<table\b[^>]*>(.*?)</table>", sayfa, re.S | re.I):
        tarihler = []
        for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", tablo, re.S | re.I):
            hucreler = re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)
            basliklar = [re.fullmatch(r"(\d{1,2})\s+(\S+)\s+\S+", etiket_temizle(h)) for h in hucreler]
            if any(b and ay_no(b.group(2)) == ay for b in basliklar):
                tarihler = []
                for b in basliklar:
                    try:
                        t = date(int(baslik.group(1)), ay, int(b.group(1))) if b and ay_no(b.group(2)) == ay else None
                    except ValueError:
                        t = None
                    tarihler.append(t)
                continue
            if len(tarihler) != len(hucreler):
                tarihler = []
                continue
            for tarih, hucre in zip(tarihler, hucreler):
                if tarih is None:
                    continue
                paragraflar = re.findall(r"<p\b[^>]*>(.*?)</p>", hucre, re.S | re.I) or [hucre]
                adlar = [etiket_temizle(a).strip(" -") for p in paragraflar for a in re.split(r"<br\s*/?>", p, flags=re.I)]
                adlar = [a for a in adlar if a]
                if not adlar:
                    continue
                if all("tatil" in a.translate(TR_KUCUK).lower() for a in adlar):
                    ogun = {"items": [], "note": "Resmi tatil"}
                else:
                    ogun = {"items": [{"name": yemek_adi(a)} for a in adlar]}
                sonuc[tarih.isoformat()] = {"lunch": ogun}
            tarihler = []
    return sonuc


class SakaryaUygulamaliBilimler(Universite):
    id = "subu"
    ad = "Sakarya Uygulamalı Bilimler Üniversitesi"
    kisa = "SUBÜ"
    sehir = "Sakarya"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("SUBÜ: merkez kampüs yemek menüsü indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("SUBÜ: aylık merkez kampüs menüsü bulunamadı")
        return sonuc
