"""İstanbul'daki devlet üniversiteleri: İÜ, İTÜ, Boğaziçi, Marmara, Galatasaray, MSGSÜ. Fixture'lar okulların gerçek yanıtlarıdır."""
import json
import os
import unittest
import zlib
from datetime import date

from yemekhane import pdf
from yemekhane.universities import boun, gsu, itu, iu, marmara, msgsu

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def oku(ad, mod="r"):
    with open(os.path.join(FIX, ad), mod, **({"encoding": "utf-8"} if mod == "r" else {})) as f:
        return f.read()


class PdfIcerikAkisiTesti(unittest.TestCase):
    def test_gomulu_yazi_tipi_dosyasi_icerik_sayilmaz(self):
        # yazı tipi dosyaları ikili veridir ve rastgele 'BT ... Tf' baytları içerebilir; içerik akışı sanılmamalı
        ikili = bytes(range(256)) * 4 + b" BT /F1 12 Tf (x) Tj ET "
        sikistirilmis = zlib.compress(ikili)
        icerik = zlib.compress(b"BT /F1 12 Tf 10 20 Td (MERHABA) Tj ET")
        pdf_bayt = (b"%PDF-1.4\n1 0 obj\n<< /Length1 4000 /Filter /FlateDecode /Length " + str(len(sikistirilmis)).encode() + b" >>\nstream\n" + sikistirilmis
                    + b"\nendstream\nendobj\n2 0 obj\n<< /Filter /FlateDecode /Length " + str(len(icerik)).encode() + b" >>\nstream\n" + icerik + b"\nendstream\nendobj\n")
        sayfalar = pdf.sayfa_metinleri(pdf_bayt)
        self.assertEqual(len(sayfalar), 1)
        self.assertEqual([t[3] for t in sayfalar[0]], ["MERHABA"])


class IuTesti(unittest.TestCase):
    def sahte(self):
        veri = json.loads(oku("iu_meals.json"))

        def indir(url):
            if "yemekhane-saatler" in url:
                return oku("iu_saat.html").encode("utf-8")
            tarih = url.split("date=")[1][:10]
            kategori = url.split("category=")[1]
            return veri.get("%s|%s" % (tarih, kategori), '{"success":false,"meal":null}').encode("utf-8")
        return indir

    def test_ogun_ayiklama(self):
        veri = json.loads(oku("iu_meals.json"))
        ogle = iu.cevap_ogun(veri["2026-10-05|lunch"])
        self.assertEqual([o["name"] for o in ogle["items"]], ["Düğün Çorbası", "Etli Bezelye", "Pirinç Pilavı", "Kıbrıs Tatlısı"])
        kahvalti = iu.cevap_ogun(veri["2026-10-05|breakfast"], kahvalti=True)
        self.assertEqual([o["name"] for o in kahvalti["items"]][:4], ["Çay", "Meyve Suyu", "Süt", "Çilek Reçeli-Tereyağı"])   # 'Çay/Meyve Suyu/Süt' ayrılır
        self.assertIsNone(iu.cevap_ogun(veri["2026-10-04|lunch"]))               # menü olmayan gün
        self.assertIsNone(iu.cevap_ogun("<html>bozuk</html>"))

    def test_saatler(self):
        self.assertEqual(iu.saat_ayikla(oku("iu_saat.html")), {"breakfast": "07:30–09:00", "lunch": "11:00–14:00", "dinner": "16:00–18:00"})

    def test_menuler(self):
        u = iu.IstanbulUniversitesi(self.sahte(), bugun=date(2026, 10, 4), bekle=0)
        m = u.menuler()
        self.assertEqual(sorted(m), ["2026-10-05", "2026-10-06"])
        g = m["2026-10-05"]
        self.assertEqual(set(g), {"breakfast", "lunch", "dinner", "vegetarian"})          # 'vegan' kategorisi vejetaryen öğünü olur
        self.assertEqual(g["vegetarian"]["items"][1], {"name": "Etsiz Bezelye Yemeği"})
        self.assertEqual(u.saatler()["lunch"], "11:00–14:00")
        self.assertEqual(u.fiyatlar(), [])                                                # ücret yalnızca taranmış kararda


