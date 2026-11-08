"""Tüm üniversiteleri çalıştırır ve statik JSON dosyalarını yazar:
   data/index.json                 -> üniversite listesi (uygulama ilk bunu okur)
   data/<id>/menu.json             -> o üniversitenin tarih bazlı menüleri
Kullanım:  python -m yemekhane.build [--cikti ../data]
"""
import argparse
import copy
import json
import multiprocessing
import os
import shutil
import signal
import sys
import tempfile
import time
from datetime import date, datetime, timedelta, timezone

from .universities import KAYITLI
from .temizle import menuleri_temizle
from .depolama import birlikte_yayinla, json_verisi, yaz

GUN_SAKLA = 45     # bugünden bu kadar gün öncesine kadar menü tutulur
OKUL_SURESI = 180  # sn: menü + günlük görsel/OCR + yemek görselleri + fiyat + saat + hazırlık
BASLATMA_SURESI = 30  # sn: spawn ile Python'un/modüllerin açılması; okul bütçesinden ayrıdır
PARALEL = 6        # tüm okul işi ayrı, sonlandırılabilir süreçlerde çalışır
TURKIYE = timezone(timedelta(hours=3))
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


def onceki_kayitlar(cikti: str) -> dict:
    """Önceki çalıştırmanın index.json kayıtları: {id: kayıt}. Dosya yoksa/bozuksa boş."""
    try:
        with open(os.path.join(cikti, "index.json"), encoding="utf-8") as f:
            return {u["id"]: u for u in json.load(f)["universities"]}
    except (OSError, ValueError, KeyError, TypeError):
        return {}


def onceki_gunler(cikti: str, kimlik: str, sinir: str, yeni: dict) -> dict:
    """Okul yalnızca bugünün ya da bu haftanın menüsünü yayınlıyorsa (`birikimli = True` eklentiler) önceki çalıştırmalarda
    kaydedilen günler korunur; aynı gün için yeni veri geçerlidir."""
    try:
        with open(os.path.join(cikti, kimlik, "menu.json"), encoding="utf-8") as f:
            eski = json.load(f)["days"]
    except (OSError, ValueError, KeyError, TypeError):
        return yeni
    birlesik = {t: g for t, g in eski.items() if t >= sinir}
    birlesik.update(yeni)
    return birlesik


def okul_hazirla(u, cikti, gecici, simdi, sinir, arama_butcesi=None):
    """Okulun TÜM işi bu çağrıdadır; yayımlanmış dosyalara yazmaz."""
    from .dishes import YemekFotolari
    klasor = os.path.join(gecici, u.id)
    onceki = os.path.join(cikti, u.id)
    if os.path.isdir(onceki):
        shutil.copytree(onceki, klasor)
    yf = YemekFotolari(os.path.join(gecici, "dishes"), bugun=simdi.date(),
                       onbellek=os.path.join(cikti, "dishes"), arama_butcesi=arama_butcesi)
    eski_fotolar = copy.deepcopy(yf.idx)
    ham = u.menuler()
    menuler = {t: g for t, g in ham.items() if t >= sinir}
    if menuler and getattr(u, "birikimli", False):
        menuler = onceki_gunler(cikti, u.id, sinir, menuler)
    if not menuler:
        raise RuntimeError("hiç menü bulunamadı")
    menuler = menuleri_temizle(menuler)
    gunluk_isle(u, klasor, menuler, simdi, sinir)
    menuler = menuleri_temizle(menuler)
    yemek_fotolari_ekle(yf, menuler, u.id)
    fiyatlar = u.fiyatlar()
    turler = sorted({tur for g in menuler.values() for tur in g})
    kayit = {"id": u.id, "name": u.ad, "short": u.kisa, "city": u.sehir, "source": u.kaynak, "meals": turler,
             "prices": fiyatlar, "hours": saat_bilgisi(u, turler), "firstDay": min(menuler), "lastDay": max(menuler)}
    menu = {"university": u.id, "updated": simdi.isoformat(timespec="seconds"), "days": menuler}
    # Saat/fiyat dahil bütün sonuç hazır olmadan menu.json bile geçici alana yazılmaz.
    yaz(os.path.join(klasor, "menu.json"), menu)
    yf.kaydet()
    fark = {bolum: {k: v for k, v in yf.idx[bolum].items() if eski_fotolar[bolum].get(k) != v}
            for bolum in ("dishes", "miss")}
    print("%-10s %d gün (%s .. %s) türler=%s" % (u.id, len(menuler), min(menuler), max(menuler), turler))
    return {"kayit": kayit, "fotolar": fark}


