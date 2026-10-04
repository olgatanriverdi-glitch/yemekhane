"""HBV, MGÜ, ODTÜ ve ASBÜ eklentilerinin testleri. Fixture'lar okul sitelerinden alınmış gerçek parçalardır.
ODTÜ'nün OCR tablo çözücüsü sahte sözcük kutularıyla sınanır (tesseract'ın kendisi burada çalıştırılmaz)."""
import os
import unittest
from datetime import date

from yemekhane import elle
from yemekhane.ocr import Kelime, tsv_kelimeler
from yemekhane.universities import asbu, hbv, mgu, odtu

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def oku(ad):
    with open(os.path.join(FIX, ad), encoding="utf-8") as f:
        return f.read()


class HbvTesti(unittest.TestCase):
    def test_json_menu(self):
        m = hbv.sayfa_menu(oku("hbv_menu.json"))
        self.assertEqual(sorted(m), ["2026-10-01", "2026-10-02", "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08"])
        gun = m["2026-10-01"]["lunch"]
        self.assertEqual(gun["items"][0], {"name": "Yayla Çorba", "kcal": 105})
        self.assertEqual([o["name"] for o in gun["items"]], ["Yayla Çorba", "Tavuk Haşlama", "Su Böreği", "Erik"])
        self.assertEqual(gun["kcal"], 105 + 404 + 375 + 92)

    def test_oge_bicimleri(self):
        self.assertEqual(hbv.yemek_ogesi("Mercimek Çorbası (137 Kcal)"), {"name": "Mercimek Çorbası", "kcal": 137})
        self.assertEqual(hbv.yemek_ogesi("Ayran(73 kcal)"), {"name": "Ayran", "kcal": 73})
        self.assertEqual(hbv.yemek_ogesi("Adana+Lavaş (500 Kcal)"), {"name": "Adana + Lavaş", "kcal": 500})
        self.assertEqual(hbv.yemek_ogesi("Mevsim Salata"), {"name": "Mevsim Salata"})
        self.assertIsNone(hbv.yemek_ogesi("  "))

    def test_bos_ve_bozuk_kayitlar_atlanir(self):
        m = hbv.sayfa_menu('[{"menu_date": "2026-10-03 00:00:00", "food_list": [], "total_calorie": 0},'
                           ' {"menu_date": "bozuk", "food_list": ["Çorba (10 Kcal)"]},'
                           ' {"menu_date": "2026-10-04", "food_list": ["Çorba"]}]')
        self.assertEqual(m, {"2026-10-04": {"lunch": {"items": [{"name": "Çorba"}]}}})      # kalorisiz öğede günün kalorisi yazılmaz

    def test_sinif(self):
        u = hbv.HaciBayramVeli(lambda url: oku("hbv_menu.json").encode("utf-8"))
        self.assertEqual(len(u.menuler()), 6)
        self.assertEqual(u.fiyatlar(), [{"label": "Öğrenci (Öğle Yemeği)", "tl": 50}])
        self.assertEqual(u.saatler(), {})           # okul servis saati yayınlamıyor: 'genelde' etiketiyle varsayılan gösterilir


