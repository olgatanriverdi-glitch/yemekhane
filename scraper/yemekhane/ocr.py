"""Tesseract ile (kuruluysa) görsel metin okuma. Kurulu değilse None döner; build bozulmaz."""
import collections
import os
import re
import shutil
import subprocess
import tempfile

from .model import yemek_ogesi


def kullanilabilir() -> bool:
    return shutil.which("tesseract") is not None


def oku(png: bytes, psm: int = 6):
    if not kullanilabilir():
        return None
    with tempfile.TemporaryDirectory() as d:
        yol = os.path.join(d, "g.png")
        with open(yol, "wb") as f:
            f.write(png)
        for dil in ("tur", "eng"):
            r = subprocess.run(["tesseract", yol, "stdout", "-l", dil, "--psm", str(psm)], capture_output=True, text=True)
            if r.returncode == 0 and r.stdout.strip():
                return r.stdout
    return None


class Kelime(collections.namedtuple("Kelime", "metin sol ust gen yuk")):
    """OCR'ın okuduğu bir sözcük ve görüntüdeki kutusu (piksel)."""
    @property
    def sag(self):
        return self.sol + self.gen

    @property
    def mx(self):
        return self.sol + self.gen / 2

    @property
    def my(self):
        return self.ust + self.yuk / 2


def tsv_kelimeler(tsv: str, en_az_guven: int = 20):
    """Tesseract TSV çıktısı -> (görüntü genişliği, yüksekliği, [Kelime]). Güveni düşük/boş sözcükler atlanır."""
    genislik = yukseklik = 0
    kelimeler = []
    for satir in tsv.splitlines()[1:]:
        a = satir.split("\t")
        if len(a) < 12:
            continue
        try:
            seviye, sol, ust, gen, yuk, guven = int(a[0]), int(a[6]), int(a[7]), int(a[8]), int(a[9]), float(a[10])
        except ValueError:
            continue
        if seviye == 1:
            genislik, yukseklik = gen, yuk
        elif seviye == 5 and guven >= en_az_guven and a[11].strip():
            kelimeler.append(Kelime(a[11].strip(), sol, ust, gen, yuk))
    return genislik, yukseklik, kelimeler


def kelimeler(resim: bytes, psm: int = 6, uzanti: str = ".jpg"):
    """Görseli tesseract ile okuyup sözcükleri kutularıyla döndürür: (genişlik, yükseklik, [Kelime]); tesseract yoksa None."""
    if not kullanilabilir():
        return None
    with tempfile.TemporaryDirectory() as d:
        yol = os.path.join(d, "g" + uzanti)
        with open(yol, "wb") as f:
            f.write(resim)
        for dil in ("tur", "eng"):
            r = subprocess.run(["tesseract", yol, "stdout", "-l", dil, "--psm", str(psm), "tsv"], capture_output=True, text=True)
            if r.returncode == 0 and r.stdout.strip():
                return tsv_kelimeler(r.stdout)
    return None


def tarih_ayikla(metin: str):
    """'02.10.2026 Tarihli Yemek Listesi' -> '2026-10-02'"""
    m = re.search(r"(\d{1,2})\s*[.,]\s*(\d{1,2})\s*[.,]\s*(20\d{2})", metin or "")
    if not m:
        return None
    g, a, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
    return "%04d-%02d-%02d" % (y, a, g) if 1 <= g <= 31 and 1 <= a <= 12 else None


def liste_ayikla(metin: str):
    """OCR çıktısı: '► TARHANA ÇORBA (176 kkal)\n\n► IZGARA TAVUK\nBAGET (756\nkkal)' -> öğe listesi.
    Madde işareti (►, >, », •) ile başlayan bloklar birleştirilir."""
    if not metin:
        return []
    bloklar, mevcut = [], None
    for satir in metin.splitlines():
        s = satir.strip()
        if not s:
            continue
        yeni = re.match(r"^[►▶>»•\-–*]+\s*(.*)$", s)
        if yeni:
            if mevcut:
                bloklar.append(mevcut)
            mevcut = yeni.group(1)
        elif mevcut is not None:
            mevcut += " " + s
    if mevcut:
        bloklar.append(mevcut)
    ogeler = []
    for b in bloklar:
        b = re.sub(r"\(\s*(\d+)\s*k\s*kal\s*\)", lambda m: "(%s kkal)" % m.group(1), b, flags=re.I)
        o = yemek_ogesi(b)
        if o["name"]:
            ogeler.append(o)
    return ogeler
