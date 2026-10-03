import io
import os
import tempfile
import unittest
from datetime import date, timedelta

from PIL import Image

from yemekhane import dishes as D


def jpeg():
    b = io.BytesIO()
    Image.new("RGB", (200, 100), (200, 50, 50)).save(b, "JPEG")
    return b.getvalue()


def sahte_ara(sonuclar):
    cagrilar = []

    def ara(sorgu, indir):
        cagrilar.append(sorgu)
        return sonuclar.get(sorgu, [])
    ara.cagrilar = cagrilar
    return ara


def aday(baslik, **kw):
    return dict({"url": "http://x/" + baslik, "baslik": baslik, "aciklama": "", "yazar": "A", "lisans": "CC BY", "sayfa": "http://p", "kaynak": "Wikimedia Commons"}, **kw)


class SorguTesti(unittest.TestCase):
    def test_sorgular(self):
        self.assertEqual(D.sorgular("Fesleğenli Domates Çorba"), ["Fesleğenli Domates Çorba", "Domates Çorba"])
        self.assertEqual(D.sorgular("Izgara Tavuk But/Patates Garnitür")[0], "Izgara Tavuk But")
        self.assertEqual(D.sorgular("Meyve"), ["Meyve tabağı", "Fruit platter"])

    def test_ilgili(self):
        self.assertFalse(D.ilgili_mi("Mantar Çorba", "Cream Mushroom soup"))       # 'mantar' karşılığı yok: bilerek katı (İngilizce arama ICEREN ile yapılır)
        self.assertTrue(D.ilgili_mi("Ezogelin Çorba", "Ezogelin soup, bread"))
        self.assertTrue(D.ilgili_mi("Domates Çorba", "Domates çorbası"))
        self.assertFalse(D.ilgili_mi("Mantar Çorba", "Riblja Corba 2008.JPG"))
        self.assertFalse(D.ilgili_mi("Kakaolu Puding", "Puding County, Guizhou"))

    def test_anahtar_yazimdan_bagimsiz(self):
        self.assertEqual(D.anahtar("MERCİMEK  Çorba"), D.anahtar("Mercimek Çorba"))


class KutuphaneTesti(unittest.TestCase):
    def kur(self, d, sonuclar, **kw):
        ara = sahte_ara(sonuclar)
        yf = D.YemekFotolari(d, indir=lambda url, *a: jpeg(), saglayicilar=[ara], bekle=0, **kw)
        return yf, ara

    def test_bul_sakla_tekrar_arama(self):
        with tempfile.TemporaryDirectory() as d:
            yf, ara = self.kur(d, {"Mercimek Çorba": [aday("Alakasız resim.jpg"), aday("Mercimek çorbası.jpg")]})
            self.assertEqual(yf.dosya("Mercimek Çorba"), "dishes/%s.jpg" % D.anahtar("Mercimek Çorba"))
            yf.kaydet()
            self.assertEqual(Image.open(os.path.join(d, D.anahtar("Mercimek Çorba") + ".jpg")).size, (D.BOYUT, D.BOYUT))
            # ikinci kez aynı yemek (başka yazımla): arama yapılmaz
            n = len(ara.cagrilar)
            self.assertTrue(yf.dosya("MERCİMEK ÇORBA"))
            self.assertEqual(len(ara.cagrilar), n)
            # yeni kütüphane nesnesi diskten okur
            yf2, ara2 = self.kur(d, {})
            self.assertTrue(yf2.dosya("Mercimek Çorba"))
            self.assertEqual(ara2.cagrilar, [])

    def test_bulunamayan_sonra_tekrar_denenir(self):
        with tempfile.TemporaryDirectory() as d:
            yf, ara = self.kur(d, {}, bugun=date(2026, 10, 1))
            self.assertIsNone(yf.dosya("Frambuaz Rüyası"))
            n = len(ara.cagrilar)
            self.assertIsNone(yf.dosya("Frambuaz Rüyası"))
            self.assertEqual(len(ara.cagrilar), n)                     # bekleme süresinde yeniden aranmaz
            yf.kaydet()
            yf2, ara2 = self.kur(d, {"Frambuaz Rüyası": [aday("Frambuaz rüyası.jpg")]}, bugun=date(2026, 10, 1) + timedelta(days=D.BASARISIZ_BEKLE + 1))
            self.assertTrue(yf2.dosya("Frambuaz Rüyası"))

    def test_menuye_ekle_ve_atla(self):
        with tempfile.TemporaryDirectory() as d:
            yf, _ = self.kur(d, {"Ayran": [], "Ezogelin Çorba": [aday("Ezogelin soup.jpg")]})
            menu = {"2026-10-05": {"lunch": {"items": [{"name": "Ezogelin Çorba"}, {"name": "29 Ekim Cumhuriyet Bayramı"}]}}}
            yf.menulere_ekle(menu)
            ogeler = menu["2026-10-05"]["lunch"]["items"]
            self.assertIn("img", ogeler[0])
            self.assertNotIn("img", ogeler[1])
            self.assertEqual(ogeler[0]["key"], D.anahtar("Ezogelin Çorba"))     # yemek bazlı puanlama anahtarı
            self.assertNotIn("key", ogeler[1])
