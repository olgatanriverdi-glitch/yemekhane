"""4 Kasım iş günü yeniden açılan kaynakların ağsız doğrulaması."""
import json
from datetime import date
from pathlib import Path
import unittest
from unittest.mock import patch
from yemekhane.universities import KAYITLI
from yemekhane.universities import bozok,bartin,rte,gumushane,bitlis,batman,erciyes,etu,agri,hakkari

FIX=Path(__file__).parent/'fixtures'
OKULLAR=(
    (bozok.YozgatBozok,12,'Yayla Çorbası',1039),
    (bartin.BartinUniversitesi,21,'Köy Çorbası',1051),
    (rte.RecepTayyipErdogan,1,'Ezogelin Çorba',785),
    (gumushane.GumushaneUniversitesi,21,'Süzme Mercimek Çorbası',None),
    (bitlis.BitlisEren,3,'Ezogelin Çorba',None),
    (batman.BatmanUniversitesi,10,'Şehriyeli Tavuk Çorbası',None),
    (erciyes.ErciyesUniversitesi,3,'Sebze Çorba',1075),
    (etu.ErzurumTeknik,10,'Şafak Çorbası',1090),
    (agri.AgriIbrahimCecen,3,'Şafak Çorbası',972),
    (hakkari.HakkariUniversitesi,21,'Yayla Çorbası',None),
)


def oku(id):
    return (FIX/(id+'_kasim.'+('json' if id=='gumushane' else 'html'))).read_bytes()


def menuler(cls):
    with patch.object(etu,'bugun_tr',return_value=date(2026,11,4)):
        return cls(indirici=lambda url:oku(cls.id)).menuler()


class YenidenSozlesme(unittest.TestCase):
    def test_gercek_kaynak_gunleri(self):
        for cls,sayi,ilk,kcal in OKULLAR:
            with self.subTest(okul=cls.id):
                days=menuler(cls)
                self.assertEqual(len(days),sayi)
                self.assertTrue(all(t.startswith('2026-11-') for t in days))
                menu=days['2026-11-04']['lunch']
                self.assertEqual(len(menu['items']),4)
                if cls is not batman.BatmanUniversitesi:
                    self.assertEqual(menu['items'][0]['name'],ilk)
                    self.assertEqual(menu.get('kcal'),kcal)

    def test_yemek_disinda_satir_yok(self):
        for cls,*_ in OKULLAR:
            for t,day in menuler(cls).items():
                for meal in day.values():
                    for item in meal['items']:
                        with self.subTest(okul=cls.id,tarih=t,yemek=item):
                            self.assertNotRegex(item['name'],r'(?i)2026|toplam|kalori|protein|kkal|kcal|gluten|hazırlanıyor|gram|menüsü|bugün')
                            self.assertTrue(item.get('kcal',1)>0)

    def test_hafta_sonu_kaydi_uydurulmaz(self):
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                self.assertNotIn('2026-11-07',menuler(cls))
                self.assertNotIn('2026-11-08',menuler(cls))

    def test_ag_hatasi_anlamli(self):
        def hata(url):
            raise OSError('bağlantı kesildi')
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                with self.assertRaisesRegex(RuntimeError,'indirilemedi.*bağlantı kesildi'):
                    cls(indirici=hata).menuler()

    def test_bos_kaynak_basari_sayilmaz(self):
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                ham=b'{}' if cls is gumushane.GumushaneUniversitesi else b'<html></html>'
                with self.assertRaisesRegex(RuntimeError,'bulunamadı'):
                    cls(indirici=lambda url:ham).menuler()

    def test_tek_kayit_ve_birikim(self):
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                self.assertEqual(sum(u.id==cls.id for u in KAYITLI),1)
                self.assertEqual(cls.birikimli,cls not in (bartin.BartinUniversitesi,gumushane.GumushaneUniversitesi,hakkari.HakkariUniversitesi))


