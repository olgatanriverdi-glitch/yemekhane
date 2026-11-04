"""P8: 1 Kasım 2026 resmî kaynaklarından kırpılmış fixture'larla ağsız testler."""
import os
import unittest
from datetime import date

from yemekhane.universities import KAYITLI, adiyaman, kilis, mku, siirt, sirnak

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def oku(ad):
    with open(os.path.join(FIX, ad), "rb") as f:
        return f.read()


def metin(ad):
    return oku(ad).decode("utf-8")


def adlar(ogun):
    return [o["name"] for o in ogun["items"]]


def indirici(kaynaklar):
    def indir(url):
        if url not in kaynaklar:
            raise AssertionError("Beklenmeyen ağ adresi: %s" % url)
        return oku(kaynaklar[url])
    return indir


class HatayMustafaKemalTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = mku.sayfa_menu(metin("mku_aylik.html"))

    def test_kasim_21_gun(self):
        self.assertEqual(len(self.menu), 21)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-30"))
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for g in self.menu.values()))

    def test_ilk_gunun_yemekleri_ve_kalorileri(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Etli Kuru Fasulye", "Şehriyeli Pirinç Pilavı", "Tulumba Tatlısı", "Turşu"])
        self.assertEqual([o["kcal"] for o in gun["items"]], [360, 280, 530, 25])
        self.assertEqual(gun["kcal"], 1195)

    def test_turkce_karakterler_arti_ve_son_gun(self):
        self.assertEqual(adlar(self.menu["2026-11-06"]["lunch"])[1], "Tavuk Kalamar + Patates")
        self.assertEqual(adlar(self.menu["2026-11-30"]["lunch"]), ["Etli Kuru Fasulye", "Şehriyeli Pirinç Pilavı", "Yoğurt", "Turşu"])
        self.assertTrue(all(set(g) == {"lunch"} for g in self.menu.values()))

    def test_bos_hafta_sonu_ve_bos_sayfa(self):
        self.assertNotIn("2026-11-01", self.menu)
        self.assertNotIn("2026-11-07", self.menu)
        self.assertEqual(mku.sayfa_menu("<section></section>"), {})

    def test_yazili_toplam_korunur(self):
        s = metin("mku_aylik.html").replace("1195 kcal", "1200 kcal", 1)
        self.assertEqual(mku.sayfa_menu(s)["2026-11-02"]["lunch"]["kcal"], 1200)

    def test_eklenti_ve_celisen_kopya(self):
        u = mku.HatayMustafaKemal(indirici({mku.SAYFA_URL: "mku_aylik.html"}))
        self.assertEqual(u.menuler(), self.menu)
        self.assertFalse(u.birikimli)
        s = metin("mku_aylik.html")
        with self.assertRaisesRegex(ValueError, "çelişen"):
            mku.sayfa_menu(s + s.replace("Etli Kuru Fasulye", "Etli Nohut"))


class KilisTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = kilis.sayfa_menu(metin("kilis_aylik.html"))

    def test_ekim_21_menu(self):
        self.assertEqual(len(self.menu), 21)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-01", "2026-10-30"))
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for g in self.menu.values()))

    def test_ilk_ve_son_gunun_yemekleri(self):
        self.assertEqual(adlar(self.menu["2026-10-01"]["lunch"]), ["Mantarlı Tavuk Sote", "Domatesli Bulgur Pilavı", "Yayla Çorba", "Armut"])
        self.assertEqual(adlar(self.menu["2026-10-30"]["lunch"]), ["Etli Kuru Fasulye", "Şehriyeli Bulgur Pilavı", "Yoğurt", "Tulumba Tatlısı"])

    def test_kisaltmalar_ve_kaynagin_acik_yazim_hatalari(self):
        self.assertEqual(adlar(self.menu["2026-10-22"]["lunch"])[1], "Bolonez Soslu Makarna")
        self.assertEqual(adlar(self.menu["2026-10-23"]["lunch"])[1], "Zeytinyağlı Dolma")
        self.assertEqual(adlar(self.menu["2026-10-06"]["lunch"])[2:], ["Kaşarlı Domates Çorba", "Şekerpare"])

    def test_bos_tatil_ve_hafta_sonu_menu_sayilmaz(self):
        for t in ("2026-10-03", "2026-10-04", "2026-10-29", "2026-10-31"):
            self.assertNotIn(t, self.menu)
        self.assertEqual(kilis.sayfa_menu("<table></table>"), {})

    def test_yayinlanmayan_kalori_ve_ogun_uretilmez(self):
        self.assertTrue(all(set(g) == {"lunch"} and "kcal" not in g["lunch"] for g in self.menu.values()))
        self.assertFalse(any("kcal" in o for g in self.menu.values() for o in g["lunch"]["items"]))

    def test_eklenti(self):
        u = kilis.Kilis7Aralik(indirici({kilis.SAYFA_URL: "kilis_aylik.html"}))
        self.assertEqual(u.menuler(), self.menu)
        self.assertFalse(u.birikimli)

    def test_ogrenci_servis_saati_personelle_karismaz(self):
        u = kilis.Kilis7Aralik(indirici({kilis.BILGI_URL: "kilis_beslenme.html"}))
        self.assertEqual(u.saatler(), {"lunch": "11:00–13:00"})

    def test_saat_sayfasi_okunamazsa_menu_engellenmez(self):
        u = kilis.Kilis7Aralik(indirici=lambda url: b"<html></html>")
        self.assertEqual(u.saatler(), {})


