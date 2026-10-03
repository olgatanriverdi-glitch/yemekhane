import os
import unittest

from yemekhane.universities.gazi import GaziUniversitesi, sayfa_menu, ucret_ayikla, yemek_adi

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def oku(ad):
    with open(os.path.join(FIX, ad), "rb") as f:
        return f.read()


class GaziTesti(unittest.TestCase):
    def setUp(self):
        self.m = sayfa_menu(oku("gazi_menu.html").decode("utf-8"))

    def test_gunler_ve_tatil(self):
        self.assertEqual(len(self.m), 18)
        self.assertIn("2026-10-05", self.m)
        self.assertNotIn("2026-10-28", self.m)       # TATİL
        self.assertNotIn("2026-10-29", self.m)

    def test_ogle_menusu(self):
        g = self.m["2026-10-06"]["lunch"]
        self.assertEqual([o["name"] for o in g["items"]], ["Mantar Çorba", "Tavuklu Çökertme Kebabı", "Nohutlu Pirinç Pilavı", "Trileçe"])
        self.assertEqual(g["kcal"], 1250)

    def test_vejetaryen(self):
        v = self.m["2026-10-06"]["vegetarian"]["items"]
        self.assertEqual([o["name"] for o in v], ["Mantar Çorba", "Etsiz Karnabahar", "Nohutlu Pirinç Pilavı", "Trileçe"])
        # ortak yan yemek etliyse (Kıymalı Kol Böreği) vejetaryen menüye girmez
        v = self.m["2026-10-05"]["vegetarian"]["items"]
        self.assertEqual([o["name"] for o in v], ["Ezogelin Çorba", "Patatesli Kol Böreği", "Meyve"])

    def test_kisaltma_ve_etsiz_ana(self):
        self.assertEqual(yemek_adi("Zyt.lı Pırasa"), "Zeytinyağlı Pırasa")
        self.assertEqual(yemek_adi("Şeh.li Bulgur Pilavı"), "Şehriyeli Bulgur Pilavı")
        self.assertEqual(yemek_adi("Tavuk Baget/Pat.Kızartma"), "Tavuk Baget/Patates Kızartma")
        self.assertEqual(yemek_adi("*Etsiz Ispanak"), "Etsiz Ispanak")
        # '*' satırı boş, ana yemek zaten etsiz ise vejetaryen menü o günün tamamıdır
        v = self.m["2026-10-30"]["vegetarian"]["items"]
        self.assertEqual(v[1]["name"], "Etsiz Nohut")

    def test_fiyat_ve_birlesik(self):
        self.assertEqual(ucret_ayikla(oku("gazi_ucret.html").decode("utf-8")), [{"label": "Öğrenci (Öğle Yemeği)", "tl": 50}])
        u = GaziUniversitesi(lambda url: oku("gazi_ucret.html") if "264777" in url else oku("gazi_menu.html"))
        self.assertEqual(len(u.menuler()), 18)
        self.assertEqual(u.fiyatlar()[0]["tl"], 50)
