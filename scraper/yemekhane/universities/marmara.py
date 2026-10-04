"""Marmara Üniversitesi: haftalık menü sks.marmara.edu.tr/yemek sayfasında üç HTML tablo olarak yayınlanıyor: 'Normal Menü', 'Vejetaryen Menü', 'Vegan Menü'.
Her satırın başlığı '28.09.2026 Pazartesi', gövdesi yemek | kalori çiftleri listesidir; normal menüde ana yemeğin altında '... (Alternatif)' ikinci seçenek
ve 'Normal Toplam / Alternatif Toplam' satırları vardır. Öğrenci ücreti 'Yemekhane Hizmetleri Katkı Bedelleri' sayfasındaki tabloda yazar.
Yalnızca öğle yemeği yayınlanır; vegan menü uygulamada ayrı bir tür olmadığı için alınmaz (vejetaryen menüyle benzerdir).
"""
import html
import re
from datetime import date

from .base import Universite, indir

MENU_URL = "https://sks.marmara.edu.tr/yemek"
FIYAT_URL = "https://sks.marmara.edu.tr/hizmetlerimiz/beslenme-hizmetleri/yemekhane-hizmetleri-katki-bedelleri"
TARIH = re.compile(r"(\d{2})\.(\d{2})\.(\d{4})")


def temiz(h: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", h)).replace("\xa0", " ")).strip()


def _kcal(metin: str):
    m = re.search(r"(\d+)", metin or "")
    return int(m.group(1)) if m else None


def satir_ogeleri(td: str):
    """Hücreden (öğeler, normal_toplam). Alternatif ana yemek '(Alternatif)' ile, kalorisiyle birlikte öğe olur."""
    ogeler, toplam = [], None
    for li in re.findall(r"<li>(.*?)</li>", td, flags=re.S):
        sol = re.search(r'<span class="pull-left">(.*?)</span>', li, re.S)
        sag = re.search(r'<span class="pull-right">(.*?)</span>', li, re.S)
        if sol:
            ad = temiz(sol.group(1))
            if re.search(r"toplam", ad, re.I):
                toplam = toplam or _kcal(sag.group(1) if sag else ad)
            elif ad:
                oge = {"name": ad}
                kcal = _kcal(sag.group(1)) if sag else None
                if kcal:
                    oge["kcal"] = kcal
                ogeler.append(oge)
        alt = re.search(r'<i class="pull-left[^"]*"[^>]*>(.*?)</i>\s*<i class="pull-right[^"]*"[^>]*>(.*?)</i>', li, re.S)
        if alt and temiz(alt.group(1)):
            oge = {"name": temiz(alt.group(1))}
            kcal = _kcal(alt.group(2))
            if kcal:
                oge["kcal"] = kcal
            ogeler.append(oge)
        if not sol:                                   # 'Normal Toplam: 722 Kal' gibi düz metin satırları
            metin = temiz(li)
            m = re.search(r"(?:Normal\s+)?Toplam\s*:\s*(\d+)", metin, re.I)
            if m and toplam is None:
                toplam = int(m.group(1))
    return ogeler, toplam


def tablo_gunleri(tablo: str) -> dict:
    sonuc = {}
    for tr in re.findall(r"<tr.*?</tr>", tablo, flags=re.S):
        th = re.search(r"<th[^>]*>(.*?)</th>", tr, re.S)
        m = TARIH.search(temiz(th.group(1))) if th else None
        if not m:
            continue
        ogeler, toplam = satir_ogeleri(tr)
        if ogeler:
            gun = {"items": ogeler}
            if toplam:
                gun["kcal"] = toplam
            elif all("kcal" in o for o in ogeler):
                gun["kcal"] = sum(o["kcal"] for o in ogeler)
            sonuc[date(int(m.group(3)), int(m.group(2)), int(m.group(1))).isoformat()] = gun
    return sonuc


def sayfa_menu(sayfa: str) -> dict:
    """{'2026-09-28': {'lunch': {...}, 'vegetarian': {...}}, ...}"""
    sonuc = {}
    for baslik, tablo in re.findall(r"<h[1-6][^>]*>\s*([^<]*?)\s*</h[1-6]>\s*(?:<[^t][^>]*>\s*)*(<table.*?</table>)", sayfa, flags=re.S):
        b = baslik.lower()
        tur = "lunch" if b.startswith("normal") else "vegetarian" if b.startswith("vejetaryen") else None
        if not tur:
            continue
        for tarih, gun in tablo_gunleri(tablo).items():
            sonuc.setdefault(tarih, {})[tur] = gun
    return {t: g for t, g in sonuc.items() if "lunch" in g or "vegetarian" in g}


def ucret_ayikla(sayfa: str) -> list:
    """'Tip 11 Öğrenci (YÖKSİS Aktif, ...) 60' satırı."""
    m = re.search(r"Öğrenci\s*\(YÖKSİS Aktif[^)]*\)\s*(\d+)", temiz(sayfa))
    return [{"label": "Öğrenci (Öğle Yemeği)", "tl": int(m.group(1))}] if m else []


class MarmaraUniversitesi(Universite):
    id = "marmara"
    ad = "Marmara Üniversitesi"
    kisa = "MÜ"
    sehir = "İstanbul"
    kaynak = MENU_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        return sayfa_menu(self.indir(MENU_URL).decode("utf-8", "ignore"))

    def fiyatlar(self) -> list:
        try:
            return ucret_ayikla(self.indir(FIYAT_URL).decode("utf-8", "ignore"))
        except Exception as e:
            print("UYARI: Marmara fiyatları alınamadı:", e)
            return []
