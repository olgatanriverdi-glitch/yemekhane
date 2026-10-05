"""İzmir (Ege, DEÜ, İKÇÜ), Antalya (ALKÜ), Çanakkale (ÇOMÜ), Sivas (SBTÜ, Cumhuriyet), Erzurum (Atatürk), Trabzon (KTÜ, Trabzon Üni.), Samsun (OMÜ, Samsun Üni.)
ve Gebze Teknik eklentileri, `pdf.py`'nin yeni yetenekleri ve build'in `birikimli` davranışı. Fixture'lar okul sitelerinden alınmış gerçek parçalardır
(PDF'lerde yalnızca gömülü görsel akışları kırpıldı: xref tablosu geçersizdir, pdf.py nesneleri düzenli ifadeyle okur)."""
import json
import os
import tempfile
import unittest
from datetime import date
from unittest import mock

from yemekhane import build, dishes, elle, model, pdf
from yemekhane.universities import KAYITLI, alku, atauni, comu, cumhuriyet, ege, ikcu, ktu, omu, samsun, sbtu
from yemekhane.universities.base import Universite

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def oku(ad, mod="r"):
    with open(os.path.join(FIX, ad), mod, **({"encoding": "utf-8"} if mod == "r" else {})) as f:
        return f.read()


def adlar(gun):
    return [o["name"] for o in gun["items"]]


class OrtakYardimcilarTesti(unittest.TestCase):
    def test_kisaltma_ac(self):
        ac = lambda s: model.baslik_yap_serbest(model.kisaltma_ac(s))
        self.assertEqual(ac("ZYT.YAĞLI YOĞ.BROKOLİ"), "Zeytinyağlı Yoğurtlu Brokoli")
        self.assertEqual(ac("Zy. Taze Fasulye"), "Zeytinyağlı Taze Fasulye")
        self.assertEqual(ac("Dom. Sos. Makarna"), "Domates Soslu Makarna")
        self.assertEqual(ac("Tel Şeh.Pirinç Pilavı"), "Tel Şehriyeli Pirinç Pilavı")
        self.assertEqual(ac("Yoğ. Közl. Kapya Biber"), "Yoğurtlu Közlenmiş Kapya Biber")
        self.assertEqual(ac("Kre. Brokoli Çorba"), "Kremalı Brokoli Çorba")
        self.assertEqual(ac("SEB.BULGUR PİLAVI"), "Sebzeli Bulgur Pilavı")
        self.assertEqual(ac("NOH.PİRİNÇ PİLAVI"), "Nohutlu Pirinç Pilavı")
        self.assertEqual(ac("Tavuk Pirzola / P. Kızartma"), "Tavuk Pirzola / Patates Kızartma")      # 'P.' yalnızca 'Kızartma' önünde açılır
        self.assertEqual(ac("Mercimek Çorba"), "Mercimek Çorba")            # kısaltma yoksa dokunulmaz

    def test_ay_ve_yil(self):
        self.assertEqual((model.ay_no("EKİM"), model.ay_no("Şubat"), model.ay_no("Ağustos"), model.ay_no("bilinmez")), (10, 2, 8, None))
        self.assertEqual(model.yil_sec(31, 12, date(2027, 1, 2)), date(2026, 12, 31))        # yıl geçişinde bugüne en yakın yıl
        self.assertEqual(model.yil_sec(5, 10, date(2026, 10, 5)), date(2026, 10, 5))
        self.assertIsNone(model.yil_sec(30, 2, date(2026, 1, 1)))

    def test_etiket_ve_gun_icerigi(self):
        self.assertEqual(model.etiket_temizle("<td> A&amp;B&nbsp;\n <b>C</b></td>"), "A&B C")
        self.assertEqual(model.gun_icerigi([{"name": "A", "kcal": 1}, {"name": "B", "kcal": 2}]), {"items": [{"name": "A", "kcal": 1}, {"name": "B", "kcal": 2}], "kcal": 3})
        self.assertNotIn("kcal", model.gun_icerigi([{"name": "A", "kcal": 1}, {"name": "B"}]))


