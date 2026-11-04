"""P4: yedi okulun 1 Kasım 2026'da indirilen gerçek kaynaklarıyla ağsız test.

HTML fixture'ları menü bölümlerine kırpılmıştır; NEÜ JSON'u ve BTÜ'nün tek
sayfalık PDF'i gerçek alan/font kaynaklarını korur. Kaynaklar README P4'te.
"""
import copy
import json
import os
import unittest

from yemekhane.universities import KAYITLI, ahievran, aksaray, btu, kayseri, neu, nevsehir, subu

FIX = os.path.join(os.path.dirname(__file__), "fixtures")
OKULLAR = (
    (subu.SakaryaUygulamaliBilimler, "subu_merkez.html", 22),
    (btu.BursaTeknik, "btu_sks.html", 22),
    (neu.NecmettinErbakan, "neu_aylik.json", 24),
    (kayseri.KayseriUniversitesi, "kayseri_hafta.html", 5),
    (nevsehir.NevsehirHaciBektasVeli, "nevsehir_menu.html", 15),
    (ahievran.KirsehirAhiEvran, "ahievran_liste.html", 11),
    (aksaray.AksarayUniversitesi, "aksaray_liste.html", 22),
)
TATIL = {"lunch": {"items": [], "note": "Resmi tatil"}}


def oku(ad):
    with open(os.path.join(FIX, ad), "rb") as f:
        return f.read()


def metin(ad):
    return oku(ad).decode("utf-8")


def adlar(ogun):
    return [o["name"] for o in ogun["items"]]


class SubuTesti(unittest.TestCase):
    def setUp(self):
        self.menu = subu.sayfa_menu(metin("subu_merkez.html"))

    def test_aylik_takvim_ve_bos_sutunlar(self):
        self.assertEqual(len(self.menu), 22)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-01", "2026-10-30"))
        self.assertNotIn("2026-10-03", self.menu)
        self.assertNotIn("2026-11-02", self.menu)

    def test_merkez_yemekleri_ve_secimler(self):
        gun = self.menu["2026-10-01"]["lunch"]
        self.assertEqual(adlar(gun), ["Arpa Şehriye Çorba", "Patlıcan Musakka", "Ekşili Köfte", "Etsiz Taze Fasulye", "Sade Pirinç Pilavı", "Şeftali"])
        self.assertNotIn("kcal", gun)
        self.assertEqual(set(self.menu["2026-10-01"]), {"lunch"})

    def test_kisaltmalar_ve_sutun_eslesmesi(self):
        self.assertIn("Garnitürlü Et Döner", adlar(self.menu["2026-10-06"]["lunch"]))
        self.assertEqual(adlar(self.menu["2026-10-20"]["lunch"])[-2], "Şehriyeli Pirinç Pilavı")
        self.assertEqual(adlar(self.menu["2026-10-21"]["lunch"])[0], "Tarhana Çorba")
        self.assertEqual(adlar(self.menu["2026-10-30"]["lunch"])[-1], "Ayran")

    def test_iki_tatil(self):
        self.assertEqual(self.menu["2026-10-28"], TATIL)
        self.assertEqual(self.menu["2026-10-29"], TATIL)


