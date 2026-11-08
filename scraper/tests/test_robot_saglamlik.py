"""Ağsız robot testleri: gerçek spawn/kill, bütçe, eski kayıt, yayın ve Actions özeti."""
import io
import json
import multiprocessing
import os
import pickle
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

from yemekhane import build, depolama, dishes, ocr
from yemekhane.universities.base import Universite


def agir_foto(*args, **kwargs):
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    while True:
        time.sleep(10)


def baslamayan_surec(*args):
    time.sleep(60)


class RobotOkulu(Universite):
    """Modül düzeyinde ve yalnız basit veri taşır; macOS/Linux spawn ile çalışır."""
    ad, kisa, sehir, kaynak = "Deneme Üniversitesi", "DÜ", "Ankara", "https://example.invalid"

    def __init__(self, kimlik="a", asama=None, hata=False, pid_yolu=None):
        self.id, self.asama, self.hata, self.pid_yolu = kimlik, asama, hata, pid_yolu

    def _asama(self, ad):
        if self.asama != ad:
            return
        if self.hata:
            raise RuntimeError("test kesintisi: " + ad)
        agir_foto()

    def menuler(self):
        if self.asama == "cokme":
            os._exit(7)
        if self.asama == "alt_surec":
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            kod = ("import os, signal, time; from pathlib import Path; "
                   "signal.signal(signal.SIGTERM, signal.SIG_IGN); "
                   "Path(%r).write_text(str(os.getpid()))\n"
                   "while True:\n"
                   "    Path(%r).write_text(str(time.monotonic()))\n"
                   "    time.sleep(0.02)\n" % (self.pid_yolu, self.pid_yolu + ".nabiz"))
            # Takılan OCR benzeri gerçek alt süreç; okulun kısa bütçesi bunu da öldürmeli.
            subprocess.run([sys.executable, "-c", kod], timeout=65)
        if self.asama == "gorsel":
            dishes.foto_bul = agir_foto  # yalnız bu test okulunun ayrı sürecinde
        self._asama("menu")
        return {"2999-01-02": {"lunch": {"items": [{"name": "Çorba"}]}}}

    def gunluk(self):
        self._asama("gunluk")
        return None

    def fiyatlar(self):
        self._asama("fiyat")
        return [{"label": "Öğrenci", "tl": 20}]

    def saatler(self):
        self._asama("saat")
        return {"lunch": "12:00–13:30"}


