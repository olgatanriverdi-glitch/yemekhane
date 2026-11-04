"""P9: gerçek resmî HTML kırpıntılarıyla ağsız menü sözleşmesi."""
from pathlib import Path
import unittest

from yemekhane.universities import KAYITLI
from yemekhane.universities import atu, isubu, ksu, maku, osmaniye, tarsus, usak

FIX = Path(__file__).parent / "fixtures"
OKULLAR = (
    (osmaniye.OsmaniyeKorkutAta, 21, 4, 988, "Fırın Köfte"),
    (ksu.KahramanmarasSutcuImam, 21, 4, 1043, "Çiftlik Köfte"),
    (tarsus.TarsusUniversitesi, 21, 5, None, "Mercimek Çorbası"),
    (atu.AdanaAlparslanTurkes, 21, 4, 734, "Kremalı Mantar Çorbası"),
    (maku.BurdurMehmetAkifErsoy, 10, 4, 768, "Mercimek Çorba"),
    (isubu.IspartaUygulamaliBilimler, 20, 4, 950, "Kremalı Sebze Çorbası"),
    (usak.UsakUniversitesi, 16, 4, 1276, "Ayranaşı Çorbası"),
)


def oku(id):
    return (FIX / (id+"_kasim.html")).read_bytes()


class P9Sozlesme(unittest.TestCase):
    def test_gercek_kaynak_gun_sayilari_ve_2026(self):
        for sinif, sayi, *_ in OKULLAR:
            with self.subTest(okul=sinif.id):
                days = sinif(indirici=lambda url: oku(sinif.id)).menuler()
                self.assertEqual(len(days), sayi)
                self.assertTrue(all(t.startswith("2026-11-") for t in days))
                self.assertNotIn("2026-11-07", days)
                self.assertNotIn("2026-11-08", days)

    def test_carsamba_yemekleri_ve_toplam_kalori(self):
        for sinif, _, adet, kcal, ilk in OKULLAR:
            with self.subTest(okul=sinif.id):
                menu = sinif(indirici=lambda url: oku(sinif.id)).menuler()["2026-11-04"]["lunch"]
                self.assertEqual(len(menu["items"]), adet)
                self.assertEqual(menu["items"][0]["name"], ilk)
                self.assertEqual(menu.get("kcal"), kcal)

    def test_afis_tarih_kalori_ve_imzalar_yemek_degil(self):
        for sinif, *_ in OKULLAR:
            days = sinif(indirici=lambda url: oku(sinif.id)).menuler()
            for t, day in days.items():
                for meal in day.values():
                    for item in meal["items"]:
                        with self.subTest(okul=sinif.id, tarih=t, yemek=item):
                            self.assertNotRegex(item["name"], r"(?i)toplam|kalori|kkal|kcal|2026|senin menün|bugün|daire başkanı|ana yemek|henüz")
                            self.assertNotRegex(item["name"], r"\([A-Z](?:,\s*[A-Z])*\)")
                            self.assertTrue(item.get("kcal", 1) > 0)

    def test_bos_sayfa_basari_sayilmaz(self):
        for sinif, *_ in OKULLAR:
            with self.subTest(okul=sinif.id):
                with self.assertRaisesRegex(RuntimeError, "bulunamadı"):
                    sinif(indirici=lambda url: b"<html></html>").menuler()

    def test_ag_hatasi_anlamli(self):
        def hata(url):
            raise OSError("bağlantı kesildi")
        for sinif, *_ in OKULLAR:
            with self.subTest(okul=sinif.id):
                with self.assertRaisesRegex(RuntimeError, "indirilemedi.*bağlantı kesildi"):
                    sinif(indirici=hata).menuler()

    def test_tek_kayit_ve_pencere_birikimi(self):
        for sinif, *_ in OKULLAR:
            with self.subTest(okul=sinif.id):
                self.assertEqual(sum(u.id == sinif.id for u in KAYITLI), 1)
                self.assertEqual(sinif.birikimli, sinif in (maku.BurdurMehmetAkifErsoy, usak.UsakUniversitesi))


