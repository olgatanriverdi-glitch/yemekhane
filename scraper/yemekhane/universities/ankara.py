"""Ankara Üniversitesi SKS: menüler sksbasvuru.ankara.edu.tr üzerinde XLSX olarak yayınlanıyor (öğle / akşam / vejetaryen)."""
import html
import re

from ..model import excel_tarih, tarih_duzelt, toplam_kalori, yemek_ogesi
from ..xlsx import satirlar
from .base import Universite, indir

TABAN = "https://sksbasvuru.ankara.edu.tr/kayit/moduller/yemeklistesi/"
KAYNAKLAR = {
    "lunch": TABAN + "aylikmenu.php",
    "dinner": TABAN + "aksammenu.php",
    "vegetarian": TABAN + "vejetaryenmenu.php",
}
SKS_SAYFA = "https://sks.ankara.edu.tr/yemek-hizmetleri-2/"
TATIL = re.compile(r"tatil|bayram", re.I)


def xlsx_menu(veri: bytes) -> dict:
    """Bir XLSX dosyasını {tarih: {'items': [...], 'kcal': n}} sözlüğüne çevirir."""
    gunler = {}
    tarih_satirlari = [s for s in satirlar(veri) if re.fullmatch(r"\d{5}(\.\d+)?", s.get("A", ""))]    # Excel gün numarası olan satırlar
    tarihler, duzeltmeler = tarih_duzelt([excel_tarih(s["A"]) for s in tarih_satirlari])
    for eski, yeni in duzeltmeler:
        print("DÜZELTME: okulun dosyasındaki tarih %s -> %s olarak yorumlandı" % (eski, yeni))
    for satir, tarih in zip(tarih_satirlari, tarihler):
        ogeler = [yemek_ogesi(satir[s]) for s in "BCDE" if satir.get(s)]
        if ogeler and all(TATIL.search(o["name"]) for o in ogeler):      # "29 Ekim Cumhuriyet Bayramı" yemek değil, tatil notudur
            gunler[tarih] = {"items": [], "note": " / ".join(o["name"] for o in ogeler)}
            continue
        gun = {"items": ogeler}
        k = toplam_kalori(satir.get("F", ""))
        if k:
            gun["kcal"] = k
        elif all("kcal" in o for o in ogeler) and ogeler:
            gun["kcal"] = sum(o["kcal"] for o in ogeler)
        gunler[tarih] = gun
    return gunler


def fiyat_ayikla(sayfa_html: str) -> list:
    metin = html.unescape(re.sub(r"<[^>]+>", "\n", re.sub(r"<script.*?</script>|<style.*?</style>", "", sayfa_html, flags=re.S)))
    satirlar_ = [s.strip() for s in metin.split("\n") if s.strip()]
    sonuc = []
    for i, s in enumerate(satirlar_):
        if s == "₺" and i > 0 and i + 1 < len(satirlar_) and satirlar_[i + 1].isdigit():
            sonuc.append({"label": satirlar_[i - 1], "tl": int(satirlar_[i + 1])})
    return sonuc


class AnkaraUniversitesi(Universite):
    id = "ankara"
    ad = "Ankara Üniversitesi"
    kisa = "AÜ"
    sehir = "Ankara"
    kaynak = SKS_SAYFA

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        sonuc = {}
        for tur, url in KAYNAKLAR.items():
            try:
                gunler = xlsx_menu(self.indir(url))
            except Exception as e:                      # bir tür bozuk olsa diğerleri yayınlansın
                print("UYARI: %s menüsü alınamadı: %s" % (tur, e))
                continue
            for tarih, gun in gunler.items():
                sonuc.setdefault(tarih, {})[tur] = gun
        return sonuc

    def gunluk(self):
        """SKS sayfası bugünün tabldot fotoğrafını ve listesini görsel olarak yayınlıyor (resim.php / baslik.php / yemek.php)."""
        from .. import ocr
        foto = None
        try:
            foto = self.indir(TABAN + "resim.php")
        except Exception as e:
            print("UYARI: günlük fotoğraf alınamadı:", e)
        tarih, ogeler = None, None
        if ocr.kullanilabilir():
            try:
                tarih = ocr.tarih_ayikla(ocr.oku(self.indir(TABAN + "baslik.php"), psm=7))
                ogeler = ocr.liste_ayikla(ocr.oku(self.indir(TABAN + "yemek.php"), psm=6)) or None
            except Exception as e:
                print("UYARI: günlük liste okunamadı:", e)
        else:
            print("BİLGİ: tesseract yok, günlük liste görselden okunmadı")
        if not foto and not ogeler:
            return None
        return {"date": tarih, "photo": foto, "items": ogeler, "meal": "lunch"}

    def fiyatlar(self) -> list:
        try:
            return fiyat_ayikla(self.indir(SKS_SAYFA).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: fiyatlar alınamadı:", e)
            return []
