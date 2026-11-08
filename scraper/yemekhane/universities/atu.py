"""ATÜ: girişsiz UBYS aylık menü kartları; günlük özet kopyası alınmaz."""
import re
from ..model import etiket_temizle, gun_icerigi
from ._son_ortak import HtmlUniversitesi, oge, tarih

SAYFA_URL = "https://ubys.atu.edu.tr/Yemekhane"


def sayfa_menu(sayfa):
    sonuc = {}
    for kart in re.split(r'<div\b[^>]*class="menu-card\b[^\"]*"[^>]*>', sayfa)[1:]:
        d = re.search(r'<div\b[^>]*class="date"[^>]*>(.*?)</div>', kart, re.S)
        t = tarih(d[1]) if d else None
        if not t:
            continue
        items = []
        for li in re.findall(r'<li\b[^>]*class="menu-item"[^>]*>(.*?)</li>', kart, re.S):
            ad = re.search(r'<div\b[^>]*class="item-name"[^>]*>(.*?)</div>', li, re.S)
            k = re.search(r'<span\b[^>]*class="calories[^\"]*"[^>]*>(.*?)</span>', li, re.S)
            o = oge(ad[1] + " " + etiket_temizle(k[1]) if ad and k else ad[1] if ad else "")
            if o:
                items.append(o)
        if items:
            menu = gun_icerigi(items)
            k = re.search(r"Toplam:\s*(\d+)\s*Kalori", etiket_temizle(kart), re.I)
            if k:
                menu["kcal"] = int(k[1])
            sonuc[t.isoformat()] = {"lunch": menu}
    return sonuc


class AdanaAlparslanTurkes(HtmlUniversitesi):
    id, ad, kisa, sehir = "atu", "Adana Alparslan Türkeş Bilim ve Teknoloji Üniversitesi", "ATÜ", "Adana"
    kaynak = SAYFA_URL
    ayristir = staticmethod(sayfa_menu)

    def fiyatlar(self):
        try:
            metin = etiket_temizle(getattr(self, "sayfa", None) or self.indir(SAYFA_URL).decode("utf-8-sig"))
        except Exception:
            return []
        sonuc = []
        for ad, kalip in (("Öğrenci (karta yükleme)", r"Öğrenci \(Öğrenci Kartına Yükleme\)"),
                          ("Günlük öğrenci", r"Günlük Öğrenci")):
            m = re.search(kalip+r"\s+(\d+),\d+\s*₺", metin)
            if m:
                sonuc.append({"label": ad, "tl": int(m[1])})
        return sonuc