class OmuTesti(unittest.TestCase):
    def test_aylik_tablo(self):
        m = omu.sayfa_menu(oku("omu_menu.html"))
        self.assertEqual(len(m), 20)                                       # hafta içi günler; hafta sonu satırları boş
        self.assertNotIn("2026-10-03", m)
        self.assertEqual(adlar(m["2026-10-01"]["lunch"]), ["Brokoli Çorba", "Kıymalı Nohut", "Pirinç Pilavı", "Turşu"])
        self.assertEqual(adlar(m["2026-10-13"]["lunch"]), ["Düğün Çorba", "Pilavüstü Fırın Tavuk", "Zeytinyağlı Yoğurtlu Brokoli", "Aşure"])
        self.assertNotIn("kcal", m["2026-10-01"]["lunch"])               # okul kalori yayınlamıyor

    def test_tablo_yoksa_bos(self):
        self.assertEqual(omu.sayfa_menu("<html></html>"), {})

    def test_sinif(self):
        u = omu.OndokuzMayis(lambda url: oku("omu_menu.html").encode("utf-8"))
        self.assertEqual((u.id, len(u.menuler())), ("omu", 20))


class SbtuTesti(unittest.TestCase):
    def test_haftalik_kartlar(self):
        m = sbtu.sayfa_menu(oku("sbtu_menu.html"))
        self.assertEqual((len(m), min(m), max(m)), (21, "2026-10-01", "2026-10-30"))
        g = m["2026-10-01"]["lunch"]
        self.assertEqual(g["items"][0], {"name": "Yayla Çorbası", "kcal": 98})
        self.assertEqual(g["kcal"], 98 + 215 + 237 + 120 + 128)           # ekmek de listede
        self.assertEqual(m["2026-10-05"]["lunch"]["kcal"], 891)           # 'bugün' kartı da okunur

    def test_secmeli_yemek_iki_oge_olur_ve_gun_kalorisi_yazilmaz(self):
        g = sbtu.sayfa_menu(oku("sbtu_menu.html"))["2026-10-02"]["lunch"]
        self.assertEqual(g["items"][1:3], [{"name": "Biber Dolması", "kcal": 262}, {"name": "Şinitzel", "kcal": 285}])      # '262/285 kal' ayrı ayrı
        self.assertNotIn("kcal", g)

    def test_sekme_adi_ogun_turu(self):
        self.assertEqual([sbtu.ogun_turu(s) for s in ("Öğlen Yemeği", "Akşam Yemeği", "Vejetaryen Menü", "Kahvaltı", "Diğer")],
                         ["lunch", "dinner", "vegetarian", "breakfast", None])

    def test_oge_ayikla(self):
        self.assertEqual(sbtu.oge_ayikla('<span class="badge">98 kal</span>YAYLA ÇORBASI'), [{"name": "Yayla Çorbası", "kcal": 98}])
        self.assertEqual(sbtu.oge_ayikla('<span class="badge">283 kal</span>SALATA/ AYRAN'), [{"name": "Salata"}, {"name": "Ayran"}])     # sayı uyuşmuyor: kalorisiz
        self.assertEqual(sbtu.oge_ayikla('<span class="badge">0 kal</span>SU'), [{"name": "Su"}])


class AlkuTesti(unittest.TestCase):
    def test_haftalik_carousel(self):
        m = alku.sayfa_menu(oku("alku_menu.html"))
        self.assertEqual(sorted(m), ["2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09"])
        g = m["2026-10-05"]["lunch"]
        self.assertEqual(g["items"][0], {"name": "Mercimek Çorbası", "kcal": 166})
        self.assertEqual(g["kcal"], 166 + 265 + 274 + 74)

    def test_birikimli(self):
        self.assertTrue(alku.AlanyaAlaaddinKeykubat.birikimli)


class CumhuriyetTesti(unittest.TestCase):
    def setUp(self):
        self.m = cumhuriyet.sayfa_menu(oku("cumhuriyet_menu.html"), date(2026, 10, 5))

    def test_takvim_izgarasi(self):
        self.assertEqual((len(self.m), min(self.m), max(self.m)), (22, "2026-10-01", "2026-10-30"))
        self.assertEqual(adlar(self.m["2026-10-01"]["lunch"]), ["Anadolu Çorba", "Çiftlik Kebap", "Buhara Pilavı", "Kakaolu Puding"])

    def test_bugun_hucresinin_tarihi_komsulardan_bulunur(self):
        # 02 Ekim Cuma'dan sonra gelen 'BUGÜN' hücresi: bir sonraki iş günü = 5 Ekim Pazartesi (hafta sonu atlanır)
        self.assertEqual(adlar(self.m["2026-10-05"]["lunch"]), ["Ezogelin Çorba", "Tavuk Şinitsel/Patates Kızartma", "Sebzeli Makarna", "Ayran"])
        # bugün parametresi yalnızca komşu hiç yoksa kullanılır: farklı bir 'bugün' sonucu değiştirmez
        self.assertEqual(cumhuriyet.sayfa_menu(oku("cumhuriyet_menu.html"), date(2030, 1, 1))["2026-10-05"], self.m["2026-10-05"])

    def test_resmi_tatil(self):
        self.assertEqual(self.m["2026-10-28"], {"lunch": {"items": [], "note": "Resmi tatil"}})
        self.assertEqual(self.m["2026-10-29"], {"lunch": {"items": [], "note": "Resmi tatil"}})

    def test_is_gunu_ekle(self):
        self.assertEqual(cumhuriyet.is_gunu_ekle(date(2026, 10, 2), 1), date(2026, 10, 5))
        self.assertEqual(cumhuriyet.is_gunu_ekle(date(2026, 10, 5), -1), date(2026, 10, 2))


