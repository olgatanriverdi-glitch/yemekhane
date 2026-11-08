"""Aksaray: aylık HTML tablosu, kalem ve toplam kalori, tek liste (öğle).

Ekim 2026 kaynağındaki '02.10.206' ve '09.06.2026' tarih hataları, komşu
günler ve ay/yıl başlığı ile doğrulanır. Yazılı toplam kalori korunur;
kalem toplamı kaynak toplamından farklıysa yeniden hesaplanmaz.
"""
import re
from datetime import date

from ..model import TR_KUCUK, ay_no, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac, tarih_duzelt
from .base import Universite, indir

SAYFA_URL = "https://sks.aksaray.edu.tr/yemek-listesi"
GUNLER = ("PAZARTESİ", "SALI", "ÇARŞAMBA", "PERŞEMBE", "CUMA", "CUMARTESİ", "PAZAR")


def sayfa_menu(sayfa: str) -> dict:
    b = re.search(r"AKSARAY ÜNİVERSİTESİ\s+(\S+)\s+(\d{4})\s*-\s*YEMEK LİSTESİ", etiket_temizle(sayfa))
    baslik = (int(b.group(2)), ay_no(b.group(1))) if b and ay_no(b.group(1)) else None
    kayitlar = []
    for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", sayfa, re.S | re.I):
        hucreler = [etiket_temizle(h) for h in re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)]
        if len(hucreler) != 6:
            continue
        t = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{3,4})\s+(\S+)", hucreler[0])
        if not t:
            continue
        try:
            tarih = date(int(t.group(3)), int(t.group(2)), int(t.group(1)))
        except ValueError:
            continue
        kayitlar.append((tarih.isoformat(), t.group(4), hucreler))
    duzeltilmis, _ = tarih_duzelt([k[0] for k in kayitlar])
    sonuc = {}
    for (ham_tarih, gun, hucreler), tarih in zip(kayitlar, duzeltilmis):
        d = date.fromisoformat(tarih)
        if tarih != ham_tarih and (not baslik or (d.year, d.month) != baslik):
            continue
        # Yanlış tarih baştaysa da yalnız başlık ve hafta günü doğruluyorsa onar.
        if baslik and (d.year, d.month) != baslik:
            try:
                aday = date(baslik[0], baslik[1], d.day)
            except ValueError:
                continue
            if GUNLER[aday.weekday()] != gun:
                continue
            d, tarih = aday, aday.isoformat()
        if GUNLER[d.weekday()] != gun:
            continue
        adlar = [h for h in hucreler[1:5] if h.strip(" .-")]
        if not adlar:
            continue
        if "tatil" in " ".join(adlar).translate(TR_KUCUK).lower():
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogeler = []
            for metin in adlar:
                k = re.search(r"\(\s*(\d+)\s*KCAL\s*\)?", metin, re.I)
                ad = (metin[:k.start()] if k else metin).strip(" .-")
                if not ad:
                    continue
                oge = {"name": baslik_yap_serbest(kisaltma_ac(ad))}
                if k and int(k.group(1)) > 0:
                    oge["kcal"] = int(k.group(1))
                ogeler.append(oge)
            if not ogeler:
                continue
            ogun = gun_icerigi(ogeler)
            toplam = re.fullmatch(r"(\d+)\s*KCAL", hucreler[5], re.I)
            if toplam and int(toplam.group(1)) > 0:
                ogun["kcal"] = int(toplam.group(1))
        sonuc[tarih] = {"lunch": ogun}
    return sonuc


class AksarayUniversitesi(Universite):
    id = "aksaray"
    ad = "Aksaray Üniversitesi"
    kisa = "ASÜ"
    sehir = "Aksaray"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("Aksaray: aylık yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Aksaray: tarihli aylık yemek tablosu bulunamadı")
        return sonuc
