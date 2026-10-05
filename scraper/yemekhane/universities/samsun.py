"""Samsun Üniversitesi: aylık öğle yemeği listesi sks.samsun.edu.tr/yemek-listesi/ sayfasına PDF olarak yükleniyor ('Ekim 2026 yemek listesinin tamamına buradan
ulaşabilirsiniz'; sayfada ayrıca yalnızca günün yemeği fotoğraflı olarak durur). PDF bir Excel formunun çıktısıdır ('2026 YILI EKİM AYI ÖĞLE YEMEK LİSTESİ FORMU'):
hafta içi 5 sütun, her hücrede gün numarası, 'Yemek Adı (179 kcal)' satırları ve 'Toplam kalori: 884 Kcal' satırı bulunur. Hücre içeriği, gün numarasıyla aynı x
konumundaki ve onun altındaki satırlardan toplanır (pdf.sayfa_metinleri).
"""
import re
from datetime import date

from .. import pdf as pdfmod
from ..model import ay_no, baslik_yap_serbest, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sks.samsun.edu.tr/yemek-listesi/"
OGE = re.compile(r"^(.+?)\s*\(\s*[~≈-]?\s*(\d+)\s*(?:kcal|kca|kal|cal)\s*\)\s*$", re.I)           # 'Salata (~97 kcal)', 'Tavuk Döner (210 kca)' gibi yazım hataları da var
TOPLAM = re.compile(r"Toplam kalori\s*:\s*(\d+)", re.I)


def pdf_menu(veri: bytes) -> dict:
    """{'2026-10-01': {'items': [{'name': 'Ezogelin Çorbası', 'kcal': 114}, ...], 'kcal': 648}, ...}"""
    sayfalar = pdfmod.sayfa_metinleri(veri)
    if not sayfalar:
        return {}
    parcalar = max(sayfalar, key=len)
    baslik = next((t for _, _, _, t in parcalar if "YILI" in t and "AYI" in t), "")
    m = re.search(r"(\d{4})\s+YILI\s+(\S+)\s+AYI", baslik)
    ay, yil = (ay_no(m.group(2)), int(m.group(1))) if m else (None, None)
    if not ay:
        return {}
    basliklar = [(x, y, int(t)) for x, y, _, t in parcalar if re.fullmatch(r"\d{1,2}", t.strip()) and 1 <= int(t) <= 31]
    gunler = {}
    for x, y, boyut, metin in sorted(parcalar, key=lambda p: -p[1]):
        o, top = OGE.match(metin.strip()), TOPLAM.search(metin)
        if not (o or top):
            continue
        ustu = [b for b in basliklar if abs(b[0] - x) < 1.0 and b[1] > y]
        if not ustu:
            continue
        yakin = min(ustu, key=lambda b: b[1] - y)          # aynı sütunda satırın üstündeki en yakın gün numarası: (x, y, gün)
        gun = gunler.setdefault(yakin[2], {"items": []})
        if o:
            gun["items"].append({"name": baslik_yap_serbest(kisaltma_ac(o.group(1).strip())), "kcal": int(o.group(2))})
        else:
            gun["kcal"] = int(top.group(1))
    sonuc = {}
    for no, gun in gunler.items():
        if not gun["items"]:
            continue
        try:
            tarih = date(yil, ay, no).isoformat()
        except ValueError:
            continue
        if "kcal" not in gun:
            gun["kcal"] = sum(o["kcal"] for o in gun["items"])
        sonuc[tarih] = gun
    return sonuc


class SamsunUniversitesi(Universite):
    id = "samsun"
    ad = "Samsun Üniversitesi"
    kisa = "SÜ"
    sehir = "Samsun"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        sonuc = {}
        sayfa = self.indir(SAYFA_URL).decode("utf-8", "ignore")
        for adres in dict.fromkeys(re.findall(r'href="([^"]+\.pdf)"', sayfa, re.I)):
            try:
                menu = pdf_menu(self.indir(adres))
            except Exception as e:
                print("UYARI: Samsun Üniversitesi PDF'i okunamadı (%s): %s" % (adres, e))
                continue
            for tarih, gun in menu.items():
                sonuc.setdefault(tarih, {})["lunch"] = gun
        return sonuc
