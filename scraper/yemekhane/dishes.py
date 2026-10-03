"""Yemek başına küçük örnek fotoğraf kütüphanesi (tüm üniversiteler ortak kullanır).

Her yemeğin adıyla Wikimedia Commons'ta telifi serbest (Creative Commons) bir görsel aranır. Bulunan görsel küçük kare JPEG
olarak saklanır; aynı adlı yemek bir daha aranmaz, bulunamayan 14 gün sonra yeniden denenir.
  data/dishes/<anahtar>.jpg    küçük fotoğraf (kalıcı)
  data/dishes/index.json       {"dishes": {anahtar: {...kaynak, yazar, lisans...}}, "miss": {anahtar: "tarih"}}
Görseller örnektir: yemeğin okuldaki hali birebir aynı olmayabilir. Lisans gereği kaynak/yazar index.json'da tutulur.
"""
import hashlib
import io
import json
import os
import re
import time
import urllib.parse
import urllib.request
from datetime import date, timedelta

from .model import kucuk_tr_ad

UA = "UniYemek/1.0 (ogrenci projesi; https://github.com/olgatanriverdi-glitch/yemekhane)"
BOYUT = 320                 # kare kenar (piksel)
BASARISIZ_BEKLE = 14        # bulunamayan yemeği kaç gün sonra tekrar ara
RUN_LIMIT = int(os.environ.get("YEMEK_ARAMA_LIMIT", 60))     # tek çalıştırmada en fazla yeni arama (kalanı sonraki turda)
ATLA = re.compile(r"^\d|bayram|tatil|kapal", re.I)       # '29 Ekim Cumhuriyet Bayramı' gibi satırlar yemek değildir
GENEL = {"ve", "ile", "usulü", "yemeği", "yemek", "soslu", "etli", "etsiz", "tavuklu", "kıymalı"}
KOTU_DOSYA = re.compile(r"\.(pdf|svg|gif|tiff?|webm|ogv|djvu)$|logo|flag|map\b|harita|poster|stamp", re.I)

_FOLD = str.maketrans("çğıöşüâîûÇĞİÖŞÜ", "cgiosuaiuCGIOSU")


def katla(metin: str) -> str:
    return metin.translate(_FOLD).lower()


def anahtar(ad: str) -> str:
    return hashlib.sha1(kucuk_tr_ad(ad).encode("utf-8")).hexdigest()[:10]


# Çok genel / belirsiz yemekler için elle seçilmiş arama metinleri
TAKMA = {
    "meyve": ["Meyve tabağı", "Fruit platter"],
    "ayran": ["Ayran"],
    "yoğurt": ["Yoğurt", "Turkish yogurt"],
    "turşu": ["Turşu"],
    "salata": ["Çoban salata"],
    "red velvet": ["Red velvet cake"],
    "trileçe": ["Tres leches cake", "Trileçe tatlısı"],
    "tiramisu": ["Tiramisu"],
    "tramisu": ["Tiramisu"],
}
# Adında şu geçen yemekler için (daha özel bir eşleşme yoksa) bu aramalar da denenir
ICEREN = [
    ("makarna", ["Makarna", "Spaghetti"]),
    ("spagetti", ["Spaghetti"]),
    ("pirinç pilavı", ["Pirinç pilavı", "Rice pilaf"]),
    ("muhallebi", ["Muhallebi"]),
    ("brownie", ["Chocolate brownie"]),
    ("mantar çorba", ["Mushroom soup"]),
    ("mısır çorba", ["Corn soup"]),
    ("sebze çorba", ["Vegetable soup"]),
    ("ezogelin", ["Ezogelin soup"]),
    ("tavuk fajita", ["Chicken fajita"]),
    ("brokoli", ["Broccoli"]),
]
# Sorguda geçen genel sözcüklerin başlıkta İngilizce karşılığı da kabul edilir
ES = {"çorba": ("corba", "soup", "chorba"), "salata": ("salad", "salat"), "pilav": ("pilaf", "pilav", "rice"),
      "köfte": ("kofte", "meatball"), "kebap": ("kebab", "kebap"), "kebabı": ("kebab", "kebap"), "tatlı": ("dessert", "sweet"),
      "tavuk": ("chicken", "tavuk"), "makarna": ("makarna", "spaghetti", "penne"), "börek": ("borek", "pie", "pastry"),
      "pasta": ("cake",)}