class KtuTesti(unittest.TestCase):
    def setUp(self):
        self.m = ktu.sayfa_menu(oku("ktu_menu.html"))

    def test_gunler(self):
        self.assertEqual(sorted(self.m), ["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02",
                                          "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09"])

    def test_kalori_ve_alerjen_kodlari_ayiklanir(self):
        g = self.m["2026-09-28"]["lunch"]
        self.assertEqual(g["items"][0], {"name": "Şehriye Çorba", "kcal": 108})            # '(1)' alerjen kodu atıldı
        self.assertEqual(g["items"][3], {"name": "Şehriyeli Pirinç Pilavı", "kcal": 329})       # '(1,4)' atıldı

    def test_secenekler_ayri_oge_olur_ve_isaretler_atilir(self):
        g = self.m["2026-10-01"]["lunch"]
        self.assertEqual(adlar(g), ["Toyga Çorba", "Köfteli Avcı Kebabı", "Sebzeli Körili Tavuk", "Şehriyeli Pirinç Pilavı", "Meyve", "Ayran"])   # '(sy)' atıldı, 'Sebz.' açıldı
        self.assertNotIn("kcal", g)                    # seçenekli günde toplam kalori yazılmaz (iki seçenek toplanırdı)
        self.assertEqual(self.m["2026-10-06"]["lunch"]["items"][2], {"name": "İmambayıldı", "kcal": 300})        # '(sy) (vejetaryen)' atıldı

    def test_kalorisiz_ogeler(self):
        self.assertEqual(self.m["2026-09-30"]["lunch"]["items"][3], {"name": "Peynirli Makarna"})
        self.assertEqual(self.m["2026-10-05"]["lunch"]["items"][4], {"name": "Meyve"})

    def test_hucre_ogeleri(self):
        self.assertEqual(ktu.hucre_ogeleri("Tulumba Tatlısı 296 Kcal (1,3,12) / Cacık 100 Kcal (4) "),
                         [{"name": "Tulumba Tatlısı", "kcal": 296}, {"name": "Cacık", "kcal": 100}])
        self.assertEqual(ktu.hucre_ogeleri("(vejetaryen)  Zy. Taze Fasulye 180 Kcal"), [{"name": "Zeytinyağlı Taze Fasulye", "kcal": 180}])
        self.assertEqual(ktu.hucre_ogeleri("  "), [])


class KtuBirikimliTesti(unittest.TestCase):
    def test_sayfa_gecmis_haftalari_kaydirdigi_icin_birikimli(self):
        self.assertTrue(ktu.KaradenizTeknik.birikimli)
        u = ktu.KaradenizTeknik(lambda url: oku("ktu_menu.html").encode("utf-8"))
        self.assertEqual((len(u.menuler()), u.fiyatlar(), u.saatler()), (10, [], {}))


class IkcuTesti(unittest.TestCase):
    def test_bugun_ve_yarin(self):
        m = ikcu.sayfa_menu(oku("ikcu_menu.html"), date(2026, 10, 5))
        self.assertEqual(sorted(m), ["2026-10-05", "2026-10-06"])
        self.assertEqual(adlar(m["2026-10-05"]["lunch"]), ["Mercimek Çorba", "Etli Kuru Fasulye", "Pirinç Pilavı", "Karışık Turşu"])
        self.assertEqual(adlar(m["2026-10-05"]["vegetarian"]), ["Mercimek Çorba", "Kuru Fasulye", "Pirinç Pilavı", "Karışık Turşu", "Yoğurt"])
        self.assertEqual(set(m["2026-10-06"]), {"lunch", "vegetarian"})            # '<ul>' sırası değişse de türler doğru

    def test_yil_bugune_gore_secilir(self):
        m = ikcu.sayfa_menu(oku("ikcu_menu.html"), date(2027, 1, 3))            # sayfa 'Ekim' diyor ama bugün Ocak 2027: en yakın yıl 2026
        self.assertEqual(sorted(m), ["2026-10-05", "2026-10-06"])

    def test_birikimli_ve_sinif(self):
        self.assertTrue(ikcu.IzmirKatipCelebi.birikimli)
        u = ikcu.IzmirKatipCelebi(lambda url: oku("ikcu_menu.html").encode("utf-8"), bugun=date(2026, 10, 5))
        self.assertEqual(len(u.menuler()), 2)


