"""P10 gerçek HTML/JSON ve tek sayfalık metin PDF kaynakları."""
from datetime import date
from pathlib import Path
import unittest
from unittest.mock import patch
from urllib.parse import unquote
from yemekhane.universities import KAYITLI
from yemekhane.universities import balikesir, bandirma, nku, klu, bilecik, yalova, hitit

FIX=Path(__file__).parent/'fixtures'
OKULLAR=(
    (balikesir.BalikesirUniversitesi,5,4,'Vitamin Çorbası',968),
    (bandirma.BandirmaOnyediEylul,21,6,'Düğün Çorba',None),
    (nku.TekirdagNamikKemal,4,4,'Domates Çorba',None),
    (klu.KirklareliUniversitesi,21,4,'Domatesli Şehriye Çorba',None),
    (bilecik.BilecikSeyhEdebali,21,4,'Mercimek Çorba',None),
    (yalova.YalovaUniversitesi,21,4,'Tel Şehriye Çorba',1179),
    (hitit.HititUniversitesi,3,4,'Havuç Çorba',None),
)


def oku(id,tip='kasim',ext='html'):
    return (FIX/(id+'_'+tip+'.'+ext)).read_bytes()


def okul(sinif):
    def indir(url):
        if url.endswith('.pdf'):
            if 'ücret' in unquote(url).lower():
                return oku(sinif.id,'fiyat','pdf')
            return oku(sinif.id,ext='pdf')
        if url in (nku.SAAT_URL,bilecik.SAAT_URL,hitit.SAAT_URL):
            return oku(sinif.id,'saat')
        if url in (nku.FIYAT_URL,bilecik.FIYAT_URL):
            return oku(sinif.id,'fiyat')
        return oku(sinif.id)
    return sinif(indirici=indir)


class P10Sozlesme(unittest.TestCase):
    def setUp(self):
        p=patch.object(balikesir,'bugun_tr',return_value=date(2026,11,4))
        p.start()
        self.addCleanup(p.stop)

    def test_gun_sayilari_ve_carsamba(self):
        for cls,sayi,adet,ilk,kcal in OKULLAR:
            with self.subTest(okul=cls.id):
                days=okul(cls).menuler()
                self.assertEqual(len(days),sayi)
                self.assertTrue(all(t.startswith('2026-11-') for t in days))
                menu=days['2026-11-04']['lunch']
                self.assertEqual(len(menu['items']),adet)
                self.assertEqual(menu['items'][0]['name'],ilk)
                self.assertEqual(menu.get('kcal'),kcal)
                self.assertNotIn('2026-11-07',days)

    def test_yemek_disinda_baslik_tarih_not_alinmaz(self):
        for cls,*_ in OKULLAR:
            for t,day in okul(cls).menuler().items():
                for meal in day.values():
                    for item in meal['items']:
                        with self.subTest(okul=cls.id,tarih=t,yemek=item):
                            self.assertNotRegex(item['name'],r'(?i)2026|toplam|kalori|kcal|kalori|öğrenci|pazartesi|pazartes|servis|içindekiler|menüsü')

    def test_kayit_ve_birikim(self):
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                self.assertEqual(sum(u.id==cls.id for u in KAYITLI),1)
                self.assertEqual(cls.birikimli,cls in (balikesir.BalikesirUniversitesi,nku.TekirdagNamikKemal,hitit.HititUniversitesi))

    def test_bos_sayfa_hatasi(self):
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                with self.assertRaisesRegex(RuntimeError,'bulunamadı'):
                    cls(indirici=lambda url:b'<html></html>').menuler()

    def test_ag_hatasi(self):
        def hata(url):
            raise OSError('kesildi')
        for cls,*_ in OKULLAR:
            with self.subTest(okul=cls.id):
                with self.assertRaisesRegex(RuntimeError,'indirilemedi.*kesildi'):
                    cls(indirici=hata).menuler()

    def test_pdf_indirme_hatasi(self):
        for cls in (bandirma.BandirmaOnyediEylul,bilecik.BilecikSeyhEdebali):
            def indir(url):
                if url.endswith('.pdf'):
                    raise OSError('PDF kesildi')
                return oku(cls.id)
            with self.subTest(okul=cls.id):
                with self.assertRaisesRegex(RuntimeError,"PDF'i okunamadı.*PDF kesildi"):
                    cls(indirici=indir).menuler()


