import io
import os
import tempfile
import unittest

from PIL import Image

from yemekhane.foto import FotoKutuphanesi, ana_yemek_anahtari, menu_anahtari


def jpeg(renk):
    b = io.BytesIO()
    Image.new("RGB", (64, 48), renk).save(b, "JPEG")
    return b.getvalue()


def menu(*adlar):
    return [{"name": a} for a in adlar]


A = menu("Tarhana Çorba", "Izgara Tavuk", "Soslu Makarna", "Meyve")
A_KCAL = [{"name": "TARHANA çorba", "kcal": 176}, {"name": "IZGARA  tavuk", "kcal": 700}, {"name": "Soslu Makarna", "kcal": 4}, {"name": "Meyve", "kcal": 80}]
B = menu("Mısır Çorba", "Izgara Tavuk", "Bulgur Pilavı", "Cacık")        # aynı ana yemek, farklı menü
C = menu("Yayla Çorba", "İzmir Köfte", "Bulgur Pilavı", "Haydari")


class FotoTesti(unittest.TestCase):
    def test_anahtar_yazimdan_bagimsiz(self):
        self.assertEqual(menu_anahtari(A), menu_anahtari(A_KCAL))
        self.assertEqual(ana_yemek_anahtari(A), ana_yemek_anahtari(B))
        self.assertNotEqual(menu_anahtari(A), menu_anahtari(B))

    def test_akis(self):
        with tempfile.TemporaryDirectory() as d:
            k = FotoKutuphanesi(d)
            self.assertIn("yeni", k.bugun_isle("2026-10-02", A, jpeg((200, 0, 0))))
            self.assertIn("aynı", k.bugun_isle("2026-10-02", A, jpeg((200, 0, 0))))
            # site fotoğrafı yenilenmeden ertesi gün: bayat, kaydedilmemeli
            self.assertIn("bayat", k.bugun_isle("2026-10-03", C, jpeg((200, 0, 0))))
            self.assertEqual(len(k.idx["menus"]), 1)
            # aynı menü başka günde tekrar: tam eşleşme, siteye gerek yok
            dosya, ykl = k.eslestir("2026-10-20", A_KCAL)
            self.assertTrue(dosya.startswith("photos/lib/")); self.assertFalse(ykl)
            # yalnızca ana yemek aynı: benzer
            dosya, ykl = k.eslestir("2026-10-21", B)
            self.assertTrue(dosya); self.assertTrue(ykl)
            # hiç ilgisi yok
            self.assertEqual(k.eslestir("2026-10-22", C), (None, False))
            # aynı menüye site farklı bir fotoğraf gönderirse kütüphane güncellenir
            self.assertIn("güncellendi", k.bugun_isle("2026-10-25", A, jpeg((0, 200, 0))))
            k.kaydet("2026-09-01")
            k2 = FotoKutuphanesi(d)
            self.assertEqual(len(k2.idx["menus"]), 1)
            self.assertTrue(os.path.exists(os.path.join(d, "photos", "lib", menu_anahtari(A) + ".jpg")))


if __name__ == "__main__":
    unittest.main()