class AtauniTesti(unittest.TestCase):
    def test_bugun_ve_yarin_yalnizca_merkez_yemekhane(self):
        m = atauni.sayfa_menu(oku("atauni_menu.html"))
        self.assertEqual(sorted(m), ["2026-10-05", "2026-10-06"])
        self.assertEqual(adlar(m["2026-10-05"]["lunch"]), ["Kırmızı Mercimek Çorba", "Etli Mevsim Türlü", "Şehriyeli Pirinç Pilavı", "Tatlı"])      # gramaj atıldı
        self.assertEqual(adlar(m["2026-10-06"]["lunch"])[0], "Yoğurt Çorba")            # 'Konuk Evi 2 Menü' alınmaz
        self.assertTrue(atauni.AtaturkUniversitesi.birikimli)


class EgeTesti(unittest.TestCase):
    BUGUN = date(2026, 10, 5)

    def test_baglanti_turu(self):
        bt = ege.baglanti_turu
        self.assertEqual(bt("Ekim\xa0Ayı Öğle Yemeği Menüsü"), (10, "lunch"))
        self.assertEqual(bt("Eylül Ayı Akşam Yemeği Menüsü"), (9, "dinner"))
        self.assertEqual(bt("Ekim Ayı Vejeteryan Öğle Yemeği Menüsü"), (10, "vegetarian"))
        for alinmayan in ("Ekim Ayı Vejeteryan Akşam Yemeği Menüsü", "Ekim Ayı Vegan Öğle Yemeği Menüsü", "Ekim Ayı Öğle Glutensiz Yemek Listesi",
                          "Ekim Ayı Kahvaltı Menüsü", "Ekim Ayı Salata Listesi", "Yemek Bursu"):
            self.assertIsNone(bt(alinmayan), alinmayan)

    def test_sayfa_baglantilari(self):
        b = ege.sayfa_baglantilari(oku("ege_liste.html"))
        self.assertEqual([(a, t) for a, t, _ in b], [(10, "lunch"), (10, "dinner"), (10, "vegetarian"), (9, "lunch"), (9, "dinner"), (9, "vegetarian")])
        self.assertEqual(b[0][2], "https://sksdb.ege.edu.tr/files/sksdb/icerik/2025YEMEK/ekimog.docx")      # .DOC (kahvaltı/salata) alınmaz

    def test_docx_ay_gunleri(self):
        m = ege.docx_menu(oku("ege_ogle.docx", "rb"), 10, "lunch", self.BUGUN)
        self.assertEqual((len(m), min(m), max(m)), (31, "2026-10-01", "2026-10-31"))        # hafta sonu da servis var
        g = m["2026-10-01"]["lunch"]
        self.assertEqual(adlar(g), ["Zeytinyağlı Kuru Fasulye", "Tereyağlı Pirinç Pilavı", "Yoğurt", "Kekli Supangle"])        # 'Z.Y.', 'TER.' açıldı
        self.assertEqual(g["kcal"], 1470)
        self.assertEqual(adlar(m["2026-10-08"]["lunch"])[:2], ["Zeytinyağlı Nohut", "Şehriyeli Pirinç Pilavı"])
        self.assertEqual(ege.ad_duzelt("CEV BAKLAVA"), "Cevizli Baklava")                    # noktasız yazım da açılır
        self.assertEqual(ege.ad_duzelt("KIY. Y. MERCİMEK"), "Kıymalı Yeşil Mercimek")
        self.assertEqual(ege.ad_duzelt("K. MERCİMEK KÖFTESİ"), "Kırmızı Mercimek Köftesi")

    def test_tatil_hucreleri_gunun_numarasi_olmasa_da_yerini_bulur(self):
        m = ege.docx_menu(oku("ege_ogle.docx", "rb"), 10, "lunch", self.BUGUN)
        self.assertEqual(m["2026-10-28"], {"lunch": {"items": [], "note": "Resmi tatil"}})
        self.assertEqual(m["2026-10-29"], {"lunch": {"items": [], "note": "Resmi tatil"}})
        self.assertEqual(adlar(m["2026-10-30"]["lunch"])[0], "Etli Bezelye")             # tatilden sonraki günler kaymaz

    def test_eski_yilin_dosyasi_atlanir(self):
        # 1 Ekim 2026 Perşembe; aynı dosya Kasım'a ya da başka haftanın gününe denk gelen bir aya yorumlanamaz
        self.assertEqual(ege.docx_menu(oku("ege_ogle.docx", "rb"), 11, "lunch", self.BUGUN), {})

    def test_sinif_yalnizca_bu_ve_gelecek_ay_indirilir(self):
        indirilen = []

        def sahte(url):
            indirilen.append(url)
            if url.endswith(".html"):
                return oku("ege_liste.html").encode("utf-8")
            return oku("ege_aksam.docx" if url.endswith("ekimaks.docx") else "ege_ogle.docx", "rb")
        u = ege.EgeUniversitesi(sahte, bugun=self.BUGUN)
        m = u.menuler()
        self.assertEqual(set(m["2026-10-01"]), {"lunch", "dinner", "vegetarian"})
        self.assertEqual(sum(1 for i in indirilen if i.endswith(".docx")), 3)              # Eylül dosyaları indirilmedi
        self.assertFalse(any("eyl" in i for i in indirilen))

    def test_bozuk_dosya_digerlerini_engellemez(self):
        def sahte(url):
            if url.endswith(".html"):
                return oku("ege_liste.html").encode("utf-8")
            return b"bu bir docx degil" if url.endswith("ekimaks.docx") else oku("ege_ogle.docx", "rb")
        m = ege.EgeUniversitesi(sahte, bugun=self.BUGUN).menuler()
        self.assertEqual(set(m["2026-10-01"]), {"lunch", "vegetarian"})


