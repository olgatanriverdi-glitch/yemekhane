"""P5: 1 Kasım 2026'da indirilen gerçek HTML/JSON ile ağsız testler.

Fixture'lar menü bölümlerine kırpılmıştır. Karatekin'de önceki ayın iki
kartı ay seçimini, Kastamonu'da konukevleri yemekhane ayrımını sınar.
Amasya'da yönetim kimlikleri çıkarılmış, yemek/metin/kalori korunmuştur.
"""
import copy
import json
import os
import unittest
from datetime import date
from urllib.parse import parse_qs, urlsplit

from yemekhane.universities import KAYITLI, amasya, karatekin, kastamonu, ohu, sinop

FIX = os.path.join(os.path.dirname(__file__), "fixtures")
OKULLAR = (
    (ohu.NigdeOmerHalisdemir, "ohu_liste.html", 21),
    (karatekin.CankiriKaratekin, "karatekin_liste.html", 21),
    (kastamonu.KastamonuUniversitesi, "kastamonu_liste.html", 20),
    (sinop.SinopUniversitesi, "sinop_liste.html", 29),
    (amasya.AmasyaUniversitesi, "amasya_kasim.json", 21),
)
TATIL = {"lunch": {"items": [], "note": "Tatil"}}


def oku(ad):
    with open(os.path.join(FIX, ad), "rb") as f:
        return f.read()


def metin(ad):
    return oku(ad).decode("utf-8")


def adlar(ogun):
    return [o["name"] for o in ogun["items"]]


