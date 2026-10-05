"""Ege Üniversitesi (İzmir): aylık menüler sksdb.ege.edu.tr/tr-8417/aylik_yemek_menuleri.html sayfasında öğün başına bir Word (.docx) dosyası olarak yayınlanıyor
('Ekim Ayı Öğle Yemeği Menüsü', 'Ekim Ayı Akşam Yemeği Menüsü', 'Ekim Ayı Vejeteryan Öğle Yemeği Menüsü', ...). Dosyanın içinde haftalık satırlı, Pazartesi-Pazar
sütunlu bir takvim tablosu vardır; her hücre 'gün no, 4 yemek, CAL: 1470 kcal (günün toplamı)' paragraflarıdır. Hafta sonu da servis vardır; tatil günlerinde 'RESMİ TATİL' yazar.
Dosyada ay ve yıl yazmaz: ay bağlantı metninden, yıl ise ayın 1'inin düştüğü sütundan (haftanın günü) bulunur; tutmuyorsa dosya eski yıldan kalmıştır ve atlanır.
Alınanlar: öğle (lunch), akşam (dinner), vejetaryen öğle (vegetarian). Kahvaltı eski .DOC biçiminde; vegan/glutensiz listeler uygulamada karşılıksız olduğu için alınmıyor.
"""
import re
import zipfile
from datetime import date
from io import BytesIO
from urllib.parse import urljoin

from ..model import TR_KUCUK, ay_no, baslik_yap_serbest, bugun_tr, etiket_temizle, kisaltma_ac
from .base import Universite, indir

SAYFA_URL = "https://sksdb.ege.edu.tr/tr-8417/aylik_yemek_menuleri.html"
# Ege'ye özgü kısaltmalar (model.kisaltma_ac'tan sonra, küçük harfe çevrilmiş metne uygulanır)
KISALTMALAR = [(re.compile(p), r) for p, r in (
    (r"\bz\.\s*y\.\s*", "zeytinyağlı "), (r"\bter\.\s*", "tereyağlı "), (r"\bfır\.\s*", "fırın "), (r"\bgar\.\s*", "garnitürlü "),
    (r"\bkar\.\s*", "karışık "), (r"\bfes\.\s*", "fesleğenli "), (r"\bnap\.\s*", "napoliten "),
    (r"\bpür\.\s*", "püreli "), (r"\bkr\.\s*", "kremalı "), (r"\bkıy\.\s*", "kıymalı "), (r"\bp\.\s*üstü\b", "pilav üstü"),
    (r"\bcev\b\.?\s*", "cevizli "), (r"\bk\.\s*mercimek", "kırmızı mercimek"), (r"\by\.\s*mercimek", "yeşil mercimek"))]


def ad_duzelt(ad: str) -> str:
    ad = re.sub(r"\s+", " ", ad.translate(TR_KUCUK).lower()).strip()
    for kalip, yerine in KISALTMALAR:
        ad = kalip.sub(yerine, ad)
    return baslik_yap_serbest(kisaltma_ac(ad))


def baglanti_turu(metin: str):
    """'Ekim Ayı Vejeteryan Öğle Yemeği Menüsü' -> (10, 'vegetarian'); alınmayan listeler için None."""
    m = etiket_temizle(metin).translate(TR_KUCUK).lower()
    ay = re.match(r"(\S+)\s+ayı", m)
    if not ay or not ay_no(ay.group(1)) or "menüsü" not in m:
        return None
    if any(k in m for k in ("vegan", "gluten", "kahvaltı", "salata")):
        return None
    if "vejet" in m and "öğle" in m:
        return ay_no(ay.group(1)), "vegetarian"
    if "vejet" in m:
        return None
    if "öğle" in m:
        return ay_no(ay.group(1)), "lunch"
    if "akşam" in m:
        return ay_no(ay.group(1)), "dinner"
    return None


