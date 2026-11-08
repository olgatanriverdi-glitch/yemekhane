"""Siirt: ay seçicili HTML listesi, tek liste (öğle).

Seçili ay ve satırdaki gün numarası okunur. Kaynak yıl yazmadığı için
bugüne en yakın yıl seçilir. Kasım 2026 henüz yalnız 2 Kasım'ı içerir;
ay seçicisiyle Ekim'in 22 tarihli listesi de doğrulandı. Aylık kaynak.
"""
import re
from html.parser import HTMLParser

from ..model import TR_KUCUK, baslik_yap_serbest, bugun_tr, gun_icerigi, kisaltma_ac, yil_sec
from .base import Universite, indir

SAYFA_URL = "https://www.siirt.edu.tr/yemeklistesi.html"


class _ListeOkuyucu(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ay = None
        self.secici = False
        self.derinlik = 0
        self.satirlar = []
        self.satir = None
        self.hucre = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "select" and a.get("id", "").endswith("_ddl_ay"):
            self.secici = True
        elif tag == "option" and self.secici and "selected" in a:
            deger = a.get("value", "")
            if deger.isdigit() and 1 <= int(deger) <= 12:
                self.ay = int(deger)
        if tag != "div":
            return
        if not self.derinlik:
            if a.get("id", "").endswith("_div_yemeklist_"):
                self.derinlik = 1
            return
        self.derinlik += 1
        if self.derinlik == 2 and "border-bottom" in a.get("style", ""):
            self.satir = []
        elif self.derinlik == 3 and self.satir is not None:
            self.hucre = []

    def handle_endtag(self, tag):
        if tag == "select":
            self.secici = False
        if tag != "div" or not self.derinlik:
            return
        if self.derinlik == 3 and self.hucre is not None:
            self.satir.append(re.sub(r"\s+", " ", "".join(self.hucre)).strip())
            self.hucre = None
        elif self.derinlik == 2 and self.satir is not None:
            self.satirlar.append(self.satir)
            self.satir = None
        self.derinlik -= 1

    def handle_data(self, data):
        if self.hucre is not None:
            self.hucre.append(data)


def sayfa_menu(sayfa: str, bugun=None) -> dict:
    okuyucu = _ListeOkuyucu()
    okuyucu.feed(sayfa)
    if okuyucu.ay is None:
        return {}
    sonuc = {}
    for h in okuyucu.satirlar:
        if not h or not h[0].isdigit():
            continue
        tarih = yil_sec(int(h[0]), okuyucu.ay, bugun or bugun_tr())
        adlar = [a for a in h[1:] if a.strip(" .-–")]
        if tarih is None or not adlar:
            continue
        if all("tatil" in a.translate(TR_KUCUK).lower() for a in adlar):
            ogun = {"items": [], "note": "Tatil"}
        else:
            ogeler = []
            for metin in adlar:
                k = re.search(r"\s+(\d+)\s*Kalori\s*$", metin, re.I)
                ad = (metin[:k.start()] if k else metin).strip(" .-–")
                if not ad:
                    continue
                oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
                if k and int(k.group(1)) > 0:
                    oge["kcal"] = int(k.group(1))
                ogeler.append(oge)
            if not ogeler:
                continue
            ogun = gun_icerigi(ogeler)
        anahtar = tarih.isoformat()
        if anahtar in sonuc and sonuc[anahtar] != {"lunch": ogun}:
            raise ValueError("Siirt: %s için çelişen menüler var" % anahtar)
        sonuc[anahtar] = {"lunch": ogun}
    return sonuc


class SiirtUniversitesi(Universite):
    id = "siirt"
    ad = "Siirt Üniversitesi"
    kisa = "SİÜ"
    sehir = "Siirt"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("Siirt: aylık yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa, self.bugun)
        if not sonuc:
            raise RuntimeError("Siirt: seçili ayda tarihli yemek menüsü bulunamadı")
        return sonuc
