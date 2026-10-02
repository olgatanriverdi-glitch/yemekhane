"""Tesseract ile (kuruluysa) görsel metin okuma. Kurulu değilse None döner; build bozulmaz."""
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
