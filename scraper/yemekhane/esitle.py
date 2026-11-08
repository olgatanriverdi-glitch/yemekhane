"""Robotun JSON çıktılarını Flutter'ın çevrimdışı paketine eşitler (JPEG kopyalamaz).

Kullanım: cd scraper && python -m yemekhane.esitle [--veri ../data] [--app ../app]
"""
import argparse
import json
import re
from pathlib import Path

from .depolama import birlikte_yayinla, json_verisi


def asset_klasorleri(pubspec):
    """Standart flutter/assets blok listesindeki klasör yolları; ek YAML bağımlılığı gerekmez."""
    flutter = False
    assets_girinti = None
    sonuc = set()
    for ham in pubspec.splitlines():
        satir = re.sub(r"\s+#.*$", "", ham).rstrip()
        if not satir.strip() or satir.lstrip().startswith("#"):
            continue
        girinti = len(satir) - len(satir.lstrip())
        if girinti == 0:
            flutter = satir == "flutter:"
            assets_girinti = None
            continue
        if not flutter:
            continue
        if satir.strip() == "assets:":
            assets_girinti = girinti
            continue
        if assets_girinti is None:
            continue
        if girinti <= assets_girinti:
            assets_girinti = None
            continue
        deger = satir.strip()
        if deger.startswith("- "):
            deger = deger[2:].strip().strip("\"'")
            if deger.endswith("/"):
                sonuc.add(deger)
    return sonuc


def esitle(veri, app):
    veri, app = Path(veri), Path(app)
    hedef = app / "assets/data"
    klasorler = asset_klasorleri((app / "pubspec.yaml").read_text(encoding="utf-8"))
    index = json.loads((veri / "index.json").read_text(encoding="utf-8"))
    kayitlar, dosyalar = [], []
    gorulen = set()
    for okul in index["universities"]:
        kimlik = okul["id"]
        if not isinstance(kimlik, str) or not re.fullmatch(r"[a-z0-9_-]+", kimlik) or kimlik in gorulen:
            raise ValueError("Geçersiz / yinelenen okul kimliği: %r" % kimlik)
        gorulen.add(kimlik)
        if "assets/data/%s/" % kimlik not in klasorler:
            print("::warning::%s eşitlenmedi: okul klasörü app/pubspec.yaml assets listesinde yok; paket indeksine alınmadı." % kimlik)
            continue
        # Zorunlu menü yok/bozuksa hiçbir hedef değişmesin; yarım paket yayımlanmasın.
        menu = (veri / kimlik / "menu.json").read_bytes()
        json.loads(menu)
        dosyalar.append((hedef / kimlik / "menu.json", menu))
        foto = veri / kimlik / "photos/index.json"
        if foto.is_file():
            icerik = foto.read_bytes()
            json.loads(icerik)
            dosyalar.append((hedef / kimlik / "photos/index.json", icerik))
        kayitlar.append(okul)
    index["universities"] = kayitlar
    dosyalar.append((hedef / "index.json", json_verisi(index)))
    birlikte_yayinla(dosyalar)
    print("Paket verisi eşitlendi: %d okul, %d JSON dosyası; %d okul atlandı." %
          (len(kayitlar), len(dosyalar), len(gorulen) - len(kayitlar)))
    return len(kayitlar)


if __name__ == "__main__":
    kok = Path(__file__).resolve().parents[2]
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--veri", default=str(kok / "data"))
    p.add_argument("--app", default=str(kok / "app"))
    a = p.parse_args()
    esitle(a.veri, a.app)