class BtuTesti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.menu = btu.pdf_menu(oku("btu_ekim.pdf"))

    def test_dinamik_pdf_baglantisi(self):
        self.assertEqual(btu.pdf_baglantisi(metin("btu_sks.html")),
                         "https://depo.btu.edu.tr/img/sayfa/1790775471_eb123e325ccad93461c3.pdf")
        self.assertEqual(btu.pdf_baglantisi('<a href="/dosya/yeni.pdf"><strong>Yemek Listesi</strong></a>'),
                         "https://sks.btu.edu.tr/dosya/yeni.pdf")
        self.assertIsNone(btu.pdf_baglantisi('<a href="/rapor.pdf">Faaliyet Raporu</a>'))

    def test_ekim_ve_ilk_gun(self):
        self.assertEqual(len(self.menu), 22)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-01", "2026-10-30"))
        gun = self.menu["2026-10-01"]["lunch"]
        self.assertEqual(adlar(gun), ["Tarhana Çorba", "Orman Kebabı/Mantar Sote", "Pirinç Pilavı", "Süt Helvası", "Mercimek Köftesi"])
        self.assertEqual(gun["kcal"], 1270)
        self.assertTrue(all("kcal" not in o for o in gun["items"]))

    def test_sarilmis_satirlar_sutunlari_karistirmaz(self):
        self.assertEqual(adlar(self.menu["2026-10-06"]["lunch"]),
                         ["Tavuk Suyu Çorba", "Falafel/Yoğurtlu Garnitür-Sos", "Spagetti (Ketçap-Mayonez)", "Triliçe", "Çoban Salata"])
        self.assertEqual(adlar(self.menu["2026-10-26"]["lunch"])[1], "Kremalı Mantarlı Tavuk Sote-Patates Püresi/Bezelye")
        self.assertEqual(adlar(self.menu["2026-10-20"]["lunch"])[0], "Kremalı Mantar Çorba")
        self.assertEqual(adlar(self.menu["2026-10-16"]["lunch"])[2], "Arpa Şehriyeli Pirinç Pilavı")

    def test_tatil_bos_hafta_sonu_ve_altbilgi(self):
        self.assertEqual(self.menu["2026-10-29"], TATIL)
        self.assertNotIn("2026-10-31", self.menu)
        self.assertNotIn("2026-10-03", self.menu)
        self.assertEqual(adlar(self.menu["2026-10-30"]["lunch"])[-1], "Mevsim Salata")
        self.assertEqual(self.menu["2026-10-30"]["lunch"]["kcal"], 1125)

    def test_ogrenci_saati_yayindan_okunur(self):
        u = btu.BursaTeknik(lambda url: oku("btu_saatler.html"))
        self.assertEqual(u.saatler(), {"lunch": "11:05–14:00"})
        self.assertEqual(btu.BursaTeknik(lambda url: b"").saatler(), {})

    def test_metinsiz_pdf_ve_pdf_ag_hatasi(self):
        self.assertEqual(btu.pdf_menu(b"%PDF-1.4\n%%EOF\n"), {})

        def indir(url):
            if url == btu.SAYFA_URL:
                return oku("btu_sks.html")
            raise OSError("dosya sunucusu kapalı")

        with self.assertRaisesRegex(RuntimeError, "BTÜ:.*PDF.*dosya sunucusu"):
            btu.BursaTeknik(indir).menuler()

    def test_yayindaki_katki_payi_pdfi(self):
        baglanti = metin("btu_fiyat_baglanti.html")
        self.assertEqual(btu.fiyat_pdf_baglantisi(baglanti),
                         "https://depo.btu.edu.tr/img/sayfa/1785222625_a4ba005db81132dea3ab.pdf")
        u = btu.BursaTeknik(lambda url: oku("btu_fiyatlar.pdf") if url.endswith(".pdf") else baglanti.encode())
        self.assertEqual(u.fiyatlar(), [{"label": "Personel", "tl": 130}, {"label": "Öğrenci", "tl": 50}, {"label": "Diğer", "tl": 255}])