class ItuTesti(unittest.TestCase):
    def test_ogun(self):
        ogle = itu.sayfa_ogun(oku("itu_ogle.html"))
        self.assertEqual([o["name"] for o in ogle["items"]], ["Tarhana Çorbası", "Dana Haşlama", "Patlıcanlı Bulgur Pilavı", "Ayran", "Osmanlı Tulumba Tatlısı"])
        aksam = itu.sayfa_ogun(oku("itu_aksam.html"))
        self.assertEqual(aksam["items"][0], {"name": "Toyga Çorbası"})
        self.assertIsNone(itu.sayfa_ogun(oku("itu_bos.html")))                   # menü yayınlanmamış gün

    def test_saat_ve_fiyat(self):
        self.assertEqual(itu.saat_ayikla(oku("itu_saat.html")), {"lunch": "11:30–14:00", "dinner": "17:00–19:30"})
        self.assertEqual(itu.ucret_ayikla(oku("itu_fiyat.html")),
                         [{"label": "Öğrenci (Öğle Yemeği)", "tl": 60}, {"label": "Öğrenci (Akşam Yemeği)", "tl": 60}])

    def test_url(self):
        self.assertTrue(itu.menu_url(date(2026, 10, 6), "itu-ogle-yemegi-genel").endswith("?tip=itu-ogle-yemegi-genel&&value=6.10.2026"))

    def test_menuler(self):
        def sahte(url):
            if "yemek-saatleri" in url:
                return oku("itu_saat.html").encode("utf-8")
            if "value=6.10.2026" in url:
                return oku("itu_aksam.html" if "aksam" in url else "itu_ogle.html").encode("utf-8")
            return oku("itu_bos.html").encode("utf-8")
        u = itu.IstanbulTeknik(sahte, bugun=date(2026, 10, 5), bekle=0)
        m = u.menuler()
        self.assertEqual(sorted(m), ["2026-10-06"])
        self.assertEqual(set(m["2026-10-06"]), {"lunch", "dinner"})


class BounTesti(unittest.TestCase):
    def test_takvim(self):
        m = boun.ay_menusu(oku("boun_ay.html"))
        self.assertEqual(sorted(m), ["2026-10-01", "2026-10-02", "2026-10-03"])
        g = m["2026-10-01"]
        self.assertEqual([o["name"] for o in g["lunch"]["items"]],
                         ["Kremalı Domates Çorba", "Etli Patlıcan kebabı", "Pirinç Pilavı", "Bulgur Pilavı", "Cacık", "Kola", "Sarı Burma"])
        self.assertEqual([o["name"] for o in g["vegetarian"]["items"]][:2], ["Kremalı Domates Çorba", "Patlıcan Tava"])    # ana yemek yerine vejetaryen
        self.assertEqual(g["dinner"]["items"][1], {"name": "Balkan Köfte"})

    def test_saatler_ve_adres(self):
        self.assertEqual(boun.saat_ayikla(oku("boun_servis.html")), {"breakfast": "07:30–09:30", "lunch": "11:30–14:30", "dinner": "17:00–19:15"})
        self.assertEqual(boun.ay_url(2026, 10), "https://yemekhane.bogazici.edu.tr/aylik-menu/2026-10")
        u = boun.BogaziciUniversitesi(lambda url: oku("boun_servis.html").encode("utf-8"))
        self.assertEqual(u.saatler(), {"lunch": "11:30–14:30", "dinner": "17:00–19:15"})            # kahvaltı menüsü alınmıyor

    def test_iki_ay_cekilir_ve_yil_sonu(self):
        istekler = []

        def sahte(url):
            istekler.append(url)
            return oku("boun_ay.html").encode("utf-8")
        boun.BogaziciUniversitesi(sahte, bugun=date(2026, 12, 20)).menuler()
        self.assertEqual([u.rsplit("/", 1)[1] for u in istekler], ["2026-12", "2027-01"])


class MarmaraTesti(unittest.TestCase):
    def test_haftalik_tablolar(self):
        m = marmara.sayfa_menu(oku("marmara_menu.html"))
        self.assertEqual(sorted(m), ["2026-09-28", "2026-09-29"])
        ogle = m["2026-09-28"]["lunch"]
        self.assertEqual([(o["name"], o.get("kcal")) for o in ogle["items"]],
                         [("Ezogelin Çorbası", 115), ("İçli Köfte (püre ile)", 330), ("Macar Gulaş (Alternatif)", 365), ("Pirinç Pilavı", 230), ("Ayran", 47)])
        self.assertEqual(ogle["kcal"], 722)                                         # okulun yazdığı 'Normal Toplam'
        veg = m["2026-09-28"]["vegetarian"]
        self.assertEqual([o["name"] for o in veg["items"]], ["Ezogelin Çorbası", "Bamya Yemeği", "Pirinç Pilavı", "Ayran"])
        self.assertEqual(veg["kcal"], 115 + 180 + 230 + 47)
        self.assertNotIn("vegan", json.dumps(m))

    def test_ucret(self):
        self.assertEqual(marmara.ucret_ayikla(oku("marmara_fiyat.html")), [{"label": "Öğrenci (Öğle Yemeği)", "tl": 60}])


