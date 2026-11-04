"""Bayburt: herkese açık yemek sayfasının aylık PDF bağlantısını veren JSON.

Günlük API hafta sonu boş olsa da getmonltyinfo/tr aylık dosyayı verir.
PDF takvimindeki tarih başlıkları ve beş sütun kullanılır; kalori olmayan
Ekim 2026 PDF'ine günlük API'den farklı bir günün kalorisi taşınmaz.
"""
import json
import re
from datetime import date
from urllib.parse import quote, unquote, urljoin

from .. import pdf as pdfmod
from ..model import TR_KUCUK, ay_no, baslik_yap_serbest, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://bayburt.edu.tr/tr/food-menu"
API_URL = "https://apiportal.bayburt.edu.tr/api/web/other/yemekmenu/getmonltyinfo/tr"
DOSYA_KOKU = "https://apifile.bayburt.edu.tr/file/portal/"


def pdf_baglantisi(veri):
    if not isinstance(veri, dict) or veri.get("status") is not True:
        return None
    yanit = veri.get("response")
    if not isinstance(yanit, dict) or yanit.get("durum") is not True:
        return None
    dosya = yanit.get("upload_object") or {}
    yol = dosya.get("filepath") if isinstance(dosya, dict) else None
    if not isinstance(yol, str) or not unquote(yol).lower().endswith(".pdf"):
        return None
    return quote(urljoin(DOSYA_KOKU, unquote(yol).lstrip("/")), safe=":/()")


def yemek_adi(metin):
    metin = re.sub(r"\be\.\s*kuru\s+fasulye\b", "etli kuru fasulye", metin, flags=re.I)
    metin = re.sub(r"\btel\s+şeh\.\s*çorbası\b", "tel şehriye çorbası", metin, flags=re.I)
    for kalip, yeni in ((r"\bkr\.\s*", "kremalı "), (r"\bgar\.\s*", "garnitürlü "),
                        (r"\bbeş\.\s*", "beşamel "), (r"\bşeh\.\s*", "şehriyeli "),
                        (r"\byoğ\.(?=\)|\s|$)", "yoğurtlu"), (r"\bkar\.\s*", "karışık "),
                        (r"\bkadınbudu k\.", "kadınbudu köfte")):
        metin = re.sub(kalip, yeni, metin, flags=re.I)
    metin = re.sub(r"\s*\(\s*", " (", metin)
    metin = re.sub(r"\s*/\s*", "/", metin)
    return baslik_yap_serbest(kisaltma_ac(re.sub(r"\s+", " ", metin).strip(" .-")))


def pdf_menu(veri):
    sonuc = {}
    for sayfa in pdfmod.sayfa_metinleri(veri):
        basliklar = []
        for x, y, _, metin in sayfa:
            m = re.fullmatch(r"(\d{1,2})\s+(\S+)\s+(\d{4})\s+\S+", metin.strip())
            ay = ay_no(m[2]) if m else None
            if ay:
                try:
                    basliklar.append((date(int(m[3]), ay, int(m[1])), x, y))
                except ValueError:
                    continue
        if not basliklar:
            continue
        kumeler = []
        for x in sorted(x for _, x, _ in basliklar):
            if not kumeler or x - kumeler[-1][-1] > 10:
                kumeler.append([x])
            else:
                kumeler[-1].append(x)
        sutunlar = [sum(k) / len(k) for k in kumeler]

        def sutun(x):
            return min(range(len(sutunlar)), key=lambda i: abs(sutunlar[i] - x))

        for tarih, x, ust in basliklar:
            sira = sutun(x)
            altlar = [y for _, xx, y in basliklar if sutun(xx) == sira and y < ust - 1]
            alt = max(altlar) if altlar else 100  # son tablonun altındaki imzalar alınmaz
            alan = [(y, t.strip()) for xx, y, b, t in sayfa if sutun(xx) == sira and alt < y < ust - 1 and b < 9 and t.strip()]
            adlar = [t for _, t in sorted(alan, key=lambda o: -o[0])]
            if not adlar:
                continue
            if all("tatil" in t.translate(TR_KUCUK).lower() for t in adlar):
                ogun = {"items": [], "note": "Resmi tatil"}
            else:
                ogun = {"items": [{"name": yemek_adi(t)} for t in adlar]}
            sonuc[tarih.isoformat()] = {"lunch": ogun}
    return sonuc


class BayburtUniversitesi(Universite):
    id = "bayburt"
    ad = "Bayburt Üniversitesi"
    kisa = "BAYÜ"
    sehir = "Bayburt"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self):
        try:
            url = pdf_baglantisi(json.loads(self.indir(API_URL).decode("utf-8-sig")))
        except Exception as e:
            raise RuntimeError("Bayburt: aylık yemek dosyası bilgisi okunamadı: %s" % e) from e
        if not url:
            raise RuntimeError("Bayburt: erişilebilir aylık yemek PDF bağlantısı bulunamadı")
        try:
            sonuc = pdf_menu(self.indir(url))
        except Exception as e:
            raise RuntimeError("Bayburt: aylık yemek PDF'i okunamadı: %s" % e) from e
        if not sonuc:
            raise RuntimeError("Bayburt: PDF'te tarihli yemek tablosu bulunamadı")
        return sonuc