class NeuTesti(unittest.TestCase):
    def setUp(self):
        self.veri = json.loads(oku("neu_aylik.json"))
        self.menu = neu.json_menu(self.veri)

    def test_kasim_ve_araliga_sarkan_dort_gun(self):
        self.assertEqual(len(self.menu), 24)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-12-04"))
        self.assertEqual(sum(t.startswith("2026-11") for t in self.menu), 20)
        self.assertNotIn("2026-11-26", self.menu)  # kaynakta bu iş günü yok
        self.assertNotIn("2026-11-07", self.menu)

    def test_sifir_kalori_bilinmeyendir(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Etli Nohut", "Tereyağlı Bulgur Pilavı", "Süzme Yoğurt", "Meyve"])
        self.assertEqual(gun["items"][0]["kcal"], 321)
        self.assertNotIn("kcal", gun["items"][2])
        self.assertNotIn("kcal", gun)
        self.assertEqual(self.menu["2026-11-04"]["lunch"]["kcal"], 646)

    def test_ogun_adi_olmayan_kayit_ve_ayri_ogun(self):
        self.assertEqual(set(self.menu["2026-11-05"]), {"lunch"})
        self.assertEqual(self.menu["2026-11-05"]["lunch"]["kcal"], 1226)
        k = copy.deepcopy(self.veri["data"][0])
        k.update(ogun_adi="AKŞAM", toplam_kalori=1000)
        menu = neu.json_menu({"data": [self.veri["data"][0], k]})
        self.assertEqual(set(menu["2026-11-02"]), {"lunch", "dinner"})
        self.assertEqual(menu["2026-11-02"]["dinner"]["kcal"], 1000)

    def test_bos_tatil_ve_ozel_menu(self):
        k = {"tarih": "2026-10-29T00:00:00", "ogun_adi": "ÖĞLE", "yemek_adi1": "RESMİ TATİL"}
        self.assertEqual(neu.json_menu({"data": [k]}), {"2026-10-29": TATIL})
        k["ozelmenukodu"] = 1
        self.assertEqual(neu.json_menu({"data": [k, {"tarih": "2026-11-07"}]}), {})

    def test_api_hatasi_ve_cakisan_kayitlar(self):
        for veri in ({"success": False, "data": []}, {"data": {}}, []):
            with self.subTest(veri=veri), self.assertRaisesRegex(ValueError, "NEÜ"):
                neu.json_menu(veri)
        with self.assertRaisesRegex(RuntimeError, "JSON.*okunamadı"):
            neu.NecmettinErbakan(lambda url: b"<html>Hata</html>").menuler()
        k = dict(self.veri["data"][0], yemek_adi1="Başka Yemek")
        with self.assertRaisesRegex(ValueError, "birden fazla"):
            neu.json_menu({"data": [self.veri["data"][0], k]})


class KayseriTesti(unittest.TestCase):
    def setUp(self):
        self.u = kayseri.KayseriUniversitesi(lambda url: oku("kayseri_hafta.html"))
        self.menu = self.u.menuler()

    def test_hafta_ve_servis_saati(self):
        self.assertEqual(len(self.menu), 5)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-06"))
        self.assertEqual(self.u.saatler(), {"lunch": "11:30–13:30"})
        self.assertTrue(self.u.birikimli)

    def test_yemekler_ve_altbilgi(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Ezogelin Çorbası", "Hasanpaşa Köfte", "Pirinç Pilavı", "Ayran"])
        self.assertNotIn("kcal", gun)
        self.assertEqual(adlar(self.menu["2026-11-06"]["lunch"])[-1], "Meyve")
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for g in self.menu.values()))

    def test_bos_tatil_ve_gecersiz_tarih(self):
        s = ('<b>29.10.2026 PERŞEMBE</b><ul><li>RESMİ TATİL</li></ul>'
             '<b>31.11.2026 SALI</b><ul><li>Çorba</li></ul>'
             '<b>07.11.2026 CUMARTESİ</b><ul><li>-</li></ul>')
        self.assertEqual(kayseri.sayfa_menu(s), {"2026-10-29": TATIL})


