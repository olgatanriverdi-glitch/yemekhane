"""ESOGÜ ve ESTÜ eklentileri, PDF metin çıkarıcı ve build'in 'önceki kaydı koru' davranışı. Fixture'lar okulların gerçek sayfa/PDF'leridir."""
import json
import os
import tempfile
import unittest
from datetime import date, timedelta
from unittest import mock

from yemekhane import build, dishes, pdf
from yemekhane.universities import esogu, estu
from yemekhane.universities.base import Universite

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def oku(ad, mod="r"):
    with open(os.path.join(FIX, ad), mod, **({"encoding": "utf-8"} if mod == "r" else {})) as f:
        return f.read()


class EsoguTesti(unittest.TestCase):
    def test_hafta_ve_yemekler(self):
        m = esogu.sayfa_menu(oku("esogu_menu1.html"))
        self.assertEqual(sorted(m), ["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02",
                                     "2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30"])
        self.assertEqual(m["2026-09-28"]["items"], [{"name": "Yoğurt Çorba", "kcal": 159}, {"name": "İçli Köfte", "kcal": 350},
                                                    {"name": "Soslu Karışık Kızartma", "kcal": 360}, {"name": "Mevsim Salata", "kcal": 60}])   # '(YAZ)' atıldı
        self.assertEqual(m["2026-09-28"]["kcal"], 159 + 350 + 360 + 60)

    def test_karbonhidrat_eki_ve_kalorisiz_ogeler(self):
        m = esogu.sayfa_menu(oku("esogu_menu1.html"))
        self.assertEqual(m["2026-09-29"]["items"][0], {"name": "Köylü Çorba", "kcal": 175})       # 'Karbonhidrat: 18 gr' eki yok
        self.assertEqual(m["2026-09-30"]["items"][-2:], [{"name": "Ceviz Sarma"}, {"name": "Meşrubat"}])    # 'A/ B' iki öğe, '(--- kcal)' kalorisiz
        self.assertNotIn("kcal", m["2026-09-30"])                                                  # tüm kalemlerin kalorisi yoksa gün kalorisi yazılmaz

    def test_tatil(self):
        m = esogu.sayfa_menu(oku("esogu_menu1.html"))
        self.assertEqual(m["2026-10-29"], {"items": [], "note": "Tatil: Cumhuriyet Bayramı"})

    def test_oge_ayiklama(self):
        self.assertEqual(esogu.yemek_ogeleri("YAYLA &#199;ORBA Karbonhidrat : 15 gr", "(163 kcal)"), [{"name": "Yayla Çorba", "kcal": 163}])
        self.assertEqual(esogu.yemek_ogeleri("&#199;İFTLİK K&#214;FTE Karbonhidrat: 10gr", "(408 kcal)"), [{"name": "Çiftlik Köfte", "kcal": 408}])
        self.assertEqual(esogu.yemek_ogeleri("MEVSİM SALATA (KIŞ)", "(105 kcal)"), [{"name": "Mevsim Salata", "kcal": 105}])
        self.assertEqual(esogu.yemek_ogeleri("TULUMBA", "(--- kcal)"), [{"name": "Tulumba"}])
        self.assertEqual(esogu.yemek_ogeleri("TULUMBA", ""), [{"name": "Tulumba"}])

    def test_sinif_ogle_aksam_vejetaryen(self):
        def sahte(url):
            return oku("esogu_menu1.html" if url.endswith("Menu/1") else "esogu_menu2.html").encode("utf-8")
        u = esogu.EskisehirOsmangazi(sahte)
        m = u.menuler()
        g = m["2026-09-28"]
        self.assertEqual(set(g), {"lunch", "dinner"})                       # vejetaryen fixture'ı bu haftayı içermiyor
        self.assertEqual(g["lunch"], g["dinner"])
        self.assertIsNot(g["lunch"], g["dinner"])                             # fotoğraf eşleştirme bir öğünü değiştirince diğeri etkilenmesin
        self.assertEqual(set(m["2026-10-27"]), {"lunch", "dinner", "vegetarian"})
        self.assertEqual(m["2026-10-29"]["dinner"]["note"], "Tatil: Cumhuriyet Bayramı")
        self.assertNotIn("vegetarian", m["2026-10-29"])
        self.assertEqual((u.fiyatlar(), u.saatler()), ([], {}))             # okul ücret ve saat yayınlamıyor

    def test_vejetaryen_alinamazsa_standart_menu_gelir(self):
        def sahte(url):
            if url.endswith("Menu/2"):
                raise OSError("bağlantı kesildi")
            return oku("esogu_menu1.html").encode("utf-8")
        self.assertEqual(len(esogu.EskisehirOsmangazi(sahte).menuler()), 10)


