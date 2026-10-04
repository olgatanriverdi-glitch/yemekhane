"""İstanbul Üniversitesi: menü sks.istanbul.edu.tr/yemek-listesi sayfasında takvim olarak gösteriliyor; sayfa her gün için
`/meals-by-date?date=YYYY-MM-DD&category=breakfast|lunch|dinner|vegan` adresinden JSON alıyor:
  {"success": true, "meal": "Düğün Çorbası,\\r\\nEtli Bezelye,\\r\\nPirinç Pilavı,\\r\\nKıbrıs Tatlısı", "category": "lunch"}
Menü olmayan günlerde `success: false` döner. Kahvaltı tek satırda virgülle ayrılmış, 'Çay/Meyve Suyu/Süt' gibi seçenekler '/' ile yazılır.
Kalori yayınlanmıyor. Öğrenci yemek ücreti yalnızca taranmış bir Yönetim Kurulu kararı olarak (resim PDF) yayınlandığı için okunmuyor.
"""
import html
import json
import re
import time
from datetime import date, timedelta

from .base import Universite, indir, saat_duzenle

BASE = "https://sks.istanbul.edu.tr/"
SAAT_URL = BASE + "tr/yemekhane-saatler-ve-ucretler"
ILERI_GUN = 40
GERI_GUN = 2
ART_ARDA_BOS = 8          # menü bittiyse bu kadar boş gün üst üste görünce dur

# sitedeki kategori -> uygulamadaki öğün türü
KATEGORILER = {"breakfast": "breakfast", "lunch": "lunch", "dinner": "dinner", "vegan": "vegetarian"}
SIRA = ("lunch", "dinner", "breakfast", "vegan")        # önce ana öğünler: ikisi de yoksa o gün atlanır


def meal_url(tarih: str, kategori: str) -> str:
    return "%smeals-by-date?date=%s&category=%s" % (BASE, tarih, kategori)


def ogeler(metin: str, kahvalti: bool = False) -> list:
    """'A,\\r\\nB,\\r\\nC' -> [{'name': 'A'}, ...]; kahvaltıda virgül ve '/' ayırıcıdır."""
    if kahvalti:
        parcalar = [p for satir in metin.splitlines() for k in satir.split(",") for p in k.split("/")]
    else:
        parcalar = [p for satir in metin.splitlines() for p in re.split(r",\s*$", satir)]
    sonuc = []
    for p in parcalar:
        ad = re.sub(r"\s+", " ", html.unescape(p)).strip(" ,")
        if ad:
            sonuc.append({"name": ad})
    return sonuc


def cevap_ogun(govde: str, kahvalti: bool = False):
    """JSON yanıtı -> {'items': [...]} ya da None (menü yok / bozuk yanıt)."""
    try:
        veri = json.loads(govde)
    except ValueError:
        return None
    if not veri.get("success") or not veri.get("meal"):
        return None
    liste = ogeler(veri["meal"], kahvalti)
    return {"items": liste} if liste else None


def saat_ayikla(sayfa: str) -> dict:
    """'Kahvaltı 07.30 09.00 ... Öğle Yemeği 11.00 14.00 ... Akşam 16.00 18.00' -> ilk (genel) saatler."""
    metin = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", sayfa)))
    sonuc = {}
    for ad, tur in (("Kahvaltı", "breakfast"), ("Öğle Yemeği", "lunch"), ("Akşam", "dinner")):
        m = re.search(r"%s\s+(\d{1,2})[.:](\d{2})\s+(\d{1,2})[.:](\d{2})" % ad, metin)
        if m:
            sonuc[tur] = saat_duzenle("%s:%s-%s:%s" % m.groups())
    return sonuc


class IstanbulUniversitesi(Universite):
    id = "iu"
    ad = "İstanbul Üniversitesi"
    kisa = "İÜ"
    sehir = "İstanbul"
    kaynak = BASE + "yemek-listesi"

    def __init__(self, indirici=indir, bugun=None, bekle=0.15):
        self.indir = indirici
        self.bugun = bugun
        self.bekle = bekle

    def _al(self, tarih: str, kategori: str):
        try:
            return self.indir(meal_url(tarih, kategori)).decode("utf-8", "ignore")
        except Exception as e:
            print("UYARI: İÜ %s %s alınamadı: %s" % (tarih, kategori, e))
            return None
        finally:
            if self.bekle:
                time.sleep(self.bekle)

    def menuler(self) -> dict:
        bugun = self.bugun or date.today()
        sonuc, bos = {}, 0
        for k in range(-GERI_GUN, ILERI_GUN + 1):
            tarih = (bugun + timedelta(days=k)).isoformat()
            gun = {}
            for kategori in SIRA:
                if kategori in ("breakfast", "vegan") and not gun:
                    continue                   # öğle/akşam menüsü yoksa o gün menü yok: kalan sorgular atlanır
                govde = self._al(tarih, kategori)
                ogun = cevap_ogun(govde, kategori == "breakfast") if govde else None
                if ogun:
                    gun[KATEGORILER[kategori]] = ogun
            if gun:
                sonuc[tarih] = gun
                bos = 0
            else:
                bos += 1
                if sonuc and bos >= ART_ARDA_BOS:
                    break
        return sonuc

    def saatler(self) -> dict:
        try:
            return saat_ayikla(self.indir(SAAT_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: İÜ saatleri alınamadı:", e)
            return {}
