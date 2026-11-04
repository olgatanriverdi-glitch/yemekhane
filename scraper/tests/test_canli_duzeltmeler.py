"""4 Kasım canlı kaynaklarının yeni biçimleri ve yayın öncesi temizlik (ağsız)."""
import json
import tempfile
import unittest
from datetime import date
from pathlib import Path
from unittest.mock import patch

from yemekhane import build, elle
from yemekhane.temizle import menuleri_temizle, oge_temizle
from yemekhane.universities import asbu, boun, comu, karabuk, ktu, omu, pamukkale
from yemekhane.universities.base import Universite

FIX = Path(__file__).parent / 'fixtures'


def oku(ad):
    return (FIX / ad).read_bytes()


class KasimBicimleriTesti(unittest.TestCase):
    def test_boun_yeni_json_takvimi(self):
        m = boun.json_menu(json.loads(oku('boun_kasim.json')), 2026, 11)
        self.assertEqual((len(m), min(m), max(m)), (30, '2026-11-01', '2026-11-30'))
        self.assertEqual(set(m['2026-11-04']), {'lunch', 'dinner'})
        self.assertEqual(m['2026-11-04']['lunch']['items'][:2], [{'name': 'Süzme Mercimek Çorba'}, {'name': 'Hünkar Beğendi'}])
        self.assertEqual(m['2026-11-04']['dinner']['items'][1]['name'], 'Adaçaylı Kremalı Tavuk Sote')
        self.assertEqual(boun.json_menu(json.loads(oku('boun_kasim.json')), 2025, 11), {})

    def test_comu_kasim_tireli_baslik(self):
        for ad in ('comu_kasim.pdf', 'comu_vegan_kasim.pdf'):
            m, saat = comu.pdf_menu(oku(ad))
            self.assertEqual((len(m), min(m), max(m)), (20, '2026-11-02', '2026-11-27'))
            self.assertEqual(saat, '11:30–14:00')
            for gun in m.values():
                self.assertIn(len(gun['items']), (4, 5))
                self.assertEqual(gun['kcal'], sum(o['kcal'] for o in gun['items']))
        normal, _ = comu.pdf_menu(oku('comu_kasim.pdf'))
        vegan, _ = comu.pdf_menu(oku('comu_vegan_kasim.pdf'))
        self.assertEqual(normal['2026-11-04']['items'][1], {'name': 'Çoban Kavurma', 'kcal': 363})
        self.assertEqual(vegan['2026-11-04']['items'][1], {'name': 'Kuru Fasulye', 'kcal': 272})
        self.assertNotIn('2026-11-30', normal)  # Kaynak PDF yalnız dört haftadır.

    def test_karabuk_kasim_sayisal_tarih_ve_bosluklu_kalori(self):
        m = karabuk.pdf_menu(oku('karabuk_kasim.pdf'))
        self.assertEqual((len(m), min(m), max(m)), (21, '2026-11-02', '2026-11-30'))
        self.assertEqual(m['2026-11-04']['lunch']['kcal'], 780)
        self.assertEqual(m['2026-11-30']['lunch']['items'][-1], {'name': 'Cacık', 'kcal': 100})
        self.assertNotIn('Mühendisi', str(m))
        self.assertTrue(all(4 <= len(g['lunch']['items']) <= 6 for g in m.values()))

    def test_omu_gunluk_dikey_tablo_birikimli(self):
        m = omu.sayfa_menu(oku('omu_gun.html').decode())
        self.assertEqual(list(m), ['2026-11-04'])
        self.assertEqual(m['2026-11-04']['lunch']['items'], [{'name': n} for n in ('Mengen Çorba', 'Fırın Tavuk', 'İç Pilav', 'Cacık')])
        self.assertTrue(omu.OndokuzMayis().birikimli)

    def test_pamukkale_tek_haneli_gun_ve_ay(self):
        m = pamukkale.sayfa_menu(oku('pamukkale_kasim.html').decode())
        self.assertEqual(sorted(m), ['2026-11-%02d' % d for d in range(2, 7)])
        self.assertEqual(set(m['2026-11-04']), {'lunch', 'vegetarian'})
        self.assertTrue(all(g['lunch']['items'] for g in m.values()))
        self.assertNotIn('Turuncu', str(m))

    def test_asbu_json_normal_ve_vejetaryen(self):
        m = asbu.gunluk_menu(json.loads(oku('asbu_gun.json')))
        self.assertEqual(list(m), ['2026-11-04'])
        self.assertEqual(m['2026-11-04']['lunch']['kcal'], 988)
        self.assertEqual(m['2026-11-04']['vegetarian']['kcal'], 746)
        self.assertEqual(m['2026-11-04']['vegetarian']['items'][1], {'name': 'Türlü Yemeği', 'kcal': 108})
        self.assertNotIn('Fırında Baget', str(m['2026-11-04']['vegetarian']))
        self.assertEqual(asbu.gunluk_menu(None), {})
        self.assertEqual(asbu.gunluk_menu({'tarih': 'bozuk'}), {})

    def test_asbu_elle_ve_gunluk_birlesir_ve_ag_hatasi(self):
        u = asbu.AnkaraSosyalBilimler(lambda url: oku('asbu_gun.json'))
        m = u.menuler()
        self.assertTrue(u.birikimli)
        self.assertEqual(len(m), 23)
        self.assertEqual(m['2026-10-05'], elle.yukle('asbu')['2026-10-05'])
        self.assertEqual(m['2026-11-04']['lunch']['kcal'], 988)
        def hatali(url):
            raise OSError('test kesintisi')
        self.assertEqual(asbu.AnkaraSosyalBilimler(hatali).menuler(), elle.yukle('asbu'))

    def test_gtu_kasim_gorselinden_eklenen_gunler(self):
        m = {t: g for t, g in elle.yukle('gtu').items() if t.startswith('2026-11-')}
        self.assertEqual(sorted(m), ['2026-11-%02d' % d for d in range(2, 7)])
        for g in m.values():
            self.assertEqual(len(g['lunch']['items']), 8)
            self.assertNotIn('kcal', g['lunch'])  # İki yan yemek seçeneği toplanmaz.
        self.assertEqual(m['2026-11-04']['lunch']['items'][3], {'name': 'Pesto Soslu Makarna', 'kcal': 453})
        self.assertEqual(m['2026-11-06']['lunch']['items'][1], {'name': 'Hamsi Tava', 'kcal': 407})