def anlamli_sozcukler(ad: str):
    return [k for k in ad.split() if kucuk_tr_ad(k) not in GENEL and len(k) > 1]


def sorgular(ad: str):
    """Aramada denenecek metinler, en özelinden en genele: 'Fesleğenli Domates Çorba' -> [tam ad, 'Domates Çorba'].
    Tek sözcüğe ('Tavuk') indirgemeyiz: alakasız ama benzer bir yemeğin fotoğrafı yanlış olur, fotoğraf olmaması daha iyi."""
    ilk = re.sub(r"\(.*?\)", "", ad.split("/")[0]).strip()
    takma = TAKMA.get(kucuk_tr_ad(ilk))
    if takma:
        return takma
    sonuc = [ilk]
    ekler = [q for anahtar_, qs in ICEREN if anahtar_ in kucuk_tr_ad(ilk) for q in qs]
    anlamli = anlamli_sozcukler(ilk)
    if anlamli and anlamli != ilk.split():
        sonuc.append(" ".join(anlamli))
    if len(anlamli) > 2:
        sonuc.append(" ".join(anlamli[-2:]))
    sonuc += ekler
    goruldu, cikti = set(), []
    for s in sonuc:
        if s and s.lower() not in goruldu:
            goruldu.add(s.lower())
            cikti.append(s)
    return cikti


def ilgili_mi(sorgu: str, baslik: str) -> bool:
    """Sonucun adı/açıklaması, sorgudaki anlamlı sözcüklerin HEPSİNİ (ilk 5 harf ya da İngilizce karşılığı) içeriyor mu.
    'Mantar Çorba' için 'Riblja Corba' gibi sadece 'çorba' içeren alakasız sonuçlar böylece elenir."""
    b = katla(baslik)
    sozcukler = anlamli_sozcukler(sorgu)
    if not sozcukler:
        return False
    for k in sozcukler:
        adaylar = (katla(k)[:5],) + tuple(ES.get(kucuk_tr_ad(k), ()))
        if not any(x in b for x in adaylar):
            return False
    return True


def puan(sorgu: str, metin: str) -> int:
    """Sorgudaki TÜM sözcüklerden (etli, soslu gibi sıfatlar dahil) kaçının kökü metinde geçiyor: en iyi adayı seçmek için."""
    b = katla(metin)
    return sum(1 for k in sorgu.split() if len(k) > 1 and katla(k)[:5] in b)


def getir(url: str, zaman_asimi: int = 25) -> bytes:
    istek = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(istek, timeout=zaman_asimi) as y:
        return y.read()


def _json(url: str, indir):
    return json.loads(indir(url).decode("utf-8"))


def commons_ara(sorgu: str, indir=getir):
    """Wikimedia Commons: [{'url','baslik','yazar','lisans','sayfa','kaynak'}]"""
    prm = {"action": "query", "generator": "search", "gsrnamespace": 6, "gsrlimit": 8, "gsrsearch": sorgu,
           "prop": "imageinfo", "iiprop": "url|mime|extmetadata", "iiurlwidth": BOYUT * 2, "format": "json"}
    veri = _json("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(prm), indir)
    sonuc = []
    for sayfa in sorted(veri.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 0)):
        bilgi = (sayfa.get("imageinfo") or [{}])[0]
        if bilgi.get("mime") not in ("image/jpeg", "image/png") or KOTU_DOSYA.search(sayfa["title"]):
            continue
        meta = bilgi.get("extmetadata", {})
        aciklama = re.sub(r"<[^>]+>", "", meta.get("ImageDescription", {}).get("value", ""))
        sonuc.append({"url": bilgi.get("thumburl") or bilgi["url"], "baslik": sayfa["title"][5:], "aciklama": aciklama,
                      "yazar": re.sub(r"<[^>]+>", "", meta.get("Artist", {}).get("value", "")).strip()[:80],
                      "lisans": meta.get("LicenseShortName", {}).get("value", ""), "sayfa": bilgi.get("descriptionurl", ""),
                      "kaynak": "Wikimedia Commons"})
    return sonuc


SAGLAYICILAR = [commons_ara]     # Openverse denendi: alakasız sonuç çok, kullanılmıyor


