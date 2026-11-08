"""P6: 1 Kasım 2026'da resmî sitelerden indirilen kaynaklarla ağsız testler.

HTML'ler menü bağlantılarına/saatlerine kırpılmıştır. PDF'ler menü tablolarını
içeren sayfalardır; fontlar ve sarılmış hücreler gerçek kaynaktan korunur.
"""
import json
import os
import unittest
from datetime import date

from yemekhane.universities import KAYITLI, bayburt, giresun, gop, odu

FIX = os.path.join(os.path.dirname(__file__), "fixtures")
BUGUN = date(2026, 11, 1)
TATIL = {"lunch": {"items": [], "note": "Resmi tatil"}}


def oku(ad):
    with open(os.path.join(FIX, ad), "rb") as f:
        return f.read()


def metin(ad):
    return oku(ad).decode("utf-8")


def adlar(gun):
    return [o["name"] for o in gun["items"]]


def indirici(kaynaklar):
    def indir(url):
        if url not in kaynaklar:
            raise AssertionError("Beklenmeyen ağ adresi: %s" % url)
        return oku(kaynaklar[url])
    return indir


def okullar():
    return [
        (gop.TokatGaziosmanpasa(indirici({
            gop.SAYFA_URL: "gop_aylik.html",
            "https://sosyaltesisler.gop.edu.tr/images/update/KASIM%2026%20L%C4%B0STE%20(3).pdf": "gop_kasim.pdf",
        }), BUGUN), 21),
        (odu.OrduUniversitesi(indirici({
            odu.SAYFA_URL: "odu_sks.html",
            "https://sksdb.odu.edu.tr/files/other/yemeklisteleri/ekim2026.pdf": "odu_ekim.pdf",
            odu.SAAT_URL: "odu_saatler.html",
        })), 22),
        (giresun.GiresunUniversitesi(indirici({
            giresun.SAYFA_URL: "giresun_sks.html",
            "https://sksdb.giresun.edu.tr/Files/ckFiles/sksdb-giresun-edu-tr/KASIM%202026%20YEMEK%20MEN%C3%9C.pdf": "giresun_kasim.pdf",
        }), BUGUN), 21),
        (bayburt.BayburtUniversitesi(indirici({
            bayburt.API_URL: "bayburt_aylik.json",
            "https://apifile.bayburt.edu.tr/file/portal/yemekuploads/262A9C2C-9EF1-4A8E-8BD7-646C293F0764.pdf": "bayburt_ekim.pdf",
        })), 22),
    ]


class GopTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = gop.pdf_menu(oku("gop_kasim.pdf"), 11, BUGUN)

    def test_kasim_aylik_takvim(self):
        self.assertEqual(len(self.menu), 21)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-30"))
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for g in self.menu.values()))

    def test_ilk_gun_ve_kalem_kalorileri(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Mercimek Çorba", "Kuru Fasulye", "Pirinç Pilavı", "Turşu"])
        self.assertEqual([o["kcal"] for o in gun["items"]], [185, 345, 327, 55])
        self.assertEqual(gun["kcal"], 912)

    def test_kucuk_yazi_ve_yarim_birim_yuksek_satir_kaybolmaz(self):
        self.assertEqual(adlar(self.menu["2026-11-12"]["lunch"])[2], "Mercimekli Bulgur Pilavı")
        self.assertEqual(adlar(self.menu["2026-11-17"]["lunch"])[2], "Şehriyeli Pirinç Pilavı")
        self.assertEqual(adlar(self.menu["2026-11-18"]["lunch"])[2], "Cevizli Peynirli Makarna")
        self.assertEqual(adlar(self.menu["2026-11-25"]["lunch"])[1], "Kıymalı Yumurtalı Ispanak")

    def test_yazili_toplamlar_84_kalemle_eslesir(self):
        for tarih, g in self.menu.items():
            with self.subTest(tarih=tarih):
                self.assertEqual(g["lunch"]["kcal"], sum(o["kcal"] for o in g["lunch"]["items"]))

    def test_bos_hafta_sonu_hucreleri_gun_yapilmaz(self):
        self.assertNotIn("2026-11-01", self.menu)
        self.assertNotIn("2026-11-07", self.menu)
        self.assertNotIn("2026-12-01", self.menu)

    def test_guncel_ay_baglantisi_https_ve_url_kodlamasi(self):
        linkler = gop.pdf_baglantilari(metin("gop_aylik.html"), BUGUN)
        self.assertEqual([a for a, _ in linkler], [11, 10])
        self.assertEqual(linkler[0][1], "https://sosyaltesisler.gop.edu.tr/images/update/KASIM%2026%20L%C4%B0STE%20(3).pdf")

    def test_bilinmeyen_hafta_gunu_yil_eslesmesi_kabul_edilmez(self):
        self.assertEqual(gop.pdf_menu(oku("gop_kasim.pdf"), 11, date(2030, 11, 1)), {})
        self.assertEqual(gop.pdf_menu(b"", 11, BUGUN), {})


class OrduTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = odu.pdf_menu(oku("odu_ekim.pdf"))

    def test_iki_sayfa_ve_eylul_tasmasi(self):
        self.assertEqual(len(self.menu), 22)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-01", "2026-10-30"))
        self.assertNotIn("2026-09-28", self.menu)
        self.assertTrue(all(len(g["lunch"]["items"]) == 6 for t, g in self.menu.items() if t != "2026-10-29"))

    def test_birlesik_tarih_ve_ilk_gunun_sutunlari(self):
        self.assertEqual(adlar(self.menu["2026-10-01"]["lunch"]), [
            "Tavuklu Arpa Şehriye Çorba", "Etli Nohut", "Tavuk Tandır", "Kaşarlı Mantar Sote",
            "Şehriyeli Pirinç Pilavı/Mercimekli Bulgur Pilavı", "Ayran/Rus Salatası/Pembe Üzüm",
        ])

    def test_satir_sinirina_yukselen_metin_komsu_gune_karismaz(self):
        self.assertEqual(adlar(self.menu["2026-10-07"]["lunch"])[1], "Etli Bezelye")
        self.assertEqual(adlar(self.menu["2026-10-08"]["lunch"])[1], "Etli Kurufasülye")
        self.assertNotIn("Fırında", adlar(self.menu["2026-10-14"]["lunch"])[2])
        self.assertEqual(adlar(self.menu["2026-10-15"]["lunch"])[2], "Fırında Kalçalı Tavuk But (Elma Dilim Patates)")

    def test_sutun_sinirindaki_tavuk_ve_parcalanmis_sozcuk(self):
        self.assertEqual(adlar(self.menu["2026-10-19"]["lunch"])[1:3], ["Hamburger Menü (Fırın Elma Dilim Patates)", "Tavuk Kavurma"])
        self.assertEqual(adlar(self.menu["2026-10-02"]["lunch"])[3], "Patates Kavurması")
        self.assertEqual(adlar(self.menu["2026-10-23"]["lunch"])[2], "Lavaş Tavuk Tantuni")

    def test_tatil_kalorisiz_menu_ve_bos_hafta_sonu(self):
        self.assertEqual(self.menu["2026-10-29"], TATIL)
        self.assertNotIn("2026-10-03", self.menu)
        self.assertTrue(all("kcal" not in g["lunch"] for g in self.menu.values()))

    def test_saatler_ogrenciye_ait_personel_saatine_karismaz(self):
        u = odu.OrduUniversitesi(lambda url: oku("odu_saatler.html"))
        self.assertEqual(u.saatler(), {"lunch": "11:30–13:00", "dinner": "16:30–18:30"})
        self.assertTrue(all(set(g) == {"lunch"} for g in self.menu.values()))

    def test_dinamik_pdf_baglantisi(self):
        self.assertEqual(odu.pdf_baglantisi(metin("odu_sks.html")), "https://sksdb.odu.edu.tr/files/other/yemeklisteleri/ekim2026.pdf")
        self.assertIsNone(odu.pdf_baglantisi('<a href="/baska.pdf">Faaliyet Raporu</a>'))
        self.assertEqual(odu.pdf_menu(b""), {})


class GiresunTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = giresun.pdf_menu(oku("giresun_kasim.pdf"))

    def test_kasim_21_gun_84_yemek(self):
        self.assertEqual(len(self.menu), 21)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-30"))
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for g in self.menu.values()))

    def test_ilk_gunun_yemekleri_ve_toplam_kalorisi(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Tarhana Çorba", "Etli Nohut", "Şehriyeli Pirinç Pilavı", "Turşu"])
        self.assertEqual(gun["kcal"], 903)
        self.assertTrue(all("kcal" not in o for o in gun["items"]))

    def test_sarilmis_ana_yemek_tek_hucre_olarak_korunur(self):
        gun = self.menu["2026-11-03"]["lunch"]
        self.assertEqual(adlar(gun)[1], "Tavuklu Samanyolu Kebap/Mitit Köfte")
        self.assertEqual(adlar(self.menu["2026-11-04"]["lunch"])[1], "Tavuk Döner + Patates Kızartma")

    def test_alternatif_kaloriler_toplanmaz(self):
        gun = self.menu["2026-11-03"]["lunch"]
        self.assertNotIn("kcal", gun)
        self.assertEqual(gun["note"], "Ana yemek seçimine göre toplam kalori: 880/905 kcal")
        self.assertEqual(sum("note" in g["lunch"] for g in self.menu.values()), 8)
        self.assertIn("934/984", self.menu["2026-11-26"]["lunch"]["note"])

    def test_kisaltma_ve_son_hafta(self):
        self.assertEqual(adlar(self.menu["2026-11-06"]["lunch"])[2], "Zeytinyağlı Taze Fasulye")
        self.assertIn("İzmir Köfte", adlar(self.menu["2026-11-17"]["lunch"])[1])
        self.assertEqual(adlar(self.menu["2026-11-30"]["lunch"])[-1], "Pembe Salata")
        self.assertEqual(self.menu["2026-11-30"]["lunch"]["kcal"], 1105)

    def test_bos_hucreler_ve_imzalar_yemek_olmaz(self):
        self.assertNotIn("2026-11-07", self.menu)
        self.assertNotIn("2026-12-01", self.menu)
        self.assertFalse(any("Başkanı" in o["name"] for g in self.menu.values() for o in g["lunch"]["items"]))

    def test_baglanti_secimi_guncel_ay_ve_onceki_ay(self):
        sayfa = metin("giresun_sks.html")
        self.assertIn("KASIM%202026", giresun.pdf_baglantisi(sayfa, BUGUN))
        self.assertIn("EK%C4%B0M%202026", giresun.pdf_baglantisi(sayfa, date(2026, 10, 1)))
        self.assertIsNone(giresun.pdf_baglantisi("", BUGUN))

    def test_pdf_metin_bloklari_birbirinin_konumunu_tasiyamaz(self):
        p = giresun.pdf_parcalari(oku("giresun_kasim.pdf"))
        self.assertTrue(all(0 <= x < 842 and 0 <= y < 595 for x, y, _, _ in p))
        self.assertEqual(giresun.pdf_menu(b""), {})


class BayburtTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = bayburt.pdf_menu(oku("bayburt_ekim.pdf"))

    def test_21_menu_bir_tatil(self):
        self.assertEqual(len(self.menu), 22)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-01", "2026-10-30"))
        self.assertEqual(sum(bool(g["lunch"]["items"]) for g in self.menu.values()), 21)
        self.assertEqual(self.menu["2026-10-29"], TATIL)

    def test_ilk_gun_ve_kalori_uydurulmaz(self):
        self.assertEqual(adlar(self.menu["2026-10-01"]["lunch"]), ["Mercimek Çorba", "Karışık Musakka", "Şehriyeli Pirinç Pilavı", "Cacık"])
        self.assertTrue(all("kcal" not in g["lunch"] for g in self.menu.values()))
        self.assertTrue(all("kcal" not in o for g in self.menu.values() for o in g["lunch"]["items"]))

    def test_kisaltmalar_ve_secimli_yemek(self):
        self.assertEqual(adlar(self.menu["2026-10-05"]["lunch"])[1], "Şinitzel/Etli Kuru Fasulye")
        self.assertEqual(adlar(self.menu["2026-10-12"]["lunch"])[1], "Etli Nohut/Kadınbudu Köfte")
        self.assertEqual(adlar(self.menu["2026-10-27"]["lunch"])[0], "Tel Şehriye Çorbası")

    def test_son_hafta_ve_imza_disi(self):
        self.assertEqual(adlar(self.menu["2026-10-30"]["lunch"]), ["Çeşmi Nigar Çorba", "Fırın Tavuk", "Bulgur Pilavı", "Cacık"])
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for t, g in self.menu.items() if t != "2026-10-29"))
        self.assertNotIn("2026-10-03", self.menu)

    def test_tatli_tatil_sayilmaz(self):
        gun = self.menu["2026-10-15"]["lunch"]
        self.assertEqual(adlar(gun)[-1], "Tatlı")
        self.assertNotIn("note", gun)

    def test_aylik_json_baglantisi_ve_resim_reddi(self):
        veri = json.loads(metin("bayburt_aylik.json"))
        self.assertEqual(bayburt.pdf_baglantisi(veri), "https://apifile.bayburt.edu.tr/file/portal/yemekuploads/262A9C2C-9EF1-4A8E-8BD7-646C293F0764.pdf")
        veri["response"]["upload_object"]["filepath"] = "/menu.jpg"
        self.assertIsNone(bayburt.pdf_baglantisi(veri))
        self.assertIsNone(bayburt.pdf_baglantisi({"response": {"data": []}, "status": True}))
        self.assertIsNone(bayburt.pdf_baglantisi({"status": False}))
        self.assertIsNone(bayburt.pdf_baglantisi([]))

    def test_gunluk_api_bos_olsa_da_aylik_dosya_okunur(self):
        u, _ = okullar()[-1]
        self.assertEqual(u.menuler(), self.menu)
        self.assertEqual(bayburt.pdf_menu(b""), {})


