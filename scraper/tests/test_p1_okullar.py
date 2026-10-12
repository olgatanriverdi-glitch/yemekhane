"""P1 partisi: Sakarya, Çukurova, Bursa Uludağ, Pamukkale, Gaziantep eklentileri. Fixture'lar okul sitelerinden alınmış gerçek (kırpılmış) parçalardır; ağ kullanılmaz."""
import os
import unittest
from datetime import date

from yemekhane.universities import KAYITLI, cukurova, gaziantep, pamukkale, sakarya, uludag

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def oku(ad):
    with open(os.path.join(FIX, ad), "rb") as f:
        return f.read()


def adlar(gun):
    return [o["name"] for o in gun["items"]]


class SakaryaTesti(unittest.TestCase):
    def test_aylik_kartlar(self):
        m = sakarya.sayfa_menu(oku("sakarya_ekim.html").decode("utf-8"), date(2026, 10, 11))
        self.assertEqual(len(m), 23)
        self.assertEqual(sorted(m)[0], "2026-09-28")           # ay başındaki önceki ay kartları doğru aya düşer
        self.assertEqual(sorted(m)[-1], "2026-10-30")
        gun = m["2026-09-29"]["lunch"]
        self.assertEqual(adlar(gun), ["Köylü Çorba", "Garnitürlü Et Döner", "Etsiz Patlıcan Yemeği (Merkez Yemekhanede)",
                                      "Fırında Tavuk Baget (Garnitür)", "Sade Pirinç Pilavı", "Ayran"])
        self.assertEqual(gun["items"][0], {"name": "Köylü Çorba", "kcal": 198})
        self.assertNotIn("kcal", gun["items"][2])            # kalori 0 -> kalorisiz
        self.assertNotIn("kcal", gun)                        # eksik kalemli günde toplam yazılmaz

    def test_sinif_iki_ay_ister(self):
        istekler = []

        def indir(url, veri=None):
            istekler.append(veri)
            if veri["month"] == 11:
                raise OSError("kasım yok")
            return oku("sakarya_ekim.html")
        u = sakarya.SakaryaUniversitesi(indir, bugun=date(2026, 10, 11))
        self.assertEqual(len(u.menuler()), 23)
        self.assertEqual([i["month"] for i in istekler], [10, 11])
        self.assertEqual(istekler[0]["diyetMi"], "false")


class CukurovaTesti(unittest.TestCase):
    def test_aylik_liste(self):
        m = cukurova.sayfa_menu(oku("cukurova_ana.html"))
        self.assertIn("2026-10-05", m)
        gun = m["2026-10-05"]["lunch"]
        self.assertEqual(adlar(gun), ["Sebzeli Dalyan Köfte", "Soslu Makarna", "Pancarlı Havuç Salatası", "Türlü Turşu"])
        self.assertEqual(gun["kcal"], 670)                   # sayfadaki 'Toplam 670 Kalori' ile aynı
        self.assertEqual(m["2026-10-12"]["lunch"]["kcal"], 661)
        self.assertEqual(adlar(m["2026-10-12"]["lunch"])[0], "Soslu Dalyan Köfte + Patates Püresi")   # Windows-1254 çözümü

    def test_sinif(self):
        self.assertGreater(len(cukurova.CukurovaUniversitesi(lambda url: oku("cukurova_ana.html")).menuler()), 10)


class UludagTesti(unittest.TestCase):
    def test_ogrenci_ve_vejetaryen(self):
        m = uludag.sayfa_menu(oku("uludag_yemek.html").decode("utf-8"))
        gun = m["2026-10-01"]
        self.assertEqual(adlar(gun["lunch"]), ["Etli Biber Dolma / Yoğurt", "Sütlü Domates Çorba", "Peynirli Puf Böreği", "Vişne Komposto"])   # alerjen no. atılır
        self.assertEqual(set(gun), {"lunch", "dinner", "vegetarian"})
        self.assertEqual(adlar(gun["vegetarian"])[0], "Sütlü Domates Çorba")
        self.assertNotIn("kcal", gun["lunch"])

    def test_tatil(self):
        m = uludag.sayfa_menu(
            '<h5 class="mt-n1 mb-0" style="x">Öğrenci Yemek Menüsü</h5><h5 class="mt-n1 mb-0">Öğle Yemeği</h5>'
            '<div class="card h-100"><small>29.10.2026</small><p>RESMİ TATİL</p></div>')
        self.assertEqual(m, {"2026-10-29": {"lunch": {"items": [], "note": "Resmi tatil"}}})

    def test_personel_alinmaz(self):
        m = uludag.sayfa_menu('<h5 class="mt-n1 mb-0">Personel Yemek Menüsü</h5><h5 class="mt-n1 mb-0">Öğle Yemeği</h5>'
                              '<div class="card h-100"><small>12.10.2026</small><p>Tantuni</p></div>')
        self.assertEqual(m, {})


class PamukkaleTesti(unittest.TestCase):
    def test_hafta(self):
        m = pamukkale.sayfa_menu(oku("pamukkale_hafta.html").decode("utf-8"))
        self.assertEqual(sorted(m), ["2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16"])
        self.assertEqual(adlar(m["2026-10-12"]["lunch"]), ["Tarhana Çorbası", "Etli Nohut", "Garnitürlü Pilav", "Haydari"])
        self.assertEqual(m["2026-10-12"]["lunch"]["kcal"], 150 + 346 + 361 + 132)       # sayfadaki toplam 989
        self.assertIn("vegetarian", m["2026-10-12"])
        self.assertNotIn("Turuncu", str(m))                  # personel/à la carte salonları alınmaz

    def test_sinif_birikimli(self):
        self.assertTrue(pamukkale.PamukkaleUniversitesi().birikimli)


class GaziantepTesti(unittest.TestCase):
    def test_aylik_tablo(self):
        m = gaziantep.sayfa_menu(oku("gaziantep_liste.html").decode("utf-8"))
        self.assertEqual(len(m), 22)
        self.assertNotIn("2026-10-03", m)                    # hafta sonu hücresi boş
        gun = m["2026-10-01"]["lunch"]
        self.assertEqual(adlar(gun), ["Mercimek Çorba", "Garnitürlü Fırın Tavuk But", "Soslu Makarna", "Ayran"])
        self.assertEqual(gun["items"][1], {"name": "Garnitürlü Fırın Tavuk But", "kcal": 670})
        self.assertEqual(gun["kcal"], 166 + 670 + 325 + 74)

    def test_parantez_icindeki_ek(self):
        self.assertEqual(gaziantep.yemek_ogesi("MEYVE (ŞEFTALİ 72 kcal)"), {"name": "Meyve (Şeftali)", "kcal": 72})
        self.assertEqual(gaziantep.yemek_ogesi("AYRAN (74 kcal)"), {"name": "Ayran", "kcal": 74})
        self.assertEqual(gaziantep.yemek_ogesi("MEVSİM SALATA"), {"name": "Mevsim Salata"})


class KayitTesti(unittest.TestCase):
    def test_kayitli(self):
        idler = [u.id for u in KAYITLI]
        for i in ("sakarya", "cukurova", "uludag", "pamukkale", "gaziantep"):
            self.assertIn(i, idler)
        self.assertEqual(len(idler), len(set(idler)))


if __name__ == "__main__":
    unittest.main()