class SamsunTesti(unittest.TestCase):
    def test_pdf_haftalik_izgara(self):
        m = samsun.pdf_menu(oku("samsun_ekim.pdf", "rb"))
        self.assertEqual((len(m), min(m), max(m)), (20, "2026-10-01", "2026-10-30"))
        g = m["2026-10-01"]
        self.assertEqual(g["items"], [{"name": "Ezogelin Çorbası", "kcal": 114}, {"name": "Sebzeli Tavuk Julyen", "kcal": 237},
                                      {"name": "Bulgur Pilavı", "kcal": 200}, {"name": "Salata", "kcal": 97}])
        self.assertEqual(g["kcal"], 648)                                              # PDF'teki 'Toplam kalori' satırı

    def test_her_gunun_toplami_kalemlerle_tutarli(self):
        for tarih, g in samsun.pdf_menu(oku("samsun_ekim.pdf", "rb")).items():
            self.assertEqual(len(g["items"]), 4, tarih)
            self.assertEqual(g["kcal"], sum(o["kcal"] for o in g["items"]), tarih)        # PDF'in 'Toplam kalori' satırı kalem toplamıdır

    def test_yaklasik_kalori_yazimi(self):
        g = samsun.pdf_menu(oku("samsun_ekim.pdf", "rb"))["2026-10-09"]
        self.assertEqual(g["items"][3], {"name": "Salata", "kcal": 97})                   # PDF'te 'Salata (~97 kcal)'
        self.assertEqual(g["kcal"], 739)

    def test_sinif_sayfadaki_pdf(self):
        def sahte(url):
            return oku("samsun_ekim.pdf", "rb") if url.endswith(".pdf") else oku("samsun_sayfa.html").encode("utf-8")
        m = samsun.SamsunUniversitesi(sahte).menuler()
        self.assertEqual(len(m), 20)
        self.assertEqual(set(m["2026-10-05"]), {"lunch"})
        self.assertEqual(adlar(m["2026-10-05"]["lunch"])[0], "Mercimek Çorbası")