class PdfTesti(unittest.TestCase):
    def test_cmap_dizi_bicimli_aralik(self):
        cmap = pdf.cmap_oku(b"1 beginbfrange\n<0067> <0068> [<00D6> <00DC>]\n<00F8> <00F8> [<0130>]\n<0024> <0026> <0041>\nendbfrange\n"
                            b"1 beginbfchar\n<0003> <0020>\nendbfchar")
        self.assertEqual((cmap[0x67], cmap[0x68], cmap[0xF8], cmap[0x25], cmap[3]), ("Ö", "Ü", "İ", "B", " "))

    def test_gercek_pdf_metni(self):
        sayfalar = pdf.sayfa_metinleri(oku("estu_menu.pdf", "rb"))
        self.assertEqual(len(sayfalar), 1)
        metinler = [t[3] for t in sayfalar[0]]
        self.assertIn("EKİM 2026 GENEL YEMEK MENÜSÜ", metinler)           # İ, Ü gibi harfler ToUnicode'dan doğru gelir
        self.assertIn("01.10.2026 Perşembe", metinler)
        self.assertEqual(pdf.sayfa_metinleri(b"%PDF-1.4 bozuk"), [])


class EstuTesti(unittest.TestCase):
    def setUp(self):
        self.menu = {}
        for sayfa in pdf.sayfa_metinleri(oku("estu_menu.pdf", "rb")):
            self.menu.update(estu.tablo_menu(sayfa))

    def test_gunler(self):
        beklenen = [date(2026, 10, 1) + timedelta(days=i) for i in range(31)]
        hafta_ici = {d.isoformat() for d in beklenen if d.weekday() < 5}
        # 28 Ekim sütunu PDF'te boş (yalnızca başlık var); gerisi tam
        self.assertEqual(hafta_ici - set(self.menu), {"2026-10-28"})
        self.assertEqual(set(self.menu) - hafta_ici, set())

    def test_normal_ve_vejetaryen_menu(self):
        g = self.menu["2026-10-01"]
        self.assertEqual([o["name"] for o in g["lunch"]["items"]], ["Domates Çorba", "Sahan Köfte", "Şehriye Pilavı", "Cacık"])
        self.assertEqual(g["lunch"]["kcal"], 220 + 330 + 265 + 130)
        # etsiz seçenek ('*') ana yemeğin yerine geçer
        self.assertEqual([o["name"] for o in g["vegetarian"]["items"]], ["Domates Çorba", "Zeytinyağlı Bamya Yemeği", "Şehriye Pilavı", "Cacık"])
        self.assertEqual(g["vegetarian"]["items"][1], {"name": "Zeytinyağlı Bamya Yemeği", "kcal": 290})

    def test_basligi_kaymis_sutunlar(self):
        # 22 Ekim başlığı satırın 1 pt üstünde; 28 Ekim başlığı sağa kaymış: sütunlar yine de doğru bulunur
        self.assertEqual([o["name"] for o in self.menu["2026-10-22"]["lunch"]["items"]],
                         ["Yayla Çorba", "Kıymalı Karnabahar Graten", "Bulgur Pilavı", "Profiterol"])
        self.assertEqual([o["name"] for o in self.menu["2026-10-27"]["lunch"]["items"]],
                         ["Havuç Çorba", "Hasanpaşa Köfte", "Yoğurtlu Makarna", "İncirli Muhallebi"])

    def test_tatil_basligi_olmayan_sutun(self):
        # 29 Ekim sütununda tarih başlığı yok, yerine bayram yazısı var; tarih haftanın diğer günlerinden hesaplanır
        self.assertEqual(self.menu["2026-10-29"], {"lunch": {"items": [], "note": "29 Ekim Cumhuriyet Bayramı"}})

    def test_sifir_kalorili_icecek(self):
        icecek = [o for o in self.menu["2026-10-19"]["lunch"]["items"] if o["name"] == "Maden Suyu"]
        self.assertEqual(icecek, [{"name": "Maden Suyu", "kcal": 0}])

    def test_her_gun_dort_kalem_ve_kalori(self):
        for tarih, g in self.menu.items():
            if g["lunch"]["items"]:
                self.assertEqual(len(g["lunch"]["items"]), 4, tarih)
                self.assertEqual(g["lunch"]["kcal"], sum(o["kcal"] for o in g["lunch"]["items"]), tarih)

    def test_menu_olustur(self):
        normal, veg = estu.menu_olustur([("ÇORBA", 100), ("ET YEMEĞİ", 300), ("SEBZE YEMEĞİ*", 200), ("PİLAV", 250)])
        self.assertEqual([a for a, _ in normal], ["ÇORBA", "ET YEMEĞİ", "PİLAV"])
        self.assertEqual([a for a, _ in veg], ["ÇORBA", "SEBZE YEMEĞİ*", "PİLAV"])
        normal, veg = estu.menu_olustur([("ÇORBA", 100), ("ET YEMEĞİ", 300)])
        self.assertEqual((len(normal), veg), (2, None))

    def test_yemek_adi(self):
        self.assertEqual(estu.yemek_adi("ET DÖNER+GARN."), "Et Döner + Garnitür")
        self.assertEqual(estu.yemek_adi("ZY. BRÜKSEL LAHANA*"), "Zeytinyağlı Brüksel Lahana")
        self.assertEqual(estu.yemek_adi("MANTI (SOS+YOĞURT)"), "Mantı (Sos+Yoğurt)")

    def test_pdf_baglantisi(self):
        self.assertEqual(estu.pdf_baglantisi(oku("estu_yemekhaneler.html")),
                         "https://saglikkulturspor.eskisehir.edu.tr/Uploads/saglikkulturspor/files/EK%c4%b0M%202026%20MEN%c3%9c(2).pdf")
        self.assertIsNone(estu.pdf_baglantisi('<a href="/a.pdf">Haftalık Yemek Menüsü</a><a href="/giris">Yemek Menüsü</a>'))

    def test_sinif(self):
        def sahte(url):
            return oku("estu_menu.pdf", "rb") if url.endswith(".pdf") else oku("estu_yemekhaneler.html").encode("utf-8")
        u = estu.EskisehirTeknik(sahte)
        self.assertEqual(len(u.menuler()), 21)           # 22 hafta içi gün - boş 28 Ekim
        with self.assertRaises(RuntimeError):
            estu.EskisehirTeknik(lambda url: b"<html></html>").menuler()


