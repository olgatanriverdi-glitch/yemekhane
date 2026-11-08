"""Kastamonu: Next.js sayfasına gömülü aylık JSON, yalnız Merkezi Yemekhane.

Flight dizgileri JSON olarak çözülür; JavaScript çalıştırılmaz. Konukevi ve
Parlayan Yıldız menüleri öğrenci yemekhanesine katılmaz. Tek liste öğle
sayılır; akşam servis saati bulunması menüyü ikinci bir öğüne çoğaltmaz.
"""
import json
import re
from datetime import date

from ..model import baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir, saat_duzenle

SAYFA_URL = "https://www.kastamonu.edu.tr/tr/yemeklistesi"


def merkez_verileri(sayfa: str):
    for ham in re.findall(r'self\.__next_f\.push\(\[1,("(?:\\.|[^"\\])*")\]\)', sayfa):
        parca = json.loads(ham)
        m = re.search(r'"data":\s*(\[\s*\{\s*"yemekhaneId")', parca)
        if not m:
            continue
        kayitlar = json.JSONDecoder().raw_decode(parca[m.start(1):])[0]
        for kayit in kayitlar:
            if isinstance(kayit, dict) and kayit.get("yemekhaneId") == 1 and kayit.get("aktif") is not False:
                return kayit.get("aylikYemekListesi", [])
    return []


def yemek_ogesi(metin: str):
    metin = etiket_temizle(metin)
    k = re.search(r"\s+(\d+)\s*K?KAL\s*$", metin, re.I)
    ad = (metin[:k.start()] if k else metin).strip(" -")
    ad = re.sub(r"\bTAV\.\s*", "TAVUKLU ", ad, flags=re.I)
    ad = re.sub(r"\bÇ\.$", "ÇORBA", ad, flags=re.I)
    if not ad or ad == "-":
        return None
    oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
    if k and int(k.group(1)) > 0:
        oge["kcal"] = int(k.group(1))
    return oge


def sayfa_menu(sayfa: str) -> dict:
    sonuc = {}
    for k in merkez_verileri(sayfa):
        if not isinstance(k, dict):
            continue
        try:
            tarih = date.fromisoformat(str(k.get("tarih", ""))[:10]).isoformat()
        except ValueError:
            continue
        if k.get("yemekVarMi") is False:
            # 'Yemek bulunmamaktadır' belirsizdir; yalnız açık tatil korunur.
            if "tatil" in str(k.get("yemekYokAciklamaTR", "")).lower():
                sonuc[tarih] = {"lunch": {"items": [], "note": "Tatil"}}
            continue
        ogeler = [o for o in (yemek_ogesi(str(k.get("yemek%dTR" % n) or "")) for n in range(1, 5)) if o]
        if ogeler:
            sonuc[tarih] = {"lunch": gun_icerigi(ogeler)}
    return sonuc


class KastamonuUniversitesi(Universite):
    id = "kastamonu"
    ad = "Kastamonu Üniversitesi"
    kisa = "KÜ"
    sehir = "Kastamonu"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici
        self.sayfa = None

    def _sayfa(self):
        if self.sayfa is None:
            self.sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        return self.sayfa

    def menuler(self) -> dict:
        try:
            sayfa = self._sayfa()
        except Exception as e:
            raise RuntimeError("Kastamonu: merkezi yemekhane sayfası indirilemedi: %s" % e) from e
        try:
            sonuc = sayfa_menu(sayfa)
        except (ValueError, TypeError) as e:
            raise RuntimeError("Kastamonu: gömülü aylık menü JSON'u okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("Kastamonu: Merkezi Yemekhane aylık menüsü bulunamadı")
        return sonuc

    def saatler(self) -> dict:
        try:
            metin = etiket_temizle(self._sayfa())
        except Exception:
            return {}
        sonuc = {}
        for baslik, tur in (("Öğle", "lunch"), ("Akşam", "dinner")):
            m = re.search(baslik + r" Yemeği Servisi:\s*([\d\s:.–—-]+)", metin)
            saat = saat_duzenle(m.group(1)) if m else None
            if saat:
                sonuc[tur] = saat
        return sonuc

    def fiyatlar(self) -> list:
        try:
            sayfa = self._sayfa()
        except Exception:
            return []
        for s in re.findall(r"<tr\b[^>]*>(.*?)</tr>", sayfa, re.S | re.I):
            h = [etiket_temizle(x) for x in re.findall(r"<td\b[^>]*>(.*?)</td>", s, re.S | re.I)]
            if len(h) == 2 and h[0] == "Öğrenci":
                k = re.fullmatch(r"(\d+(?:[.,]\d+)?)\s*₺", h[1])
                if k:
                    return [{"label": "Öğrenci", "tl": float(k.group(1).replace(",", "."))}]
        return []