class GsuTesti(unittest.TestCase):
    def setUp(self):
        self.kelimeler = [tuple(k) for k in json.loads(oku("gsu_ogle_metin.json"))]

    def test_baglanti_yalniz_vegan_olmayan_ogle(self):
        self.assertEqual(gsu.ogle_pdf_baglantisi(oku("gsu_sayfa.html")), "https://dosya2.gsu.edu.tr/page/2026/9/30/ekim-menu-oglen-226.pdf")

    def test_girdiler(self):
        self.assertEqual(gsu.girdiler("MERCİMEK ÇORBA 215 KAZDAĞI ÇORBASI  180 DİYET ET 215 ZY ENGİNAR 165"),
                         [("MERCİMEK ÇORBA", 215), ("KAZDAĞI ÇORBASI", 180)])
        self.assertEqual(gsu.yemek_adi("ŞEH.PİRİNÇ PİLAV"), "Şehriyeli Pirinç Pilav")
        self.assertEqual(gsu.yemek_adi("DOM.SOS. MİDİ KÖFTE"), "Domates Soslu Midi Köfte")

    def test_haftalar(self):
        m = gsu.sayfa_menu(self.kelimeler)
        self.assertEqual(len(m), 22)
        self.assertEqual([(o["name"], o["kcal"]) for o in m["2026-10-05"]["lunch"]["items"]],
                         [("Tarhana Çorba", 205), ("İzmir Köfte", 368), ("Biberli Makarna", 326), ("Sarıburma", 340)])
        self.assertEqual(m["2026-10-05"]["lunch"]["kcal"], 205 + 368 + 326 + 340)
        # ilk hafta yalnızca perşembe-cuma: iki sütun
        self.assertEqual([o["name"] for o in m["2026-10-01"]["lunch"]["items"]], ["Mercimek Çorba", "Kış Türlüsü", "Nohutlu Pirinç Pilav", "Profiterol"])
        self.assertEqual([o["name"] for o in m["2026-10-02"]["lunch"]["items"]][0], "Kazdağı Çorbası")
        # diyet/zeytinyağlı listeleri ve başlıktaki iri yazı karışmaz
        self.assertEqual([o["name"] for o in m["2026-10-12"]["lunch"]["items"]], ["Şehriyeli Sütlüce Çorba", "Et Döner", "Pirinç Pilav", "Havuç Dilimi"])

    def test_eslesmeyen_hafta_atlanir(self):
        # 5-9 Ekim haftasının çorba satırından bir hücre eksilirse (örn. boş hücre) o hafta yanlış eşleşmesin diye tümüyle atlanır
        bozuk = [k for k in self.kelimeler if not k[3].startswith("TARHANA ÇORBA  205 MERCİMEK")]
        m = gsu.sayfa_menu(bozuk)
        self.assertNotIn("2026-10-05", m)
        self.assertIn("2026-10-12", m)


class MsgsuTesti(unittest.TestCase):
    def test_medya_listesi(self):
        self.assertEqual(msgsu.en_yeni_menu_pdf(oku("msgsu_medya.json")), "https://msgsu.edu.tr/wp-content/uploads/2026/10/2026-Ekim-Ayi-Menu.pdf")
        self.assertIsNone(msgsu.en_yeni_menu_pdf("[]"))
        self.assertIsNone(msgsu.en_yeni_menu_pdf("bozuk"))

    def test_pdf(self):
        kelimeler = [k for akis in pdf.sayfa_metinleri(oku("msgsu_menu.pdf", "rb")) for k in akis]
        m = msgsu.sayfa_menu(kelimeler)
        self.assertEqual(len(m), 21)                                                # 22 hafta içi gün - 'YARIM GÜN' yazan 28 Ekim
        self.assertEqual(m["2026-10-01"]["lunch"],
                         {"items": [{"name": "Tarhana Çorba"}, {"name": "Hamburger"}, {"name": "Elma Dilim Patates"}, {"name": "Sarı Burma"}, {"name": "Ayran"}], "kcal": 1170})
        self.assertEqual(m["2026-10-02"]["lunch"]["kcal"], 800)                     # ilk hafta yalnızca perşembe-cuma
        self.assertNotIn("2026-10-28", m)
        self.assertEqual(m["2026-10-29"], {"lunch": {"items": [], "note": "Cumhuriyet Bayramı"}})
        self.assertEqual([o["name"] for o in m["2026-10-13"]["lunch"]["items"]][:3], ["Tarhana Çorba", "Köri Soslu Tavuk", "Parmak Patates"])

    def test_sinif(self):
        def sahte(url):
            return oku("msgsu_medya.json").encode("utf-8") if "wp-json" in url else oku("msgsu_menu.pdf", "rb")
        self.assertEqual(len(msgsu.MimarSinanGuzelSanatlar(sahte).menuler()), 21)
        with self.assertRaises(RuntimeError):
            msgsu.MimarSinanGuzelSanatlar(lambda url: b"[]").menuler()


if __name__ == "__main__":
    unittest.main()