class MguTesti(unittest.TestCase):
    def test_haftalik_tablo(self):
        m = mgu.sayfa_menu(oku("mgu_menu.html"), date(2026, 10, 4))
        self.assertEqual(sorted(m)[0], "2026-09-28")
        self.assertEqual(sorted(m)[-1], "2026-10-09")
        self.assertEqual(len(m), 10)                             # iki hafta, hafta sonu yok
        self.assertEqual([o["name"] for o in m["2026-09-28"]["lunch"]["items"]],
                         ["Mercimek Çorba", "Etli Nohut Yemeği", "Pirinç Pilavı", "Meyve Salata"])
        self.assertEqual([o["name"] for o in m["2026-09-29"]["lunch"]["items"]],
                         ["Şehriye Çorba", "Akçaabat Köfte", "Soslu Makarna", "Ayran", "Salata"])     # 'Ayran/Salata' ikiye ayrılır
        self.assertNotIn("kcal", m["2026-10-05"]["lunch"])       # okul kalori yayınlamıyor

    def test_personel_tablosu_atlanir(self):
        m = mgu.sayfa_menu(oku("mgu_menu.html"), date(2026, 10, 4))
        self.assertTrue(all(len(t) == 10 for t in m))

    def test_yil_cikarimi(self):
        self.assertEqual(mgu.hafta_araligi("28 Eylül - 02 Ekim Haftası", date(2026, 10, 4)), (date(2026, 9, 28), date(2026, 10, 2)))
        self.assertEqual(mgu.hafta_araligi("29 Aralık - 02 Ocak Haftası", date(2026, 12, 30)), (date(2026, 12, 29), date(2027, 1, 2)))
        self.assertEqual(mgu.hafta_araligi("29 Aralık - 02 Ocak Haftası", date(2027, 1, 5)), (date(2026, 12, 29), date(2027, 1, 2)))
        self.assertIsNone(mgu.hafta_araligi("MEMURLARDAN", date(2026, 10, 4)))

    def test_tatil_hucresi(self):
        sayfa = ('<table><thead><tr><th colspan="2">26 Ekim - 30 Ekim Haftası</th></tr></thead><tbody>'
                 '<tr><td><strong>Pazartesi</strong></td><td><strong>Salı</strong></td></tr>'
                 '<tr><td>Mercimek Çorba</td><td>RESMİ TATİL</td></tr></tbody></table>')
        m = mgu.sayfa_menu(sayfa, date(2026, 10, 20))
        self.assertEqual(m["2026-10-26"]["lunch"]["items"], [{"name": "Mercimek Çorba"}])
        self.assertEqual(m["2026-10-27"]["lunch"], {"items": [], "note": "Tatil"})

    def test_saat_ve_ucret(self):
        self.assertEqual(mgu.ayrintilar(oku("mgu_yemekhane.html")), {"saat": "11:30–13:30", "ucret": 40})
        u = mgu.AnkaraMuzikGuzelSanatlar(lambda url: oku("mgu_yemekhane.html" if "yemekhane" in url else "mgu_menu.html").encode("utf-8"),
                                         bugun=date(2026, 10, 4))
        self.assertEqual(u.saatler(), {"lunch": "11:30–13:30"})
        self.assertEqual(u.fiyatlar(), [{"label": "Öğrenci (Öğle Yemeği)", "tl": 40}])
        self.assertEqual(len(u.menuler()), 10)


class AsbuTesti(unittest.TestCase):
    def test_saat_ve_ucret(self):
        self.assertEqual(asbu.saat_ayikla(oku("asbu_menu.html")), {"lunch": "11:30–13:30", "vegetarian": "11:30–13:30"})
        self.assertEqual(asbu.ucret_ayikla(oku("asbu_beslenme.html")), [{"label": "Öğrenci (Öğle Yemeği)", "tl": 45}])

    def test_elle_girilen_menu(self):
        m = asbu.AnkaraSosyalBilimler().menuler()
        self.assertEqual(len(m), 22)
        g = m["2026-10-05"]
        self.assertEqual([o["name"] for o in g["lunch"]["items"]],
                         ["Tarhana Çorba", "Fırında Köfte-Püreli", "Peynirli Makarna", "Mevsim Salata", "Tulumba"])
        self.assertEqual(g["lunch"]["kcal"], 184 + 290 + 360 + 55 + 270)       # okulun yazdığı 1057 değil, kalem toplamı
        self.assertEqual([o["name"] for o in g["vegetarian"]["items"]][1], "Zeytinyağlı Taze Fasulye")     # ana yemek yerine etsiz karşılığı
        self.assertEqual(m["2026-10-29"]["lunch"], {"items": [], "note": "Resmi tatil"})
        self.assertNotIn("kcal", m["2026-10-07"]["vegetarian"])                # etsiz yemeğin kalorisi resimde boş

    def test_kalori_toplamlari_tutarli(self):
        for tarih, gun in elle.yukle("asbu").items():
            for ogun in gun.values():
                if "kcal" in ogun:
                    self.assertEqual(ogun["kcal"], sum(o["kcal"] for o in ogun["items"]), tarih)


# --- ODTÜ ---------------------------------------------------------------------------------------------------------

GEN = 2480


def yazi(metin, sol, y, harf=15, yuk=26):
    sonuc, x = [], sol
    for parca in metin.split():
        g = harf * len(parca)
        sonuc.append(Kelime(parca, x, int(y - yuk / 2), g, yuk))
        x += g + 12
    return sonuc


def sag_hizali(metin, sag, y):
    g = 15 * len(metin)
    return Kelime(metin, sag - g, int(y - 13), g, 26)


