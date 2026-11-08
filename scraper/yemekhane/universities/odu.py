"""Ordu: SKS ana sayfasının bağladığı iki sayfalık aylık metin PDF'i.

Satırlar tarihlere, altı yemek sütunu PDF konumlarına göre ayrılır. Seçenekler
aynı hücrede '/' ile korunur; ayrı vejetaryen/akşam menüsü uydurulmaz.
Önceki ayın taşan satırları ayıklanır. İlk doğrulama Ekim 2026 düzeni.
"""
import html
import re
from datetime import date
from urllib.parse import quote, unquote, urljoin

from .. import pdf as pdfmod
from ..model import TR_KUCUK, baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir, saat_duzenle

SAYFA_URL = "https://sksdb.odu.edu.tr/"
SAAT_URL = "https://sksdb.odu.edu.tr/Page/62/yemekhane_hizmetleri"
SINIRLAR = (90, 150, 222, 300, 375, 460, 565)


def pdf_baglantisi(sayfa):
    for url, ad in re.findall(r'<a\b[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>', sayfa, re.S | re.I):
        if etiket_temizle(ad) == "Yemek Listesi" and unquote(url).lower().endswith(".pdf"):
            return quote(urljoin(SAYFA_URL, html.unescape(unquote(url))), safe=":/()")
    return None


def yemek_adi(metin):
    metin = re.sub(r"\b(arpa|tel) şeh\.\s*", r"\1 şehriye ", metin, flags=re.I)
    for kalip, yeni in ((r"\bşeh\.\s*", "şehriyeli "), (r"\bşehr?\.\s*", "şehriye "),
                        (r"\bzyt\.\s*", "zeytinyağlı "), (r"\bbeş\.\s*", "beşamel "),
                        (r"\bgarn\.?\s+", "garnitürlü "), (r"\byoğ\.\s*", "yoğurtlu ")):
        metin = re.sub(kalip, yeni, metin, flags=re.I)
    metin = re.sub(r"\s*/\s*", "/", re.sub(r"\s+", " ", metin)).strip(" .-/")
    metin = re.sub(r"\s+([),])", r"\1", metin)
    return baslik_yap_serbest(kisaltma_ac(metin))


def pdf_menu(veri):
    sonuc = {}
    for sayfa in pdfmod.sayfa_metinleri(veri):
        # Bazı tarihler 01.10 + .2026 gibi ayrı yazı parçalarına bölünür.
        tarihler = {}
        for x, y, _, t in sayfa:
            if x < SINIRLAR[0] and t.strip():
                anahtar = next((yy for yy in tarihler if abs(y - yy) < .6), y)
                tarihler.setdefault(anahtar, []).append((x, t.strip()))
        basliklar = []
        for y, parcalar in tarihler.items():
            t = re.fullmatch(r"(\d{2})\.(\d{2})\.(\d{4})", "".join(t for _, t in sorted(parcalar)))
            if t:
                try:
                    basliklar.append((date(int(t[3]), int(t[2]), int(t[1])), y))
                except ValueError:
                    continue
        basliklar.sort(key=lambda o: -o[1])
        for n, (tarih, ust) in enumerate(basliklar):
            alt = basliklar[n + 1][1] if n + 1 < len(basliklar) else ust - 65
            alan = [(x, y, t.strip()) for x, y, _, t in sayfa if SINIRLAR[0] <= x < SINIRLAR[-1] and alt + 1.5 < y <= ust + 1.5 and t.strip()]
            metin = " ".join(t for _, _, t in alan).translate(TR_KUCUK).lower()
            if "tatil" in metin or "cumhuriyet bayram" in metin:
                sonuc[tarih.isoformat()] = {"lunch": {"items": [], "note": "Resmi tatil"}}
                continue
            ogeler = []
            for sol, sag in zip(SINIRLAR, SINIRLAR[1:]):
                satirlar = {}
                for x, y, t in alan:
                    if sol <= x < sag:
                        yy = next((yy for yy in satirlar if abs(y - yy) < .6), y)
                        satirlar.setdefault(yy, []).append((x, t))
                metinler = []
                for yy in sorted(satirlar, reverse=True):
                    parcalar = [t for _, t in sorted(satirlar[yy])]
                    satir = ""
                    for i, t in enumerate(parcalar):
                        satir += ("" if i == 0 or len(t) == 1 or len(parcalar[i - 1]) == 1 else " ") + t
                    metinler.append(satir)
                ad = yemek_adi(" ".join(metinler))
                if ad and ad != "-":
                    ogeler.append({"name": ad})
            if ogeler:
                sonuc[tarih.isoformat()] = {"lunch": {"items": ogeler}}
    if not sonuc:
        return {}
    son_ay = max(sonuc)[:7]
    return {t: g for t, g in sonuc.items() if t.startswith(son_ay)}


class OrduUniversitesi(Universite):
    id = "odu"
    ad = "Ordu Üniversitesi"
    kisa = "ODÜ"
    sehir = "Ordu"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self):
        try:
            url = pdf_baglantisi(self.indir(SAYFA_URL).decode("utf-8-sig"))
        except Exception as e:
            raise RuntimeError("Ordu: SKS yemek listesi sayfası indirilemedi: %s" % e) from e
        if not url:
            raise RuntimeError("Ordu: güncel yemek PDF bağlantısı bulunamadı")
        try:
            sonuc = pdf_menu(self.indir(url))
        except Exception as e:
            raise RuntimeError("Ordu: aylık yemek PDF'i okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("Ordu: PDF'te tarihli yemek tablosu bulunamadı")
        return sonuc

    def saatler(self):
        try:
            metin = etiket_temizle(self.indir(SAAT_URL).decode("utf-8-sig"))
        except Exception:
            return {}
        sonuc = {}
        for ad, tur in (("öğle", "lunch"), ("akşam", "dinner")):
            m = re.search(r"öğrenci yemekhanelerimizde hafta içi " + ad + r" yemeği servisi\s+([\d:.-]+)", metin, re.I)
            saat = saat_duzenle(m[1]) if m else None
            if saat:
                sonuc[tur] = saat
        return sonuc