class YemekTemizligiTesti(unittest.TestCase):
    def test_kalori_tarih_gramaj_ve_parantez(self):
        for ham, sonuc in [
            ('Tutmaç Çorba Kcal', {'name': 'Tutmaç Çorba'}),
            ('Meyve 80 kkal12.10.2026 - 16.10.2026', {'name': 'Meyve', 'kcal': 80}),
            ('Ekmek (50 gr)', {'name': 'Ekmek'}),
            ('Meyve (Şeftali 72 kcal)', {'name': 'Meyve (Şeftali)', 'kcal': 72}),
            ('Hamburger Menü', {'name': 'Hamburger Menü'}),
            ('Köfte (Vegan Köfte)', {'name': 'Köfte (Vegan Köfte)'}),
            ('Ayran 200 ml 80 Kcal', {'name': 'Ayran', 'kcal': 80}),
        ]:
            with self.subTest(ham=ham):
                self.assertEqual(oge_temizle({'name': ham}), (sonuc, None))

    def test_alternatifler_ve_aralik_toplanmaz(self):
        self.assertEqual(oge_temizle({'name': 'Patlıcan Musakka/ Körili Tavuk 158Kkal/286Kkal', 'kcal': 444}),
                         ({'name': 'Patlıcan Musakka/ Körili Tavuk'}, None))
        self.assertEqual(oge_temizle({'name': 'Ayran 60-70 KCAL', 'kcal': 60}), ({'name': 'Ayran'}, None))
        # Kastamonu ayrıştırıcısı ikinci kaloriyi addan ayırmış olabilir.
        self.assertEqual(oge_temizle({'name': 'Kıymalı Fırın Patates/ Soslu Fırın Tavuk 224Kkal/', 'kcal': 302}),
                         ({'name': 'Kıymalı Fırın Patates/ Soslu Fırın Tavuk'}, None))

    def test_ktu_bayram_kutlamasi_dort_sutunda(self):
        m = menuleri_temizle(ktu.sayfa_menu(oku('ktu_bayram.html').decode()))
        self.assertEqual(m['2026-10-29']['lunch'], {'items': [], 'note': '29 Ekim Cumhuriyet Bayramımız Kutlu Olsun'})

    def test_tatil_note_olur_ve_toplam_temizlenir(self):
        for ad in ('29 Ekim', '29 Ekim Cumhuriyet Bayramı'):
            m = menuleri_temizle({'2026-10-29': {'lunch': {'items': [{'name': ad, 'kcal': 100}], 'kcal': 100}}})
            self.assertEqual(m['2026-10-29']['lunch'], {'items': [], 'note': '29 Ekim Cumhuriyet Bayramı'})
        m = menuleri_temizle({'t': {'lunch': {'items': [{'name': 'A/B 158Kkal/286Kkal', 'kcal': 444}], 'kcal': 444}}})
        self.assertNotIn('kcal', m['t']['lunch'])
        m = menuleri_temizle({'2026-10-29': {'lunch': {'items': [{'name': 'Cumhuriyet Bayramımız'}]}}})
        self.assertEqual(m['2026-10-29']['lunch'], {'items': [], 'note': 'Cumhuriyet Bayramımız'})

    def test_birikimli_ve_gunluk_kayitlar_da_temizlenir(self):
        class Okul(Universite):
            id = 'temiztest'
            birikimli = True
            def menuler(self):
                return {'2999-01-02': {'lunch': {'items': [{'name': 'Meyve 80 kkal12.10.2026 - 16.10.2026'}]}}}
        with tempfile.TemporaryDirectory() as d:
            build.yaz(str(Path(d) / 'temiztest/menu.json'), {'days': {'2999-01-01': {'lunch': {'items': [{'name': '29 Ekim'}]}}}})
            def gunluk(u, klasor, m, *args):
                m['2999-01-03'] = {'lunch': {'items': [{'name': 'Tutmaç Çorba Kcal'}]}}
            with patch.object(build, 'gunluk_isle', side_effect=gunluk), patch.object(build, 'yemek_fotolari_ekle'):
                self.assertEqual(build.calistir(d, [Okul()]), 0)
            m = json.loads((Path(d) / 'temiztest/menu.json').read_text())['days']
            self.assertEqual(m['2999-01-01']['lunch']['items'], [])
            self.assertEqual(m['2999-01-02']['lunch']['items'], [{'name': 'Meyve', 'kcal': 80}])
            self.assertEqual(m['2999-01-03']['lunch']['items'], [{'name': 'Tutmaç Çorba'}])


class CalVeNoktaKTemizligi(unittest.TestCase):
    def test_cal_ve_nokta_k_kaloriye_tasinir(self):
        self.assertEqual(oge_temizle({'name': 'Mercimek Çorbası - 180 Cal'})[0], {'name': 'Mercimek Çorbası', 'kcal': 180})
        self.assertEqual(oge_temizle({'name': 'Helva 180.K'})[0], {'name': 'Helva', 'kcal': 180})

    def test_benzer_adlar_bozulmaz(self):
        for ad in ('Çalı Fasulye', 'Patates Kalıbı', 'Kuru Fasulye 2.Kap'):
            self.assertEqual(oge_temizle({'name': ad})[0], {'name': ad})


if __name__ == '__main__':
    unittest.main()