class BuildOncekiKayitTesti(unittest.TestCase):
    class Sahte(Universite):
        def __init__(self, kimlik, bozuk=False):
            self.id, self.ad, self.kisa, self.sehir, self.kaynak = kimlik, "Okul " + kimlik, kimlik.upper(), "Ankara", "http://x"
            self.bozuk = bozuk

        def menuler(self):
            if self.bozuk:
                raise OSError("sunucu yanıt vermedi")
            return {"2999-01-01": {"lunch": {"items": [{"name": "Çorba"}]}}}

    def calistir(self, klasor, uniler):
        with mock.patch.object(dishes, "RUN_LIMIT", 0):          # testte ağa çıkıp fotoğraf aranmasın
            return build.calistir(klasor, uniler)

    def test_bozulan_okul_indexten_dusmez(self):
        with tempfile.TemporaryDirectory() as k:
            self.assertEqual(self.calistir(k, [self.Sahte("a"), self.Sahte("b")]), 0)
            self.assertEqual([u["id"] for u in json.load(open(os.path.join(k, "index.json")))["universities"]], ["a", "b"])
            # 2. çalıştırmada a bozuk: kaydı korunur, sıra değişmez; b yenilenir
            self.assertEqual(self.calistir(k, [self.Sahte("a", bozuk=True), self.Sahte("b")]), 0)
            index = json.load(open(os.path.join(k, "index.json")))["universities"]
            self.assertEqual([u["id"] for u in index], ["a", "b"])
            self.assertTrue(os.path.exists(os.path.join(k, "a", "menu.json")))

    def test_hepsi_bozuksa_hata_kodu(self):
        with tempfile.TemporaryDirectory() as k:
            self.calistir(k, [self.Sahte("a")])
            self.assertEqual(self.calistir(k, [self.Sahte("a", bozuk=True)]), 1)       # önceki kayıt korunur ama CI hatayı görür
            self.assertEqual(len(json.load(open(os.path.join(k, "index.json")))["universities"]), 1)

    def test_yeni_ve_bozuk_okul_listede_olmaz(self):
        with tempfile.TemporaryDirectory() as k:
            self.calistir(k, [self.Sahte("a")])
            self.calistir(k, [self.Sahte("a"), self.Sahte("c", bozuk=True)])       # c hiç başarıyla okunmadı: önceki kaydı yok
            self.assertEqual([u["id"] for u in json.load(open(os.path.join(k, "index.json")))["universities"]], ["a"])


if __name__ == "__main__":
    unittest.main()
