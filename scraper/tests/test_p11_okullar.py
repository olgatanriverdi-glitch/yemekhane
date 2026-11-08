"""YÖK karşılaştırmasında kalan altı okunabilir okulun gerçek kaynakları."""
import json
from datetime import date
from pathlib import Path
import unittest
from unittest.mock import patch
from yemekhane.universities import KAYITLI
from yemekhane.universities import gibtu,kmu,mtu,iste,ksbu,istiklal

FIX=Path(__file__).parent/'fixtures'
OKULLAR=(
    (gibtu.GaziantepIslamBilimTeknoloji,19,'Tavuklu Orman Kebabı',None),
    (kmu.KaramanogluMehmetbey,21,'Yayla Çorbası',1030),
    (mtu.MalatyaTurgutOzal,1,'Kıymalı Kapuska',None),
    (iste.IskenderunTeknik,21,'Toga Çorba',688),
    (ksbu.KutahyaSaglikBilimleri,21,'Ezogelin Çorba',1110),
    (istiklal.IstiklalBilimTeknoloji,21,'İzmir Köfte',936),
)


def oku(id,ext='html'):
    return (FIX/(id+'_kasim.'+ext)).read_bytes()


def okul(cls):
    def indir(url,*args):
        if cls is istiklal.IstiklalBilimTeknoloji:
            return (FIX/'istiklal_sayfa.json').read_bytes() if url==istiklal.SAYFA_API else oku('istiklal','json')
        if url.endswith('.pdf'):
            return oku(cls.id,'pdf')
        if cls is iste.IskenderunTeknik and url!=iste.SAYFA_URL:
            return (FIX/'iste_duyuru.html').read_bytes()
        return oku(cls.id)
    return cls(indirici=indir)


class P11Sozlesme(unittest.TestCase):
    def setUp(self):
        p=patch.object(istiklal,'bugun_tr',return_value=date(2026,11,4));p.start();self.addCleanup(p.stop)

    def test_gun_sayisi_yil_carsamba(self):
        for cls,sayi,ilk,kcal in OKULLAR:
            with self.subTest(okul=cls.id):
                days=okul(cls).menuler()
                self.assertEqual(len(days),sayi)
                self.assertTrue(all(t.startswith('2026-11-') for t in days))
                self.assertEqual(days['2026-11-04']['lunch']['items'][0]['name'],ilk)
                self.assertEqual(days['2026-11-04']['lunch'].get('kcal'),kcal)
                self.assertTrue(all(set(d)=={'lunch'} for d in days.values()))

    def test_dort_yemek_ve_yemek_disinda_satir_yok(self):
        for cls,*_ in OKULLAR:
            for t,d in okul(cls).menuler().items():
                self.assertEqual(len(d['lunch']['items']),4,(cls.id,t,d))
                for o in d['lunch']['items']:
                    self.assertNotRegex(o['name'],r'(?i)2026|toplam|\b(?:kcal|kkal|gram|enerji|yemek adı)\b')
                    self.assertNotIn('*',o['name'])
                    self.assertTrue(o.get('kcal',1)>0)

    def test_bos_gun_uydurulmaz(self):
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                self.assertNotIn('2026-11-07',okul(cls).menuler())
                self.assertNotIn('2026-11-08',okul(cls).menuler())

    def test_ag_hatasi_anlamli(self):
        def hata(url,*args):
            raise OSError('kesildi')
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                with self.assertRaisesRegex(RuntimeError,'indirilemedi.*kesildi'):
                    cls(indirici=hata).menuler()

    def test_bos_kaynak_hatasi(self):
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                ham=b'{}' if cls is istiklal.IstiklalBilimTeknoloji else b'<html></html>'
                with self.assertRaisesRegex(RuntimeError,'bulunamadı'):
                    cls(indirici=lambda url,*args:ham).menuler()

    def test_kayit_ve_birikim(self):
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                self.assertEqual(sum(u.id==cls.id for u in KAYITLI),1)
                self.assertEqual(cls.birikimli,cls in (gibtu.GaziantepIslamBilimTeknoloji,mtu.MalatyaTurgutOzal))


