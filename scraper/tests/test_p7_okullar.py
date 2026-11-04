"""P7: 1 Kasım 2026 resmî kaynaklarından kırpılmış fixture'larla ağsız testler."""
import copy
import json
import os
import unittest
from datetime import date

from yemekhane.universities import KAYITLI, alparslan, ardahan, bingol, kafkas, munzur

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


class KafkasTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = kafkas.pdf_menu(oku("kafkas_dort_hafta.pdf"))

    def test_dort_haftalik_normal_menu(self):
        self.assertEqual(len(self.menu), 19)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-19", "2026-11-13"))
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for t, g in self.menu.items() if t != "2026-10-28"))

    def test_tj_icindeki_komsu_sutunlar_karismaz(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Mercimek Çorbası", "Kıymalı Nohut Yemeği", "Pirinç Pilavı", "Turşu"])
        self.assertEqual([o["kcal"] for o in gun["items"]], [136, 285, 280, 24])
        self.assertEqual(gun["kcal"], 725)
        self.assertEqual(adlar(self.menu["2026-11-03"]["lunch"]), ["Kesme Aşı Çorbası", "Soslu Tavuk", "Bulgur Pilavı", "Karışık Komposto"])

    def test_ikinci_sayfanin_glutensiz_menusu_alinmaz(self):
        self.assertEqual(adlar(self.menu["2026-11-06"]["lunch"])[1], "Biber Dolması")
        self.assertEqual(adlar(self.menu["2026-11-13"]["lunch"])[-1], "Revani")
        self.assertTrue(all(set(g) == {"lunch"} for g in self.menu.values()))

    def test_72_kalem_ve_yazili_toplamlar(self):
        for tarih, gun in self.menu.items():
            if gun["lunch"]["items"]:
                with self.subTest(tarih=tarih):
                    self.assertEqual(gun["lunch"]["kcal"], sum(o["kcal"] for o in gun["lunch"]["items"]))

    def test_yarim_gun_tatili_ve_resimli_bos_hucre(self):
        self.assertEqual(self.menu["2026-10-28"], {"lunch": {"items": [], "note": "Yarım gün / Resmi tatil"}})
        self.assertNotIn("2026-10-29", self.menu)  # Bu hücrenin bayram yazısı yalnız resimdir.
        self.assertNotIn("2026-10-24", self.menu)
        self.assertEqual(kafkas.pdf_menu(b""), {})

    def test_baglanti_ve_eklenti(self):
        url = "https://www.kafkas.edu.tr/belgeler/65d827f1-34d4-4749-991b-9fa7f77d0bdf..pdf"
        self.assertEqual(kafkas.pdf_baglantisi(metin("kafkas_sks.html")), url)
        u = kafkas.KafkasUniversitesi(indirici({kafkas.SAYFA_URL: "kafkas_sks.html", url: "kafkas_dort_hafta.pdf"}))
        self.assertEqual(u.menuler(), self.menu)
        self.assertTrue(u.birikimli)


class ArdahanTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.veri = json.loads(metin("ardahan_menu.json"))
        cls.menu = ardahan.json_menu(cls.veri)

    def test_api_arsivinden_guncel_kasim_secilir(self):
        u = ardahan.ArdahanUniversitesi(indirici({ardahan.API_URL: "ardahan_menu.json"}), date(2026, 11, 1))
        menu = u.menuler()
        self.assertEqual(len(menu), 3)
        self.assertEqual((min(menu), max(menu)), ("2026-11-02", "2026-11-04"))
        self.assertFalse(u.birikimli)

    def test_kasim_ilk_gun_sifir_kalori_bilinmiyor(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Tavuk Suyu Çorbası", "Etli Kuru Fasulye", "Pirinç Pilavı", "Turşu"])
        self.assertNotIn("kcal", gun)
        self.assertTrue(all("kcal" not in o for o in gun["items"]))

    def test_arsivde_yazili_ogun_ve_kalem_kalorileri(self):
        self.assertEqual(self.menu["2026-10-30"]["lunch"]["kcal"], 1020)
        gun = self.menu["2026-05-13"]["lunch"]
        self.assertEqual([o["kcal"] for o in gun["items"]], [223, 123, 231, 212])
        self.assertEqual(gun["kcal"], 789)

    def test_colyak_ve_bos_gun_normal_menu_sayilmaz(self):
        self.assertNotIn("2026-10-29", self.menu)  # Yalnız çölyak tatil kaydı var.
        self.assertNotIn("2026-11-01", self.menu)
        self.assertEqual(ardahan.json_menu([]), {})
        self.assertEqual(self.menu["2026-05-19"], {"lunch": {"items": [], "note": "Resmi Tatil"}})

    def test_guncel_ay_bossa_son_dolu_ay(self):
        ham = json.dumps([k for k in self.veri if not k["date"].startswith("2026-11")]).encode()
        menu = ardahan.ArdahanUniversitesi(lambda url: ham, date(2026, 11, 1)).menuler()
        self.assertEqual(len(menu), 21)
        self.assertEqual((min(menu), max(menu)), ("2026-10-01", "2026-10-30"))

    def test_bozuk_api_ve_celisen_kayit_hata_verir(self):
        with self.assertRaisesRegex(ValueError, "kayıt listesi"):
            ardahan.json_menu({"error": "giriş"})
        k = copy.deepcopy(self.veri[0])
        k["corba"] = "Farklı Çorba"
        with self.assertRaisesRegex(ValueError, "çelişen"):
            ardahan.json_menu(self.veri + [k])


class MusAlparslanTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = alparslan.pdf_menu(oku("alparslan_ekim_son_hafta.pdf"))

    def test_guncel_hafta_bes_tarih(self):
        self.assertEqual(len(self.menu), 5)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-26", "2026-10-30"))
        self.assertTrue(all(len(g["lunch"]["items"]) == 5 for t, g in self.menu.items() if t != "2026-10-29"))

    def test_ilk_gun_ve_secimli_ana_yemekler_toplanmaz(self):
        gun = self.menu["2026-10-26"]["lunch"]
        self.assertEqual(adlar(gun), ["Çoban Kavurma", "Köri Tavuk Sote", "Bulgur Pilavı", "Süzme Mercimek Çorbası", "Kemal Paşa Tatlısı"])
        self.assertEqual([o["kcal"] for o in gun["items"]], [340, 320, 230, 130, 300])
        self.assertNotIn("kcal", gun)
        self.assertEqual(gun["note"], "Ana yemek seçmelidir.")
        self.assertEqual(set(self.menu["2026-10-26"]), {"lunch"})

    def test_sarilmis_sozcuk_ve_bolunmus_kalori(self):
        gun = self.menu["2026-10-28"]["lunch"]
        self.assertEqual(adlar(gun), ["Kasap Köfte/Püre", "Sebzeli Tavuk But", "Soslu Makarna", "Sultan Çorbası", "Mevsim Salata"])
        self.assertEqual(gun["items"][3]["kcal"], 180)
        self.assertNotIn("kcal", gun["items"][-1])

    def test_bayram_notu_ve_bos_hafta_sonu(self):
        self.assertEqual(self.menu["2026-10-29"], {"lunch": {"items": [], "note": "Cumhuriyet Bayramı"}})
        self.assertNotIn("2026-10-31", self.menu)
        self.assertEqual(alparslan.pdf_menu(b""), {})

    def test_ayni_duzenin_ikinci_haftasi(self):
        menu = alparslan.pdf_menu(oku("alparslan_ekim_ikinci_hafta.pdf"))
        self.assertEqual(len(menu), 5)
        self.assertEqual((min(menu), max(menu)), ("2026-10-12", "2026-10-16"))
        self.assertEqual(adlar(menu["2026-10-13"]["lunch"])[0], "Patlıcan Tava")
        self.assertEqual(menu["2026-10-14"]["lunch"]["items"][3]["kcal"], 160)

    def test_dinamik_yeni_sks_baglantisi_ve_eklenti(self):
        url = "https://nsks.alparslan.edu.tr/uploads/nsks/belge/EKiM_4_1792756301_6adb4a4de2db5.pdf"
        self.assertEqual(alparslan.pdf_baglantisi(metin("alparslan_haftalik.html")), url)
        u = alparslan.MusAlparslan(indirici({alparslan.SAYFA_URL: "alparslan_haftalik.html", url: "alparslan_ekim_son_hafta.pdf", alparslan.FIYAT_URL: "alparslan_fiyatlar.html"}))
        self.assertEqual(u.menuler(), self.menu)
        self.assertTrue(u.birikimli)
        self.assertEqual(u.fiyatlar(), [{"label": "Öğrenci", "tl": 35.0}])


class BingolTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = bingol.sayfa_menu(metin("bingol_aylik.html"))

    def test_aylik_21_gun(self):
        self.assertEqual(len(self.menu), 21)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-30"))
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for g in self.menu.values()))

    def test_ilk_gun_ve_yayinlanmayan_kalori(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Çoban Kavurma", "Şehriyeli Pirinç Pilavı", "Mercimek Çorba", "Ayran"])
        self.assertNotIn("kcal", gun)

    def test_kismi_kalori_toplanmaz(self):
        gun = self.menu["2026-11-10"]["lunch"]
        self.assertEqual([o.get("kcal") for o in gun["items"]], [290, 40, 120, None])
        self.assertEqual(adlar(gun)[0], "Kıymalı Pide")
        self.assertNotIn("kcal", gun)

    def test_kalori_araligi_kesin_sayi_degil_nottur(self):
        gun = self.menu["2026-11-25"]["lunch"]
        self.assertEqual([o.get("kcal") for o in gun["items"]], [380, 320, 130, None])
        self.assertEqual(gun["note"], "Ayran: 60–70 kcal")
        self.assertEqual(adlar(gun)[-1], "Ayran")
        self.assertNotIn("kcal", gun)

    def test_kisaltmalar_ve_garnitur_ana_yemekte_kalir(self):
        self.assertEqual(adlar(self.menu["2026-11-09"]["lunch"])[-1], "Havuç Kırmızı Lahana Salata")
        self.assertEqual(adlar(self.menu["2026-11-12"]["lunch"])[-1], "Hindistan Cevizli Muhallebi")
        self.assertEqual(adlar(self.menu["2026-11-12"]["lunch"])[0], "Köri Soslu Tavuk Kavurma/Küp Patates")
        self.assertEqual(set(self.menu["2026-11-03"]), {"lunch"})

    def test_bos_hafta_sonu_gun_yapilmaz(self):
        self.assertNotIn("2026-11-07", self.menu)
        self.assertEqual(bingol.sayfa_menu("<table><tr><td></td></tr></table>"), {})

    def test_eklenti_gercek_kaynagi_ag_olmadan_okur(self):
        u = bingol.BingolUniversitesi(indirici({bingol.SAYFA_URL: "bingol_aylik.html"}))
        self.assertEqual(u.menuler(), self.menu)


class MunzurTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = munzur.sayfa_menu(metin("munzur_aylik.html"))

    def test_aylik_22_gun_ve_mobil_kopya(self):
        self.assertEqual(len(self.menu), 22)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-01", "2026-10-30"))
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for t, g in self.menu.items() if t != "2026-10-29"))

    def test_ilk_ve_son_gunun_yemekleri(self):
        self.assertEqual(adlar(self.menu["2026-10-01"]["lunch"]), ["Ezogelin Çorbası", "Tavuk Kroket", "Pirinç Pilavı", "Ayran"])
        self.assertEqual(adlar(self.menu["2026-10-30"]["lunch"]), ["Şehriye Çorbası", "Piliç Biftek", "Meyhane Pilavı", "Tarator"])

    def test_ayri_hucrelerde_resmi_tatil(self):
        self.assertEqual(self.menu["2026-10-29"], {"lunch": {"items": [], "note": "Resmi tatil"}})
        self.assertNotIn("2026-10-03", self.menu)
        self.assertNotIn("2026-11-01", self.menu)

    def test_kalori_ve_yayinlanmayan_ogun_uydurulmaz(self):
        self.assertTrue(all(set(g) == {"lunch"} and "kcal" not in g["lunch"] for g in self.menu.values()))

    def test_celisen_kopya_sessizce_ezilmez(self):
        s = metin("munzur_aylik.html")
        with self.assertRaisesRegex(ValueError, "çelişen"):
            munzur.sayfa_menu(s + s.replace("Tavuk Kroket", "Tavuk Sote"))

    def test_eklenti_ve_bos_tablo(self):
        u = munzur.MunzurUniversitesi(indirici({munzur.SAYFA_URL: "munzur_aylik.html"}))
        self.assertEqual(u.menuler(), self.menu)
        self.assertEqual(munzur.sayfa_menu("<table></table>"), {})


