"""Ağsız TLS kurtarma ve gerçek OpenSSL/LibreSSL doğrulama testleri.

fixtures/tls/leaf.key yalnız bu test sunucusunun açık test anahtarıdır.
"""
import ssl
import struct
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import MagicMock, patch

from yemekhane.universities import _tls, base, sakarya, istiklal

FIX = Path(__file__).parent / 'fixtures' / 'tls'


def der(ad):
    return ssl.PEM_cert_to_DER_cert((FIX / ad).read_text())


def ssl_hata(neden):
    hata = ssl.SSLError(1, neden)
    hata.reason = neden
    return urllib.error.URLError(hata)


def yanit(veri=b'test'):
    sonuc = MagicMock()
    sonuc.__enter__.return_value.read.return_value = veri
    return sonuc


class TlsTesti(unittest.TestCase):
    def setUp(self):
        _tls._ONBELLEK.clear()

    def tearDown(self):
        _tls._ONBELLEK.clear()

    def assertDogrulama(self, ctx):
        self.assertEqual(ctx.verify_mode, ssl.CERT_REQUIRED)
        self.assertTrue(ctx.check_hostname)
        self.assertFalse(ctx.verify_flags & getattr(ssl, 'VERIFY_X509_PARTIAL_CHAIN', 0))

    def test_der_aia_yalniz_ca_issuers(self):
        self.assertEqual(_tls.aia_adresleri((FIX / 'aia.der').read_bytes()),
                         ['http://crt.sectigo.com/SectigoPublicServerAuthenticationCADVR36.crt'])
        self.assertEqual(_tls.aia_adresleri(der('root.pem')), [])
        for ham in (b'', b'\x30\x80', b'\x30\x04\0', b'\x30\xff'):
            with self.subTest(ham=ham), self.assertRaises(ValueError):
                _tls.aia_adresleri(ham)

    def test_tam_dogrulama_her_baglamda_acik(self):
        for ctx in (_tls.baglam(), _tls.baglam((der('intermediate.pem'),))):
            self.assertDogrulama(ctx)
        if ssl.OPENSSL_VERSION.startswith('LibreSSL'):
            # LibreSSL SECLEVEL sözdizimini desteklemez; güvenlik kapatılarak
            # geçiş yapılması yerine hata kalması beklenir. Robot OpenSSL'dir.
            with self.assertRaises(ssl.SSLError):
                _tls.baglam((), True)
        else:
            self.assertDogrulama(_tls.baglam((), True))

    def test_der_pem_ve_pkcs7_sertifika_kumesi(self):
        c = der('intermediate.pem')
        def tlv(tag, veri):
            n = len(veri)
            boy = bytes([n]) if n < 128 else bytes([0x82]) + n.to_bytes(2, 'big')
            return bytes([tag]) + boy + veri
        pkcs7 = tlv(0x30, tlv(6, bytes.fromhex('2a864886f70d010702')) + tlv(0xa0, tlv(0x30, tlv(0xa0, c))))
        self.assertEqual(_tls._sertifikalar(c), [c])
        self.assertEqual(_tls._sertifikalar((FIX / 'intermediate.pem').read_bytes()), [c])
        self.assertEqual(_tls._sertifikalar(pkcs7), [c])

    def test_kesif_parcalanmis_tls_certificate_iletisini_okur(self):
        c = der('leaf.pem')
        cert = len(c).to_bytes(3, 'big') + c
        govde = len(cert).to_bytes(3, 'big') + cert
        hs = b'\x0b' + len(govde).to_bytes(3, 'big') + govde
        records = b''.join(b'\x16\x03\x03' + struct.pack('!H', len(p)) + p for p in (hs[:13], hs[13:]))
        soket = MagicMock()
        veri = bytearray(records)
        def recv(n):
            sonuc = bytes(veri[:min(n, 7)])
            del veri[:len(sonuc)]
            return sonuc
        soket.recv.side_effect = recv
        soket.__enter__.return_value = soket
        with patch.object(_tls.socket, 'create_connection', return_value=soket):
            self.assertEqual(_tls.sunucu_sertifikalari('example.edu.tr', 443, 3), [c])
        self.assertEqual(soket.sendall.call_count, 1)
        hello = soket.sendall.call_args.args[0]
        self.assertTrue(hello.startswith(b'\x16\x03\x01'))
        self.assertIn(b'example.edu.tr', hello)
        self.assertNotIn(b'GET ', hello)

    def test_aia_ara_sertifika_onbellegi_ve_kok_indirilse_bile_guvenilmez(self):
        leaf, ara, kok = der('leaf.pem'), der('intermediate.pem'), der('root.pem')
        def adres(c):
            return ['http://ca.example/ara'] if c == leaf else ['http://ca.example/kok']
        with patch.object(_tls, 'sunucu_sertifikalari', return_value=[leaf]) as kesif, \
             patch.object(_tls, 'aia_adresleri', side_effect=adres), \
             patch.object(_tls.urllib.request, 'urlopen', side_effect=[yanit(ara), yanit(kok)]) as ac:
            self.assertEqual(_tls.ara_sertifikalar('example.edu.tr', 443, 3), (ara,))
            self.assertEqual(_tls.ara_sertifikalar('example.edu.tr', 443, 3), (ara,))
        kesif.assert_called_once()
        self.assertEqual(ac.call_count, 2)
        for cagri in ac.call_args_list:
            self.assertDogrulama(cagri.kwargs['context'])
        self.assertNotIn(kok, _tls.baglam((ara, kok)).get_ca_certs(binary_form=True))

    def test_dogrulama_hatasinda_ayni_post_tam_dogrulamayla_tekrarlanir(self):
        req = urllib.request.Request('https://example.edu.tr/menu', data=b'ay=11', headers={'Content-Type': 'application/json'})
        with patch.object(base.urllib.request, 'urlopen', side_effect=[ssl_hata('CERTIFICATE_VERIFY_FAILED'), yanit()]) as ac, \
             patch.object(_tls, 'ara_sertifikalar', return_value=(der('intermediate.pem'),)) as aia:
            self.assertEqual(base.indir(req), b'test')
        aia.assert_called_once_with('example.edu.tr', 443, 30)
        self.assertEqual(ac.call_count, 2)
        for cagri in ac.call_args_list:
            self.assertIs(cagri.args[0], req)
            self.assertEqual(cagri.args[0].data, b'ay=11')
            self.assertDogrulama(cagri.kwargs['context'])

    def test_yalniz_dh_hatasinda_o_istege_seclevel_1(self):
        with patch.object(base.urllib.request, 'urlopen', side_effect=[ssl_hata('DH_KEY_TOO_SMALL'), yanit(), yanit()]) as ac, \
             patch.object(ssl.SSLContext, 'set_ciphers') as sifre, \
             patch.object(_tls, 'baglam', wraps=_tls.baglam) as ctx:
            base.indir('https://example.edu.tr/')
            base.indir('https://example.edu.tr/')
        self.assertEqual([c.args[1] for c in ctx.call_args_list], [False, True, False])
        sifre.assert_called_once_with('DEFAULT@SECLEVEL=1')
        for cagri in ac.call_args_list:
            self.assertDogrulama(cagri.kwargs['context'])

    def test_dh_ve_eksik_ara_sertifika_ayni_istekte(self):
        with patch.object(base.urllib.request, 'urlopen', side_effect=[ssl_hata('DH_KEY_TOO_SMALL'), ssl_hata('CERTIFICATE_VERIFY_FAILED'), yanit()]) as ac, \
             patch.object(ssl.SSLContext, 'set_ciphers'), \
             patch.object(_tls, 'ara_sertifikalar', return_value=(der('intermediate.pem'),)):
            self.assertEqual(base.indir('https://example.edu.tr/'), b'test')
        self.assertEqual(ac.call_count, 3)

    def test_guvenilmeyen_ve_diger_ag_hatalari_yutulmaz(self):
        hata = ssl_hata('CERTIFICATE_VERIFY_FAILED')
        with patch.object(base.urllib.request, 'urlopen', side_effect=hata) as ac, \
             patch.object(_tls, 'ara_sertifikalar', return_value=()):
            with self.assertRaises(urllib.error.URLError):
                base.indir('https://example.edu.tr/')
        self.assertEqual(ac.call_count, 2)
        with patch.object(base.urllib.request, 'urlopen', side_effect=OSError('test')) as ac, \
             patch.object(_tls, 'ara_sertifikalar') as aia:
            with self.assertRaises(OSError):
                base.indir('https://example.edu.tr/')
            aia.assert_not_called()
            ac.assert_called_once()

    def test_post_eklentileri_ortak_indiriciyi_kullanir(self):
        with patch.object(sakarya, 'indir', return_value=b'sabis') as ac:
            self.assertEqual(sakarya.sabis_indir('https://example.edu.tr', {'month': 11}), b'sabis')
            self.assertEqual(ac.call_args.args[0].data, b'month=11')
        with patch.object(istiklal, 'indir', return_value=b'{}') as ac:
            self.assertEqual(istiklal.json_indir('https://example.edu.tr', {'ay': 11}), b'{}')
            self.assertEqual(ac.call_args.args[0].headers['Content-type'], 'application/json')


