import urllib.request
from urllib.parse import urlsplit

from . import _tls

UA = "Mozilla/5.0 (yemekhane-uygulamasi; ogrenci projesi)"


def indir(url, zaman_asimi: int = 30) -> bytes:
    """GET veya Request (POST dahil); TLS kurtarmasında da tam doğrulama."""
    istek = url if isinstance(url, urllib.request.Request) else urllib.request.Request(url, headers={"User-Agent": UA})
    adres = urlsplit(istek.full_url)
    anahtar = (adres.hostname, adres.port or 443)
    ara = _tls._ONBELLEK.get(anahtar, ())
    dusuk_dh = aia_denendi = False
    for _ in range(3):
        try:
            with urllib.request.urlopen(istek, timeout=zaman_asimi, context=_tls.baglam(ara, dusuk_dh)) as yanit:
                return yanit.read()
        except OSError as hata:
            ssl_hata = _tls.ssl_hatasi(hata)
            neden = getattr(ssl_hata, 'reason', '')
            if neden == 'DH_KEY_TOO_SMALL' and not dusuk_dh:
                dusuk_dh = True
            elif neden == 'CERTIFICATE_VERIFY_FAILED' and not aia_denendi:
                aia_denendi = True
                try:
                    ara = _tls.ara_sertifikalar(*anahtar, zaman_asimi)
                except (OSError, ValueError):
                    raise hata
            else:
                raise
    raise RuntimeError('TLS yeniden deneme sınırı aşıldı')


class Universite:
    """Bir üniversitenin yemek listesini üreten eklenti arayüzü."""
    id = ""            # url/klasör dostu kısa ad: 'ankara'
    ad = ""            # 'Ankara Üniversitesi'
    kisa = ""          # 'AÜ'
    sehir = ""
    kaynak = ""        # bilgi amaçlı: verinin alındığı site
    birikimli = False  # True: okul yalnızca bugünün/haftanın menüsünü yayınlıyor; build önceki çalıştırmalarda kaydedilen günleri korur

    def menuler(self) -> dict:
        """{'2026-10-01': {'lunch': {...}, 'dinner': {...}, 'vegetarian': {...}}, ...} döndürür."""
        raise NotImplementedError

    def gunluk(self):
        """Opsiyonel: bugüne özel veri. {'date': 'YYYY-MM-DD'|None, 'photo': jpeg bayt|None, 'items': [...]|None, 'meal': 'lunch'} ya da None."""
        return None

    def saatler(self) -> dict:
        """Okulun yayınladığı servis saatleri: {'lunch': '11:30–14:00', ...}. Bulunamayanlar yazılmaz (varsayılan build.py'de)."""
        return {}

    def fiyatlar(self) -> list:
        """[{'label': 'Öğrenci (Öğle)', 'tl': 50}, ...] (bulunamazsa boş liste)."""
        return []


class ElleUniversite(Universite):
    """Menüyü yalnızca resim/PDF-resim olarak yayınlayan okullar: menü `elle_veri/<id>.json` dosyasına resimden elle girilir (bkz. elle.py, README).
    Okul her ay (ya da hafta) yeni resmi koyunca dosyaya yeni günler eklenmelidir; aksi halde menü bitince okul uygulamada boş görünür."""

    def menuler(self) -> dict:
        from .. import elle
        return elle.yukle(self.id)


def saat_duzenle(metin: str):
    """'11.30-13.30', '11:30 - 14:00' -> '11:30–13:30'; saat aralığı yoksa None."""
    import re
    m = re.search(r"(\d{1,2})[.:](\d{2})\s*[-–—]\s*(\d{1,2})[.:](\d{2})", metin or "")
    if not m:
        return None
    a, b, c, d = m.groups()
    return "%02d:%s–%02d:%s" % (int(a), b, int(c), d)