class P7SozlesmeTesti(unittest.TestCase):
    SINIFLAR = (kafkas.KafkasUniversitesi, ardahan.ArdahanUniversitesi, alparslan.MusAlparslan,
                bingol.BingolUniversitesi, munzur.MunzurUniversitesi)

    def test_yeni_bes_okul_bir_kez_kayitli(self):
        for sinif in self.SINIFLAR:
            with self.subTest(okul=sinif.id):
                kayitlar = [u for u in KAYITLI if u.id == sinif.id]
                self.assertEqual(len(kayitlar), 1)
                self.assertIsInstance(kayitlar[0], sinif)
                self.assertTrue(kayitlar[0].ad and kayitlar[0].kisa and kayitlar[0].sehir)

    def test_ag_hatalari_okul_adiyla_anlamli_hata_verir(self):
        def hata(url):
            raise OSError("bağlantı kesildi")
        for sinif in self.SINIFLAR:
            with self.subTest(okul=sinif.id):
                with self.assertRaisesRegex(RuntimeError, "indirilemedi.*bağlantı kesildi"):
                    sinif(indirici=hata).menuler()

    def test_bos_kaynak_basarili_menu_sayilmaz(self):
        for sinif in self.SINIFLAR:
            with self.subTest(okul=sinif.id):
                ham = b"[]" if sinif is ardahan.ArdahanUniversitesi else b"<html></html>"
                with self.assertRaisesRegex(RuntimeError, "bulunamadı"):
                    sinif(indirici=lambda url: ham).menuler()

    def test_pdf_indirme_hatasi_ve_bozuk_json_ayirt_edilir(self):
        for sinif, mod, fixture in ((kafkas.KafkasUniversitesi, kafkas, "kafkas_sks.html"),
                                    (alparslan.MusAlparslan, alparslan, "alparslan_haftalik.html")):
            def hata(url):
                if url == mod.SAYFA_URL:
                    return oku(fixture)
                raise OSError("PDF bağlantısı kesildi")
            with self.subTest(okul=sinif.id):
                with self.assertRaisesRegex(RuntimeError, "PDF'i okunamadı.*PDF bağlantısı kesildi"):
                    sinif(indirici=hata).menuler()
        with self.assertRaisesRegex(RuntimeError, "JSON'u okunamadı"):
            ardahan.ArdahanUniversitesi(indirici=lambda url: b"<html>Giris</html>").menuler()


if __name__ == "__main__":
    unittest.main()