def sahte_sayfa(bloklar, corba_tablosu=True):
    """Gerçek ODTÜ sayfasının düzenini taklit eder: sol tarih sütunu, öğle adı + kalori, akşam adı + kalori, her günün altında toplam."""
    kel = yazi("KAFETERYA MÜDÜRLÜĞÜNÜN 01.10.2026 - 31.10.2026 TARİHLERİ ARASINDAKİ TABLDOT YEMEK LİSTESİ", 700, 300)
    kel += yazi("ÖĞLE YEMEĞİ", 480, 345) + [sag_hizali("Kalori", 1375, 345)] + yazi("AKŞAM YEMEĞİ", 1405, 345) + [sag_hizali("Kalori", 2260, 345)]
    y = 400
    for tarih, gun, ogle, ot, aksam, at in bloklar:
        ilk = y
        for (a, k), (b, l) in zip(ogle, aksam):
            kel += yazi(a, 480, y) + [sag_hizali(str(k), 1375, y)] + yazi(b, 1405, y) + [sag_hizali(str(l), 2260, y)]
            y += 40
        kel += [sag_hizali(str(ot), 1375, y), sag_hizali(str(at), 2260, y)]
        if tarih:
            kel += yazi(tarih, 200, (ilk + y) / 2 - 12) + yazi(gun, 220, (ilk + y) / 2 + 14)
        y += 56
    if corba_tablosu:      # sayfa sonundaki yalnızca çorbaların listelendiği tablo (tek kalori sütunu)
        y += 100
        for tarih, ad, k in (("01.10.2026", "Tarhana Çorba", 175), ("02.10.2026", "Kremalı Soğan Çorba", 150)):
            kel += yazi(tarih, 200, y) + yazi(ad, 480, y) + [sag_hizali(str(k), 2260, y)]
            y += 60
    return kel


GUN1 = ("01.10.2026", "PERŞEMBE",
        [("Tarhana Çorba", 175), ("Hardal Soslu Kremalı Tavuk", 309), ("Bulgur Pilavı", 377), ("Acılı Ezme", 106)], 967,
        [("Tarhana Çorba", 175), ("Hardal Soslu Kremalı Tavuk", 309), ("Bulgur Pilavı", 377), ("Acılı Ezme", 106)], 967)
GUN2 = ("05.10.2026", "PAZARTESİ",
        [("Mercimek Çorba", 156), ("Etli Elbistan Tava", 476), ("Dereotlu Pirinç Pilavı", 466), ("Meyve", 116)], 1214,
        [("Mercimek Çorba", 156), ("Piliç Baget Haşlama", 346), ("Napoliten Soslu Makarna", 326), ("Zyt. Barbunya", 135)], 963)


