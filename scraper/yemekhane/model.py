"""Ortak veri modeli ve yardımcılar. Her üniversite bu biçimde veri üretir; uygulama yalnızca bu biçimi bilir."""
import re
from datetime import date, timedelta

TR_KUCUK = str.maketrans({"I": "ı", "İ": "i"})


def baslik_yap(metin: str) -> str:
    """'KIRMIZI MERCİMEK ÇORBA' -> 'Kırmızı Mercimek Çorba' (Türkçe büyük/küçük harf kurallarıyla)."""
    def kelime(k):
        kucuk = k.translate(TR_KUCUK).lower()
        ilk = {"i": "İ", "ı": "I"}.get(kucuk[0], kucuk[0].upper())
        return ilk + kucuk[1:]
    return " ".join("/".join(kelime(p) for p in k.split("/") if p) for k in metin.split())


def excel_tarih(seri) -> str:
    """Excel gün numarasını ISO tarihe çevirir (46266 -> 2026-09-01)."""
    return (date(1899, 12, 30) + timedelta(days=int(float(seri)))).isoformat()


_KKAL = re.compile(r"\(\s*(\d+)\s*kkal\s*\)", re.I)


def yemek_ogesi(hucre: str):
    """'YAYLA ÇORBA (168 kkal)' -> {'name': 'Yayla Çorba', 'kcal': 168}; kalori yoksa kcal anahtarı eklenmez."""
    m = _KKAL.search(hucre)
    ad = _KKAL.sub("", hucre).strip(" /-")
    oge = {"name": baslik_yap(re.sub(r"\s+", " ", ad))}
    if m:
        oge["kcal"] = int(m.group(1))
    return oge


def toplam_kalori(hucre: str):
    m = re.search(r"(\d+)", hucre or "")
    return int(m.group(1)) if m else None