def el_sikis(ctx, host='localhost'):
    """Gerçek TLS motoru; soket/ağ kullanmadan MemoryBIO üstünde el sıkışma."""
    server = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    server.load_cert_chain(str(FIX / 'leaf.pem'), str(FIX / 'leaf.key'))
    ci, co, si, so = (ssl.MemoryBIO() for _ in range(4))
    client, sunucu = ctx.wrap_bio(ci, co, server_hostname=host), server.wrap_bio(si, so, server_side=True)
    bitti = set()
    for _ in range(20):
        for taraf in (client, sunucu):
            try:
                taraf.do_handshake()
                bitti.add(taraf)
            except ssl.SSLWantReadError:
                pass
        for cikti, girdi in ((co, si), (so, ci)):
            if cikti.pending:
                girdi.write(cikti.read())
        if len(bitti) == 2:
            return
    raise AssertionError('TLS el sıkışması bitmedi')


class GercekDogrulamaTesti(unittest.TestCase):
    def koklu_baglam(self):
        ctx = ssl.create_default_context(cadata=(FIX / 'root.pem').read_text())
        ctx.verify_flags &= ~getattr(ssl, 'VERIFY_X509_PARTIAL_CHAIN', 0)
        return ctx

    def test_eksik_ara_sonradan_yuklenince_zincir_tamamlanir(self):
        ctx = self.koklu_baglam()
        with self.assertRaises(ssl.SSLCertVerificationError):
            el_sikis(ctx)
        with patch.object(_tls, 'varsayilan_baglam', return_value=ctx):
            el_sikis(_tls.baglam((der('intermediate.pem'),)))

    def test_alan_adi_yanlisken_yine_reddedilir(self):
        with patch.object(_tls, 'varsayilan_baglam', return_value=self.koklu_baglam()):
            ctx = _tls.baglam((der('intermediate.pem'),))
        with self.assertRaises(ssl.SSLCertVerificationError):
            el_sikis(ctx, 'baska.example')

    def test_indirilen_kok_ve_ara_tek_basina_guven_saglamaz(self):
        ctx = _tls.baglam((der('intermediate.pem'), der('root.pem')))
        with self.assertRaises(ssl.SSLCertVerificationError):
            el_sikis(ctx)


if __name__ == '__main__':
    unittest.main()
