"""JSON dosyalarını önce hazırlar, os.replace ile yayımlar; yazma hatasında eski dosyaları geri koyar."""
import json
import os
import tempfile


def json_verisi(veri):
    return json.dumps(veri, ensure_ascii=False, indent=1, sort_keys=True).encode("utf-8")


def _gecici(yol, veri):
    fd, gecici = tempfile.mkstemp(prefix=".robot-", dir=os.path.dirname(yol))
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(veri)
            f.flush()
            os.fsync(f.fileno())
    except BaseException:
        os.unlink(gecici)
        raise
    return gecici


def birlikte_yayinla(dosyalar):
    """(hedef, bayt) çiftleri; tüm içerik ve yedekler ilk değiştirmeden önce hazırlanır.

    Her dosya değişimi atomiktir; birden çok sabit dosya yolu tek dosya sistemi işlemi
    olamaz. Yakalanan yazma/replace hatasında tamamlanan değişimler geri alınır.
    Çağıran indeks dosyasını en sona koyar; CI ancak tüm işlem bitince commit eder.
    """
    hazir, degisen = [], []
    try:
        gorulen = set()
        for yol, veri in dosyalar:
            yol = os.path.abspath(yol)
            if yol in gorulen:
                raise ValueError("Yinelenen yayın hedefi: " + yol)
            gorulen.add(yol)
            os.makedirs(os.path.dirname(yol), exist_ok=True)
            kayit = [yol, None, None]
            hazir.append(kayit)
            if os.path.exists(yol):
                with open(yol, "rb") as f:
                    kayit[2] = _gecici(yol, f.read())
            kayit[1] = _gecici(yol, veri)
        for kayit in hazir:
            os.replace(kayit[1], kayit[0])
            degisen.append(kayit)
    except BaseException:
        for yol, _, yedek in reversed(degisen):
            if yedek is None:
                os.unlink(yol)
            else:
                os.replace(yedek, yol)
        raise
    finally:
        for _, yeni, yedek in hazir:
            for gecici in (yeni, yedek):
                if gecici and os.path.exists(gecici):
                    os.unlink(gecici)


def yaz(yol, veri):
    birlikte_yayinla([(yol, json_verisi(veri))])