class P6SozlesmeTesti(unittest.TestCase):
    def test_kayit_tekillik_ve_aylik_ogun(self):
        for u, _ in okullar():
            with self.subTest(okul=u.id):
                self.assertEqual(sum(k.id == u.id for k in KAYITLI), 1)
                self.assertFalse(u.birikimli)
                self.assertTrue(u.ad and u.kisa and u.sehir and u.kaynak.startswith("https://"))

    def test_tum_eklentiler_gercek_fixture_ile_agsiz_calisir(self):
        for u, sayi in okullar():
            with self.subTest(okul=u.id):
                menu = u.menuler()
                self.assertEqual(len(menu), sayi)
                self.assertTrue(all(set(g) == {"lunch"} for g in menu.values()))

    def test_ag_hatalari_anlamli_istisna(self):
        def hata(url):
            raise OSError("sunucuya ulaşılamadı")

        for sinif in (gop.TokatGaziosmanpasa, odu.OrduUniversitesi, giresun.GiresunUniversitesi, bayburt.BayburtUniversitesi):
            with self.subTest(okul=sinif.id):
                with self.assertRaisesRegex(RuntimeError, "sunucuya ulaşılamadı"):
                    sinif(hata).menuler()
        self.assertEqual(odu.OrduUniversitesi(hata).saatler(), {})

    def test_bos_ve_degisen_kaynak_sessizce_kabul_edilmez(self):
        for sinif in (gop.TokatGaziosmanpasa, odu.OrduUniversitesi, giresun.GiresunUniversitesi, bayburt.BayburtUniversitesi):
            with self.subTest(okul=sinif.id):
                with self.assertRaises(RuntimeError):
                    sinif(lambda url: b"{}").menuler()

    def test_pdf_indirme_hatasi_menu_gibi_yayinlanmaz(self):
        for u, _ in okullar():
            asil = u.indir

            def indir(url, asil=asil):
                if url.lower().endswith(".pdf"):
                    raise OSError("PDF indirilemedi")
                return asil(url)

            u.indir = indir
            with self.subTest(okul=u.id):
                with self.assertRaisesRegex(RuntimeError, "PDF indirilemedi"):
                    u.menuler()


if __name__ == "__main__":
    unittest.main()
