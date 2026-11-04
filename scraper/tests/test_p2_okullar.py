"""P2 partisi: Süleyman Demirel, Aydın Adnan Menderes, İnönü, Karabük eklentileri. Fixture'lar okul sitelerinden alınmış gerçek (kırpılmış) parçalardır; ağ kullanılmaz."""
import json
import os
import unittest
from datetime import date

from yemekhane.universities import KAYITLI, adu, inonu, karabuk, sdu

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def oku(ad):
    with open(os.path.join(FIX, ad), "rb") as f:
        return f.read()


def adlar(ogun):
    return [o["name"] for o in ogun["items"]]


class SduTesti(unittest.TestCase):
    def test_aylik_tablo(self):
        m = sdu.sayfa_menu(oku("sdu_liste.html").decode("utf-8"))
        self.assertEqual(sorted(m), ["2026-10-01", "2026-10-02", "2026-10-20", "2026-10-21", "2026-10-27"])      # '-' günleri (28, 29 Ekim) atılır
        gun = m["2026-10-01"]
        self.assertEqual(adlar(gun["lunch"]), ["Yüzük Çorbası", "Pilav Üstü Tavuk Döner", "Çoban Salatası", "Kase Ayran"])
        self.assertEqual(gun["lunch"]["kcal"], 1000)
        self.assertEqual(set(gun), {"lunch", "dinner"})

    def test_ogle_aksam_farkli(self):
        gun = sdu.sayfa_menu(oku("sdu_liste.html").decode("utf-8"))["2026-10-20"]
        self.assertEqual(adlar(gun["lunch"])[:2], ["Toyga Çorbası", "Piliç Roti"])
        self.assertEqual(adlar(gun["dinner"])[:2], ["Toyga Çorbası", "Tavuk Döner"])

    def test_sinif(self):
        self.assertEqual(len(sdu.SuleymanDemirel(lambda url: oku("sdu_liste.html")).menuler()), 5)


class AduTesti(unittest.TestCase):
    def test_iki_hafta_karti(self):
        m = adu.sayfa_menu(oku("adu_liste.html").decode("utf-8"))
        self.assertEqual(sorted(m), ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-30"])      # boş 'Önümüzdeki Hafta' ve 29 Ekim (tatil) yok
        self.assertEqual(adlar(m["2026-10-26"]["lunch"]), ["Domates Çorbası", "Tavuk Döner-Parmak Patates", "Pirinç Pilavı", "Ayran"])
        self.assertNotIn("kcal", m["2026-10-26"]["lunch"])

    def test_sinif_birikimli(self):
        u = adu.AydinAdnanMenderes(lambda url: oku("adu_liste.html"))
        self.assertTrue(u.birikimli)
        self.assertEqual(len(u.menuler()), 4)


class InonuTesti(unittest.TestCase):
    def setUp(self):
        self.gunler = json.loads(oku("inonu_gunler.json").decode("utf-8"))

    def test_gun_menu(self):
        gun = inonu.gun_menu(self.gunler["2026-10-27"])
        self.assertEqual(adlar(gun), ["Tavuk İncik", "Salçalı Makarna", "Ayran", "Şekerpare"])
        self.assertEqual(gun["items"][0], {"name": "Tavuk İncik", "kcal": 250})
        self.assertEqual(gun["kcal"], 250 + 335 + 75 + 540)
        self.assertIsNone(inonu.gun_menu([]))

    def test_ozel_menu_alinmaz(self):
        self.assertIsNone(inonu.gun_menu([{"food_name": "Diyet Tabağı", "food_type": "D", "food_desc": "300 kalori"}]))

    def test_sinif_gun_gun_ister(self):
        istekler = []

        def indir(url):
            istekler.append(url)
            tarih = url.rsplit("=", 1)[1]
            if tarih == "2026-10-29":
                raise OSError("zaman aşımı")            # tek günlük hata menüyü düşürmez
            return json.dumps(self.gunler.get(tarih, [])).encode()
        m = inonu.InonuUniversitesi(indir, bugun=date(2026, 10, 27)).menuler()
        self.assertEqual(sorted(m), ["2026-10-27", "2026-10-30"])
        self.assertEqual(len(istekler), inonu.GERI + inonu.ILERI + 1)
        self.assertTrue(istekler[0].endswith("2026-10-25"))


class KarabukTesti(unittest.TestCase):
    def test_pdf_baglantisi(self):
        self.assertEqual(karabuk.pdf_baglantisi(oku("karabuk_sks.html").decode("utf-8")),
                         "https://sks.karabuk.edu.tr/yuklenen/dosyalar/1261102026094350.pdf")

    def test_aylik_pdf(self):
        m = karabuk.pdf_menu(oku("karabuk_ekim.pdf"))
        self.assertEqual(len(m), 22)
        self.assertEqual(sorted(m)[0], "2026-10-01")
        gun = m["2026-10-05"]["lunch"]
        self.assertEqual(adlar(gun), ["Mercimek Çorba", "Bezelye", "Tavuk Adana", "Bulgur Pilavı", "Cacık"])      # 'A(350)/B(435)' iki kalem
        self.assertEqual(gun["items"][1], {"name": "Bezelye", "kcal": 350})
        self.assertEqual(gun["kcal"], 175 + 350 + 435 + 290 + 120)

    def test_iki_satira_bolunen_ad(self):
        gun = karabuk.pdf_menu(oku("karabuk_ekim.pdf"))["2026-10-08"]["lunch"]
        self.assertIn("Nohutlu Pirinç Pilavı Üstü Tiftik Tavuk", adlar(gun))

    def test_tatil_ve_imza(self):
        m = karabuk.pdf_menu(oku("karabuk_ekim.pdf"))
        self.assertEqual(m["2026-10-29"], {"lunch": {"items": [], "note": "Resmi tatil"}})
        self.assertEqual(adlar(m["2026-10-30"]["lunch"])[-1], "İrmik Helvası")      # altındaki imza satırları menüye karışmaz

    def test_sinif(self):
        def indir(url):
            return oku("karabuk_sks.html") if url.endswith("index.aspx") else oku("karabuk_ekim.pdf")
        self.assertEqual(len(karabuk.KarabukUniversitesi(indir).menuler()), 22)


class KayitTesti(unittest.TestCase):
    def test_kayitli(self):
        idler = [u.id for u in KAYITLI]
        for i in ("sdu", "adu", "inonu", "karabuk"):
            self.assertIn(i, idler)
        self.assertEqual(len(idler), len(set(idler)))
