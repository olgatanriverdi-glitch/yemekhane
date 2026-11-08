"""Şırnak SKS: arşivden güncel aylık metin PDF'i ve öğrenci yemek ücreti.

Beş sütunlu takvimde konumlar tarih başlıklarından çıkarılır. Dört yemek
ve tek toplam kalori korunur; seçeneklere göre iki toplam varsa not olur.
İlk doğrulama Ekim 2026'nın 22 tarihi (bir resmî tatil dahil) ile yapıldı.
"""
import html
import re
from datetime import date
from urllib.parse import quote, urljoin

from .. import pdf as pdfmod
from ..model import TR_KUCUK, ay_no, baslik_yap_serbest, bugun_tr, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sks.sirnak.edu.tr/tr/menu/yemek-listesi/4533"


def pdf_baglantisi(sayfa: str, bugun=None, fiyat=False):
    adaylar = []
    bugun = bugun or bugun_tr()
    for url, ad in re.findall(r'<a\b[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>', sayfa, re.S | re.I):
        if not url.lower().endswith(".pdf"):
            continue
        ad = etiket_temizle(ad)
        if fiyat:
            t = re.search(r"\b(\d{4})\s+Yemek Ücretleri\b", ad, re.I)
            donem = (int(t.group(1)), 1) if t else None
        else:
            t = re.search(r"\b(\S+)\s+(\d{4})\s+Yemek Listesi\b", ad, re.I)
            ay = ay_no(t.group(1)) if t else None
            donem = (int(t.group(2)), ay) if ay else None
        if donem:
            adaylar.append((donem, quote(urljoin(SAYFA_URL, html.unescape(url)), safe=":/%?=&")))
    if not adaylar:
        return None
    guncel = [a for a in adaylar if a[0] == (bugun.year, 1 if fiyat else bugun.month)]
    return max(guncel or adaylar)[1]


def yemek_adi(metin: str) -> str:
    metin = re.sub(r"\bp\.\s*kzrt\.?", "patates kızartması", metin, flags=re.I)
    metin = re.sub(r"\bkzrt\.?", "kızartması", metin, flags=re.I)
    metin = re.sub(r"\s*/\s*", "/", re.sub(r"\s+", " ", metin)).strip(" .-")
    return baslik_yap_serbest(kisaltma_ac(metin))


def pdf_menu(veri: bytes) -> dict:
    sonuc = {}
    for sayfa in pdfmod.sayfa_metinleri(veri):
        satirlar = pdfmod.satirlari_birlestir(sayfa, bosluk=1.0)
        basliklar = []
        for metin, x, _, y, _ in satirlar:
            t = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", metin.strip())
            if not t:
                continue
            try:
                basliklar.append((date(int(t.group(3)), int(t.group(2)), int(t.group(1))), x, y))
            except ValueError:
                continue
        if not basliklar:
            continue
        kumeler = []
        for x in sorted(b[1] for b in basliklar):
            if not kumeler or x - kumeler[-1][-1] > 15:
                kumeler.append([x])
            else:
                kumeler[-1].append(x)
        merkezler = [sum(k) / len(k) for k in kumeler]
        for tarih, x, ust in basliklar:
            sutun = min(range(len(merkezler)), key=lambda i: abs(merkezler[i] - x))
            sol = (merkezler[sutun - 1] + merkezler[sutun]) / 2 if sutun else float("-inf")
            sag = (merkezler[sutun] + merkezler[sutun + 1]) / 2 if sutun + 1 < len(merkezler) else float("inf")
            alt = max((y for _, _, y in basliklar if y < ust - 1), default=ust - 70)
            alan = [(m.strip(), y) for m, xx, _, y, _ in satirlar if sol <= xx < sag and alt < y < ust - 1 and m.strip()]
            alan.sort(key=lambda s: -s[1])
            if not alan:
                continue
            if any("tatil" in m.translate(TR_KUCUK).lower() for m, _ in alan):
                ogun = {"items": [], "note": "Resmi tatil"}
            else:
                ogeler, kaloriler = [], []
                for metin, _ in alan:
                    k = re.fullmatch(r"Kalori\s*:\s*(\d+(?:\s*/\s*\d+)*)", metin, re.I)
                    if k:
                        kaloriler = [int(n) for n in re.findall(r"\d+", k.group(1)) if int(n) > 0]
                    else:
                        ogeler.append({"name": yemek_adi(metin)})
                if not ogeler:
                    continue
                ogun = {"items": ogeler}
                if kaloriler and len(set(kaloriler)) == 1:
                    ogun["kcal"] = kaloriler[0]
                elif kaloriler:
                    ogun["note"] = "Ana yemek seçimine göre toplam kalori: %s kcal" % "/".join(map(str, kaloriler))
            anahtar = tarih.isoformat()
            if anahtar in sonuc and sonuc[anahtar] != {"lunch": ogun}:
                raise ValueError("Şırnak: %s için çelişen menüler var" % anahtar)
            sonuc[anahtar] = {"lunch": ogun}
    return sonuc


def pdf_fiyatlar(veri: bytes) -> list:
    for sayfa in pdfmod.sayfa_metinleri(veri):
        satirlar = pdfmod.satirlari_birlestir(sayfa)
        for ad, x, _, y, _ in satirlar:
            if ad.strip() != "Öğrenci":
                continue
            for metin, xx, _, yy, _ in satirlar:
                k = re.fullmatch(r"(\d+(?:[.,]\d+)?)\s*₺", metin.strip())
                if k and xx > x and abs(yy - y) < 1:
                    return [{"label": "Öğrenci", "tl": float(k.group(1).replace(",", "."))}]
    return []


class SirnakUniversitesi(Universite):
    id = "sirnak"
    ad = "Şırnak Üniversitesi"
    kisa = "ŞÜ"
    sehir = "Şırnak"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun
        self.sayfa = None

    def _sayfa(self):
        if self.sayfa is None:
            self.sayfa = self.indir(SAYFA_URL).decode("utf-8-sig")
        return self.sayfa

    def menuler(self) -> dict:
        try:
            url = pdf_baglantisi(self._sayfa(), self.bugun)
        except Exception as e:
            raise RuntimeError("Şırnak: SKS yemek listesi indirilemedi: %s" % e) from e
        if not url:
            raise RuntimeError("Şırnak: aylık yemek PDF bağlantısı bulunamadı")
        try:
            sonuc = pdf_menu(self.indir(url))
        except Exception as e:
            raise RuntimeError("Şırnak: aylık yemek PDF'i okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("Şırnak: PDF'te tarihli menü bulunamadı")
        return sonuc

    def fiyatlar(self) -> list:
        try:
            url = pdf_baglantisi(self._sayfa(), self.bugun, fiyat=True)
            return pdf_fiyatlar(self.indir(url)) if url else []
        except Exception:
            return []
