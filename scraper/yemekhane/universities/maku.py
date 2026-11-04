"""MAKÜ: merkez/Bucak haftalık HTML. İlçe ve diğer salonlar karıştırılmaz."""
import re
from datetime import timedelta
from ..model import etiket_temizle
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL = "https://mehmetakif.edu.tr/tr/content/10606/haftalik-yemek-listesi"
GUNLER = ("Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma")


def sayfa_menu(sayfa):
    sonuc = {}
    bloklar = re.split(r'<span class="text-maku-600">', sayfa)[1:]
    for blok in bloklar:
        baslik = blok.split("</span>", 1)[0]
        if "Merkez Yemekhane" not in baslik:
            continue
        aralik = re.search(r"(\d{2}\.\d{2}\.\d{4})\s*-\s*(\d{2}\.\d{2}\.\d{4})", baslik)
        ilk, son = (tarih(aralik[1]), tarih(aralik[2])) if aralik else (None, None)
        if not ilk or not son or ilk.weekday() != 0 or (son-ilk).days != 4:
            continue
        gunler = re.split(r'<div class="text-md text-slate-700 font-semibold my-1 border-b">', blok)[1:]
        for n, gun in enumerate(gunler[:5]):
            if etiket_temizle(gun.split("</div>", 1)[0]) != GUNLER[n]:
                continue
            items = [o for o in (oge(x) for x in re.findall(r'<div class="text-md border-b py-0.5">(.*?)</div>', gun, re.S)) if o]
            if items:
                menu = {"items": items}
                k = re.search(r'<div class="text-green-700[^\"]*">\s*(\d+)\s*Kalori', gun)
                if k:
                    menu["kcal"] = int(k[1])
                sonuc[(ilk+timedelta(days=n)).isoformat()] = {"lunch": menu}
    return sonuc


class BurdurMehmetAkifErsoy(HtmlUniversitesi):
    id, ad, kisa, sehir = "maku", "Burdur Mehmet Akif Ersoy Üniversitesi", "MAKÜ", "Burdur"
    kaynak = SAYFA_URL
    birikimli = True
    ayristir = staticmethod(sayfa_menu)
