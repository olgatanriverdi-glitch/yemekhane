import os
import unittest
from datetime import date

from yemekhane.universities.aybu import AnkaraYildirimBeyazit, saat_ayikla, sayfa_menu, ucret_ayikla, yemek_ogesi
from yemekhane.universities.base import saat_duzenle
from yemekhane.universities.hacettepe import HacettepeUniversitesi, servis_saatleri, sayfa_gun, yemek_adi

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def oku(ad):
    with open(os.path.join(FIX, ad), "rb") as f:
        return f.read()


class HacettepeTesti(unittest.TestCase):
    def test_gun_bolumleri(self):
        g = sayfa_gun(oku("hacettepe_gun.html").decode("utf-8"))
        self.assertEqual(set(g), {"breakfast", "lunch", "dinner", "vegetarian"})
        self.assertEqual([o["name"] for o in g["lunch"]["items"]], ["Alaca Çorbası", "Kaşarlı Kıymalı Karnabahar", "Soslu Makarna", "Meyve"])
        self.assertEqual(g["lunch"]["kcal"], 200 + 320 + 375 + 130)
        self.assertIn("Etsiz Karnabahar", [o["name"] for o in g["vegetarian"]["items"]])
        self.assertEqual(g["breakfast"]["items"][0], {"name": "Çay"})
        self.assertNotIn("kcal", g["breakfast"])               # kahvaltıda kalori yok

    def test_planlanmadi_gunu_bos(self):
        self.assertEqual(sayfa_gun(oku("hacettepe_bos.html").decode("utf-8")), {})

    def test_sadece_kahvalti_olan_gun_menu_sayilmaz(self):
        sadece_kahvalti = oku("hacettepe_gun.html").decode("utf-8")
        import re
        sadece_kahvalti = re.sub(r'<section id="(ogle|aksam|vegan)".*?</section>', "", sadece_kahvalti, flags=re.S)
        self.assertEqual(set(sayfa_gun(sadece_kahvalti)), {"breakfast"})
        u = HacettepeUniversitesi(lambda url: sadece_kahvalti.encode("utf-8"), bugun=date(2026, 11, 1), bekle=0)
        self.assertEqual(u.menuler(), {})

    def test_kisaltma(self):
        self.assertEqual(yemek_adi("Kaş. Kıy. Karnabahar"), "Kaşarlı Kıymalı Karnabahar")

    def test_tarih_tarama_ve_durma(self):
        istekler = []

        def sahte(url):
            istekler.append(url)
            tarih = url.split("date=")[1][:10]
            return oku("hacettepe_gun.html" if tarih <= "2026-10-12" else "hacettepe_bos.html")
        u = HacettepeUniversitesi(sahte, bugun=date(2026, 10, 10), bekle=0)
        m = u.menuler()
        self.assertEqual(sorted(m), ["2026-10-08", "2026-10-09", "2026-10-10", "2026-10-11", "2026-10-12"])
        self.assertLess(len(istekler), 25)                     # menü bitince taramayı bırakır
        self.assertEqual(u.fiyatlar(), [])


class AybuTesti(unittest.TestCase):
    def test_haftalik_menu_ve_aralik_disi_gunler(self):
        m = sayfa_menu(oku("aybu_menu.html").decode("utf-8"))
        # ilk hafta 01-02 Ekim: Pzt-Çar sekmeleri boş / aralık dışı
        self.assertEqual(sorted(m)[:3], ["2026-10-01", "2026-10-02", "2026-10-05"])
        self.assertEqual([o["name"] for o in m["2026-10-05"]["items"]], ["Brokoli Çorba", "Tavuk Kanat / Patates Kızartma", "Soslu Makarna", "Ayran"])
        self.assertEqual(m["2026-10-05"]["kcal"], 150 + 495 + 306 + 152)

    def test_oge_ve_yazim_hatasi(self):
        self.assertEqual(yemek_ogesi("Bezelye Yemeği 165 kkakl"), {"name": "Bezelye Yemeği", "kcal": 165})
        self.assertEqual(yemek_ogesi("Yoğurtlu Mantı Makarna 235\xa0 kkal"), {"name": "Yoğurtlu Mantı Makarna", "kcal": 235})
        self.assertEqual(yemek_ogesi("Şeh. Pirinç Pilavı 342 kkal"), {"name": "Şehriyeli Pirinç Pilavı", "kcal": 342})
        self.assertIsNone(yemek_ogesi("<br>"))

    def test_birlesik_ve_fiyat(self):
        def sahte(url):
            if "10423" in url:
                return oku("aybu_vejetaryen.html")
            if "10304" in url:
                return oku("aybu_ucret.html")
            return oku("aybu_menu.html")
        u = AnkaraYildirimBeyazit(sahte)
        m = u.menuler()
        self.assertIn("vegetarian", m["2026-10-01"]["lunch"] and m["2026-10-01"] or {})
        self.assertEqual(m["2026-10-05"]["vegetarian"]["items"][1]["name"], "Patates Oturtma")
        self.assertEqual(u.fiyatlar(), [{"label": "Öğrenci (Öğle Yemeği)", "tl": 50}])
        self.assertEqual(ucret_ayikla(oku("aybu_ucret.html").decode("utf-8"))[0]["tl"], 50)


class SaatTesti(unittest.TestCase):
    def test_saat_duzenle(self):
        self.assertEqual(saat_duzenle("11.30-13.30"), "11:30–13:30")
        self.assertEqual(saat_duzenle("Servis 11:30 - 14:00 arası"), "11:30–14:00")
        self.assertIsNone(saat_duzenle("saat yok"))

    def test_hacettepe_servis_saatleri(self):
        s = servis_saatleri(oku("hacettepe_gun.html").decode("utf-8"))
        self.assertEqual(s["lunch"], "11:30–14:00")
        self.assertEqual(s["dinner"], "17:00–19:00")
        u = HacettepeUniversitesi(lambda url: oku("hacettepe_gun.html"), bugun=date(2026, 10, 5), bekle=0)
        u.menuler()
        self.assertEqual(u.saatler()["vegetarian"], "11:30–14:00")      # vegan öğle saatinde

    def test_aybu_saat(self):
        self.assertEqual(saat_ayikla(oku("aybu_ucret.html").decode("utf-8"))["lunch"], "11:30–13:30")

    def test_build_saat_bilgisi_varsayilan_ve_kesin(self):
        from yemekhane.build import saat_bilgisi
        from yemekhane.universities.base import Universite

        class Bos(Universite):
            pass

        class Kesin(Universite):
            def saatler(self):
                return {"lunch": "11:30–13:30"}
        b = saat_bilgisi(Bos(), ["lunch", "dinner", "vegetarian"])
        self.assertEqual(b["lunch"], {"t": "11:00–14:00", "approx": True})
        self.assertEqual(b["dinner"], {"t": "17:00–19:00", "approx": True})
        self.assertNotIn("vegetarian", b)
        k = saat_bilgisi(Kesin(), ["lunch", "dinner"])
        self.assertEqual(k["lunch"], {"t": "11:30–13:30", "approx": False})
        self.assertTrue(k["dinner"]["approx"])