def kare_jpeg(veri: bytes) -> bytes:
    from PIL import Image
    im = Image.open(io.BytesIO(veri)).convert("RGB")
    w, h = im.size
    k = min(w, h)
    im = im.crop(((w - k) // 2, (h - k) // 2, (w - k) // 2 + k, (h - k) // 2 + k)).resize((BOYUT, BOYUT))
    t = io.BytesIO()
    im.save(t, "JPEG", quality=72, optimize=True, progressive=True)
    return t.getvalue()


def foto_bul(ad: str, indir=getir, saglayicilar=None, bekle=0.4):
    """Yemek adı için (jpeg_bayt, kaynak_bilgisi) ya da None."""
    for sira, sorgu in enumerate(sorgular(ad)):
        for ara in (saglayicilar or SAGLAYICILAR):
            try:
                adaylar = ara(sorgu, indir)
            except Exception as e:
                print("UYARI: %s aramasında hata (%s): %s" % (ara.__name__, sorgu, e))
                continue
            finally:
                time.sleep(bekle)
            uygun = []
            for a in adaylar:
                metin = a["baslik"] + (" " + a.get("aciklama", "") if sira == 0 else "")      # genelleşmiş sorguda yalnız başlığa güven
                if ilgili_mi(sorgu, metin):
                    uygun.append((-puan(sorgu, a["baslik"]), len(uygun), a))                 # çok sözcük eşleşen önce; eşitse arama sırası
            for _, _, a in sorted(uygun, key=lambda x: x[:2]):
                try:
                    return kare_jpeg(indir(a["url"])), {k: a[k] for k in ("kaynak", "baslik", "yazar", "lisans", "sayfa")} | {"sorgu": sorgu}
                except Exception as e:
                    print("UYARI: görsel indirilemedi (%s): %s" % (a["url"], e))
    return None


class YemekFotolari:
    def __init__(self, klasor: str, indir=getir, saglayicilar=None, bekle=0.4, bugun=None):
        self.dir = klasor
        self.yol = os.path.join(klasor, "index.json")
        self.indir, self.saglayicilar, self.bekle = indir, saglayicilar, bekle
        self.bugun = bugun or date.today()
        self.idx = {"dishes": {}, "miss": {}}
        if os.path.exists(self.yol):
            with open(self.yol, encoding="utf-8") as f:
                self.idx.update(json.load(f))
        self.aranan = 0

    def dosya(self, ad: str):
        """Yemeğin fotoğraf yolu ('dishes/<anahtar>.jpg') ya da None; yoksa aramayı dener (limit dahilinde)."""
        if ATLA.search(ad.strip()):
            return None
        k = anahtar(ad)
        yol = os.path.join(self.dir, k + ".jpg")
        if k in self.idx["dishes"] and os.path.exists(yol):
            return "dishes/%s.jpg" % k
        son = self.idx["miss"].get(k)
        if son and date.fromisoformat(son) > self.bugun - timedelta(days=BASARISIZ_BEKLE):
            return None
        if self.aranan >= RUN_LIMIT:
            return None
        self.aranan += 1
        bulunan = foto_bul(ad, self.indir, self.saglayicilar, self.bekle)
        if not bulunan:
            self.idx["miss"][k] = self.bugun.isoformat()
            print("  fotoğraf yok: %s" % ad)
            return None
        os.makedirs(self.dir, exist_ok=True)
        with open(yol, "wb") as f:
            f.write(bulunan[0])
        self.idx["dishes"][k] = dict(bulunan[1], name=ad)
        self.idx["miss"].pop(k, None)
        print("  fotoğraf bulundu: %-32s <- %s (%s)" % (ad, bulunan[1]["baslik"][:40], bulunan[1]["kaynak"]))
        return "dishes/%s.jpg" % k

    def menulere_ekle(self, menuler: dict):
        """Menüdeki her yemek öğesine 'img' ekler (okulun kendi fotoğrafı olan öğle menüleri dahil, yemek başına)."""
        for gun in menuler.values():
            for ogun in gun.values():
                for oge in ogun.get("items", []):
                    yol = self.dosya(oge["name"])
                    if yol:
                        oge["img"] = yol

    def kaydet(self):
        os.makedirs(self.dir, exist_ok=True)
        with open(self.yol, "w", encoding="utf-8") as f:
            json.dump(self.idx, f, ensure_ascii=False, indent=1, sort_keys=True)
