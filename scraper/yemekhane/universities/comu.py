"""Çanakkale Onsekiz Mart Üniversitesi: aylık menü sks.comu.edu.tr/tr/sayfa/yemek-listesi-65.html sayfasına PDF olarak ('EKİM 2026 YEMEK MENÜSÜ.pdf') ve vegan menü
için ayrı bir PDF olarak ('EKİM 2026 VEGAN YEMEK MENÜSÜ.pdf') yükleniyor. PDF'ler Canva çıkışlıdır: metin gerçek metindir (ToUnicode var) ama her karakter ayrı
konumlandığından `pdf.sayfa_metinleri(ctm=True)` ile sayfa koordinatları alınıp satırlar birleştirilir. Düzen: hafta içi 5 sütun, her hücrede 'GG.AA.YYYY' başlığı
ve altında 'Yemek Adı (kalori)' satırları; sütunlar başlıkların x konumundan, hücre satırları ise başlığın altındaki en yakın başlıktan bulunur. Şablondan kalma, görünmeyen
beyaz eski tarihler (31.08.2026 gibi) başlıktaki ay dışında oldukları için atılır. Servis saatleri PDF'in sol üstündeki yazıdan okunur (öğle 11:30-14:00).
"""
import re
from datetime import date

from .. import pdf as pdfmod
from ..model import ay_no, baslik_yap_serbest, bugun_tr, gun_icerigi, kisaltma_ac
from .base import Universite, indir, saat_duzenle

SAYFA_URL = "https://sks.comu.edu.tr/tr/sayfa/yemek-listesi-65.html"
DOSYA_URL = "https://cdn.comu.edu.tr/cms/sks/files/"
TARIH = re.compile(r"(\d{2})\.(\d{2})\.(\d{4})")
OGE = re.compile(r"^(.+?)\s*\(\s*(\d+)\s*\)")                # 'Mercimek Çorba (233)'


def pdf_baglantilari(sayfa: str) -> list:
    """[(dosya_adı, başlık)]: `viewer('74551_ekim-2026-yemek-menusu.pdf', 'EKİM 2026 YEMEK MENÜSÜ.pdf', ...)` çağrılarından (her dosya için simge ve ad olmak üzere iki çağrı vardır)."""
    return list(dict.fromkeys(re.findall(r"viewer\('([^']+\.pdf)',\s*'([^']+)'", sayfa)))


def pdf_menu(veri: bytes) -> tuple:
    """(menü, saat): menü {'2026-10-01': {'items': [{'name': 'Tarhana Çorba', 'kcal': 194}, ...], 'kcal': 1013}, ...}; saat '11:30–14:00' (yoksa None)."""
    sayfalar = pdfmod.sayfa_metinleri(veri, ctm=True)
    if not sayfalar:
        return {}, None
    satirlar = pdfmod.satirlari_birlestir(max(sayfalar, key=len), bosluk=1.0)
    baslik = next((s[0] for s in satirlar if "MENÜSÜ" in s[0]), "")
    m = re.match(r"(\S+)\s+(\d{4})", baslik)
    ay, yil = (ay_no(m.group(1)), int(m.group(2))) if m else (None, None)
    if not ay:
        return {}, None
    saat = None
    for s in satirlar:
        if re.search(r"Öğle Yemeği Saatleri", s[0]):
            saat = saat_duzenle(s[0])
    basliklar = []         # [(tarih, x_orta, y)]: yalnızca başlıktaki ay (şablondan kalan gizli tarihler dışarıda kalır)
    sutunlar = set()
    ogeler = []
    for metin, x0, x1, y, _ in satirlar:
        d = TARIH.fullmatch(metin.strip())
        orta = round((x0 + x1) / 2)
        if d:
            sutunlar.add(orta)
            if int(d.group(2)) == ay and int(d.group(3)) == yil:
                try:
                    basliklar.append((date(yil, ay, int(d.group(1))), orta, y))
                except ValueError:
                    pass
            continue
        o = OGE.match(metin)
        if o and "Saatleri" not in metin:
            ogeler.append((o.group(1), int(o.group(2)), orta, y))
    if not basliklar:
        return {}, saat
    gunler = {}
    for ad, kcal, orta, y in sorted(ogeler, key=lambda o: -o[3]):
        sutun = min(sutunlar, key=lambda c: abs(c - orta))
        ustu = [b for b in basliklar if abs(b[1] - sutun) < 40 and b[2] > y]
        if not ustu:
            continue
        baslik_hucre = min(ustu, key=lambda b: b[2] - y)
        gunler.setdefault(baslik_hucre[0], []).append({"name": baslik_yap_serbest(kisaltma_ac(ad.strip(" .-"))), "kcal": kcal})
    return {t.isoformat(): gun_icerigi(o) for t, o in gunler.items()}, saat


class CanakkaleOnsekizMart(Universite):
    id = "comu"
    ad = "Çanakkale Onsekiz Mart Üniversitesi"
    kisa = "ÇOMÜ"
    sehir = "Çanakkale"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun
        self._saat = None

    def menuler(self) -> dict:
        bugun = self.bugun or bugun_tr()
        yakin = {(bugun.year, bugun.month), (bugun.year + (bugun.month == 12), bugun.month % 12 + 1)}
        sonuc = {}
        for dosya, baslik in pdf_baglantilari(self.indir(SAYFA_URL).decode("utf-8", "ignore")):
            m = re.match(r"(\S+)\s+(\d{4})", baslik)
            if not m or (int(m.group(2)), ay_no(m.group(1))) not in yakin:         # eski aylar tekrar indirilmez
                continue
            tur = "vegetarian" if "vegan" in baslik.lower() else "lunch"
            try:
                menu, saat = pdf_menu(self.indir(DOSYA_URL + dosya))
            except Exception as e:
                print("UYARI: ÇOMÜ %s okunamadı: %s" % (baslik, e))
                continue
            if tur == "lunch" and saat:
                self._saat = saat
            for tarih, gun in menu.items():
                sonuc.setdefault(tarih, {})[tur] = gun
        return sonuc

    def saatler(self) -> dict:
        return {"lunch": self._saat} if self._saat else {}
