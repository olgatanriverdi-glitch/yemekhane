import urllib.request

UA = "Mozilla/5.0 (yemekhane-uygulamasi; ogrenci projesi)"


def indir(url: str, zaman_asimi: int = 30) -> bytes:
    istek = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(istek, timeout=zaman_asimi) as yanit:
        return yanit.read()


class Universite:
    """Bir üniversitenin yemek listesini üreten eklenti arayüzü."""
    id = ""            # url/klasör dostu kısa ad: 'ankara'
    ad = ""            # 'Ankara Üniversitesi'
    kisa = ""          # 'AÜ'
    sehir = ""
    kaynak = ""        # bilgi amaçlı: verinin alındığı site

    def menuler(self) -> dict:
        """{'2026-10-01': {'lunch': {...}, 'dinner': {...}, 'vegetarian': {...}}, ...} döndürür."""
        raise NotImplementedError

    def gunluk(self):
        """Opsiyonel: bugüne özel veri. {'date': 'YYYY-MM-DD'|None, 'photo': jpeg bayt|None, 'items': [...]|None, 'meal': 'lunch'} ya da None."""
        return None

    def fiyatlar(self) -> list:
        """[{'label': 'Öğrenci (Öğle)', 'tl': 50}, ...] (bulunamazsa boş liste)."""
        return []