class P11Ayrintilar(unittest.TestCase):
    def test_gibtu_windows1254_ve_pencere_baslangici(self):
        days=okul(gibtu.GaziantepIslamBilimTeknoloji).menuler()
        self.assertEqual(min(days),'2026-11-04')
        self.assertEqual(max(days),'2026-11-30')
        self.assertEqual(days['2026-11-04']['lunch']['items'][-1]['name'],'Fırın Sütlaç')

    def test_kmu_yil_basligi_ve_yazili_toplam(self):
        days=okul(kmu.KaramanogluMehmetbey).menuler()
        self.assertEqual(days['2026-11-04']['lunch']['items'][1]['name'],'Calla')
        self.assertEqual(days['2026-11-30']['lunch']['kcal'],1297)
        self.assertTrue(all('kcal' not in o for d in days.values() for o in d['lunch']['items']))

    def test_mtu_gunluk_metin_aylik_resimden_bagimsiz(self):
        days=okul(mtu.MalatyaTurgutOzal).menuler()
        self.assertEqual(list(days),['2026-11-04'])
        self.assertEqual([o['name'] for o in days['2026-11-04']['lunch']['items']],['Kıymalı Kapuska','Peynirli Tepsi Böreği','Ezogelin Çorbası','Haydari'])

    def test_iste_gramaj_kalori_degildir_84_kalem(self):
        days=okul(iste.IskenderunTeknik).menuler()
        self.assertEqual(sum(len(d['lunch']['items']) for d in days.values()),84)
        self.assertEqual([o['kcal'] for o in days['2026-11-04']['lunch']['items']],[102,228,254,104])
        self.assertEqual(days['2026-11-02']['lunch']['items'][0]['kcal'],276)

    def test_iste_rakam_parcalari_ve_yuksek_satirli_yemek(self):
        days=okul(iste.IskenderunTeknik).menuler()
        self.assertEqual(days['2026-11-09']['lunch']['items'][1],{'name':'Ekmek Arası Tavuk Tantuni','kcal':550})
        self.assertEqual(days['2026-11-30']['lunch']['items'][0]['kcal'],114)
        self.assertEqual(days['2026-11-12']['lunch']['items'][1],{'name':'Sosyete Mantı','kcal':340})

    def test_iste_duyuru_adresi_kaynaktan_bulunur(self):
        calls=[]
        u=okul(iste.IskenderunTeknik);orig=u.indir
        def indir(url):
            calls.append(url);return orig(url)
        u.indir=indir;u.menuler()
        self.assertEqual(calls[1],'https://iste.edu.tr/duyuru-merkezi/sksdb/2026/10/27/7149')
        self.assertEqual(calls[2],'https://iste.edu.tr/files/7149_files_1793080297.pdf')

    def test_ksbu_harf_genisligi_ve_gunluk_enerji(self):
        days=okul(ksbu.KutahyaSaglikBilimleri).menuler()
        self.assertEqual(days['2026-11-04']['lunch']['items'][1]['name'],'Kıymalı Kuru Fasulye')
        self.assertEqual(days['2026-11-04']['lunch']['kcal'],1110)
        self.assertTrue(all('kcal' not in o for d in days.values() for o in d['lunch']['items']))

    def test_ksbu_sarilmis_adlar_ve_ay_sonu(self):
        days=okul(ksbu.KutahyaSaglikBilimleri).menuler()
        self.assertEqual(days['2026-11-17']['lunch']['items'][2]['name'],'Bolonez Soslu Makarna')
        self.assertEqual(days['2026-11-30']['lunch']['kcal'],660)
        self.assertIn('Yoğurt',days['2026-11-30']['lunch']['items'][1]['name'])

    def test_ksbu_dinamik_aylik_pdf_colyak_degil(self):
        u=okul(ksbu.KutahyaSaglikBilimleri)
        self.assertEqual(u.pdf_baglantisi(oku('ksbu').decode()),'https://erasmus.ksbu.edu.tr/duyuru_medya/uploads/167/document/doc_6ae4488fe5cf6.pdf')

    def test_istiklal_kasim_ve_ekim_arsivi_ayrilir(self):
        veri=json.loads(oku('istiklal','json'))
        kasim=istiklal.json_menu(veri,date(2026,11,4));ekim=istiklal.json_menu(veri,date(2026,10,31))
        self.assertEqual(len(kasim),21)
        self.assertEqual(len(ekim),20)
        self.assertEqual(kasim['2026-11-04']['lunch']['kcal'],936)
        self.assertNotIn('2026-10-29',ekim)

    def test_istiklal_okuma_postlari_giris_istemez(self):
        calls=[];u=okul(istiklal.IstiklalBilimTeknoloji);orig=u.indir
        def indir(url,payload):
            calls.append((url,payload));return orig(url,payload)
        u.indir=indir;u.menuler()
        self.assertEqual(calls[0],(istiklal.SAYFA_API,{'originId':'1','language':'tr-TR','slug':'sksdb'}))
        self.assertEqual(calls[1][1]['slug'],'beslenme-ve-kafeterya')
        self.assertEqual(calls[1][1]['pageId'],json.loads((FIX/'istiklal_sayfa.json').read_text())['id'])

    def test_istiklal_bozuk_yazi_jsonu(self):
        with self.assertRaises(ValueError):
            istiklal.json_menu({'content':'bozuk'},date(2026,11,4))
        self.assertEqual(istiklal.json_menu({'content':'[]'},date(2026,11,4)),{})

    def test_istiklal_yil_ve_ay_uyusmazsa_atlanir(self):
        veri=json.loads(oku('istiklal','json'));tree=json.loads(veri['content'])
        for ay in tree['componentTree'][0]['arguments']['foodLists']:
            ay['year']=2025
        veri['content']=json.dumps(tree)
        self.assertEqual(istiklal.json_menu(veri,date(2026,11,4)),{})


if __name__=='__main__':
    unittest.main()