class SiirtTesti(unittest.TestCase):
    BUGUN = date(2026, 11, 1)

    def test_kasim_yalniz_yayinlanmis_bir_gun(self):
        menu = siirt.sayfa_menu(metin("siirt_kasim.html"), self.BUGUN)
        self.assertEqual(set(menu), {"2026-11-02"})
        gun = menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Meyve", "Cacık", "Tas Kebabı", "Bulgur Pilavı"])
        self.assertEqual([o["kcal"] for o in gun["items"]], [90, 100, 380, 280])
        self.assertEqual(gun["kcal"], 850)

    def test_ekim_secicisi_22_tarih(self):
        menu = siirt.sayfa_menu(metin("siirt_ekim.html"), self.BUGUN)
        self.assertEqual(len(menu), 22)
        self.assertEqual((min(menu), max(menu)), ("2026-10-01", "2026-10-30"))
        self.assertEqual(adlar(menu["2026-10-01"]["lunch"]), ["Dana Tandır", "Mercimek Çorbası", "Salata", "Pirinç Pilavı"])
        self.assertEqual(menu["2026-10-01"]["lunch"]["kcal"], 930)

    def test_tatil_notlari_ve_bos_hafta_sonu(self):
        menu = siirt.sayfa_menu(metin("siirt_ekim.html"), self.BUGUN)
        for t in ("2026-10-28", "2026-10-29"):
            self.assertEqual(menu[t], {"lunch": {"items": [], "note": "Tatil"}})
        self.assertNotIn("2026-10-03", menu)

    def test_buyuk_i_kalorisi_ve_yilin_yakindan_secilmesi(self):
        menu = siirt.sayfa_menu(metin("siirt_ekim.html"), date(2027, 1, 1))
        self.assertEqual(menu["2026-10-06"]["lunch"]["items"][0]["kcal"], 340)

    def test_secili_ay_yoksa_tarih_uydurulmaz(self):
        self.assertEqual(siirt.sayfa_menu(metin("siirt_kasim.html").replace('selected="selected"', ''), self.BUGUN), {})
        self.assertEqual(siirt.sayfa_menu("<div></div>", self.BUGUN), {})

    def test_eklenti_ayliktir(self):
        u = siirt.SiirtUniversitesi(indirici({siirt.SAYFA_URL: "siirt_kasim.html"}), bugun=self.BUGUN)
        self.assertEqual(u.menuler(), siirt.sayfa_menu(metin("siirt_kasim.html"), self.BUGUN))
        self.assertFalse(u.birikimli)


class SirnakTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = sirnak.pdf_menu(oku("sirnak_ekim.pdf"))

    def test_ekim_22_tarih_21_menu(self):
        self.assertEqual(len(self.menu), 22)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-01", "2026-10-30"))
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for t, g in self.menu.items() if t != "2026-10-29"))

    def test_ilk_kismi_haftanin_iki_sutunu(self):
        gun = self.menu["2026-10-01"]["lunch"]
        self.assertEqual(adlar(gun), ["Şehriye Çorbası", "Tavuk Haşlama/Et Haşlama", "Sebzeli Bulgur Pilavı", "Tulumba Tatlısı"])
        self.assertNotIn("kcal", gun)
        self.assertEqual(gun["note"], "Ana yemek seçimine göre toplam kalori: 1118/1171 kcal")
        self.assertEqual(adlar(self.menu["2026-10-02"]["lunch"]), ["Süzme Mercimek Çorbası", "Fırında Güveç", "Pirinç Pilavı", "Cacık"])
        self.assertEqual(self.menu["2026-10-02"]["lunch"]["kcal"], 891)

    def test_secimli_toplamlar_toplanmaz(self):
        self.assertEqual(sum("kcal" in g["lunch"] for g in self.menu.values()), 7)
        self.assertEqual(sum(bool(g["lunch"]["items"]) and "note" in g["lunch"] for g in self.menu.values()), 14)
        gun = self.menu["2026-10-05"]["lunch"]
        self.assertEqual(adlar(gun)[1], "Etli Kuru Fasulye/Fırında Tavuk")
        self.assertEqual(gun["note"], "Ana yemek seçimine göre toplam kalori: 696/882 kcal")
        self.assertNotIn("kcal", gun)
        self.assertTrue(all("kcal" not in o for g in self.menu.values() for o in g["lunch"]["items"]))

    def test_kisaltmalar_ve_son_gun(self):
        self.assertEqual(adlar(self.menu["2026-10-13"]["lunch"])[1], "Çıtır Tavuk Baget+Patates Kızartması")
        self.assertEqual(adlar(self.menu["2026-10-26"]["lunch"])[1], "Et Tantuni/Tavuk Tantuni+Patates Kızartması")
        self.assertEqual(adlar(self.menu["2026-10-30"]["lunch"]), ["Süzme Mercimek Çorbası", "Karnıyarık", "Pirinç Pilavı", "Cacık"])
        self.assertEqual(self.menu["2026-10-30"]["lunch"]["kcal"], 841)

    def test_tatil_ve_bos_hucreler(self):
        self.assertEqual(self.menu["2026-10-29"], {"lunch": {"items": [], "note": "Resmi tatil"}})
        self.assertNotIn("2026-10-03", self.menu)
        self.assertEqual(sirnak.pdf_menu(b""), {})
        self.assertTrue(all(set(g) == {"lunch"} for g in self.menu.values()))

    def test_dinamik_aylik_ve_ucret_pdf_baglantilari(self):
        s = metin("sirnak_aylik.html")
        self.assertEqual(sirnak.pdf_baglantisi(s, date(2026, 11, 1)), "https://sks.sirnak.edu.tr/file/menuFiles/ekim-2026-yemek-listesi_8120e87b-1f8f-4592-b6ee-8b1cbaf7a02e.pdf")
        self.assertEqual(sirnak.pdf_baglantisi(s, date(2026, 11, 1), fiyat=True), "https://sks.sirnak.edu.tr/file/menuFiles/2026-yemek-ucretleri_f6d7c13c-e955-466a-b96b-7989fd5d8c6e.pdf")
        self.assertEqual(sirnak.pdf_baglantisi("<a>Yemek</a>"), None)

    def test_ogrenci_ucreti_personel_ve_misafirden_ayrilir(self):
        self.assertEqual(sirnak.pdf_fiyatlar(oku("sirnak_ucret.pdf")), [{"label": "Öğrenci", "tl": 30.0}])
        self.assertEqual(sirnak.pdf_fiyatlar(b""), [])

    def test_eklenti_aylik_ve_fiyat(self):
        s = metin("sirnak_aylik.html")
        u = sirnak.SirnakUniversitesi(indirici({sirnak.SAYFA_URL: "sirnak_aylik.html",
            sirnak.pdf_baglantisi(s, date(2026, 11, 1)): "sirnak_ekim.pdf",
            sirnak.pdf_baglantisi(s, date(2026, 11, 1), fiyat=True): "sirnak_ucret.pdf"}), bugun=date(2026, 11, 1))
        self.assertEqual(u.menuler(), self.menu)
        self.assertFalse(u.birikimli)
        self.assertEqual(u.fiyatlar(), [{"label": "Öğrenci", "tl": 30.0}])


class AdiyamanTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = adiyaman.sayfa_menu(metin("adiyaman_gunluk.html"))

    def test_tek_gunun_ogle_ve_aksami(self):
        self.assertEqual(set(self.menu), {"2026-11-02"})
        self.assertEqual(set(self.menu["2026-11-02"]), {"lunch", "dinner"})
        self.assertEqual(adlar(self.menu["2026-11-02"]["lunch"]), ["Pilav Üzeri Tavuk Döner", "Süzme Mercimek Çorba", "Salata", "Ayran"])
        self.assertEqual(adlar(self.menu["2026-11-02"]["dinner"]), ["Sebzeli Misket Köfte", "Pirinç Pilavı", "Şehriye Çorba", "Revani"])

    def test_resmi_stil_ogun_sirasini_dogrular(self):
        css = metin("adiyaman_ogunler.css")
        self.assertIn('nth-child(3n+2):before{content:"Öğle"}', css)
        self.assertIn('nth-child(3n):before{content:"Akşam"}', css)

    def test_bos_kcal_yer_tutuculari_kalori_sayilmaz(self):
        self.assertTrue(all("kcal" not in g for g in self.menu["2026-11-02"].values()))
        self.assertFalse(any("kcal" in o for g in self.menu["2026-11-02"].values() for o in g["items"]))

    def test_bos_gun_ve_ogun_uydurulmaz(self):
        self.assertNotIn("2026-11-01", self.menu)
        self.assertNotIn("2026-11-03", self.menu)
        s = metin("adiyaman_gunluk.html")
        for yemek in ("PİLAV ÜZERİ TAVUK DÖNER", "SÜZME MERCİMEK ÇORBA", "SALATA", "AYRAN"):
            s = s.replace(yemek, "")
        self.assertEqual(set(adiyaman.sayfa_menu(s)["2026-11-02"]), {"dinner"})
        self.assertEqual(adiyaman.sayfa_menu("<div class='mt-meals'></div>"), {})

    def test_celisen_kopya_sessizce_ezilmez(self):
        s = metin("adiyaman_gunluk.html")
        with self.assertRaisesRegex(ValueError, "çelişen"):
            adiyaman.sayfa_menu(s + s.replace("SALATA", "CACIK"))

    def test_eklenti_gunluk_biriktirilir(self):
        u = adiyaman.AdiyamanUniversitesi(indirici({adiyaman.SAYFA_URL: "adiyaman_gunluk.html"}))
        self.assertEqual(u.menuler(), self.menu)
        self.assertTrue(u.birikimli)


class P8SozlesmeTesti(unittest.TestCase):
    SINIFLAR = (siirt.SiirtUniversitesi, sirnak.SirnakUniversitesi, adiyaman.AdiyamanUniversitesi,
                kilis.Kilis7Aralik, mku.HatayMustafaKemal)

    def test_yeni_bes_okul_bir_kez_kayitli(self):
        for sinif in self.SINIFLAR:
            with self.subTest(okul=sinif.id):
                kayitlar = [u for u in KAYITLI if u.id == sinif.id]
                self.assertEqual(len(kayitlar), 1)
                self.assertIsInstance(kayitlar[0], sinif)
                self.assertTrue(kayitlar[0].ad and kayitlar[0].kisa and kayitlar[0].sehir)

    def test_ag_hatasi_okul_adiyla_anlamlidir(self):
        def hata(url):
            raise OSError("bağlantı kesildi")
        for sinif in self.SINIFLAR:
            with self.subTest(okul=sinif.id):
                with self.assertRaisesRegex(RuntimeError, "indirilemedi.*bağlantı kesildi"):
                    sinif(indirici=hata).menuler()

    def test_bos_sayfa_basarili_menu_sayilmaz(self):
        for sinif in self.SINIFLAR:
            with self.subTest(okul=sinif.id):
                with self.assertRaisesRegex(RuntimeError, "bulunamadı"):
                    sinif(indirici=lambda url: b"<html></html>").menuler()

    def test_pdf_indirme_hatasi_ve_istege_bagli_fiyat(self):
        def hata(url):
            if url == sirnak.SAYFA_URL:
                return oku("sirnak_aylik.html")
            raise OSError("PDF bağlantısı kesildi")
        u = sirnak.SirnakUniversitesi(indirici=hata, bugun=date(2026, 11, 1))
        with self.assertRaisesRegex(RuntimeError, "PDF'i okunamadı.*PDF bağlantısı kesildi"):
            u.menuler()
        self.assertEqual(u.fiyatlar(), [])


if __name__ == "__main__":
    unittest.main()