class OhuTesti(unittest.TestCase):
    def setUp(self):
        self.menu = ohu.sayfa_menu(metin("ohu_liste.html"))

    def test_kasim_ayi_ve_hafta_sonu(self):
        self.assertEqual(len(self.menu), 21)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-30"))
        self.assertNotIn("2026-11-01", self.menu)
        self.assertNotIn("2026-11-07", self.menu)

    def test_yemekler_toplam_ve_yer_tutucular(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Ezogelin Çorba", "Etli Kuru Fasulye", "Şehriyeli Pirinç Pilavı", "Havuç Tarator"])
        self.assertEqual(gun["kcal"], 1022)
        self.assertTrue(all("kcal" not in o for g in self.menu.values() for o in g["lunch"]["items"]))
        self.assertTrue(all(len(g["lunch"]["items"]) == 4 for g in self.menu.values()))
        self.assertEqual(self.menu["2026-11-30"]["lunch"]["kcal"], 997)

    def test_kisaltma_ve_artiksiz_ad(self):
        self.assertEqual(adlar(self.menu["2026-11-10"]["lunch"])[1], "Garnitürlü Soslu Tavuk Baget")
        self.assertTrue(all("--" not in o["name"] for g in self.menu.values() for o in g["lunch"]["items"]))

    def test_tatil_bos_ve_gecersiz_tarih(self):
        s = ('<tr class="cart_table_item"><td>29.10.2026</td><td>RESMİ TATİL-- --</td></tr>'
             '<tr class="cart_table_item"><td>31.11.2026</td><td>Çorba, Pilav 800</td></tr>'
             '<tr class="cart_table_item"><td>07.11.2026</td><td>-- -- --</td></tr>')
        self.assertEqual(ohu.sayfa_menu(s), {"2026-10-29": TATIL})

    def test_sifir_ve_eksik_toplam_bilinmeyendir(self):
        for toplam in ("0", ""):
            s = '<tr class="cart_table_item"><td>02.11.2026</td><td>Çorba, Pilav %s</td></tr>' % toplam
            self.assertNotIn("kcal", ohu.sayfa_menu(s)["2026-11-02"]["lunch"])


class KaratekinTesti(unittest.TestCase):
    def setUp(self):
        self.menu = karatekin.sayfa_menu(metin("karatekin_liste.html"))

    def test_arsivden_son_dolu_ay_alinir(self):
        self.assertIn("Eyl&#xFC;l", metin("karatekin_liste.html"))
        self.assertEqual(len(self.menu), 21)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-10-01", "2026-10-30"))
        self.assertNotIn("2026-09-30", self.menu)
        self.assertNotIn("2026-10-29", self.menu)

    def test_yemekler_kalem_ve_toplam_kalori(self):
        gun = self.menu["2026-10-01"]["lunch"]
        self.assertEqual(adlar(gun), ["Ezogelin Çorba", "Fırın Tavuk", "Pirinç Pilavı", "Salata"])
        self.assertEqual(gun["items"][1]["kcal"], 270)
        self.assertEqual(gun["kcal"], 819)
        self.assertEqual(adlar(self.menu["2026-10-30"]["lunch"])[-1], "Cacık")

    def test_secimli_yemek_tek_kalemdir(self):
        gun = self.menu["2026-10-26"]["lunch"]
        self.assertEqual(len(gun["items"]), 4)
        self.assertEqual(gun["items"][1], {"name": "Etli Kurufasülye/Adana Kebap(Piliç)", "kcal": 268})
        self.assertEqual(gun["kcal"], 739)
        self.assertEqual(set(self.menu["2026-10-26"]), {"lunch"})

    def test_yayinlanmayan_kalori_uretilmez(self):
        for gun in range(13, 17):
            ogun = self.menu["2026-10-%02d" % gun]["lunch"]
            self.assertNotIn("kcal", ogun)
            self.assertTrue(all("kcal" not in o for o in ogun["items"]))

    def test_yazili_toplam_kalem_toplamiyla_ezilmez(self):
        s = metin("karatekin_liste.html").replace("819 kcal</p>", "900 kcal</p>")
        self.assertEqual(karatekin.sayfa_menu(s)["2026-10-01"]["lunch"]["kcal"], 900)

    def test_bos_ve_gecersiz_kart_yeni_ay_sayilmaz(self):
        bos = ('<article class="food-menu-day-card"><h2 class="food-menu-day-heading">02 Kasım Pazartesi 2026</h2><ul></ul></article>'
               '<article class="food-menu-day-card"><h2 class="food-menu-day-heading">31 Kasım Salı 2026</h2>'
               '<ul><li><a class="food-menu-day-item-name">Çorba</a></li></ul></article>')
        self.assertEqual(karatekin.sayfa_menu(bos), {})
        self.assertEqual(karatekin.sayfa_menu(metin("karatekin_liste.html") + bos), self.menu)


class KastamonuTesti(unittest.TestCase):
    def setUp(self):
        self.sayfa = metin("kastamonu_liste.html")
        self.menu = kastamonu.sayfa_menu(self.sayfa)

    def test_merkezi_yemekhane_konukevine_karismaz(self):
        self.assertEqual(len(self.menu), 20)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-27"))
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Ezogelin Çorba", "Püreli Tavuk Şinitzel", "Soslu Makarna", "Mevsim Salata"])
        self.assertNotIn("Sucuklu Tarhana Çorbası", adlar(gun))
        self.assertNotIn("2026-11-30", self.menu)

    def test_kalemler_toplam_ve_kisaltmalar(self):
        self.assertEqual(self.menu["2026-11-02"]["lunch"]["kcal"], 1054)
        self.assertEqual(self.menu["2026-11-02"]["lunch"]["items"][1]["kcal"], 474)
        self.assertEqual(adlar(self.menu["2026-11-03"]["lunch"])[0], "Tavuklu Şehriye Çorba")
        self.assertEqual(adlar(self.menu["2026-11-27"]["lunch"])[-1], "İrmik Helvası")

    def test_resmi_saat_ve_ogrenci_fiyati(self):
        u = kastamonu.KastamonuUniversitesi(lambda url: self.sayfa.encode())
        self.assertEqual(u.saatler(), {"lunch": "11:30–13:30", "dinner": "16:30–18:00"})
        self.assertEqual(u.fiyatlar(), [{"label": "Öğrenci", "tl": 50}])
        self.assertTrue(all(set(g) == {"lunch"} for g in self.menu.values()))

    def test_tatil_bos_gun_ve_gecersiz_tarih(self):
        kayitlar = [
            {"tarih": "2026-10-29", "yemekVarMi": False, "yemekYokAciklamaTR": "Resmi tatil"},
            {"tarih": "2026-11-07", "yemekVarMi": False, "yemekYokAciklamaTR": "Yemek bulunmamaktadır."},
            {"tarih": "2026-11-31", "yemek1TR": "Çorba"},
            {"tarih": "2026-11-08", "yemek1TR": "-"},
        ]
        veri = '"data":' + json.dumps([{"yemekhaneId": 1, "aylikYemekListesi": kayitlar}])
        sayfa = '<script>self.__next_f.push([1,' + json.dumps(veri) + '])</script>'
        self.assertEqual(kastamonu.sayfa_menu(sayfa), {"2026-10-29": TATIL})

    def test_json_calistirilmaz_ve_merkez_yoksa_baska_menu_alinmaz(self):
        self.assertEqual(kastamonu.sayfa_menu('<script>window.menu = "Çorba"</script>'), {})
        self.assertEqual(kastamonu.sayfa_menu(self.sayfa.replace('\\"yemekhaneId\\":1,', '\\"yemekhaneId\\":99,')), {})
        self.assertIsNone(kastamonu.yemek_ogesi("-"))
        self.assertNotIn("kcal", kastamonu.yemek_ogesi("ÇORBA 0KKAL"))

    def test_istege_bagli_bilgi_hatasi_menu_hatasi_sayilmaz(self):
        def indir(url):
            raise OSError("sunucu kapalı")

        u = kastamonu.KastamonuUniversitesi(indir)
        self.assertEqual(u.saatler(), {})
        self.assertEqual(u.fiyatlar(), [])


class SinopTesti(unittest.TestCase):
    def setUp(self):
        self.menu = sinop.sayfa_menu(metin("sinop_liste.html"))

    def test_kasim_21_menu_8_tatil_ve_bos_pazar(self):
        self.assertEqual(len(self.menu), 29)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-30"))
        self.assertEqual(sum(bool(g["lunch"]["items"]) for g in self.menu.values()), 21)
        self.assertEqual(sum(g == TATIL for g in self.menu.values()), 8)
        self.assertNotIn("2026-11-01", self.menu)
        self.assertEqual(self.menu["2026-11-07"], TATIL)

    def test_yemekler_yazim_duzeltmesi_ve_toplam(self):
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Ezogelin Çorba", "Orman Kebabı", "Mısırlı Pirinç Pilavı", "Meyve"])
        self.assertEqual(gun["kcal"], 820)
        self.assertTrue(all("kcal" not in o for o in gun["items"]))
        self.assertEqual(self.menu["2026-11-30"]["lunch"]["kcal"], 840)

    def test_uc_yemek_yayinlanan_gune_dorduncu_eklenmez(self):
        gun = self.menu["2026-11-26"]["lunch"]
        self.assertEqual(adlar(gun), ["Tavuk Suyu Çorba", "Etli Yeşil Fasulye", "Bulgur Pilavı"])
        self.assertEqual(gun["kcal"], 691)

    def test_sifir_toplam_ve_baska_tablo_alinmaz(self):
        s = metin("sinop_liste.html").replace("<td>820</td>", "<td>0</td>")
        self.assertNotIn("kcal", sinop.sayfa_menu(s)["2026-11-02"]["lunch"])
        self.assertEqual(sinop.sayfa_menu(s.replace('id="yemek-listesi"', 'id="haberler"')), {})

    def test_gecersiz_tarih_atlanir(self):
        s = metin("sinop_liste.html").replace("2 Kasım 2026</td>", "31 Kasım 2026</td>", 1)
        self.assertNotIn("2026-11-02", sinop.sayfa_menu(s))


class AmasyaTesti(unittest.TestCase):
    def setUp(self):
        self.veri = json.loads(oku("amasya_kasim.json"))
        self.menu = amasya.json_menu(self.veri)

    def test_kasim_menu_ve_kalori(self):
        self.assertEqual(len(self.menu), 21)
        self.assertEqual((min(self.menu), max(self.menu)), ("2026-11-02", "2026-11-30"))
        gun = self.menu["2026-11-02"]["lunch"]
        self.assertEqual(adlar(gun), ["Mercimek Çorbası", "Et Kavurma", "Şehriyeli Pirinç Pilavı", "Ayran"])
        self.assertEqual(gun["kcal"], 942)
        self.assertTrue(all("kcal" not in o for o in gun["items"]))
        self.assertNotIn("2026-11-07", self.menu)

    def test_secimli_yemek_tek_ogun_ve_tek_kalem(self):
        self.assertEqual(adlar(self.menu["2026-11-05"]["lunch"])[1], "Fırın Köftesi/Patates Püresi")
        self.assertEqual(adlar(self.menu["2026-11-25"]["lunch"])[1], "Kıymalı Ispanak/Yoğurt")
        self.assertTrue(all(set(g) == {"lunch"} for g in self.menu.values()))

    def test_guncel_ay_doluysa_onceki_ay_sorgulanmaz(self):
        istekler = []

        def indir(url):
            istekler.append(url)
            return oku("amasya_kasim.json")

        self.assertEqual(amasya.AmasyaUniversitesi(indir, date(2026, 11, 1)).menuler(), self.menu)
        self.assertEqual(istekler, [amasya.API_URL + "?yil=2026&ay=11"])

    def test_guncel_ay_bossa_onceki_yayin_okunur(self):
        istekler = []

        def indir(url):
            istekler.append(url)
            return (b'{"yil":2026,"ay":11,"gunler":[]}' if url.endswith("ay=11") else oku("amasya_ekim.json"))

        menu = amasya.AmasyaUniversitesi(indir, date(2026, 11, 1)).menuler()
        self.assertEqual(len(menu), 20)
        self.assertEqual((min(menu), max(menu)), ("2026-10-01", "2026-10-30"))
        self.assertEqual(istekler[-1], amasya.API_URL + "?yil=2026&ay=10")

    def test_ocak_geri_donusu_onceki_yilin_araligi(self):
        istekler = []

        def indir(url):
            istekler.append(url)
            q = parse_qs(urlsplit(url).query)
            return json.dumps({"yil": int(q["yil"][0]), "ay": int(q["ay"][0]), "gunler": []}).encode()

        with self.assertRaisesRegex(RuntimeError, "bulunamadı"):
            amasya.AmasyaUniversitesi(indir, date(2027, 1, 1)).menuler()
        self.assertEqual(istekler[-1], amasya.API_URL + "?yil=2026&ay=12")

    def test_bos_tatil_donem_disi_ve_gecersiz_tarih(self):
        veri = {"yil": 2026, "ay": 10, "gunler": [
            {"tarih": "2026-10-29", "corbaYemekAdi": "RESMİ TATİL"},
            {"tarih": "2026-10-03", "corbaYemekAdi": "—", "anaYemekAdi": "-"},
            {"tarih": "2026-11-02", "corbaYemekAdi": "Çorba"},
            {"tarih": "2026-10-32", "corbaYemekAdi": "Çorba"},
        ]}
        self.assertEqual(amasya.json_menu(veri), {"2026-10-29": TATIL})

    def test_sifir_ve_eksik_kalori_bilinmeyendir(self):
        for deger in (0, None, ""):
            veri = copy.deepcopy(self.veri)
            veri["gunler"][0]["toplamKalori"] = deger
            self.assertNotIn("kcal", amasya.json_menu(veri)["2026-11-02"]["lunch"])

    def test_bozuk_api_ve_yanlis_ay_rededilir(self):
        for veri in ([], {}, {"gunler": None}):
            with self.subTest(veri=veri), self.assertRaisesRegex(ValueError, "gunler"):
                amasya.json_menu(veri)
        with self.assertRaisesRegex(ValueError, "eşleşmiyor"):
            amasya.json_menu(self.veri, 2026, 10)
        with self.assertRaisesRegex(RuntimeError, "JSON.*okunamadı"):
            amasya.AmasyaUniversitesi(lambda url: b"<html>Hata</html>", date(2026, 11, 1)).menuler()


class P5EklentiTesti(unittest.TestCase):
    def test_gercek_fixture_ile_ag_kullanmadan_okuma(self):
        for sinif, fixture, sayi in OKULLAR:
            with self.subTest(okul=sinif.id):
                istekler = []

                def indir(url):
                    istekler.append(url)
                    return oku(fixture)

                u = sinif(indir, date(2026, 11, 1)) if sinif is amasya.AmasyaUniversitesi else sinif(indir)
                menu = u.menuler()
                self.assertEqual(len(menu), sayi)
                self.assertEqual(len(istekler), 1)
                self.assertTrue(all(set(g) == {"lunch"} for g in menu.values()))

    def test_ag_hatasi_okulu_ve_nedeni_belirtir(self):
        def indir(url):
            raise OSError("zaman aşımı")

        for sinif, _, _ in OKULLAR:
            with self.subTest(okul=sinif.id), self.assertRaisesRegex(RuntimeError, "indirilemedi.*zaman aşımı") as ctx:
                sinif(indir).menuler()
            self.assertIsInstance(ctx.exception.__cause__, OSError)

    def test_bos_sayfa_basari_sayilmaz(self):
        for sinif, _, _ in OKULLAR:
            if sinif is amasya.AmasyaUniversitesi:
                continue  # JSON'un boş iki ayı Amasya takvim testinde sınanır.
            with self.subTest(okul=sinif.id), self.assertRaisesRegex(RuntimeError, "bulunamadı"):
                sinif(lambda url: b"<html></html>").menuler()

    def test_okullar_kayitli_benzersiz_ve_aylik(self):
        idler = [u.id for u in KAYITLI]
        self.assertEqual(len(idler), len(set(idler)))
        for sinif, _, _ in OKULLAR:
            with self.subTest(okul=sinif.id):
                self.assertIn(sinif.id, idler)
                self.assertFalse(sinif().birikimli)


if __name__ == "__main__":
    unittest.main()
