"""Ortak veri modeli ve yardımcılar. Her üniversite bu biçimde veri üretir; uygulama yalnızca bu biçimi bilir."""
import html
import re
from datetime import date, datetime, timedelta, timezone

TR_KUCUK = str.maketrans({"I": "ı", "İ": "i"})


def baslik_yap(metin: str) -> str:
    """'KIRMIZI MERCİMEK ÇORBA' -> 'Kırmızı Mercimek Çorba' (Türkçe büyük/küçük harf kurallarıyla)."""
    def kelime(k):
        kucuk = k.translate(TR_KUCUK).lower()
        ilk = {"i": "İ", "ı": "I"}.get(kucuk[0], kucuk[0].upper())
        return ilk + kucuk[1:]
    return " ".join("/".join(kelime(p) for p in k.split("/") if p) for k in metin.split())


def baslik_yap_serbest(metin: str) -> str:
    """Parantez/artı gibi noktalama içeren adlar için: her harf dizisi ayrı başlıklanır ('MANTI (SOS+YOĞURT)' -> 'Mantı (Sos+Yoğurt)')."""
    return re.sub(r"[^\W\d_]+", lambda m: baslik_yap(m.group(0)), metin)


AYLAR = {"ocak": 1, "şubat": 2, "mart": 3, "nisan": 4, "mayıs": 5, "haziran": 6, "temmuz": 7, "ağustos": 8, "eylül": 9,
         "ekim": 10, "kasım": 11, "aralık": 12}


def ay_no(ad: str):
    """'Ekim' / 'EKİM' -> 10; tanınmayan ad için None."""
    return AYLAR.get(ad.strip().translate(TR_KUCUK).lower())


def bugun_tr() -> date:
    return datetime.now(timezone(timedelta(hours=3))).date()


def yil_sec(gun: int, ay: int, bugun: date):
    """Yılı yazmayan tarihler için ('05 Ekim'): bugüne en yakın yılı seçer (Aralık/Ocak geçişinde doğru yıl çıkar). Geçersiz tarihte None."""
    adaylar = []
    for yil in (bugun.year - 1, bugun.year, bugun.year + 1):
        try:
            adaylar.append(date(yil, ay, gun))
        except ValueError:
            pass
    return min(adaylar, key=lambda d: abs((d - bugun).days)) if adaylar else None


_KISALTMALAR = [(re.compile(p, re.I), r) for p, r in (
    (r"\bzyt?\.\s*yağlı", "zeytinyağlı"), (r"\bzyt?\.\s*", "zeytinyağlı "), (r"\bdom\.\s*", "domates "),
    (r"\bşeh\.\s*", "şehriyeli "), (r"\byoğ\.\s*", "yoğurtlu "), (r"\bsebz\.\s*", "sebzeli "), (r"\bsos\.\s*", "soslu "),
    (r"\bgarn\.\s*", "garnitürlü "), (r"\bkre\.\s*", "kremalı "), (r"\bközl?\.\s*", "közlenmiş "), (r"\bzerd\.\s*", "zerdeçallı "),
    (r"\bseb\.\s*", "sebzeli "), (r"\bkr\.\s*", "kremalı "), (r"\bnoh\.\s*", "nohutlu "), (r"\blav\.\s*", "lavaş "), (r"\bpat\.\s*", "patates "),
    (r"\bp\.\s*(?=kızartma)", "patates "), (r"\bket\s+may\b", "ketçap mayonez"))]


def kisaltma_ac(ad: str) -> str:
    """Menülerde sık geçen kısaltmaları açar: 'Zyt.Yağlı Yoğ.Brokoli' -> 'zeytinyağlı yoğurtlu Brokoli', 'Şeh. Pirinç Pilavı' -> 'şehriyeli Pirinç Pilavı'.
    Büyük/küçük harfi baslik_yap düzeltir; bu yüzden başlıklamadan önce çağrılır."""
    for kalip, yerine in _KISALTMALAR:
        ad = kalip.sub(yerine, ad)
    return ad


def etiket_temizle(h: str) -> str:
    """HTML parçasından düz metin: etiketler atılır, karakter kodları çözülür, boşluklar teke iner."""
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", h)).replace("\xa0", " ")).strip()


def gun_icerigi(ogeler: list) -> dict:
    """Öğün sözlüğü: {'items': [...]} ve tüm kalemlerin kalorisi varsa 'kcal' (toplam)."""
    gun = {"items": ogeler}
    if ogeler and all("kcal" in o for o in ogeler):
        gun["kcal"] = sum(o["kcal"] for o in ogeler)
    return gun


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