class RobotSurecTesti(unittest.TestCase):
    def test_kayitli_100_okul_spawn_icin_pickle_edilebilir(self):
        for u in build.KAYITLI:
            with self.subTest(okul=u.id):
                kopya = pickle.loads(pickle.dumps(u))
                self.assertEqual(kopya.id, u.id)
                self.assertEqual(type(kopya), type(u))

    def calistir(self, klasor, okullar, sure=3, limit=0):
        with patch.object(build, "OKUL_SURESI", sure), patch.object(dishes, "RUN_LIMIT", limit):
            return build.calistir(str(klasor), okullar)

    def test_spawn_tam_sonuc_ve_sira(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.calistir(d, [RobotOkulu("b"), RobotOkulu("a")]), 0)
            idx = json.loads((Path(d) / "index.json").read_text())
            self.assertEqual([u["id"] for u in idx["universities"]], ["b", "a"])
            for u in idx["universities"]:
                menu = json.loads((Path(d) / u["id"] / "menu.json").read_text())
                self.assertEqual(u["lastDay"], max(menu["days"]))
                self.assertEqual(u["hours"]["lunch"], {"t": "12:00–13:30", "approx": False})
                self.assertEqual(u["prices"][0]["tl"], 20)
            self.assertEqual(list(Path(d).glob(".robot-*")), [])

    def test_her_asama_sure_icinde_ve_kuyruk_devam_eder(self):
        for asama in ("menu", "gunluk", "fiyat", "saat", "gorsel"):
            with self.subTest(asama=asama), tempfile.TemporaryDirectory() as d:
                baslangic = time.monotonic()
                onceki_pidler = {p.pid for p in multiprocessing.active_children()}
                with patch.object(build, "PARALEL", 1):
                    kod = self.calistir(d, [RobotOkulu("takilan", asama), RobotOkulu("saglam")],
                                        sure=0.2, limit=1 if asama == "gorsel" else 0)
                self.assertEqual(kod, 0)
                self.assertLess(time.monotonic() - baslangic, 6)
                self.assertEqual([u["id"] for u in json.loads((Path(d) / "index.json").read_text())["universities"]], ["saglam"])
                self.assertFalse((Path(d) / "takilan/menu.json").exists())
                self.assertEqual({p.pid for p in multiprocessing.active_children()}, onceki_pidler)

    def test_saat_hatasi_eski_menu_indeks_ve_fotoyu_aynen_korur(self):
        with tempfile.TemporaryDirectory() as d:
            self.calistir(d, [RobotOkulu()])
            dosyalar = [Path(d) / "a/menu.json", Path(d) / "a/photos/index.json", Path(d) / "index.json"]
            idx = json.loads(dosyalar[-1].read_text())
            idx["universities"][0]["lastDay"] = "2020-01-01"
            depolama.yaz(dosyalar[-1], idx)
            eski = [p.read_bytes() for p in dosyalar]
            self.assertEqual(self.calistir(d, [RobotOkulu(asama="saat", hata=True)]), 1)
            self.assertEqual([p.read_bytes() for p in dosyalar], eski)

    def test_kismi_hata_olunca_eski_okul_kaydi_aynen_kalir(self):
        with tempfile.TemporaryDirectory() as d:
            self.calistir(d, [RobotOkulu()])
            idx = json.loads((Path(d) / "index.json").read_text())
            eski = idx["universities"][0]
            eski["lastDay"] = "2020-01-01"
            depolama.yaz(Path(d) / "index.json", idx)
            menu = (Path(d) / "a/menu.json").read_bytes()
            self.assertEqual(self.calistir(d, [RobotOkulu(asama="fiyat", hata=True), RobotOkulu("b")]), 0)
            yeni = json.loads((Path(d) / "index.json").read_text())
            self.assertEqual(yeni["universities"][0], eski)
            self.assertEqual((Path(d) / "a/menu.json").read_bytes(), menu)

    def test_coken_surec_ve_pickle_hatasi_robotu_bekletmez(self):
        class YerelOkul(RobotOkulu):
            pass  # bilerek spawn ile pickle edilemeyen eklenti
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.calistir(d, [RobotOkulu("coken", "cokme"), YerelOkul("yerel"), RobotOkulu("b")]), 0)
            self.assertEqual([u["id"] for u in json.loads((Path(d) / "index.json").read_text())["universities"]], ["b"])

    def test_baslatma_suresi_de_sinirlidir(self):
        with tempfile.TemporaryDirectory() as d, patch.object(build, "BASLATMA_SURESI", 0.1), \
                patch.object(build, "_okul_sureci", baslamayan_surec):
            t = time.monotonic()
            self.assertEqual(self.calistir(d, [RobotOkulu()]), 1)
            self.assertLess(time.monotonic() - t, 4)

    @unittest.skipUnless(os.name == "posix", "Süreç grubu POSIX'e özgü")
    def test_sigterm_yutan_ocr_alt_sureci_de_oldurulur(self):
        with tempfile.TemporaryDirectory() as d:
            pid_yolu = Path(d) / "ocr.pid"
            self.assertEqual(self.calistir(d, [RobotOkulu(asama="alt_surec", pid_yolu=str(pid_yolu))], sure=0.5), 1)
            self.assertTrue(pid_yolu.exists(), "OCR benzeri alt süreç gerçekten başlamalı")
            self.assertGreater(int(pid_yolu.read_text()), 0)
            nabiz = Path(str(pid_yolu) + ".nabiz")
            son = nabiz.read_bytes()
            time.sleep(0.15)
            self.assertEqual(nabiz.read_bytes(), son, "Alt süreç build döndükten sonra çalışmamalı")

    def test_yayin_hatasinda_menu_ve_indeks_birlikte_geri_alinir(self):
        with tempfile.TemporaryDirectory() as d:
            self.calistir(d, [RobotOkulu()])
            menu, idx = Path(d) / "a/menu.json", Path(d) / "index.json"
            eski = menu.read_bytes(), idx.read_bytes()
            replace = os.replace
            kesildi = []
            def hata_ver(kaynak, hedef):
                if str(hedef) == str(idx) and not kesildi:
                    kesildi.append(True)
                    raise OSError("disk yazma testi")
                return replace(kaynak, hedef)
            with patch.object(depolama.os, "replace", side_effect=hata_ver):
                with self.assertRaisesRegex(OSError, "disk yazma testi"):
                    self.calistir(d, [RobotOkulu(), RobotOkulu("b")])
            self.assertEqual((menu.read_bytes(), idx.read_bytes()), eski)
            self.assertFalse((Path(d) / "b/menu.json").exists())
            self.assertEqual(list(Path(d).rglob(".robot-*")), [])