class OdtuOcrTesti(unittest.TestCase):
    def test_tsv_kelimeler(self):
        tsv = ("level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n"
               "1\t1\t0\t0\t0\t0\t0\t0\t2480\t3507\t-1\t\n"
               "5\t1\t1\t1\t1\t1\t480\t400\t90\t26\t96.5\tTarhana\n"
               "5\t1\t1\t1\t1\t2\t580\t400\t70\t26\t91\tÇorba\n"
               "5\t1\t1\t1\t1\t3\t900\t400\t30\t26\t-1\t|\n"
               "5\t1\t1\t1\t1\t4\t950\t400\t30\t26\t88\t \n"
               "4\t1\t1\t1\t1\t0\t480\t400\t200\t26\t-1\t\n")
        genislik, yukseklik, kelimeler = tsv_kelimeler(tsv)
        self.assertEqual((genislik, yukseklik), (2480, 3507))
        self.assertEqual([k.metin for k in kelimeler], ["Tarhana", "Çorba"])
        self.assertEqual(kelimeler[1].sol, 580)

    def test_iki_gun_okunur_ve_corba_tablosu_yok_sayilir(self):
        gunler = odtu.tablo_ayikla(sahte_sayfa([GUN1, GUN2]), GEN)
        self.assertEqual(sorted(gunler), ["2026-10-01", "2026-10-05"])
        g = gunler["2026-10-01"]
        self.assertEqual(g["lunch"], {"items": [{"name": "Tarhana Çorba", "kcal": 175}, {"name": "Hardal Soslu Kremalı Tavuk", "kcal": 309},
                                                {"name": "Bulgur Pilavı", "kcal": 377}, {"name": "Acılı Ezme", "kcal": 106}], "kcal": 967})
        self.assertEqual(g["dinner"]["items"], g["lunch"]["items"])
        self.assertEqual([o["name"] for o in gunler["2026-10-05"]["dinner"]["items"]],
                         ["Mercimek Çorba", "Piliç Baget Haşlama", "Napoliten Soslu Makarna", "Zeytinyağlı Barbunya"])
        self.assertEqual(gunler["2026-10-05"]["dinner"]["kcal"], 963)

    def test_yanlis_okunan_rakam_gunu_dusurur(self):
        yanlis_toplam = GUN2[:3] + (1215,) + GUN2[4:]                       # toplam bir fazla okunmuş
        self.assertEqual(sorted(odtu.tablo_ayikla(sahte_sayfa([GUN1, yanlis_toplam]), GEN)), ["2026-10-01"])
        ogle = list(GUN2[2])
        ogle[1] = ("Etli Elbistan Tava", 486)                              # bir kalem yanlış okunmuş
        yanlis_kalem = GUN2[:2] + (ogle,) + GUN2[3:]
        self.assertEqual(sorted(odtu.tablo_ayikla(sahte_sayfa([GUN1, yanlis_kalem]), GEN)), ["2026-10-01"])

    def test_okunamayan_rakam_gunu_dusurur(self):
        sayfa = sahte_sayfa([GUN1, GUN2])
        sayfa = [Kelime("47S", k.sol, k.ust, k.gen, k.yuk) if k.metin == "476" else k for k in sayfa]
        self.assertEqual(sorted(odtu.tablo_ayikla(sayfa, GEN)), ["2026-10-01"])

    def test_tablo_cizgisi_yapisik_rakam(self):
        sayfa = [Kelime("|" + k.metin if k.metin == "309" else k.metin + "|" if k.metin == "967" else k.metin, k.sol, k.ust, k.gen, k.yuk)
                 for k in sahte_sayfa([GUN1])]
        self.assertEqual(sorted(odtu.tablo_ayikla(sayfa, GEN)), ["2026-10-01"])

    def test_tarihi_okunamayan_blok_atlanir_ve_siradaki_etkilenmez(self):
        sahte = (None,) + GUN1[1:]
        self.assertEqual(sorted(odtu.tablo_ayikla(sahte_sayfa([sahte, GUN2]), GEN)), ["2026-10-05"])

    def test_eksik_toplam_satiri_sonraki_gunleri_bozmaz(self):
        gun3 = ("06.10.2026", "SALI") + GUN2[2:]
        sayfa = [k for k in sahte_sayfa([GUN1, GUN2, gun3]) if k.metin != "967"]      # 1. günün toplam satırı okunamamış
        # 1. ve 2. günün kalemleri birikir ve 2. günün toplamında birlikte reddedilir; 3. gün yine doğru okunur
        self.assertEqual(sorted(odtu.tablo_ayikla(sayfa, GEN)), ["2026-10-06"])

    def test_ad_duzeltme(self):
        self.assertEqual(odtu.ad_duzelt("Yoğ. Yeşil Merc. Erişte Salatası"), "Yoğurtlu Yeşil Mercimek Erişte Salatası")
        self.assertEqual(odtu.ad_duzelt("Ezolin Çorba"), "Ezogelin Çorba")
        self.assertEqual(odtu.ad_duzelt("| Kase  Yoğurt ."), "Kase Yoğurt")


def sahte_pdf(*parcalar):
    """İçinde verilen (süzgeç, bayt) görselleri bulunan en küçük PDF benzeri veri."""
    cikti = [b"%PDF-1.4\n"]
    for i, (suzgec, veri) in enumerate(parcalar):
        cikti.append(b"%d 0 obj\n<< /Type /XObject /Subtype /Image /Width 10 /Height 10 /Filter /%s /Length %d >>\nstream\n"
                     % (i + 5, suzgec, len(veri)) + veri + b"\nendstream\nendobj\n")
    cikti.append(b"%%EOF")
    return b"".join(cikti)


