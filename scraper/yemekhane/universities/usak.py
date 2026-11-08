"""Uşak: Türkçe aylık/pencere kartları, normal ve açık etiketli vejetaryen."""
import re
from ..model import etiket_temizle, gun_icerigi
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL = "https://yemek.usak.edu.tr/yemekhane"


def sayfa_menu(sayfa):
    # İngilizce çeviri kopyası aynı tarihleri tekrarlar.
    sayfa = sayfa.split("Monthly List", 1)[0]
    sonuc = {}
    for kart in re.split(r'<div\s+class="card-header\b[^\"]*"[^>]*>', sayfa)[1:]:
        t = tarih(kart.split("</div>",1)[0])
        if not t:
            continue
        normal, vejetaryen, alternatif = [], [], False
        notlar = []
        toplamlar = []
        for li in re.findall(r'<li\b[^>]*>(.*?)</li>', kart, re.S):
            metin = etiket_temizle(li)
            if metin.startswith("Toplam Kalori"):
                toplamlar = [int(k) for k in re.findall(r"(\d+)\s*kkal", metin)]
                continue
            parcalar = re.split(r"\s*/\s*VEJETARYEN\s*:\s*", metin, maxsplit=1, flags=re.I)
            a = oge(parcalar[0])
            if not a:
                continue
            normal.append(a)
            kaloriler = re.findall(r"(\d+)\s*kkal", parcalar[0], re.I)
            if len(parcalar) == 1 and len(kaloriler) > 1:
                notlar.append("%s: %s kcal" % (a["name"], " / ".join(kaloriler)))
            b = oge(parcalar[1]) if len(parcalar) == 2 else None
            vejetaryen.append(b or a.copy())
            alternatif = alternatif or b is not None
        if normal:
            gun = {"lunch": gun_icerigi(normal)}
            if toplamlar and (alternatif or len(toplamlar) == 1):
                gun["lunch"]["kcal"] = toplamlar[0]
            elif toplamlar:
                notlar.append("Seçeneklere göre toplam: %s kcal" % " / ".join(map(str, toplamlar)))
            if notlar:
                gun["lunch"]["note"] = "; ".join(notlar)
            if alternatif:
                gun["vegetarian"] = gun_icerigi(vejetaryen)
                if len(toplamlar) == 2:
                    gun["vegetarian"]["kcal"] = toplamlar[1]
            sonuc.setdefault(t.isoformat(), gun)
    return sonuc


class UsakUniversitesi(HtmlUniversitesi):
    id, ad, kisa, sehir = "usak", "Uşak Üniversitesi", "UÜ", "Uşak"
    kaynak = SAYFA_URL
    birikimli = True
    ayristir = staticmethod(sayfa_menu)
