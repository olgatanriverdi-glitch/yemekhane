"""Asset eşitlemesi yalnız geçici klasörlerde ve ağsız sınanır."""
import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from yemekhane.depolama import birlikte_yayinla, yaz
from yemekhane.esitle import asset_klasorleri, esitle


class EsitleTesti(unittest.TestCase):
    def hazirla(self, kok):
        veri, app = Path(kok) / "veri", Path(kok) / "app"
        app.mkdir()
        (app / "pubspec.yaml").write_text(
            'name: test\nflutter:\n  assets:\n    - assets/data/\n    - "assets/data/a/" # kayıtlı\n', encoding="utf-8")
        yaz(veri / "index.json", {"version": 1, "updated": "test", "universities": [{"id": "a"}, {"id": "yeni"}]})
        for kimlik in ("a", "yeni", "indexte_yok"):
            yaz(veri / kimlik / "menu.json", {"university": kimlik, "days": {}})
            yaz(veri / kimlik / "photos/index.json", {"menus": {}, "dates": {}})
            (veri / kimlik / "photos/ornek.jpg").write_bytes(b"jpeg")
        yaz(veri / "dishes/index.json", {"dishes": {}})
        (veri / "dishes/ornek.jpg").write_bytes(b"jpeg")
        return veri, app

    def test_yalniz_kayitli_okul_jsonlari_esitlenir_pubspec_ve_digerleri_korunur(self):
        with tempfile.TemporaryDirectory() as d:
            veri, app = self.hazirla(d)
            pubspec = (app / "pubspec.yaml").read_bytes()
            yaz(app / "assets/data/ayarlar.json", {"koru": True})
            out = io.StringIO()
            with redirect_stdout(out):
                self.assertEqual(esitle(veri, app), 1)
            self.assertIn("::warning::yeni", out.getvalue())
            hedef = app / "assets/data"
            idx = json.loads((hedef / "index.json").read_text())
            self.assertEqual(idx["universities"], [{"id": "a"}])
            self.assertEqual(idx["updated"], "test")
            self.assertEqual((hedef / "a/menu.json").read_bytes(), (veri / "a/menu.json").read_bytes())
            self.assertEqual((hedef / "a/photos/index.json").read_bytes(), (veri / "a/photos/index.json").read_bytes())
            self.assertFalse((hedef / "yeni").exists())
            self.assertFalse((hedef / "indexte_yok").exists())
            self.assertFalse((hedef / "dishes").exists())
            self.assertEqual(list(hedef.rglob("*.jpg")), [])
            self.assertEqual((app / "pubspec.yaml").read_bytes(), pubspec)
            self.assertEqual(json.loads((hedef / "ayarlar.json").read_text()), {"koru": True})

    def test_hiyerarsi_ve_yorum_tirnaklar(self):
        metin = ("assets:\n  - assets/data/sahte/\nflutter:\n  uses-material-design: true\n  assets:\n"
                 "    # açıklama\n    - 'assets/data/a/'\n    - assets/data/b/ # açıklama\n"
                 "    - assets/data/c/menu.json\n  fonts:\n    - assets/data/sahte2/\n")
        self.assertEqual(asset_klasorleri(metin), {"assets/data/a/", "assets/data/b/"})

    def test_zorunlu_menu_yoksa_hicbir_hedef_degismez(self):
        with tempfile.TemporaryDirectory() as d:
            veri, app = self.hazirla(d)
            (app / "pubspec.yaml").write_text("flutter:\n  assets:\n    - assets/data/a/\n    - assets/data/yeni/\n")
            yaz(app / "assets/data/a/menu.json", {"eski": True})
            yaz(app / "assets/data/index.json", {"eski": True})
            hedef = app / "assets/data"
            eski = {p: p.read_bytes() for p in hedef.rglob("*.json")}
            (veri / "yeni/menu.json").unlink()
            with self.assertRaises(FileNotFoundError):
                esitle(veri, app)
            self.assertEqual({p: p.read_bytes() for p in hedef.rglob("*.json")}, eski)

    def test_opsiyonel_foto_indeksi_olmayabilir(self):
        with tempfile.TemporaryDirectory() as d:
            veri, app = self.hazirla(d)
            (veri / "a/photos/index.json").unlink()
            self.assertEqual(esitle(veri, app), 1)
            self.assertFalse((app / "assets/data/a/photos/index.json").exists())

    def test_gecersiz_ve_yinelenen_kimlik_yayinlanmaz(self):
        for kimlikler in (("../disari",), ("a", "a")):
            with self.subTest(kimlikler=kimlikler), tempfile.TemporaryDirectory() as d:
                veri, app = self.hazirla(d)
                yaz(veri / "index.json", {"universities": [{"id": k} for k in kimlikler]})
                with self.assertRaises(ValueError):
                    esitle(veri, app)
                self.assertFalse((app / "assets/data").exists())


class AtomikYayinTesti(unittest.TestCase):
    def test_gecici_dosyalar_tam_hazirlanmadan_hedef_degismez(self):
        with tempfile.TemporaryDirectory() as d:
            menu, idx = Path(d) / "menu.json", Path(d) / "index.json"
            menu.write_bytes(b"eski menu")
            idx.write_bytes(b"eski index")
            with self.assertRaises(TypeError):
                birlikte_yayinla([(menu, b"yeni"), (idx, None)])
            self.assertEqual(menu.read_bytes(), b"eski menu")
            self.assertEqual(idx.read_bytes(), b"eski index")
            self.assertEqual(list(Path(d).glob(".robot-*")), [])

    def test_index_replace_hatasinda_yeni_menu_silinir_eski_index_kalir(self):
        with tempfile.TemporaryDirectory() as d:
            menu, idx = Path(d) / "menu.json", Path(d) / "index.json"
            idx.write_bytes(b"eski index")
            replace = os.replace
            def kesinti(kaynak, hedef):
                if str(hedef) == str(idx):
                    raise OSError("disk testi")
                replace(kaynak, hedef)
            with patch("yemekhane.depolama.os.replace", side_effect=kesinti):
                with self.assertRaises(OSError):
                    birlikte_yayinla([(menu, b"yeni menu"), (idx, b"yeni index")])
            self.assertFalse(menu.exists())
            self.assertEqual(idx.read_bytes(), b"eski index")


if __name__ == "__main__":
    unittest.main()