class ComuTesti(unittest.TestCase):
    def test_pdf_baglantilari(self):
        self.assertEqual(comu.pdf_baglantilari(oku("comu_sayfa.html")),
                         [("74551_ekim-2026-yemek-menusu.pdf", "EKİM 2026 YEMEK MENÜSÜ.pdf"), ("98115_.pdf", "EKİM 2026 VEGAN YEMEK MENÜSÜ.pdf")])

    def test_pdf_menu_ve_saat(self):
        m, saat = comu.pdf_menu(oku("comu_ekim.pdf", "rb"))
        self.assertEqual(saat, "11:30–14:00")
        self.assertEqual((len(m), min(m), max(m)), (21, "2026-10-01", "2026-10-30"))
        self.assertEqual(m["2026-10-01"]["items"], [{"name": "Tarhana Çorba", "kcal": 194}, {"name": "Hünkarbeğendi", "kcal": 446},
                                                    {"name": "Tel Şehriyeli Pirinç Pilavı", "kcal": 345}, {"name": "Ballı Balım", "kcal": 380}])
        self.assertEqual(m["2026-10-01"]["kcal"], 1365)

    def test_hucre_basina_birden_cok_satir_ve_sutun_eslesmesi(self):
        m, _ = comu.pdf_menu(oku("comu_ekim.pdf", "rb"))
        # 5 Ekim: ana yemek yanında köz biber ayrı satır; satırlar kendi hücrelerine (sütun + en yakın üst başlık) atanır
        self.assertEqual(adlar(m["2026-10-05"]), ["Ezogelin Çorba", "Et Döner", "Köz Domates Biber", "Arpa Şehriye Pilavı", "Ayran"])
        self.assertEqual(adlar(m["2026-10-06"]), ["Buğday Çorba", "Izgara Tavuk Kanat", "Patates Püresi", "Garnitürlü Pirinç Pilavı", "Cevizli Baklava"])

    def test_tatil_ve_gizli_sablon_tarihleri(self):
        m, _ = comu.pdf_menu(oku("comu_ekim.pdf", "rb"))
        self.assertNotIn("2026-10-29", m)                      # bayram hücresinde yemek yok
        self.assertTrue(all(t.startswith("2026-10-") for t in m))      # 31.08.2026 gibi görünmeyen şablon tarihleri alınmaz

    def test_vegan_pdf(self):
        m, _ = comu.pdf_menu(oku("comu_vegan.pdf", "rb"))
        self.assertEqual(len(m), 21)
        self.assertEqual(adlar(m["2026-10-05"]), ["Ezogelin Çorba", "Zeytinyağlı Brokoli", "Arpa Şehriye Pilavı", "Meyve Suyu"])

    def test_sinif_yalnizca_bu_ve_gelecek_ay(self):
        indirilen = []

        def sahte(url):
            indirilen.append(url)
            if url == comu.SAYFA_URL:
                return oku("comu_sayfa.html").encode("utf-8")
            return oku("comu_vegan.pdf" if url.endswith("98115_.pdf") else "comu_ekim.pdf", "rb")
        u = comu.CanakkaleOnsekizMart(sahte, bugun=date(2026, 10, 5))
        m = u.menuler()
        self.assertEqual(set(m["2026-10-05"]), {"lunch", "vegetarian"})
        self.assertEqual(u.saatler(), {"lunch": "11:30–14:00"})
        indirilen.clear()
        self.assertEqual(comu.CanakkaleOnsekizMart(sahte, bugun=date(2027, 3, 1)).menuler(), {})            # Ekim 2026 PDF'leri Mart 2027'de indirilmez
        self.assertEqual(indirilen, [comu.SAYFA_URL])


