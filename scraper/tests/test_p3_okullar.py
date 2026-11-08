"""P3: altı okulun gerçek HTML/PDF menülerinden alınmış ağsız fixture testleri.

HTML fixture'larında yalnızca menü bölümü bırakılmıştır. AKÜ tek sayfalık
PDF'i, gerçek font/metin kaynaklarını sınamak için değiştirilmeden saklanır.
Kaynaklar ve tarih aralıkları README'deki P3 bölümünde açıklanır.
"""
import os
import unittest

from yemekhane.universities import KAYITLI, aku, duzce, harran, mugla, trakya, yyu

FIX = os.path.join(os.path.dirname(__file__), "fixtures")
OKULLAR = (
    (mugla.MuglaSitkiKocman, "mugla_liste.html", 20),
    (aku.AfyonKocatepe, "aku_sks.html", 20),
    (trakya.TrakyaUniversitesi, "trakya_liste.html", 21),
    (harran.HarranUniversitesi, "harran_liste.html", 21),
    (yyu.VanYuzuncuYil, "yyu_hafta.html", 4),
    (duzce.DuzceUniversitesi, "duzce_liste.html", 22),
)


def oku(ad):
    with open(os.path.join(FIX, ad), "rb") as f:
        return f.read()


def metin(ad):
    return oku(ad).decode("utf-8")


def adlar(ogun):
    return [o["name"] for o in ogun["items"]]