def sayfa_baglantilari(sayfa: str, taban: str = SAYFA_URL) -> list:
    """[(ay_no, öğün, docx adresi)]; yalnızca .docx dosyaları."""
    sonuc = []
    for href, metin in re.findall(r'<a [^>]*href="([^"]+\.docx)"[^>]*>(.*?)</a>', sayfa, re.S | re.I):
        tur = baglanti_turu(metin)
        if tur:
            sonuc.append((tur[0], tur[1], urljoin(taban, href)))
    return sonuc


def docx_satirlari(veri: bytes) -> list:
    """Word tablosu -> satırlar -> hücreler -> paragraf metinleri: [[['01', 'Z.Y. KURU FASULYE', ...], ...], ...]"""
    xml = zipfile.ZipFile(BytesIO(veri)).read("word/document.xml").decode("utf-8")
    satirlar = []
    for tr in re.findall(r"<w:tr[ >].*?</w:tr>", xml, re.S):
        hucreler = []
        for tc in re.findall(r"<w:tc>.*?</w:tc>", tr, re.S):
            paragraflar = [etiket_temizle("".join(re.findall(r"<w:t[^>]*>(.*?)</w:t>", p, re.S))) for p in re.findall(r"<w:p[ >].*?</w:p>", tc, re.S)]
            hucreler.append([p for p in paragraflar if p])
        satirlar.append(hucreler)
    return satirlar


def docx_menu(veri: bytes, ay: int, tur: str, bugun: date) -> dict:
    """{'2026-10-01': {tur: {'items': [...], 'kcal': 1470}}, ...}; yıl bulunamazsa (dosya başka yıldan kalmışsa) boş.
    Hücreler satır sırasıyla düz bir listeye dizilir (her satır 7 hücre): '01' yazan hücrenin sırası ayın 1'idir, ondan sonraki hücreler ardışık günlerdir
    (böylece günün numarası yazmayan 'RESMİ TATİL' hücreleri de yerini bulur)."""
    hucreler = [h for satir in docx_satirlari(veri) for h in satir]
    bir = next((i for i, h in enumerate(hucreler) if h and h[0].isdigit() and int(h[0]) == 1), None)
    if bir is None:
        return {}
    yil = next((y for y in (bugun.year, bugun.year - 1, bugun.year + 1) if date(y, ay, 1).weekday() == bir % 7), None)
    if yil is None:
        return {}
    sonuc = {}
    for sira in range(bir, len(hucreler)):
        paragraflar = hucreler[sira]
        try:
            tarih = date(yil, ay, sira - bir + 1).isoformat()
        except ValueError:
            break
        if paragraflar and "tatil" in paragraflar[0].translate(TR_KUCUK).lower():
            sonuc[tarih] = {tur: {"items": [], "note": "Resmi tatil"}}
            continue
        ogeler, kcal = [], None
        for p in paragraflar[1:]:
            m = re.search(r"cal\s*:?\s*(\d+)", p, re.I)
            if m:
                kcal = int(m.group(1))
            else:
                ogeler.append({"name": ad_duzelt(p)})
        if ogeler:
            icerik = {"items": ogeler}
            if kcal:
                icerik["kcal"] = kcal
            sonuc[tarih] = {tur: icerik}
    return sonuc


class EgeUniversitesi(Universite):
    id = "ege"
    ad = "Ege Üniversitesi"
    kisa = "EÜ"
    sehir = "İzmir"
    kaynak = SAYFA_URL

    def __init__(self, indirici=indir, bugun=None):
        self.indir = indirici
        self.bugun = bugun

    def menuler(self) -> dict:
        bugun = self.bugun or bugun_tr()
        sonraki = bugun.month % 12 + 1
        sonuc = {}
        for ay, tur, adres in sayfa_baglantilari(self.indir(SAYFA_URL).decode("utf-8", "ignore")):
            if ay not in (bugun.month, sonraki):          # sayfa geçmiş ayları da listeler; yalnızca bu ay ve gelecek ay indirilir
                continue
            try:
                gunler = docx_menu(self.indir(adres), ay, tur, bugun)
            except Exception as e:
                print("UYARI: Ege %s %s dosyası okunamadı: %s" % (ay, tur, e))
                continue
            for tarih, ogun in gunler.items():
                sonuc.setdefault(tarih, {}).update(ogun)
        return sonuc
