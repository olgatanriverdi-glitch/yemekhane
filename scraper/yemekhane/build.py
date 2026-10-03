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
# Okul yayınlamıyorsa gösterilecek tipik saatler ('genelde' etiketiyle, kesin bilgi gibi sunulmaz)
VARSAYILAN_SAATLER = {"lunch": "11:00–14:00", "dinner": "17:00–19:00"}


def saat_bilgisi(u, turler) -> dict:
    """{'lunch': {'t': '11:30–14:00', 'approx': False}, ...}: okulun saati varsa kesin, yoksa tipik saat 'approx' ile."""
    okul = u.saatler()
    sonuc = {}
    for tur in turler:
        if tur in okul:
            sonuc[tur] = {"t": okul[tur], "approx": False}
        elif tur in VARSAYILAN_SAATLER:
            sonuc[tur] = {"t": VARSAYILAN_SAATLER[tur], "approx": True}
    return sonuc


def yaz(yol, veri):
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    with open(yol, "w", encoding="utf-8") as f:
        json.dump(veri, f, ensure_ascii=False, indent=1, sort_keys=True)


def gunluk_isle(u, klasor, menuler, simdi, sinir):
    from .foto import FotoKutuphanesi
    kut = FotoKutuphanesi(klasor)
    g = u.gunluk()
    if g:
        tarih = g.get("date") or simdi.date().isoformat()
        ogun = g.get("meal", "lunch")
        if g.get("items") and not menuler.get(tarih, {}).get(ogun, {}).get("items"):
            gun = {"items": g["items"]}
            if all("kcal" in o for o in g["items"]):
                gun["kcal"] = sum(o["kcal"] for o in g["items"])
            menuler.setdefault(tarih, {})[ogun] = gun
            print("%-10s %s günlük liste görselden okundu (%d öğe)" % (u.id, tarih, len(g["items"])))
    kut.tasi(menuler)
    if g:
        durum = kut.bugun_isle(tarih, menuler.get(tarih, {}).get("lunch", {}).get("items"), g.get("photo"))
        print("%-10s fotoğraf %s: %s" % (u.id, tarih, durum))
    tam = yaklasik = 0
    for t, gun in menuler.items():
        ogeler = gun.get("lunch", {}).get("items")
        dosya, ykl = kut.eslestir(t, ogeler)
        if dosya:
            gun["lunch"]["photo"] = dosya
            if ykl:
                gun["lunch"]["photoApprox"] = True
                yaklasik += 1
            else:
                tam += 1
    print("%-10s fotoğraf: %d tam eşleşme, %d benzer menü, kütüphane %d fotoğraf" % (u.id, tam, yaklasik, len(kut.idx["menus"])))
    kut.kaydet(sinir)


def yemek_fotolari_ekle(yf, menuler, ad):
    """Menüdeki her yemeğe küçük örnek fotoğraf ekler. Ağ/arama hatası menüyü yayınlamayı engellemez."""
    try:
        yf.menulere_ekle(menuler)
    except Exception as e:
        print("UYARI: %s yemek fotoğrafları eklenemedi: %s" % (ad, e))


def calistir(cikti: str, uniler=None) -> int:
    simdi = datetime.now(timezone(timedelta(hours=3)))        # Türkiye saati
    sinir = (simdi - timedelta(days=GUN_SAKLA)).date().isoformat()
    liste = []
    hata = 0
    from .dishes import YemekFotolari
    yf = YemekFotolari(os.path.join(cikti, "dishes"), bugun=simdi.date())
    for u in (uniler or KAYITLI):
        try:
            menuler = {t: g for t, g in u.menuler().items() if t >= sinir}
            if not menuler:
                raise RuntimeError("hiç menü bulunamadı")
            gunluk_isle(u, os.path.join(cikti, u.id), menuler, simdi, sinir)
            yemek_fotolari_ekle(yf, menuler, u.id)
            fiyatlar = u.fiyatlar()
            yaz(os.path.join(cikti, u.id, "menu.json"), {"university": u.id, "updated": simdi.isoformat(timespec="seconds"), "days": menuler})
            turler = sorted({tur for g in menuler.values() for tur in g})
            liste.append({"id": u.id, "name": u.ad, "short": u.kisa, "city": u.sehir, "source": u.kaynak, "meals": turler,
                          "prices": fiyatlar, "hours": saat_bilgisi(u, turler), "firstDay": min(menuler), "lastDay": max(menuler)})
            print("%-10s %d gün (%s .. %s) türler=%s" % (u.id, len(menuler), min(menuler), max(menuler), turler))
        except Exception as e:
            hata += 1
            print("HATA: %s güncellenemedi: %s" % (u.id, e), file=sys.stderr)
    yf.kaydet()
    if liste:
        yaz(os.path.join(cikti, "index.json"), {"version": 1, "updated": simdi.isoformat(timespec="seconds"), "universities": liste})
    return 1 if hata and not liste else 0


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--cikti", default=os.path.join(os.path.dirname(__file__), "..", "..", "data"))
    a = p.parse_args()
    sys.exit(calistir(os.path.abspath(a.cikti)))