class OdtuTesti(unittest.TestCase):
    def test_pdf_baglantisi_saat_ucret(self):
        self.assertEqual(odtu.pdf_baglantisi(oku("odtu_ana.html")), "https://kafeterya.metu.edu.tr/system/files/ekim_2026_maliyetsiz_tabldot_menu.pdf")
        self.assertIsNone(odtu.pdf_baglantisi('<a href="/baska.pdf">Rapor</a>'))
        self.assertEqual(odtu.saat_ayikla(oku("odtu_saat.html")), {"lunch": "11:30–14:00", "dinner": "17:00–18:30"})      # hafta sonu saatleri değil
        self.assertEqual(odtu.ucret_ayikla(oku("odtu_fiyat.html")),
                         [{"label": "Öğrenci (Öğle Yemeği)", "tl": 50}, {"label": "Öğrenci (Akşam Yemeği)", "tl": 50}])

    def test_pdf_gorselleri(self):
        jpeg1, jpeg2 = b"\xff\xd8\xff\xe0AAAA\xff\xd9", b"\xff\xd8\xff\xe0BBBBBB\xff\xd9"
        pdf = sahte_pdf((b"DCTDecode", jpeg1), (b"FlateDecode", b"x\x9c...."), (b"DCTDecode", jpeg2))
        self.assertEqual(odtu.pdf_gorselleri(pdf), [jpeg1, jpeg2])           # Flate görseli atlanır
        self.assertEqual(odtu.pdf_gorselleri(b"%PDF-1.4 metin"), [])

    def test_elle_girilen_menu_tutarli(self):
        gunler = elle.yukle("odtu")
        self.assertEqual(len(gunler), 31)
        for tarih, gun in gunler.items():
            self.assertEqual(set(gun), {"lunch", "dinner"}, tarih)
            for ogun in gun.values():
                self.assertEqual(ogun["kcal"], sum(o["kcal"] for o in ogun["items"]), tarih)
                self.assertEqual(len(ogun["items"]), 4, tarih)
        self.assertEqual([o["name"] for o in gunler["2026-10-16"]["dinner"]["items"]],
                         ["Melek Çorba", "Orman Kebabı", "Yoğurtlu Yeşil Mercimek Erişte Salatası", "Meyve"])

    def _universite(self, okuyucu):
        pdf = sahte_pdf((b"DCTDecode", b"\xff\xd8JPEG\xff\xd9"))

        def sahte_indir(url):
            if url.endswith(".pdf"):
                return pdf
            return oku("odtu_ana.html").encode("utf-8")
        return odtu.OrtaDoguTeknik(sahte_indir, okuyucu)

    def test_tesseract_yoksa_yalniz_elle_veri(self):
        class Yok:
            kullanilabilir = staticmethod(lambda: False)
        self.assertEqual(len(self._universite(Yok).menuler()), 31)

    def test_ocr_eksik_gunleri_doldurur_elle_girileni_ezmez(self):
        kasim = ("02.11.2026", "PAZARTESİ", GUN2[2], GUN2[3], GUN2[4], GUN2[5])
        degisik = ("01.10.2026", "PERŞEMBE", [("Başka Çorba", 100), ("Başka Yemek", 200), ("Pilav", 300), ("Meyve", 100)], 700) + GUN1[4:]
        sayfa = sahte_sayfa([degisik, kasim])

        class Sahte:
            kullanilabilir = staticmethod(lambda: True)

            @staticmethod
            def kelimeler(resim, psm):
                return (GEN, 3507, sayfa)
        m = self._universite(Sahte).menuler()
        self.assertEqual(len(m), 32)
        self.assertIn("2026-11-02", m)
        self.assertEqual(m["2026-10-01"]["lunch"]["items"][0]["name"], "Tarhana Çorba")      # elle girilen korunur
        self.assertEqual([o["name"] for o in m["2026-11-02"]["dinner"]["items"]][-1], "Zeytinyağlı Barbunya")

    def test_ocr_hatasi_menuyu_bozmaz(self):
        class Bozuk:
            kullanilabilir = staticmethod(lambda: True)

            @staticmethod
            def kelimeler(resim, psm):
                raise RuntimeError("tesseract çöktü")
        self.assertEqual(len(self._universite(Bozuk).menuler()), 31)

    def test_karsilastirma(self):
        elle_gunler = elle.yukle("odtu")
        ayni, ortak = odtu.karsilastir({"2026-10-01": elle_gunler["2026-10-01"], "2026-10-02": elle_gunler["2026-10-01"], "2026-11-01": {}}, elle_gunler)
        self.assertEqual((ayni, ortak), (1, 2))


if __name__ == "__main__":
    unittest.main()