class P10Ayrintilar(unittest.TestCase):
    def test_balikesir_yilsiz_hafta_takvimle_dogrulanir(self):
        days=balikesir.sayfa_menu(oku('balikesir').decode(),date(2026,11,4))
        self.assertEqual(sorted(days),['2026-11-02','2026-11-03','2026-11-04','2026-11-05','2026-11-06'])
        self.assertEqual(days['2026-11-02']['lunch']['items'][0],{'name':'Köylüm Çorbası','kcal':182})

    def test_bandirma_126_kalem_kalorisi_ve_secenekler_toplanmaz(self):
        days=okul(bandirma.BandirmaOnyediEylul).menuler()
        self.assertEqual(sum(len(d['lunch']['items']) for d in days.values()),126)
        self.assertEqual(sum('kcal' in o for d in days.values() for o in d['lunch']['items']),125)
        self.assertNotIn('kcal',days['2026-11-12']['lunch']['items'][4])
        self.assertTrue(all('kcal' not in d['lunch'] for d in days.values()))
        self.assertEqual(days['2026-11-19']['lunch']['items'][1]['name'],'Yayla Soslu Tavuk Haş')

    def test_bandirma_saat_pdf_dipnotundan(self):
        u=okul(bandirma.BandirmaOnyediEylul);u.menuler()
        self.assertEqual(u.saatler(),{'lunch':'11:30–14:00','dinner':'16:00–17:30'})

    def test_bandirma_ogrenci_ucreti_dinamik_karar_pdfinden(self):
        u=okul(bandirma.BandirmaOnyediEylul)
        u.menuler()
        self.assertEqual(u.fiyatlar(),[{'label':'Öğrenci','tl':55}])

    def test_nku_acik_vejetaryen_ana_yemek(self):
        days=okul(nku.TekirdagNamikKemal).menuler()
        self.assertNotIn('vegetarian',days['2026-11-03'])
        self.assertEqual([o['name'] for o in days['2026-11-04']['vegetarian']['items']],['Domates Çorba','Sebze Haşlama','Kuskus','Hayrabolu Tatlısı'])

    def test_nku_saat_ve_fiyat(self):
        u=okul(nku.TekirdagNamikKemal)
        self.assertEqual(u.fiyatlar(),[{'label':'Öğrenci','tl':37}])
        self.assertEqual(u.saatler(),{'lunch':'11:00–14:00'})

    def test_klu_arsiv_ve_eski_ay_karismaz(self):
        days=okul(klu.KirklareliUniversitesi).menuler()
        self.assertEqual(max(days),'2026-11-30')
        self.assertNotIn('2026-10-29',days)
        self.assertEqual(days['2026-11-04']['lunch']['items'][2]['name'],'Şehriyeli Pirinç Pilavı')

    def test_klu_bozuk_json_basari_sayilmaz(self):
        with self.assertRaisesRegex(RuntimeError,"JSON'u okunamadı"):
            klu.sayfa_menu('<textarea>[bozuk]</textarea>')

    def test_bilecik_parcali_tarih_ve_sozcukler(self):
        days=okul(bilecik.BilecikSeyhEdebali).menuler()
        self.assertEqual(days['2026-11-04']['lunch']['items'][1]['name'],'Izgara Köfte + Patates')
        self.assertEqual(days['2026-11-09']['lunch']['items'][1]['name'],'Şinitzel + Patates Püresi')
        self.assertEqual(days['2026-11-30']['lunch']['items'][-1]['name'],'Turşu')

    def test_bilecik_ogrenci_ucret_ve_saatleri(self):
        u=okul(bilecik.BilecikSeyhEdebali)
        self.assertEqual([p['tl'] for p in u.fiyatlar()],[50,60])
        self.assertEqual(u.saatler(),{'lunch':'11:00–14:00'})

    def test_yalova_tooltip_malzemeleri_katilmadan_yazili_toplam(self):
        day=okul(yalova.YalovaUniversitesi).menuler()['2026-11-02']['lunch']
        self.assertEqual(day['items'][0],{'name':'Mercimek Çorba','kcal':137})
        self.assertEqual(day['kcal'],625)  # Kaynağın 620 yerine yazdığı toplam korunur.
        self.assertEqual(sum(o['kcal'] for o in day['items']),625)

    def test_hitit_gunluk_pencere_ve_saat(self):
        u=okul(hitit.HititUniversitesi)
        self.assertEqual(sorted(u.menuler()),['2026-11-04','2026-11-05','2026-11-06'])
        self.assertEqual(u.saatler(),{'lunch':'11:45–13:30'})


if __name__=='__main__':
    unittest.main()