class YenidenAyrintilar(unittest.TestCase):
    def test_bozok_toplam_yildiz_ve_bos_secmeli(self):
        days=menuler(bozok.YozgatBozok)
        self.assertEqual(max(days),'2026-11-17')
        self.assertEqual(days['2026-11-04']['lunch']['kcal'],1039)
        self.assertTrue(all('*' not in o['name'] for d in days.values() for o in d['lunch']['items']))

    def test_bartin_literal_kaloriler_ve_birden_cok_yemek(self):
        days=menuler(bartin.BartinUniversitesi)
        self.assertEqual([o['kcal'] for o in days['2026-11-04']['lunch']['items']],[188,350,350,163])
        self.assertEqual(len(days['2026-11-11']['lunch']['items']),5)
        self.assertNotIn('kcal',days['2026-11-10']['lunch'])

    def test_bartin_bos_fonksiyon_ve_kod_calistirilmaz(self):
        self.assertEqual(bartin.sayfa_menu('function tabloverileriEkle() {\n}'),{})
        s=oku('bartin').decode().replace("yemek1='Köy Çorbası (188 kcal)';","yemek1=process.exit(1);")
        self.assertEqual(len(bartin.sayfa_menu(s)['2026-11-04']['lunch']['items']),3)

    def test_rte_virgullu_kaloriler(self):
        day=menuler(rte.RecepTayyipErdogan)['2026-11-04']['lunch']
        self.assertEqual([o['kcal'] for o in day['items']],[173,250,290,72])
        self.assertEqual(day['kcal'],785)

    def test_gumushane_takvim_bos_gunler_ve_ay_sonu(self):
        days=menuler(gumushane.GumushaneUniversitesi)
        self.assertNotIn('2026-11-01',days)
        self.assertEqual(days['2026-11-02']['lunch']['items'][0]['name'],'Ezogelin Çorbası')
        self.assertEqual(max(days),'2026-11-30')
        self.assertTrue(all(len(d['lunch']['items'])==4 for d in days.values()))

    def test_gumushane_bozuk_json_ve_yanlis_dizi_boyutu(self):
        with self.assertRaisesRegex(RuntimeError,"JSON'u okunamadı"):
            gumushane.GumushaneUniversitesi(indirici=lambda url:b'bozuk').menuler()
        veri=json.loads(oku('gumushane'));veri['yemekhanes'][0]['yemekhaneTitle'][0].pop()
        self.assertEqual(gumushane.json_menu(veri),{})

    def test_bitlis_ana_yemek_secenekleri_ayri_ogun_degil(self):
        day=menuler(bitlis.BitlisEren)['2026-11-04']
        self.assertEqual(set(day),{'lunch'})
        self.assertEqual(day['lunch']['items'][1]['name'],'Tavuk Döner/Etli Nuhut/Karnıyarık')
        self.assertNotIn('kcal',day['lunch'])

    def test_batman_bugun_div_diger_gun_span(self):
        days=menuler(batman.BatmanUniversitesi)
        self.assertIn('2026-11-04',days)
        self.assertIn('2026-11-02',days)
        self.assertEqual(max(days),'2026-11-13')

    def test_erciyes_ogle_aksam_ve_bos_aksam(self):
        days=menuler(erciyes.ErciyesUniversitesi)
        self.assertEqual(set(days['2026-11-04']),{'lunch','dinner'})
        self.assertEqual(days['2026-11-04']['dinner']['kcal'],1075)
        self.assertEqual(set(days['2026-11-06']),{'lunch'})

    def test_etu_ilerleyen_gunler_ve_yil_dogrulamasi(self):
        days=etu.sayfa_menu(oku('etu').decode(),date(2026,11,4))
        self.assertEqual(len(days),10)
        self.assertEqual(max(days),'2026-11-17')
        self.assertEqual(days['2026-11-05']['lunch']['items'][0],{'name':'Mercimek Çorbası','kcal':200})
        self.assertIsNone(etu.gun_tarihi('4 Kasım Pazartesi',date(2026,11,4)))

    def test_agri_bitisik_kalori_ayrandan_ayrilir(self):
        day=menuler(agri.AgriIbrahimCecen)['2026-11-04']['lunch']
        self.assertEqual(day['items'][-1],{'name':'Ayran'})
        self.assertEqual(day['kcal'],972)
        self.assertTrue(all('kcal' not in o for o in day['items']))

    def test_hakkari_ikili_toplamlar_toplanmaz(self):
        day=menuler(hakkari.HakkariUniversitesi)['2026-11-04']['lunch']
        self.assertNotIn('kcal',day)
        self.assertNotIn('kcal',day['items'][1])
        self.assertIn('926 / 879 kcal',day['note'])
        self.assertIn('363 / 310 kcal',day['note'])
        self.assertEqual(day['items'][0]['kcal'],130)
        self.assertEqual(menuler(hakkari.HakkariUniversitesi)['2026-11-02']['lunch']['kcal'],922)


if __name__=='__main__':
    unittest.main()
