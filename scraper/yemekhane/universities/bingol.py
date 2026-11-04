"""Bingöl SKS: aylık HTML tablosu, tek liste (öğle).

Yalnız bazı yemeklerin kalorisi yazılıdır. '60-70 KCAL' bir aralıktır;
tek kaloriye veya kesin günlük toplama çevrilmez, öğün notunda korunur.
"""
import re
from datetime import date

from ..model import TR_KUCUK, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sks.bingol.edu.tr/yemek-listesi"
KALORI = re.compile(r"\s+(\d+)(?:\s*[-–]\s*(\d+))?\s*KCAL\s*$", re.I)


def yemek_adi(metin):
    for kalip, yeni in ((r"\bHAV\.\s*KIR\.\s*LAH\.\s*", "HAVUÇ KIRMIZI LAHANA "),
                        (r"\bHİNDİS\.\s*CEVİZ\.\s*", "HİNDİSTAN CEVİZLİ "),
                        (r"\bGARNİLİ\b", "GARNİTÜRLÜ")):
        metin = re.sub(kalip, yeni, metin, flags=re.I)
    metin = re.sub(r"\s*/\s*", "/", kisaltma_ac(metin)).strip(" .-")
    return baslik_yap_serbest(metin)


def sayfa_menu(sayfa):
    sonuc = {}
    for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", sayfa, re.S | re.I):
        h = [etiket_temizle(x) for x in re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)]
        if len(h) != 5:
            continue
        t = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", h[0])
        if not t:
            continue
        try:
            tarih = date(int(t[3]), int(t[2]), int(t[1])).isoformat()
        except ValueError:
            continue
        adlar = [a for a in h[1:] if a.strip(" .-–")]
        if not adlar:
            continue
        if "tatil" in " ".join(adlar).translate(TR_KUCUK).lower():
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogeler, notlar = [], []
            for metin in adlar:
                k = KALORI.search(metin)
                ad = yemek_adi(metin[:k.start()] if k else metin)
                if not ad:
                    continue
                oge = {"name": ad}
                if k and k[2]:
                    notlar.append("%s: %s–%s kcal" % (ad, k[1], k[2]))
                elif k and int(k[1]) > 0:
                    oge["kcal"] = int(k[1])
                ogeler.append(oge)
            if not ogeler:
                continue
            ogun = gun_icerigi(ogeler)
            if notlar:
                ogun["note"] = "; ".join(notlar)
        sonuc[tarih] = {"lunch": ogun}
    return sonuc


class BingolUniversitesi(Universite):
    id = "bingol"
    ad = "Bingöl Üniversitesi"
    kisa = "BÜ"
    sehir = "Bingöl"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self):
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("Bingöl: aylık yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Bingöl: tarihli aylık yemek tablosu bulunamadı")
        return sonuc
