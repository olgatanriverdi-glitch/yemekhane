"""Menü fotoğrafı kütüphanesi.

Okul günlük tabldot fotoğrafı yayınlar. Aynı menü (aynı yemek listesi) tekrar gelirse fotoğrafı yeniden çekmeye gerek yoktur:
  data/<id>/photos/lib/<menü_anahtarı>.jpg   : bir menüye ait fotoğraf (kalıcı, silinmez)
  data/<id>/photos/index.json                : {"menus": {anahtar: {...}}, "main": {ana_yemek_anahtarı: menü_anahtarı}, "dates": {tarih: anahtar}}

Eşleştirme: 1) menünün tüm yemekleri aynıysa "tam eşleşme", 2) yalnızca ana yemek aynıysa "benzer" (uygulamada etiketlenir).
Her gün site de kontrol edilir: yeni / farklı fotoğraf gelirse kütüphane güncellenir, eski (bayat) fotoğraf başka bir güne yazılmaz.
"""
import hashlib
import io
import json
import os

from .model import kucuk_tr_ad


def _sha(metin: str, n: int) -> str:
    return hashlib.sha1(metin.encode("utf-8")).hexdigest()[:n]


def menu_anahtari(ogeler) -> str:
    ad = sorted(kucuk_tr_ad(o["name"]) for o in ogeler)
    return _sha("|".join(ad), 12)


def ana_yemek_anahtari(ogeler):
    """Ana yemek: listenin ikinci öğesi (çorba, ANA YEMEK, yan yemek, tatlı). Yoksa None."""
    if len(ogeler) < 3:
        return None
    return _sha(kucuk_tr_ad(ogeler[1]["name"]), 10)


def kucult(foto: bytes) -> bytes:
    try:
        from PIL import Image
        im = Image.open(io.BytesIO(foto)).convert("RGB")
        im.thumbnail((900, 900))
        tampon = io.BytesIO()
        im.save(tampon, "JPEG", quality=80, optimize=True, progressive=True)
        return tampon.getvalue()
    except Exception as e:
        print("UYARI: fotoğraf küçültülemedi, orijinal saklanıyor:", e)
        return foto


class FotoKutuphanesi:
    def __init__(self, klasor: str):
        self.dir = os.path.join(klasor, "photos")
        self.lib = os.path.join(self.dir, "lib")
        self.yol = os.path.join(self.dir, "index.json")
        os.makedirs(self.lib, exist_ok=True)
        self.idx = {"menus": {}, "main": {}, "dates": {}}
        if os.path.exists(self.yol):
            with open(self.yol, encoding="utf-8") as f:
                eski = json.load(f)
            if "menus" in eski:
                self.idx.update(eski)
        self.eski_gun_dosyalari = self._eski_dosyalar()

    def _eski_dosyalar(self):
        """Eski düzen: photos/<tarih>.jpg. Menü listesi bilinince kütüphaneye taşınır."""
        return {f[:-4]: os.path.join(self.dir, f) for f in os.listdir(self.dir) if f.endswith(".jpg") and len(f) == 14}

    def tasi(self, menuler):
        """Eski tarih adlı fotoğrafları, o günün öğle menüsü biliniyorsa kütüphaneye taşır."""
        for tarih, yol in list(self.eski_gun_dosyalari.items()):
            ogeler = menuler.get(tarih, {}).get("lunch", {}).get("items")
            if ogeler:
                with open(yol, "rb") as f:
                    self._yaz(menu_anahtari(ogeler), ogeler, f.read(), tarih, hazir=True)
                self.idx["dates"][tarih] = menu_anahtari(ogeler)
            os.remove(yol)

    def _yaz(self, anahtar, ogeler, foto, tarih, hazir=False):
        veri = foto if hazir else kucult(foto)
        with open(os.path.join(self.lib, anahtar + ".jpg"), "wb") as f:
            f.write(veri)
        self.idx["menus"][anahtar] = {"hash": hashlib.sha1(foto).hexdigest(), "added": tarih, "items": [o["name"] for o in ogeler]}
        ana = ana_yemek_anahtari(ogeler)
        if ana:
            self.idx["main"][ana] = anahtar

    def bugun_isle(self, tarih, ogeler, foto):
        """Sitedeki günlük fotoğrafı kütüphaneyle karşılaştırır. Döndürür: durum metni."""
        if not foto or not ogeler:
            return "foto yok" if not foto else "bugünün listesi bilinmiyor"
        anahtar = menu_anahtari(ogeler)
        h = hashlib.sha1(foto).hexdigest()
        # bayat: aynı fotoğraf başka bir menüye ait olarak kayıtlıysa site henüz yenilememiştir
        for k, m in self.idx["menus"].items():
            if m["hash"] == h and k != anahtar:
                return "bayat (site fotoğrafı henüz yenilenmemiş, %s menüsüne ait)" % m["added"]
        mevcut = self.idx["menus"].get(anahtar)
        if mevcut and mevcut["hash"] == h:
            self.idx["dates"][tarih] = anahtar
            return "kontrol: kütüphanedekiyle aynı"
        self._yaz(anahtar, ogeler, foto, tarih)
        self.idx["dates"][tarih] = anahtar
        return "kontrol: kütüphane güncellendi" if mevcut else "yeni fotoğraf kaydedildi"

    def eslestir(self, tarih, ogeler):
        """Bir günün öğle menüsü için fotoğraf: (dosya, yaklaşık_mı) ya da (None, False)."""
        if not ogeler:
            return None, False
        anahtar = self.idx["dates"].get(tarih)
        if not anahtar or anahtar != menu_anahtari(ogeler):
            anahtar = menu_anahtari(ogeler)
        if anahtar in self.idx["menus"] and os.path.exists(os.path.join(self.lib, anahtar + ".jpg")):
            return "photos/lib/%s.jpg" % anahtar, False
        ana = ana_yemek_anahtari(ogeler)
        k = self.idx["main"].get(ana) if ana else None
        if k and os.path.exists(os.path.join(self.lib, k + ".jpg")):
            return "photos/lib/%s.jpg" % k, True
        return None, False

    def kaydet(self, sinir):
        # tarih eşlemelerinden eskileri at; fotoğraf dosyaları kalıcıdır
        self.idx["dates"] = {t: k for t, k in self.idx["dates"].items() if t >= sinir}
        os.makedirs(self.dir, exist_ok=True)
        with open(self.yol, "w", encoding="utf-8") as f:
            json.dump(self.idx, f, ensure_ascii=False, indent=1, sort_keys=True)
