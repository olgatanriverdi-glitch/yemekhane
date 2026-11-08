"""Son partilerin tarih başlıklı, beş sütunlu metin PDF yardımcıları."""
import html
import re
from urllib.parse import quote, unquote, urljoin

from .. import pdf
from ..model import TR_KUCUK, etiket_temizle
from ._son_ortak import oge, tarih
from .base import Universite, indir

GUNLER = {"Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"}


def satirlar(parcalar,tolerans=.6):
    gruplar = {}
    for x,y,b,t in parcalar:
        if not t.strip():
            continue
        yy = next((yy for yy in gruplar if abs(yy-y)<tolerans), y)
        gruplar.setdefault(yy, []).append((x,t))
    return [(y, sorted(gruplar[y])) for y in sorted(gruplar, reverse=True)]


def birlestir(parcalar):
    sonuc = ""
    onceki = ""
    for _,t in parcalar:
        if sonuc and not sonuc[-1].isspace() and not t[0].isspace() and len(onceki.strip())>1 and len(t.strip())>1:
            sonuc += " "
        sonuc += t
        onceki = t
    return re.sub(r"\s+", " ", sonuc).strip()


def sutun_menu(veri, sinirlar, alt=0, kalori=False):
    sonuc = {}
    for sayfa in pdf.sayfa_metinleri(veri):
        for sol,sag in zip(sinirlar,sinirlar[1:]):
            rows = satirlar([(x,y,b,t) for x,y,b,t in sayfa if sol<=x<sag and y>alt])
            basliklar = []
            for y,parcalar in rows:
                # Parçalanmış tarihte boşluklar birleştirmeyi bozmamalı.
                t = tarih("".join(t for _,t in parcalar))
                if t:
                    basliklar.append((y,t))
            for n,(ust,t) in enumerate(basliklar):
                alt_y = basliklar[n+1][0] if n+1<len(basliklar) else alt
                items = []
                for y,parcalar in rows:
                    if not alt_y<y<ust:
                        continue
                    metin = birlestir(parcalar)
                    if metin in GUNLER or metin == "Kcal":
                        continue
                    if kalori:
                        adlar = [(x,v) for x,v in parcalar if not v.strip().isdigit()]
                        kaloriler = [int(v.strip()) for _,v in parcalar if v.strip().isdigit()]
                        o = oge(birlestir(adlar))
                        if o and len(kaloriler)==1 and kaloriler[0]>0:
                            o["kcal"] = kaloriler[0]
                    else:
                        o = oge(metin)
                    if o:
                        items.append(o)
                if items:
                    if all("tatil" in o["name"].lower() for o in items):
                        menu = {"items":[],"note":"Resmi tatil"}
                    else:
                        menu = {"items":items}
                    sonuc[t.isoformat()] = {"lunch":menu}
    return sonuc


class BaglantiliPdfUniversitesi(Universite):
    def __init__(self, indirici=indir):
        self.indir = indirici

    def pdf_baglantisi(self, sayfa):
        for u,b in re.findall(r'<a\b[^>]*href=[\'"]([^\'"]+)[\'"][^>]*>(.*?)</a>',sayfa,re.S|re.I):
            ad = (unquote(u)+" "+etiket_temizle(b)).translate(TR_KUCUK).lower()
            if ".pdf" in ad and self.baglanti_uygun(ad):
                return quote(urljoin(self.kaynak,html.unescape(unquote(u))),safe=":/()%")
        return None

    def menuler(self):
        try:
            sayfa = self.indir(self.kaynak).decode("utf-8-sig")
        except Exception as e:
            raise RuntimeError("%s: menü sayfası indirilemedi: %s"%(self.ad,e)) from e
        self.sayfa = sayfa
        url = self.pdf_baglantisi(sayfa)
        if not url:
            raise RuntimeError("%s: yemek PDF bağlantısı bulunamadı"%self.ad)
        try:
            self.pdf = self.indir(url)
            sonuc = self.ayristir(self.pdf)
        except Exception as e:
            raise RuntimeError("%s: yemek PDF'i okunamadı: %s"%(self.ad,e)) from e
        if not sonuc:
            raise RuntimeError("%s: PDF'te tarihli yemek menüsü bulunamadı"%self.ad)
        return sonuc
