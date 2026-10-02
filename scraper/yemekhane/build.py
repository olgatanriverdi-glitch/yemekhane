"""Tüm üniversiteleri çalıştırır ve statik JSON dosyalarını yazar:
   data/index.json                 -> üniversite listesi (uygulama ilk bunu okur)
   data/<id>/menu.json             -> o üniversitenin tarih bazlı menüleri
Kullanım:  python -m yemekhane.build [--cikti ../data]
"""
import argparse
import hashlib
import io
import json
import os
import sys
from datetime import datetime, timedelta, timezone

from .universities import KAYITLI

GUN_SAKLA = 45     # bugünden bu kadar gün öncesine kadar menü tutulur


def yaz(yol, veri):
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    with open(yol, "w", encoding="utf-8") as f:
        json.dump(veri, f, ensure_ascii=False, indent=1, sort_keys=True)


def foto_kaydet(klasor: str, tarih: str, foto: bytes, sinir: str):
    """Günlük fotoğrafı küçültüp data/<id>/photos/<tarih>.jpg olarak saklar. Aynı fotoğraf başka bir güne aitse (site henüz
    yenilememişse) bugüne yazılmaz. Döndürür: {tarih: dosya_adı} (sınırdan yeni olanlar)."""
    fdir = os.path.join(klasor, "photos")
    os.makedirs(fdir, exist_ok=True)
    idx_yol = os.path.join(fdir, "index.json")
    idx = json.load(open(idx_yol, encoding="utf-8")) if os.path.exists(idx_yol) else {}
    if foto:
        h = hashlib.sha1(foto).hexdigest()
        baska_gun = [t for t, v in idx.items() if v == h and t != tarih]
        if baska_gun:
            print("BİLGİ: fotoğraf %s günündekiyle aynı, %s için kaydedilmedi" % (max(baska_gun), tarih))
        elif idx.get(tarih) != h:
            try:
                from PIL import Image
                im = Image.open(io.BytesIO(foto)).convert("RGB")
                im.thumbnail((900, 900))
                tampon = io.BytesIO()
                im.save(tampon, "JPEG", quality=80, optimize=True, progressive=True)
                veri = tampon.getvalue()
            except Exception as e:
                print("UYARI: fotoğraf küçültülemedi, orijinal saklanıyor:", e)
                veri = foto
            with open(os.path.join(fdir, tarih + ".jpg"), "wb") as f:
                f.write(veri)
            idx[tarih] = h
    for t in [t for t in idx if t < sinir]:                     # eskileri temizle
        idx.pop(t)
        try:
            os.remove(os.path.join(fdir, t + ".jpg"))
        except OSError:
            pass
    yaz(idx_yol, idx)
    return {t: "photos/%s.jpg" % t for t in idx if os.path.exists(os.path.join(fdir, t + ".jpg"))}


def gunluk_isle(u, klasor, menuler, simdi, sinir):
    g = u.gunluk()
    fotolar = {}
    if g:
        tarih = g.get("date") or simdi.date().isoformat()
        ogun = g.get("meal", "lunch")
        if g.get("items") and not menuler.get(tarih, {}).get(ogun, {}).get("items"):
            gun = {"items": g["items"]}
            if all("kcal" in o for o in g["items"]):
                gun["kcal"] = sum(o["kcal"] for o in g["items"])
            menuler.setdefault(tarih, {})[ogun] = gun
            print("%-10s %s günlük liste görselden okundu (%d öğe)" % (u.id, tarih, len(g["items"])))
        fotolar = foto_kaydet(klasor, tarih, g.get("photo"), sinir)
    else:
        fdir = os.path.join(klasor, "photos", "index.json")
        if os.path.exists(fdir):
            fotolar = foto_kaydet(klasor, "0000-00-00", None, sinir)
    for t, dosya in fotolar.items():
        menuler.setdefault(t, {}).setdefault("lunch", {"items": []})["photo"] = dosya


def calistir(cikti: str, uniler=None) -> int:
    simdi = datetime.now(timezone(timedelta(hours=3)))        # Türkiye saati
    sinir = (simdi - timedelta(days=GUN_SAKLA)).date().isoformat()
    liste = []
    hata = 0
    for u in (uniler or KAYITLI):
        try:
            menuler = {t: g for t, g in u.menuler().items() if t >= sinir}
            if not menuler:
                raise RuntimeError("hiç menü bulunamadı")
            gunluk_isle(u, os.path.join(cikti, u.id), menuler, simdi, sinir)
            fiyatlar = u.fiyatlar()
            yaz(os.path.join(cikti, u.id, "menu.json"), {"university": u.id, "updated": simdi.isoformat(timespec="seconds"), "days": menuler})
            turler = sorted({tur for g in menuler.values() for tur in g})
            liste.append({"id": u.id, "name": u.ad, "short": u.kisa, "city": u.sehir, "source": u.kaynak, "meals": turler,
                          "prices": fiyatlar, "firstDay": min(menuler), "lastDay": max(menuler)})
            print("%-10s %d gün (%s .. %s) türler=%s" % (u.id, len(menuler), min(menuler), max(menuler), turler))
        except Exception as e:
            hata += 1
            print("HATA: %s güncellenemedi: %s" % (u.id, e), file=sys.stderr)
    if liste:
        yaz(os.path.join(cikti, "index.json"), {"version": 1, "updated": simdi.isoformat(timespec="seconds"), "universities": liste})
    return 1 if hata and not liste else 0


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--cikti", default=os.path.join(os.path.dirname(__file__), "..", "..", "data"))
    a = p.parse_args()
    sys.exit(calistir(os.path.abspath(a.cikti)))