class RobotRaporTesti(unittest.TestCase):
    def test_30_yuzde_siniri_ve_turkiye_gece_yarisi(self):
        okullar = [RobotOkulu("okul%d" % n) for n in range(10)]
        simdi = datetime(2026, 11, 7, 22, 30, tzinfo=timezone.utc)  # Türkiye'de 8 Kasım
        liste = [{"id": u.id, "lastDay": "2026-11-08"} for u in okullar]
        liste[0]["lastDay"] = "2026-11-05"  # tam 3 gün: rapora girmeli
        liste[1]["lastDay"] = "2026-11-06"  # 2 gün: girmemeli
        liste[2]["lastDay"] = "bozuk"
        for hata_sayisi in (3, 4):
            with self.subTest(hata=hata_sayisi), tempfile.TemporaryDirectory() as d:
                ozet = Path(d) / "ozet.md"
                out = io.StringIO()
                with patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(ozet)}), redirect_stdout(out), redirect_stderr(io.StringIO()):
                    build.raporla(okullar, liste, [(u.id, "kesinti") for u in okullar[:hata_sayisi]],
                                  10 - hata_sayisi, simdi, 12.5)
                self.assertEqual("::warning::" in out.getvalue(), hata_sayisi > 3)
                metin = ozet.read_text()
                self.assertIn("2026-11-08 (Türkiye saati)", metin)
                self.assertIn("| okul0 | 2026-11-05 | 3 gün |", metin)
                self.assertNotIn("| okul1 |", metin)
                self.assertIn("bilinmeyen", metin)

    def test_tumu_basarisizken_de_ozet_yazilir_ve_hata_kodu_doner(self):
        with tempfile.TemporaryDirectory() as d:
            ozet = Path(d) / "ozet.md"
            with patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(ozet)}), patch.object(dishes, "RUN_LIMIT", 0):
                self.assertEqual(build.calistir(str(Path(d) / "cikti"), [RobotOkulu(asama="menu", hata=True)]), 1)
            self.assertIn("0 başarılı, 1 başarısız", ozet.read_text())
            self.assertFalse((Path(d) / "cikti/index.json").exists())


class OcrSureTesti(unittest.TestCase):
    def test_iki_ocr_girisi_de_subprocess_timeout_kullanir(self):
        for oku in (ocr.oku, ocr.kelimeler):
            with self.subTest(oku=oku.__name__), patch.object(ocr, "kullanilabilir", return_value=True), \
                    patch.object(ocr.subprocess, "run", side_effect=subprocess.TimeoutExpired("tesseract", ocr.OCR_SURESI)) as run:
                with self.assertRaises(subprocess.TimeoutExpired):
                    oku(b"gorsel")
                self.assertEqual(run.call_args.kwargs["timeout"], ocr.OCR_SURESI)


class OrtakFotografButceTesti(unittest.TestCase):
    def test_onbellek_salt_okunur_ve_ortak_arama_limiti_asılmaz(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            ortak = d / "ortak"
            ortak.mkdir()
            k = dishes.anahtar("Çorba")
            (ortak / (k + ".jpg")).write_bytes(b"hazir jpeg")
            depolama.yaz(ortak / "index.json", {"dishes": {k: {"name": "Çorba"}}, "miss": {}})
            eski = (ortak / "index.json").read_bytes()
            butce = multiprocessing.get_context("spawn").Semaphore(1)
            a = dishes.YemekFotolari(str(d / "a"), onbellek=str(ortak), arama_butcesi=butce)
            b = dishes.YemekFotolari(str(d / "b"), onbellek=str(ortak), arama_butcesi=butce)
            with patch.object(dishes, "foto_bul", return_value=None) as ara:
                self.assertEqual(a.dosya("Çorba"), "dishes/%s.jpg" % k)
                self.assertIsNone(a.dosya("Pilav"))
                self.assertIsNone(b.dosya("Meyve"))
                self.assertEqual(ara.call_count, 1)
            self.assertEqual((ortak / "index.json").read_bytes(), eski)


if __name__ == "__main__":
    unittest.main()
