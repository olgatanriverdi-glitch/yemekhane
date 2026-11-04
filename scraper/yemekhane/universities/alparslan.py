"""Muş Alparslan: yeni SKS sitesinin haftalık gerçek metin PDF'i.

İlk sayfa menüdür; sonraki sayfalar içerik/alerjen tarifleridir. Tarih ve
yemeklerin bölünmüş parçaları beş gün sütununda birleştirilir. İki ana
yemek seçmelidir: kalem kalorileri korunur, ikisi toplanmaz. Öğle listesi.
"""
import html
import re
from datetime import date
from urllib.parse import quote, unquote, urljoin

from .. import pdf as pdfmod
from ..model import baslik_yap_serbest, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://nsks.alparslan.edu.tr/sayfa/50/haftalik-yemek-menusu"
FIYAT_URL = "https://nsks.alparslan.edu.tr/sayfa/53/universitemizde-alinan-yemek-ucretleri"
SINIRLAR = (36, 200, 359, 519, 672, 810)
GUNLER = ("Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma")


def pdf_baglantisi(sayfa):
    for url, ad in re.findall(r'<a\b[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>', sayfa, re.S | re.I):
        if etiket_temizle(ad) == "YEMEK MENÜSÜ" and unquote(url).lower().endswith(".pdf"):
            return quote(urljoin(SAYFA_URL, html.unescape(unquote(url))), safe=":/()")
    return None


def _satirlar(alan):
    satirlar = {}
    for x, y, _, t in alan:
        yy = next((yy for yy in satirlar if abs(yy - y) < .6), y)
        satirlar.setdefault(yy, []).append((x, t))
    # Ayrı PDF parçaları bazen tek sözcüğü veya kalori rakamını böler.
    return [(y, "".join(t for _, t in sorted(satirlar[y])).strip()) for y in sorted(satirlar, reverse=True)]


def pdf_menu(veri):
    sayfalar = pdfmod.sayfa_metinleri(veri, ctm=True)
    if not sayfalar:
        return {}
    sayfa = sayfalar[0]
    alt = max((y for _, y, _, t in sayfa if "Ana" in t and "seçmelidir" in t), default=130) + 10
    sonuc = {}
    for i, (sol, sag) in enumerate(zip(SINIRLAR, SINIRLAR[1:])):
        sutun = [o for o in sayfa if sol <= o[0] < sag]
        tarih, ust = None, None
        for y, t in _satirlar(sutun):
            m = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", re.sub(r"\s", "", t))
            if not m:
                continue
            try:
                tarih = date(int(m[3]), int(m[2]), int(m[1]))
            except ValueError:
                continue
            if tarih.weekday() != i:
                raise ValueError("Muş Alparslan: PDF tarihi haftanın gün sütunuyla eşleşmiyor")
            ust = y
            break
        if tarih is None:
            continue
        hafta_gunu = next((y for _, y, _, t in sutun if t.strip() == GUNLER[i] and y < ust), ust - 20)
        metin = " ".join(t for _, t in _satirlar([o for o in sutun if alt < o[1] < hafta_gunu - 5]) if t)
        if "BAYRAMI" in metin or "TATİL" in metin:
            sonuc[tarih.isoformat()] = {"lunch": {"items": [], "note": "Cumhuriyet Bayramı" if "CUMHURİYET" in metin else "Resmi tatil"}}
            continue
        ogeler, bas = [], 0
        for k in re.finditer(r"\(\s*(\d+)\s*kal\s*\)", metin, re.I):
            ad = metin[bas:k.start()].strip(" .-–/")
            if ad:
                ogeler.append({"name": baslik_yap_serbest(kisaltma_ac(re.sub(r"\s*/\s*", "/", ad))), "kcal": int(k[1])})
            bas = k.end()
        son = metin[bas:].strip(" .-–/")
        if son:
            ogeler.append({"name": baslik_yap_serbest(kisaltma_ac(son))})
        if ogeler:
            sonuc[tarih.isoformat()] = {"lunch": {"items": ogeler, "note": "Ana yemek seçmelidir."}}
    return sonuc


def sayfa_fiyatlar(sayfa):
    for satir in re.findall(r"<tr\b[^>]*>(.*?)</tr>", sayfa, re.S | re.I):
        h = [etiket_temizle(x) for x in re.findall(r"<td\b[^>]*>(.*?)</td>", satir, re.S | re.I)]
        if len(h) == 2 and h[0] == "Öğrenci":
            m = re.fullmatch(r"(\d+(?:[.,]\d+)?)\s*₺", h[1])
            if m:
                return [{"label": "Öğrenci", "tl": float(m[1].replace(",", "."))}]
    return []


class MusAlparslan(Universite):
    id = "alparslan"
    ad = "Muş Alparslan Üniversitesi"
    kisa = "MAUN"
    sehir = "Muş"
    kaynak = SAYFA_URL
    birikimli = True

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self):
        try:
            url = pdf_baglantisi(self.indir(SAYFA_URL).decode("utf-8-sig"))
        except Exception as e:
            raise RuntimeError("Muş Alparslan: haftalık menü sayfası indirilemedi: %s" % e) from e
        if not url:
            raise RuntimeError("Muş Alparslan: güncel YEMEK MENÜSÜ PDF bağlantısı bulunamadı")
        try:
            sonuc = pdf_menu(self.indir(url))
        except Exception as e:
            raise RuntimeError("Muş Alparslan: haftalık yemek PDF'i okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("Muş Alparslan: PDF'te tarihli haftalık menü bulunamadı")
        return sonuc

    def fiyatlar(self):
        try:
            return sayfa_fiyatlar(self.indir(FIYAT_URL).decode("utf-8-sig"))
        except Exception:
            return []