class PdfGelistirmeTesti(unittest.TestCase):
    CMAP = (b"/CIDInit /ProcSet findresource begin begincmap 1 begincodespacerange <0000> <FFFF> endcodespacerange "
            b"2 beginbfchar <0041> <0058> <0042> <015E> endbfchar endcmap")

    def mini_pdf(self, icerik: bytes) -> bytes:
        uzunluk = lambda b: str(len(b)).encode()
        return (b"%PDF-1.4\n1 0 obj << /Type /Font /Subtype /Type0 /ToUnicode 2 0 R >> endobj\n"
                b"2 0 obj << /Length " + uzunluk(self.CMAP) + b" >> stream\n" + self.CMAP + b"\nendstream endobj\n"
                b"3 0 obj << /F1 1 0 R >> endobj\n4 0 obj << /Type /Page /Resources << /Font 3 0 R >> /Contents 5 0 R >> endobj\n"
                b"5 0 obj << /Length " + uzunluk(icerik) + b" >> stream\n" + icerik + b"\nendstream endobj\n%%EOF")

    def test_dolayli_yazitipi_sozlugu_ve_literal_iki_baytlik_dizgi(self):
        s = pdf.sayfa_metinleri(self.mini_pdf(b"BT /F1 10 Tf 1 0 0 1 5 5 Tm (\\000A\\000B) Tj ET"))
        self.assertEqual(s, [[(5.0, 5.0, 10.0, "XŞ")]])            # '/Font 3 0 R' izlenir; (\000A) -> kod 0x0041 -> 'X', 0x0042 -> 'Ş'

    def test_hex_dizgi_hala_calisir(self):
        s = pdf.sayfa_metinleri(self.mini_pdf(b"BT /F1 10 Tf 1 0 0 1 5 5 Tm <00410042> Tj ET"))
        self.assertEqual(s[0][0][3], "XŞ")

    def test_ctm_modu_sayfa_koordinatlarini_verir(self):
        icerik = b"q 2 0 0 2 10 20 cm BT /F1 10 Tf 1 0 0 1 5 5 Tm <0041> Tj 3 4 Td <0042> Tj ET Q BT /F1 10 Tf 1 0 0 1 7 8 Tm <0041> Tj ET"
        ham = pdf.sayfa_metinleri(self.mini_pdf(icerik))
        self.assertEqual([(x, y) for x, y, _, _ in ham[0]], [(5.0, 5.0), (8.0, 9.0), (7.0, 8.0)])           # varsayılan: ham değerler
        ctm = pdf.sayfa_metinleri(self.mini_pdf(icerik), ctm=True)
        # q..Q içinde: x = 5*2+10, y = 5*2+20; Td (3,4) ölçekli eklenir; Q sonrasında dönüşüm sıfırlanır
        self.assertEqual([(x, y) for x, y, _, _ in ctm[0]], [(20.0, 30.0), (26.0, 38.0), (7.0, 8.0)])

    def test_satirlari_birlestir(self):
        parcalar = [(10, 50, 10, "A"), (18, 50, 10, "B"), (60, 50, 10, "C"), (10, 40, 10, "D")]
        self.assertEqual(pdf.satirlari_birlestir(parcalar, bosluk=1.0),
                         [("AB", 10, 18, 50, 10), ("C", 60, 60, 50, 10), ("D", 10, 10, 40, 10)])      # uzak parça ayrı satır; farklı y ayrı satır

    def test_cmap_genislik(self):
        self.assertEqual(pdf.cmap_genislik(b"begincodespacerange <0000> <FFFF> endcodespacerange"), 2)
        self.assertEqual(pdf.cmap_genislik(b"begincodespacerange <00> <FF> endcodespacerange"), 1)
        self.assertEqual(pdf.cmap_genislik(b"yok"), 2)


class ElleOkullarTesti(unittest.TestCase):
    """Resimden elle girilen okullar (DEÜ, GTÜ, Trabzon Üni.): veri kümeleri tutarlı ve eklentiler dosyadan okur."""

    def test_deu(self):
        m = elle.yukle("deu")
        self.assertEqual((min(m), max(m)), ("2026-09-28", "2026-10-30"))
        self.assertEqual(adlar(m["2026-10-06"]["lunch"]), ["Etli Mevsim Türlü", "Erişte", "Havuç Tarator", "Meyve"])
        self.assertEqual(m["2026-10-06"]["lunch"]["kcal"], 1119)
        self.assertEqual(adlar(m["2026-10-06"]["vegetarian"])[0], "Mevsim Türlü (Etsiz)")
        self.assertEqual(m["2026-10-29"]["lunch"], {"items": [], "note": "Cumhuriyet Bayramı (resmi tatil)"})
        self.assertEqual(sum(1 for g in m.values() if g["lunch"]["items"]), 23)         # 23 öğle günü (hafta içi; 28 Ekim yarım gün, 29 Ekim tatil)

    def test_gtu(self):
        m = elle.yukle("gtu")
        self.assertEqual((min(m), max(m)), ("2026-10-01", "2026-10-30"))
        g = m["2026-10-06"]["lunch"]
        self.assertEqual(len(g["items"]), 8)
        self.assertEqual(g["items"][0], {"name": "Yayla Çorba", "kcal": 192})
        self.assertEqual(g["items"][5], {"name": "Zeytinyağlı Bamya", "kcal": 163})        # 'ZYT' açıldı
        self.assertNotIn("kcal", m["2026-10-01"]["lunch"])                               # 'MEYVE' kalorisiz: toplam yazılmaz
        self.assertEqual(m["2026-10-28"]["lunch"]["note"], "İyi tatiller")

    def test_trabzon_gunluk_toplam_kalem_toplamina_esit(self):
        m = elle.yukle("trabzon")
        self.assertEqual(len(m), 20)
        for tarih, ogun in m.items():
            g = ogun["lunch"]
            self.assertEqual(g["kcal"], sum(o["kcal"] for o in g["items"]), tarih)
            self.assertEqual(len(g["items"]), 4, tarih)
        self.assertEqual(adlar(m["2026-10-06"]["lunch"]), ["Köylüm Çorba", "Tavuk Külbastı + Patates Kızartma", "Soslu Makarna", "Ayran"])

    def test_siniflar_elle_veriyi_dondurur(self):
        from yemekhane.universities import deu, gtu, trabzon
        for sinif, kimlik in ((deu.DokuzEylul(), "deu"), (gtu.GebzeTeknik(), "gtu"), (trabzon.TrabzonUniversitesi(), "trabzon")):
            self.assertEqual(sinif.id, kimlik)
            self.assertEqual(sinif.menuler(), elle.yukle(kimlik))
            self.assertEqual((sinif.fiyatlar(), sinif.saatler()), ([], {}))


