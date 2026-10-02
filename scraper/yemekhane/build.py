"""Tüm üniversiteleri çalıştırır ve statik JSON dosyalarını yazar:
   data/index.json                 -> üniversite listesi (uygulama ilk bunu okur)
   data/<id>/menu.json             -> o üniversitenin tarih bazlı menüleri
Kullanım:  python -m yemekhane.build [--cikti ../data]
"""
import argparse
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