class NevsehirTesti(unittest.TestCase):
    def setUp(self):
        self.menu = nevsehir.sayfa_menu(metin("nevsehir_menu.html"))

    def test_uc_haftalik_pencere(self):
        self.assertEqual(len(self.menu), 15)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-26", "2026-11-13"))
        self.assertNotIn("2026-11-07", self.menu)
        self.assertTrue(nevsehir.NevsehirHaciBektasVeli().birikimli)

    def test_yemekler_ve_ogun_toplami(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Mercimek Çorbası", "Etli Barbunya", "Pirinç Pilavı", "Turşu"])
        self.assertEqual(gun["kcal"], 900)
        self.assertTrue(all("kcal" not in o for o in gun["items"]))
        self.assertTrue(all(set(g) == {"lunch"} for g in self.menu.values()))

    def test_tatil_ve_yorumdaki_ornekler(self):
        self.assertEqual(self.menu["2026-10-28"], TATIL)
        self.assertEqual(self.menu["2026-10-29"], TATIL)
        sayfa = metin("nevsehir_menu.html") + '/* Örnek: {"tarih":"31.12.2025","ana_yemek":"Piliç Roti"} */'
        self.assertEqual(nevsehir.sayfa_menu(sayfa), self.menu)

    def test_bos_gun_ve_bozuk_dizi(self):
        s = 'var menuVerileri = [{"tarih":"7.11.2026","ana_yemek":"-"},{"tarih":"31.11.2026","ana_yemek":"Çorba"},];'
        self.assertEqual(nevsehir.sayfa_menu(s), {})
        with self.assertRaisesRegex(RuntimeError, "menuVerileri.*okunamadı"):
            nevsehir.NevsehirHaciBektasVeli(lambda url: b"var menuVerileri = [bozuk];").menuler()

    def test_ogrenci_fiyatlari(self):
        u = nevsehir.NevsehirHaciBektasVeli(lambda url: oku("nevsehir_fiyatlar.html"))
        self.assertEqual(u.fiyatlar(), [
            {"label": "Öğrenci Aylık Ve Haftalık", "tl": 37},
            {"label": "Öğrenci İkinci Öğün Günlük", "tl": 102.5},
        ])


class AhiEvranTesti(unittest.TestCase):
    def setUp(self):
        self.menu = ahievran.sayfa_menu(metin("ahievran_liste.html"))

    def test_tarih_penceresi(self):
        self.assertEqual(len(self.menu), 11)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-23", "2026-11-06"))
        self.assertNotIn("2026-11-01", self.menu)
        self.assertTrue(ahievran.KirsehirAhiEvran().birikimli)

    def test_yemekler_ve_kalori(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Çatal Çorba", "Kuru Fasulye", "Şehriyeli Pirinç Pilavı", "Ayran"])
        self.assertEqual(gun["kcal"], 583)
        self.assertEqual(gun["items"][-1]["kcal"], 23)

    def test_alerjenler_ve_eksik_parantez_yemek_adina_girmez(self):
        gun = self.menu["2026-10-26"]["lunch"]
        self.assertEqual(gun["items"][2], {"name": "Şehriyeli Pirinç Pilavı", "kcal": 170})
        self.assertEqual(gun["kcal"], 613)
        self.assertEqual(self.menu["2026-10-23"]["lunch"]["items"][1], {"name": "Tavuk Sote", "kcal": 510})
        self.assertTrue(all("gluten" not in o["name"].lower() for g in self.menu.values() for o in g["lunch"]["items"]))

    def test_tatil_ve_sifir_kalori(self):
        self.assertEqual(self.menu["2026-10-28"], TATIL)
        self.assertEqual(self.menu["2026-10-29"], TATIL)
        self.assertEqual(ahievran.yemek_ogesi("Ayran (0 kcal) süt ve süt ürünleri"), {"name": "Ayran"})

    def test_rezervasyonlu_ve_rezervasyonsuz_ucret(self):
        u = ahievran.KirsehirAhiEvran(lambda url: oku("ahievran_fiyatlar.html"))
        self.assertEqual(u.fiyatlar(), [
            {"label": "Öğrenci (Rezervasyonlu)", "tl": 28},
            {"label": "Öğrenci (Rezervasyonsuz)", "tl": 50},
            {"label": "Öğrenci (İkinci Yemek)", "tl": 94},
        ])


class AksarayTesti(unittest.TestCase):
    def setUp(self):
        self.menu = aksaray.sayfa_menu(metin("aksaray_liste.html"))

    def test_aylik_tarihler_ve_kaynaktaki_yazim_hatalari(self):
        self.assertEqual(len(self.menu), 22)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-01", "2026-10-30"))
        self.assertIn("2026-10-02", self.menu)  # kaynak: 02.10.206
        self.assertIn("2026-10-09", self.menu)  # kaynak: 09.06.2026
        self.assertNotIn("2026-06-09", self.menu)
        self.assertNotIn("0206-10-02", self.menu)
        self.assertNotIn("2026-10-03", self.menu)

    def test_yemekler_ve_yazili_toplam_onceligi(self):
        gun = self.menu["2026-10-01"]["lunch"]
        self.assertEqual(adlar(gun), ["Kremalı Mantar Çorba", "Etli Nohut", "Tereyağlı Bulgur Pilavı", "Cacık"])
        self.assertEqual([o["kcal"] for o in gun["items"]], [184, 350, 291, 69])
        self.assertEqual(gun["kcal"], 890)  # kaynak toplamı 894'e düzeltilmez

    def test_eksik_kapanis_parantezi(self):
        gun = self.menu["2026-10-21"]["lunch"]
        self.assertEqual(gun["items"][1], {"name": "Etli Nohut", "kcal": 350})
        self.assertEqual(gun["kcal"], 808)

    def test_iki_hucreye_yazilmis_tatil(self):
        self.assertEqual(self.menu["2026-10-29"], TATIL)
        self.assertEqual(adlar(self.menu["2026-10-30"]["lunch"])[-1], "Cacık")

    def test_gecersiz_ve_bos_gun(self):
        s = '<table><tr><td>31.11.2026 SALI</td>' + '<td>Çorba</td>' * 5 + '</tr><tr><td>07.11.2026 CUMARTESİ</td>' + '<td></td>' * 5 + '</tr></table>'
        self.assertEqual(aksaray.sayfa_menu(s), {})


class P4EklentiTesti(unittest.TestCase):
    def test_gercek_kaynaklar_ag_kullanmadan_okunur(self):
        for sinif, fixture, sayi in OKULLAR:
            with self.subTest(okul=sinif.id):
                istekler = []

                def indir(url):
                    istekler.append(url)
                    return oku("btu_ekim.pdf" if url.endswith(".pdf") else fixture)

                menu = sinif(indir).menuler()
                self.assertEqual(len(menu), sayi)
                self.assertEqual(len(istekler), 2 if sinif is btu.BursaTeknik else 1)
                self.assertTrue(all(set(g) == {"lunch"} for g in menu.values()))

    def test_ag_hatasi_okulu_ve_nedeni_belirtir(self):
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
                bos = b'{"success":true,"data":[]}' if sinif is neu.NecmettinErbakan else b"<html></html>"
                with self.assertRaisesRegex(RuntimeError, "bulunamadı"):
                    sinif(lambda url: bos).menuler()

    def test_kayitlar_benzersiz_ve_pencereler_birikimli(self):
        idler = [u.id for u in KAYITLI]
        self.assertEqual(len(idler), len(set(idler)))
        for sinif, _, _ in OKULLAR:
            with self.subTest(okul=sinif.id):
                self.assertIn(sinif.id, idler)
                self.assertEqual(sinif().birikimli, sinif.id in {"kayseri", "nevsehir", "ahievran"})

    def test_istege_bagli_ucret_hatasi_menuye_engel_olmaz(self):
        def indir(url):
            raise OSError("geçici hata")

        for sinif in (btu.BursaTeknik, nevsehir.NevsehirHaciBektasVeli, ahievran.KirsehirAhiEvran):
            with self.subTest(okul=sinif.id):
                self.assertEqual(sinif(indir).fiyatlar(), [])


if __name__ == "__main__":
    unittest.main()
