import os
import unittest

from yemekhane.model import baslik_yap, excel_tarih, yemek_ogesi
from yemekhane.universities.ankara import AnkaraUniversitesi, fiyat_ayikla, xlsx_menu

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def oku(ad, mod="rb"):
    with open(os.path.join(FIX, ad), mod) as f:
        return f.read()


class ModelTesti(unittest.TestCase):
    def test_baslik(self):
        self.assertEqual(baslik_yap("KIRMIZI MERCİMEK ÇORBA"), "Kırmızı Mercimek Çorba")
        self.assertEqual(baslik_yap("IZGARA TAVUK/PATATES"), "Izgara Tavuk/Patates")

    def test_tarih(self):
        self.assertEqual(excel_tarih(46266), "2026-09-01")

    def test_oge(self):
        self.assertEqual(yemek_ogesi("YAYLA ÇORBA (168 kkal)"), {"name": "Yayla Çorba", "kcal": 168})
        self.assertEqual(yemek_ogesi("MISIR ÇORBA"), {"name": "Mısır Çorba"})


class AnkaraTesti(unittest.TestCase):
    def test_ogle(self):
        g = xlsx_menu(oku("ankara_ogle.xlsx"))
        self.assertIn("2026-09-01", g)
        ilk = g["2026-09-01"]
        self.assertEqual(len(ilk["items"]), 4)
        self.assertEqual(ilk["kcal"], 1910)

    def test_aksam_ve_vejetaryen(self):
        self.assertGreater(len(xlsx_menu(oku("ankara_aksam.xlsx"))), 20)
        self.assertGreater(len(xlsx_menu(oku("ankara_vejetaryen.xlsx"))), 1)

    def test_fiyat(self):
        f = fiyat_ayikla(oku("ankara_sks.html").decode("utf-8", "ignore"))
        self.assertEqual(f[0], {"label": "Öğrenci (Öğle Yemeği)", "tl": 50})

    def test_birlesik(self):
        dosyalar = {"aylikmenu": "ankara_ogle.xlsx", "aksammenu": "ankara_aksam.xlsx", "vejetaryenmenu": "ankara_vejetaryen.xlsx"}

        def sahte(url):
            for k, v in dosyalar.items():
                if k in url:
                    return oku(v)
            return oku("ankara_sks.html")
        m = AnkaraUniversitesi(sahte).menuler()
        self.assertEqual(set(m["2026-10-05"]), {"lunch", "dinner", "vegetarian"} & set(m["2026-10-05"]))
        self.assertIn("dinner", m["2026-10-02"])


class TarihDuzeltTesti(unittest.TestCase):
    def test_okul_hatasi(self):
        from yemekhane.model import tarih_duzelt
        g, d = tarih_duzelt(["2026-10-11", "2026-04-12", "2026-04-13", "2026-04-14", "2026-10-15"])
        self.assertEqual(g, ["2026-10-11", "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15"])
        self.assertEqual(len(d), 3)
        # ay geçişi bozulmamalı
        self.assertEqual(tarih_duzelt(["2026-10-31", "2026-11-01"])[0], ["2026-10-31", "2026-11-01"])
        # hafta içi atlamalı (öğle) listede normal gelen tarihlere dokunma
        self.assertEqual(tarih_duzelt(["2026-10-02", "2026-10-05", "2026-10-06"])[1], [])

    def test_aksam_dosyasi(self):
        g = xlsx_menu(oku("ankara_aksam.xlsx"))
        for gun in range(12, 19):
            self.assertIn("2026-10-%02d" % gun, g)
        self.assertFalse([t for t in g if t.startswith("2026-04")])


class OcrTesti(unittest.TestCase):
    def test_liste(self):
        from yemekhane.ocr import liste_ayikla, tarih_ayikla
        m = "► TARHANA ÇORBA (176 kkal)\n\n► IZGARA TAVUK\nBAGET/PATATES GARNİTÜR (756\nkkal)\n\n► MEYVE (80 kkal)\n"
        self.assertEqual(liste_ayikla(m), [{"name": "Tarhana Çorba", "kcal": 176}, {"name": "Izgara Tavuk Baget/Patates Garnitür", "kcal": 756}, {"name": "Meyve", "kcal": 80}])
        self.assertEqual(tarih_ayikla("02.10.2026 Tarihli Yemek Listesi"), "2026-10-02")
        self.assertIsNone(tarih_ayikla("tarih yok"))


if __name__ == "__main__":
    unittest.main()
