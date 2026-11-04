"""Tarsus: beş yemekli aylık öğle tablosu. Kalori ve vejetaryen etiketi yok."""
import re
from datetime import timedelta
from ..model import etiket_temizle
from ._son_ortak import HtmlUniversitesi, oge, son_ay, tarih

SAYFA_URL = "https://sks.tarsus.edu.tr/tr/page/yemek-listesi/2581"
FIYAT_URL = "https://sks.tarsus.edu.tr/tr/page/yemekhane-ve-kantin/2687"


def sayfa_menu(sayfa):
    sonuc = {}
    for tablo in re.findall(r"<table\b[^>]*>(.*?)</table>", sayfa, re.S):
        if "ÖĞLE YEMEK LİSTESİ" not in etiket_temizle(tablo):
            continue
        satirlar = [re.findall(r"<td\b[^>]*>(.*?)</td>", s, re.S) for s in re.findall(r"<tr\b[^>]*>(.*?)</tr>", tablo, re.S)]
        for n, h in enumerate(satirlar):
            if len(h) != 6:
                continue
            t = tarih(h[0])
            # Kaynak 4 Kasım tarih hücresine “SENİN MENÜN” yazmış.
            # Yalnız iki komşusu tam bir gün boşluk bıraktığında tarih çıkarılır.
            if not t and etiket_temizle(h[0]) == "SENİN MENÜN" and 0 < n < len(satirlar)-1:
                a, b = tarih(satirlar[n-1][0]), tarih(satirlar[n+1][0])
                if a and b and (b-a).days == 2 and a.weekday() < 4:
                    t = a + timedelta(days=1)
            if not t:
                continue
            items = [o for o in (oge(x) for x in h[1:]) if o]
            if items:
                sonuc[t.isoformat()] = {"lunch": {"items": items}}
    return son_ay(sonuc)


class TarsusUniversitesi(HtmlUniversitesi):
    id, ad, kisa, sehir = "tarsus", "Tarsus Üniversitesi", "Tarsus Ü", "Mersin"
    kaynak = SAYFA_URL
    ayristir = staticmethod(sayfa_menu)

    def fiyatlar(self):
        try:
            metin = etiket_temizle(self.indir(FIYAT_URL).decode("utf-8-sig"))
        except Exception:
            return []
        m = re.search(r"Öğrencilerimizden\s+(\d+),\d+\s*TL", metin)
        return [{"label": "Öğrenci", "tl": int(m[1])}] if m else []