def _okul_sureci(u, cikti, gecici, simdi, sinir, basladi, arama_butcesi):
    """Modül düzeyinde hedef: Linux ve macOS spawn ile pickle edilebilir."""
    if os.name == "posix":
        os.setsid()  # OCR dahil alt süreçler aynı grupta; zaman aşımında hepsi durdurulur.
    baslangic = time.monotonic()
    basladi.send(None)
    basladi.close()
    for akis in (sys.stdout, sys.stderr):
        if hasattr(akis, "reconfigure"):
            akis.reconfigure(line_buffering=True)
    try:
        sonuc = okul_hazirla(u, cikti, gecici, simdi, sinir, arama_butcesi)
    except Exception as e:
        sonuc = {"hata": "%s: %s" % (type(e).__name__, e)}
    sonuc["sure"] = time.monotonic() - baslangic
    yaz(os.path.join(gecici, "sonuc.json"), sonuc)


def _sureci_durdur(p, grup):
    """terminate + sınırlı join + kill; SIGTERM'i yutan OCR/okul da bekletmez."""
    if grup and os.name == "posix":
        for sig in (signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(p.pid, sig)
            except ProcessLookupError:
                pass
            except PermissionError:
                if p.is_alive():
                    raise
            if sig == signal.SIGTERM:
                p.join(timeout=1)
    else:
        if p.is_alive():
            p.terminate()
            p.join(timeout=1)
        if p.is_alive():
            p.kill()
    p.join(timeout=1)


def okullari_topla(uniler, cikti, gecici, simdi, sinir):
    """En çok PARALEL okul; süreler sıra beklemesinden bağımsız izlenir, büyük sonuçlar pipe'a girmez."""
    from .dishes import RUN_LIMIT
    ctx = multiprocessing.get_context("spawn")
    arama_butcesi = ctx.Semaphore(max(0, RUN_LIMIT))
    calisan, sonuclar = {}, {}
    sira = 0
    try:
        while sira < len(uniler) or calisan:
            while sira < len(uniler) and len(calisan) < PARALEL:
                no, u = sira, uniler[sira]
                sira += 1
                klasor = os.path.join(gecici, str(no))
                os.makedirs(klasor)
                oku, gonder = ctx.Pipe(duplex=False)
                p = ctx.Process(target=_okul_sureci,
                                args=(u, cikti, klasor, simdi, sinir, gonder, arama_butcesi))
                try:
                    p.start()
                except Exception as e:
                    oku.close()
                    if p.pid is not None:
                        _sureci_durdur(p, False)
                    p.close()
                    sonuclar[no] = {"hata": "okul süreci başlatılamadı: %s" % e}
                else:
                    calisan[no] = {"p": p, "oku": oku, "basladi": False,
                                   "vade": time.monotonic() + BASLATMA_SURESI, "klasor": klasor}
                finally:
                    gonder.close()
            for no, is_ in list(calisan.items()):
                p, oku = is_["p"], is_["oku"]
                if not is_["basladi"] and oku.poll():
                    try:
                        oku.recv()
                        # macOS/Python 3.9 monotonic başlangıcı süreçler arasında aynı değildir.
                        is_["vade"] = time.monotonic() + OKUL_SURESI
                        is_["basladi"] = True
                    except EOFError:
                        pass
                if p.exitcode is not None:
                    p.join(timeout=0)
                    try:
                        with open(os.path.join(is_["klasor"], "sonuc.json"), encoding="utf-8") as f:
                            sonuc = json.load(f)
                        if p.exitcode != 0:
                            raise RuntimeError("çıkış kodu %s" % p.exitcode)
                        if sonuc["sure"] > OKUL_SURESI:
                            sonuc = {"hata": "zaman aşımı (%g sn)" % OKUL_SURESI}
                    except (OSError, ValueError, KeyError, RuntimeError) as e:
                        sonuc = {"hata": "okul süreci sonuç vermeden kapandı (%s): %s" % (p.exitcode, e)}
                    if "hata" in sonuc:
                        _sureci_durdur(p, is_["basladi"])
                elif time.monotonic() >= is_["vade"]:
                    _sureci_durdur(p, is_["basladi"])
                    sonuc = {"hata": "zaman aşımı (%g sn%s)" %
                             (OKUL_SURESI if is_["basladi"] else BASLATMA_SURESI,
                              "" if is_["basladi"] else ", süreç başlatma")}
                else:
                    continue
                sonuclar[no] = sonuc
                oku.close()
                p.close()
                del calisan[no]
            if calisan:
                time.sleep(0.02)
    finally:
        for is_ in calisan.values():
            _sureci_durdur(is_["p"], is_["basladi"])
            is_["oku"].close()
            is_["p"].close()
    return sonuclar


def _dosyalari_oku(klasor, hedef):
    for kok, _, dosyalar in os.walk(klasor):
        for ad in sorted(dosyalar):
            yol = os.path.join(kok, ad)
            with open(yol, "rb") as f:
                yield os.path.join(hedef, os.path.relpath(yol, klasor)), f.read()


def raporla(uniler, liste, hatalilar, basarili, simdi, sure):
    bugun = simdi.astimezone(TURKIYE).date()
    kayitlar = {u["id"]: u for u in liste}
    geride, eksik = [], []
    for u in uniler:
        son = kayitlar.get(u.id, {}).get("lastDay")
        try:
            fark = (bugun - date.fromisoformat(son)).days
        except (ValueError, TypeError):
            eksik.append(u.id)
            continue
        if fark >= 3:
            geride.append((u.id, son, fark))
    ozet = "%d okul: %d başarılı, %d başarısız; %.1f sn" % (len(uniler), basarili, len(hatalilar), sure)
    print("SONUÇ: " + ozet)
    if hatalilar:
        print("ÖZET: %d okul hatalı: %s" % (len(hatalilar), ", ".join("%s (%s)" % h for h in hatalilar)), file=sys.stderr)
    cok_hata = len(hatalilar) * 10 > len(uniler) * 3
    if cok_hata:
        print("::warning::Okulların %30'dan fazlası güncellenemedi: " + ozet)
    print("GÜNCELLİK (%s, Türkiye): menüsü 3+ gün geride kalan okullar: %s" %
          (bugun, ", ".join("%s (%s, %d gün)" % g for g in geride) or "yok"))
    satirlar = ["## Menü robotu", "", ozet, ""]
    if cok_hata:
        satirlar += ["**UYARI: Okulların %30'dan fazlası güncellenemedi.**", ""]
    if hatalilar:
        satirlar += ["### Güncellenemeyen okullar", ""]
        satirlar += ["- `%s`: %s" % (k, str(e).replace("\n", " ")) for k, e in hatalilar]
        satirlar += [""]
    satirlar += ["### Menüsü 3+ gün geride kalan okullar", "", "Bugün: %s (Türkiye saati)." % bugun, ""]
    if geride:
        satirlar += ["| Okul | Son menü günü | Gecikme |", "| --- | --- | --- |"]
        satirlar += ["| %s | %s | %d gün |" % g for g in geride]
    else:
        satirlar += ["Yok."]
    if eksik:
        satirlar += ["", "Son menü günü bilinmeyen / yayımlanmış kaydı olmayan okullar: " + ", ".join(eksik)]
    yol = os.environ.get("GITHUB_STEP_SUMMARY")
    if yol:
        try:
            with open(yol, "a", encoding="utf-8") as f:
                f.write("\n".join(satirlar) + "\n")
        except OSError as e:
            print("UYARI: Actions özeti yazılamadı: %s" % e, file=sys.stderr)


def calistir(cikti: str, uniler=None) -> int:
    baslangic = time.monotonic()
    simdi = datetime.now(TURKIYE)
    sinir = (simdi - timedelta(days=GUN_SAKLA)).date().isoformat()
    cikti = os.path.abspath(cikti)
    uniler = list(KAYITLI if uniler is None else uniler)
    eski = onceki_kayitlar(cikti)
    liste, hatalilar, dosyalar = [], [], {}
    basarili = 0
    os.makedirs(cikti, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".robot-", dir=cikti) as gecici:
        sonuclar = okullari_topla(uniler, cikti, gecici, simdi, sinir)
        from .dishes import YemekFotolari
        yf = YemekFotolari(os.path.join(cikti, "dishes"), bugun=simdi.date())
        for no, u in enumerate(uniler):
            sonuc = sonuclar[no]
            if "hata" in sonuc:
                hata = sonuc["hata"]
                hatalilar.append((u.id, hata))
                print("HATA: %s güncellenemedi: %s" % (u.id, hata), file=sys.stderr)
                if u.id in eski:
                    # Eski kayıt alanları (varsa stale dahil) ve menü birlikte, aynen korunur.
                    liste.append(eski[u.id])
                    print("%-10s önceki kayıt korundu" % u.id, file=sys.stderr)
                continue
            klasor = os.path.join(gecici, str(no))
            dosyalar.update(_dosyalari_oku(os.path.join(klasor, u.id), os.path.join(cikti, u.id)))
            for yol, veri in _dosyalari_oku(os.path.join(klasor, "dishes"), os.path.join(cikti, "dishes")):
                if yol.endswith(".jpg"):
                    dosyalar[yol] = veri
            yf.idx["dishes"].update(sonuc["fotolar"]["dishes"])
            yf.idx["miss"].update(sonuc["fotolar"]["miss"])
            liste.append(sonuc["kayit"])
            basarili += 1
        if basarili:
            for k in yf.idx["dishes"]:
                yf.idx["miss"].pop(k, None)
            dosyalar[yf.yol] = json_verisi(yf.idx)
            # Menü/indeks ve görsel dosyaları önce tamamen hazırlanır; indeks en son değiştirilir.
            dosyalar[os.path.join(cikti, "index.json")] = json_verisi(
                {"version": 1, "updated": simdi.isoformat(timespec="seconds"), "universities": liste})
            birlikte_yayinla(dosyalar.items())
    raporla(uniler, liste, hatalilar, basarili, simdi, time.monotonic() - baslangic)
    return 1 if hatalilar and not basarili else 0


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--cikti", default=os.path.join(os.path.dirname(__file__), "..", "..", "data"))
    a = p.parse_args()
    sys.exit(calistir(os.path.abspath(a.cikti)))