class P9Ayrintilar(unittest.TestCase):
    def test_osmaniye_ekim_arsivi_kasimla_karismaz(self):
        days = osmaniye.sayfa_menu(oku("osmaniye").decode())
        self.assertEqual(min(days), "2026-11-02")
        self.assertEqual(max(days), "2026-11-30")
        self.assertEqual(days["2026-11-30"]["lunch"]["kcal"], 975)
        self.assertNotIn("kcal", days["2026-11-04"]["lunch"]["items"][0])

    def test_ksu_kalemler_toplami_ve_gunluk_kopya(self):
        days = ksu.sayfa_menu(oku("ksu").decode())
        self.assertEqual([o["kcal"] for o in days["2026-11-04"]["lunch"]["items"]], [505,271,197,70])
        self.assertEqual(len(days["2026-11-04"]["lunch"]["items"]), 4)

    def test_tarsus_ozel_baslik_komsularla_tarihlenir(self):
        days = tarsus.sayfa_menu(oku("tarsus").decode())
        self.assertEqual([o["name"] for o in days["2026-11-04"]["lunch"]["items"]], ["Mercimek Çorbası","Sac Kavurma","Kısır","Pirinç Pilavı","Baklava"])
        self.assertEqual(set(days["2026-11-04"]), {"lunch"})

    def test_tarsus_belirsiz_komsularda_tarih_uydurmaz(self):
        sayfa = oku("tarsus").decode().replace("3.11.2026", "2.11.2026")
        self.assertNotIn("2026-11-04", tarsus.sayfa_menu(sayfa))

    def test_tarsus_ogrenci_ucreti(self):
        u=tarsus.TarsusUniversitesi(indirici=lambda url:(FIX/'tarsus_fiyat.html').read_bytes())
        self.assertEqual(u.fiyatlar(), [{'label':'Öğrenci','tl':35}])

    def test_atu_html_karakterleri_ve_kalem_kalorisi(self):
        days = atu.sayfa_menu(oku("atu").decode())
        self.assertEqual(days["2026-11-02"]["lunch"]["items"][0], {"name":"Toyga Çorbası","kcal":85})
        self.assertEqual(days["2026-11-02"]["lunch"]["kcal"], 1147)

    def test_atu_ogrenci_ucretleri(self):
        u = atu.AdanaAlparslanTurkes(indirici=lambda url: oku("atu"))
        self.assertEqual(u.fiyatlar(), [{"label":"Öğrenci (karta yükleme)","tl":30}, {"label":"Günlük öğrenci","tl":90}])

    def test_maku_ikinci_hafta_ve_ilceler_ayrilir(self):
        days = maku.sayfa_menu(oku("maku").decode())
        self.assertEqual(max(days), "2026-11-13")
        self.assertEqual(days["2026-11-02"]["lunch"]["items"][0]["name"], "Domates Çorba")
        self.assertEqual(days["2026-11-13"]["lunch"]["kcal"], 1188)

    def test_isubu_bugun_komsulardan_bulunur(self):
        days = isubu.sayfa_menu(oku("isubu").decode())
        self.assertEqual(days["2026-11-04"]["lunch"]["items"][1]["name"], "Çiftlik Kebabı")
        self.assertNotIn("2026-11-30", days)

    def test_usak_vejetaryen_ortak_yemekleri_tasir(self):
        day = usak.sayfa_menu(oku("usak").decode())["2026-11-04"]
        self.assertEqual(day["vegetarian"]["items"][1], {"name":"Sebze Graten","kcal":261})
        self.assertEqual(day["vegetarian"]["kcal"], 998)
        self.assertEqual(day["lunch"]["items"][0], day["vegetarian"]["items"][0])

    def test_usak_bilinmeyen_kalori_uydurulmaz(self):
        days = usak.sayfa_menu(oku("usak").decode())
        self.assertNotIn("kcal", days["2026-11-05"]["lunch"])
        self.assertNotIn("kcal", days["2026-11-25"]["vegetarian"])
        self.assertNotIn("kcal", days["2026-11-25"]["vegetarian"]["items"][1])

    def test_usak_etiketsiz_secenege_vejetaryen_denmez(self):
        day = usak.sayfa_menu(oku("usak").decode())["2026-11-20"]
        self.assertNotIn("vegetarian", day)
        self.assertNotIn("kcal", day["lunch"]["items"][1])
        self.assertNotIn("kcal", day["lunch"])
        self.assertIn("396 / 331 kcal", day["lunch"]["note"])
        self.assertIn("1207 / 1142 kcal", day["lunch"]["note"])


if __name__ == "__main__":
    unittest.main()
