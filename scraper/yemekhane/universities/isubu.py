"""İSUBÜ merkez: kapanış etiketleri olmayan beş sütunlu aylık takvim."""
import re
from datetime import timedelta
from ..model import etiket_temizle
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL = "https://yemek.isparta.edu.tr/menu"


def sayfa_menu(sayfa):
    tablo = re.search(r'<table\b[^>]*>(.*?)</table>', sayfa, re.S)
    if not tablo:
        return {}
    tarihler, sonuc = [], {}
    for satir in re.split(r"<tr\b[^>]*>", tablo[1], flags=re.I):
        hucreler = re.split(r"<td\b[^>]*>", satir, flags=re.I)[1:]
        if len(hucreler) != 5:
            continue
        if any(tarih(h) for h in hucreler):
            tarihler = [tarih(h) for h in hucreler]
            adaylar = {t-timedelta(days=i) for i,t in enumerate(tarihler) if t}
            if len(adaylar) == 1:
                ilk = adaylar.pop()
                if ilk.weekday() == 0:
                    tarihler = [t or (ilk+timedelta(days=i) if "Bugün" in hucreler[i] else None) for i,t in enumerate(tarihler)]
        elif tarihler and "<ul>" in satir:
            for t,h in zip(tarihler,hucreler):
                if not t:
                    continue
                liste = re.search(r"<ul>(.*?)</ul>", h, re.S)
                items = [o for o in (oge(x) for x in re.split(r"<li\b[^>]*>",liste[1] if liste else "")[1:]) if o]
                if items:
                    menu = {"items": items}
                    k = re.search(r"\b(\d+)\s*Kal\b", etiket_temizle(h))
                    if k:
                        menu["kcal"] = int(k[1])
                    sonuc[t.isoformat()] = {"lunch": menu}
            tarihler = []
    return sonuc


class IspartaUygulamaliBilimler(HtmlUniversitesi):
    id, ad, kisa, sehir = "isubu", "Isparta Uygulamalı Bilimler Üniversitesi", "İSUBÜ", "Isparta"
    kaynak = SAYFA_URL
    ayristir = staticmethod(sayfa_menu)
