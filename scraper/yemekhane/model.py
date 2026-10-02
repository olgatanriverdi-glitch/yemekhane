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


def tarih_duzelt(tarihler):
    """Okulun Excel dosyalarındaki ay/yıl yazım hatalarını komşu satırlara bakarak düzeltir.
    Örn: ...10/11, 4/12, 4/13 ... 4/18, 10/19 -> 4/12..4/18 aslında 10/12..10/18'dir (gün sırası doğru, ay yanlış).
    Kural: tarih bir önceki (güvenilir) satırdan 1-4 gün sonra değilse, günü aynı kalıp ay/yılı önceki satırdan (ya da bir sonraki aydan)
    alan aday aynı aralığa düşüyorsa onu kullanır. Döndürür: (düzeltilmiş ISO liste, [(eski, yeni), ...])."""
    from datetime import date
    cikti, duzeltmeler, onceki = [], [], None
    for t in tarihler:
        d = date.fromisoformat(t)
        if onceki is not None and not (1 <= (d - onceki).days <= 4):
            for ay_ek in (0, 1):
                ay = onceki.month + ay_ek
                yil = onceki.year + (1 if ay > 12 else 0)
                ay = ay - 12 if ay > 12 else ay
                try:
                    aday = date(yil, ay, d.day)
                except ValueError:
                    continue
                if 1 <= (aday - onceki).days <= 4:
                    duzeltmeler.append((t, aday.isoformat()))
                    d = aday
                    break
        cikti.append(d.isoformat())
        onceki = d
    return cikti, duzeltmeler


def kucuk_tr_ad(ad: str) -> str:
    """Eşleştirme için: Türkçe küçük harf + fazla boşluk/noktalama yok."""
    import re
    return re.sub(r"[^0-9a-zçğıöşü]+", " ", ad.replace("İ", "i").replace("I", "ı").lower()).strip()
