"""Muğla Sıtkı Koçman: /tr/yemek aylık HTML listesi, tek öğün (öğle).
Her satırda tarih, dört yemek ve toplam kalori sütunu vardır. Kaynağın boş
kalorileri ve '0 cal' toplamı bilinmiyor sayılır; sıfır kalori yayınlanmaz.
"""
import re
from datetime import date

from ..model import ay_no, baslik_yap_serbest, etiket_temizle, gun_icerigi, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://www.mu.edu.tr/tr/yemek"


def yemek_adi(metin: str) -> str:
    for kalip, yerine in (
        (r"\bmor\.\s*lah\.\s*", "mor lahana "),
        (r"\ber\.\s*yeş\.\s*merc\.\s*", "erişteli yeşil mercimek "),
        (r"\b(tel|arpa)\.\s*şehr?\.\s*", r"\1 şehriye "),
        (r"\bpil\.\s*ü\.\s*", "pilav üstü "),
        (r"\bkarnabahar\s+k\.", "karnabahar kızartması"),
        (r"\bkız\.", "kızartması"),
        (r"\byoğ\b\.?", "yoğurt"),
        (r"\byeş\b\.?", "yeşillik"),
        (r"\bcev\.\s*", "cevizli "),
    ):
        metin = re.sub(kalip, yerine, metin, flags=re.I)
    return baslik_yap_serbest(kisaltma_ac(metin.strip(" .-")))


def sayfa_menu(sayfa: str) -> dict:
    liste = re.search(r"<ul\b[^>]*class=['\"][^'\"]*\byemekList\b[^'\"]*['\"][^>]*>(.*?)</ul>", sayfa, re.S)
    if not liste:
        return {}
    sonuc = {}
    for satir in re.findall(r"<li\b[^>]*>(.*?)</li>", liste.group(1), re.S):
        hucreler = re.findall(r"<div\b[^>]*class=['\"]col-md-2['\"][^>]*>(.*?)</div>", satir, re.S)
        if len(hucreler) < 3:
            continue
        t = re.search(r"class=['\"]trh['\"]>\s*(\d{1,2})\s+(\S+)\s*</span>", hucreler[0])
        y = re.search(r"class=['\"]year['\"]>\s*(\d{4})\s*</span>", hucreler[0])
        if not t or not y or not ay_no(t.group(2)):
            continue
        try:
            tarih = date(int(y.group(1)), ay_no(t.group(2)), int(t.group(1)))
        except ValueError:
            continue
        ogeler = []
        for hucre in hucreler[1:-1]:
            ad = yemek_adi(etiket_temizle(re.split(r"<br\s*/?>", hucre)[0]))
            if not ad:
                continue
            oge = {"name": ad}
            k = re.search(r">\s*(\d+)\s*cal\s*</span>", hucre, re.I)
            if k and int(k.group(1)) > 0:
                oge["kcal"] = int(k.group(1))
            ogeler.append(oge)
        if not ogeler:
            continue
        if all("tatil" in o["name"].lower() for o in ogeler):
            ogun = {"items": [], "note": "Resmi tatil"}
        else:
            ogun = gun_icerigi(ogeler)
            k = re.search(r">\s*(\d+)\s*cal\s*</span>", hucreler[-1], re.I)
            if k and int(k.group(1)) > 0:
                ogun["kcal"] = int(k.group(1))
        sonuc[tarih.isoformat()] = {"lunch": ogun}
    return sonuc


class MuglaSitkiKocman(Universite):
    id = "mugla"
    ad = "Muğla Sıtkı Koçman Üniversitesi"
    kisa = "MSKÜ"
    sehir = "Muğla"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir):
        self.indir = indirici

    def menuler(self) -> dict:
        try:
            sayfa = self.indir(SAYFA_URL).decode("utf-8")
        except Exception as e:
            raise RuntimeError("Muğla: yemek listesi indirilemedi: %s" % e) from e
        sonuc = sayfa_menu(sayfa)
        if not sonuc:
            raise RuntimeError("Muğla: aylık yemek listesinde tarihli menü bulunamadı")
        return sonuc