class MuglaTesti(unittest.TestCase):
    def setUp(self):
        self.menu = mugla.sayfa_menu(metin("mugla_liste.html"))

    def test_kasim_gunleri(self):
        self.assertEqual(len(self.menu), 20)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-30"))
        self.assertNotIn("2026-11-06", self.menu)  # kaynak bu iş gününü yayınlamamış
        self.assertNotIn("2026-11-07", self.menu)  # hafta sonu için menü uydurulmaz

    def test_yemekler_ve_sifir_kalori(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Yayla Çorbası", "Etli Nohut", "Bulgur Pilavı", "Mor Lahana Turşusu"])
        self.assertNotIn("kcal", gun)  # kaynaktaki '0 cal' bilinmeyen toplamdır
        self.assertTrue(all("kcal" not in o for g in self.menu.values() for o in g["lunch"]["items"]))

    def test_kisaltmalar(self):
        self.assertIn("Pilav Üstü Et Kavurma", adlar(self.menu["2026-11-27"]["lunch"]))
        self.assertIn("Cevizli Erişte", adlar(self.menu["2026-11-26"]["lunch"]))
        self.assertTrue(all("." not in o["name"] for g in self.menu.values() for o in g["lunch"]["items"]))


class AkuTesti(unittest.TestCase):
    def setUp(self):
        self.menu = aku.pdf_menu(oku("aku_kasim.pdf"))

    def test_guncel_pdf_baglantisi(self):
        self.assertEqual(aku.pdf_baglantisi(metin("aku_sks.html")),
                         "https://skultur.aku.edu.tr/wp-content/uploads/sites/21/2025/08/KASIM-MENU-kalorili-2026.pdf")
        self.assertEqual(aku.pdf_baglantisi('<iframe src="/yeni-menu.pdf"></iframe>'),
                         "https://skultur.aku.edu.tr/yeni-menu.pdf")
        self.assertIsNone(aku.pdf_baglantisi('<a href="/faaliyet-raporu.pdf">Rapor</a>'))

    def test_dort_hafta(self):
        self.assertEqual(len(self.menu), 20)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-27"))
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for g in self.menu.values()))
        self.assertNotIn("2026-11-07", self.menu)
        self.assertNotIn("2026-11-30", self.menu)  # PDF'te bu tarih henüz yok

    def test_ilk_gunun_yemekleri_ve_kalorisi(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Ezogelin Çorba", "Piliç Roti", "Pirinç Pilavı", "Limonata"])
        self.assertEqual(gun["items"][1], {"name": "Piliç Roti", "kcal": 330})
        self.assertEqual(gun["kcal"], 925)

    def test_sutunlar_ve_haftalar_karismaz(self):
        gun = self.menu["2026-11-11"]["lunch"]
        self.assertEqual(adlar(gun), ["Kaşarlı Domates Çorba", "Çökertme Kebabı", "Sebzeli Pirinç Pilavı", "Kakaolu Puding"])
        self.assertEqual(gun["kcal"], 1095)
        self.assertEqual(adlar(self.menu["2026-11-27"]["lunch"]),
                         ["Tandır Çorba", "Barbunya", "Bulgur Pilavı", "Portakallı Revani"])
        self.assertEqual(self.menu["2026-11-27"]["lunch"]["kcal"], 1085)

    def test_metinsiz_pdf(self):
        self.assertEqual(aku.pdf_menu(b"%PDF-1.4\n%%EOF\n"), {})


class TrakyaTesti(unittest.TestCase):
    def setUp(self):
        self.menu = trakya.sayfa_menu(metin("trakya_liste.html"))

    def test_kasim_gunleri(self):
        self.assertEqual(len(self.menu), 21)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-30"))
        self.assertNotIn("2026-11-01", self.menu)
        self.assertNotIn("2026-11-07", self.menu)

    def test_yemekler_ve_ogun_toplami(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Düğün Çorba", "Etli Nohut", "Bulgur Pilavı", "Mevsim Salata"])
        self.assertEqual(gun["kcal"], 872)
        self.assertTrue(all("kcal" not in o for o in gun["items"]))

    def test_bes_kalem_ve_altbilgi(self):
        self.assertEqual(len(self.menu["2026-11-04"]["lunch"]["items"]), 5)
        self.assertEqual(adlar(self.menu["2026-11-30"]["lunch"]),
                         ["Düğün Çorba", "Etli Nohut", "Şehriyeli Pirinç Pilavı", "Yoğurt"])

    def test_bos_ve_tatil_karti(self):
        s = ('<div class="mitem col-md-5c"><div><h4>28.10.2026</h4></div></div>'
             '<div class="mitem col-md-5c"><div><h4>29.10.2026</h4>RESMİ TATİL</div></div>')
        self.assertEqual(trakya.sayfa_menu(s), {"2026-10-29": {"lunch": {"items": [], "note": "Resmi tatil"}}})


class HarranTesti(unittest.TestCase):
    def setUp(self):
        self.menu = harran.sayfa_menu(metin("harran_liste.html"))

    def test_kasim_ve_bos_ayrac_satirlari(self):
        self.assertEqual(len(self.menu), 21)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-30"))
        self.assertNotIn("2026-11-07", self.menu)
        self.assertTrue(all(len(g["lunch"]["items"]) == 5 for g in self.menu.values()))

    def test_secmeli_yemekler_toplanmaz(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Etli Taze Fasulye", "Nohut Yahni", "Bulgur Pilavı", "Ezogelin Çorba", "Meyve"])
        self.assertEqual([o["kcal"] for o in gun["items"]], [320, 280, 290, 290, 100])
        self.assertNotIn("kcal", gun)  # iki alternatif ana yemek birlikte toplanamaz

    def test_kalori_sonraki_gune_tasmaz(self):
        gun = self.menu["2026-11-03"]["lunch"]
        self.assertEqual(gun["items"][-1], {"name": "Kıbrıs Tatlısı", "kcal": 400})

    def test_tatil(self):
        s = ('<table><tr><td>SEÇMELİ ANA YEMEK</td></tr>'
             '<tr><td>29.10.2026</td>' + '<td>RESMİ TATİL</td>' * 5 + '</tr>'
             '<tr><td>PERŞEMBE</td>' + '<td>&nbsp;</td>' * 5 + '</tr></table>')
        self.assertEqual(harran.sayfa_menu(s), {"2026-10-29": {"lunch": {"items": [], "note": "Resmi tatil"}}})


class YyuTesti(unittest.TestCase):
    def setUp(self):
        self.menu = yyu.sayfa_menu(metin("yyu_hafta.html"))

    def test_yayinlanan_dort_gun(self):
        self.assertEqual(sorted(self.menu), ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05"])
        self.assertNotIn("2026-11-01", self.menu)
        self.assertTrue(yyu.VanYuzuncuYil().birikimli)

    def test_yemekler_ve_kalori(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Köy Çorba", "Etli Kuru Fasülye", "Şehriyeli Pirinç Pilavı", "Cacık"])
        self.assertEqual(gun["items"][0], {"name": "Köy Çorba", "kcal": 110})
        self.assertEqual(gun["kcal"], 719)
        self.assertEqual(self.menu["2026-11-03"]["lunch"]["kcal"], 1089)

    def test_bos_ve_gecersiz_tarih(self):
        s = ('<div class="card-food"><span>31 Kasım 2026</span><ul><li>Çorba</li></ul></div>'
             '<div class="card-food"><span>6 Kasım 2026</span><ul></ul></div>')
        self.assertEqual(yyu.sayfa_menu(s), {})


class DuzceTesti(unittest.TestCase):
    def setUp(self):
        self.menu = duzce.sayfa_menu(metin("duzce_liste.html"))

    def test_ekim_ve_kaynakta_olmayan_gun(self):
        self.assertEqual(len(self.menu), 22)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-01", "2026-10-30"))
        self.assertNotIn("2026-10-03", self.menu)
        self.assertNotIn("2026-11-02", self.menu)

    def test_ilk_kart_ve_ana_yemek_secimi(self):
        # Gerçek sayfada menü kartları da bir dış <article> içindedir.
        m = duzce.sayfa_menu('<article class="xl-container">' + metin("duzce_liste.html") + '</article>')
        gun = m["2026-10-01"]["lunch"]
        self.assertEqual(adlar(gun), ["Kremalı Domates Çorba", "Piliç Roti", "Zeytinyağlı Barbunya Pilaki", "Makarna Napoliten Soslu", "Magnolia"])
        self.assertNotIn("kcal", gun)
        self.assertEqual(set(m["2026-10-01"]), {"lunch"})
        self.assertNotIn("veya", " ".join(adlar(gun)))

    def test_tatil_ve_son_kart(self):
        self.assertEqual(self.menu["2026-10-29"], {"lunch": {"items": [], "note": "Resmi tatil"}})
        self.assertEqual(adlar(self.menu["2026-10-30"]["lunch"])[-1], "Orman Meyveli Cup")


class P3EklentiTesti(unittest.TestCase):
    def test_siniflar_ag_kullanmadan_gercek_kaynagi_okur(self):
        for sinif, fixture, sayi in OKULLAR:
            with self.subTest(okul=sinif.id):
                istekler = []

                def indir(url):
                    istekler.append(url)
                    return oku("aku_kasim.pdf" if url.endswith(".pdf") else fixture)

                menu = sinif(indir).menuler()
                self.assertEqual(len(menu), sayi)
                self.assertEqual(len(istekler), 2 if sinif is aku.AfyonKocatepe else 1)
                self.assertTrue(all(set(g) == {"lunch"} for g in menu.values()))

    def test_ag_hatasi_okulu_belirtir(self):
        def indir(url):
            raise OSError("zaman aşımı")

        for sinif, _, _ in OKULLAR:
            with self.subTest(okul=sinif.id):
                with self.assertRaisesRegex(RuntimeError, "indirilemedi.*zaman aşımı") as ctx:
                    sinif(indir).menuler()
                self.assertIsInstance(ctx.exception.__cause__, OSError)

    def test_bos_kaynak_basari_sayilmaz(self):
        for sinif, _, _ in OKULLAR:
            with self.subTest(okul=sinif.id):
                with self.assertRaisesRegex(RuntimeError, "bulunamadı"):
                    sinif(lambda url: b"<html></html>").menuler()

    def test_kayitli(self):
        idler = [u.id for u in KAYITLI]
        for sinif, _, _ in OKULLAR:
            self.assertIn(sinif.id, idler)
        self.assertEqual(len(idler), len(set(idler)))


if __name__ == "__main__":
    unittest.main()