class BirikimliBuildTesti(unittest.TestCase):
    class Gunluk(Universite):
        """Her çalıştırmada yalnızca bir günün menüsünü yayınlayan okul."""
        id, ad, kisa, sehir, kaynak, birikimli = "g", "Okul G", "G", "Ankara", "http://x", True

        def __init__(self, gun, birikimli=True):
            self.gun = gun
            self.birikimli = birikimli

        def menuler(self):
            return {self.gun: {"lunch": {"items": [{"name": "Çorba " + self.gun}]}}}

    def calistir(self, klasor, uni):
        with mock.patch.object(dishes, "RUN_LIMIT", 0):
            return build.calistir(klasor, [uni])

    def gunler(self, klasor):
        with open(os.path.join(klasor, "g", "menu.json"), encoding="utf-8") as f:
            return sorted(json.load(f)["days"])

    def test_onceki_gunler_korunur(self):
        with tempfile.TemporaryDirectory() as k:
            self.calistir(k, self.Gunluk("2999-01-01"))
            self.calistir(k, self.Gunluk("2999-01-02"))
            self.assertEqual(self.gunler(k), ["2999-01-01", "2999-01-02"])
            index = json.load(open(os.path.join(k, "index.json")))["universities"][0]
            self.assertEqual((index["firstDay"], index["lastDay"]), ("2999-01-01", "2999-01-02"))

    def test_ayni_gun_yeni_veriyle_degisir(self):
        with tempfile.TemporaryDirectory() as k:
            self.calistir(k, self.Gunluk("2999-01-01"))
            u = self.Gunluk("2999-01-01")
            u.menuler = lambda: {"2999-01-01": {"lunch": {"items": [{"name": "Yeni"}]}}}
            self.calistir(k, u)
            with open(os.path.join(k, "g", "menu.json"), encoding="utf-8") as f:
                self.assertEqual(json.load(f)["days"]["2999-01-01"]["lunch"]["items"][0]["name"], "Yeni")

    def test_birikimsiz_okulda_eski_gunler_gider(self):
        with tempfile.TemporaryDirectory() as k:
            self.calistir(k, self.Gunluk("2999-01-01", birikimli=False))
            self.calistir(k, self.Gunluk("2999-01-02", birikimli=False))
            self.assertEqual(self.gunler(k), ["2999-01-02"])

    def test_cok_eski_gunler_atilir(self):
        with tempfile.TemporaryDirectory() as k:
            self.calistir(k, self.Gunluk("2001-01-01"))                  # 45 günden eski: build sınırı atar
            self.calistir(k, self.Gunluk("2999-01-02"))
            self.assertEqual(self.gunler(k), ["2999-01-02"])


class KayitTesti(unittest.TestCase):
    def test_kimlikler_benzersiz_ve_yeni_okullar_kayitli(self):
        kimlikler = [u.id for u in KAYITLI]
        self.assertEqual(len(kimlikler), len(set(kimlikler)))
        yeni = {"ege", "deu", "ikcu", "alku", "comu", "sbtu", "cumhuriyet", "atauni", "ktu", "trabzon", "omu", "samsun", "gtu"}
        self.assertTrue(yeni <= set(kimlikler))

    def test_her_eklentide_ad_kisa_ad_ve_sehir_var(self):
        for u in KAYITLI:
            self.assertTrue(u.ad and u.kisa and u.sehir and u.kaynak.startswith("http"), u.id)


if __name__ == "__main__":
    unittest.main()
