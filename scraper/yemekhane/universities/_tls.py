"""Eksik ara sertifikaları AIA'dan tamamlar; güven kökleri sistem/certifi'dir.

Sertifika keşfi, TLS 1.2'nin açık Certificate iletisini okur; bu bağlantıda HTTP
isteği gönderilmez ve veri güvenilir sayılmaz. Asıl indirme her zaman Python'un
alan adı, süre ve imza zinciri doğrulamasından geçer. Harici ASN.1 bağımlılığı yok.
"""
import os
import socket
import ssl
import struct
import time
import urllib.request
from functools import lru_cache
from threading import RLock
from urllib.parse import urlsplit

_AIA = bytes.fromhex('2b06010505070101')
_CA_ISSUERS = bytes.fromhex('2b06010505073002')
_ONBELLEK = {}
_KILIT = RLock()
_SINIR = 2 * 1024 * 1024


def _tlv(veri, konum=0):
    if konum + 2 > len(veri):
        raise ValueError('Eksik DER başlığı')
    etiket, n = veri[konum:konum + 2]
    bas = konum + 2
    if n & 128:
        sayi = n & 127
        if not 1 <= sayi <= 4 or bas + sayi > len(veri):
            raise ValueError('Geçersiz DER uzunluğu')
        n = int.from_bytes(veri[bas:bas + sayi], 'big')
        bas += sayi
    son = bas + n
    if son > len(veri):
        raise ValueError('Eksik DER gövdesi')
    return etiket, veri[bas:son], son


def _alanlar(veri):
    konum = 0
    while konum < len(veri):
        etiket, govde, konum = _tlv(veri, konum)
        yield etiket, govde


def _tbs(der):
    etiket, sertifika, son = _tlv(der)
    if etiket != 0x30 or son != len(der):
        raise ValueError('X.509 dizisi bekleniyordu')
    alanlar = list(_alanlar(sertifika))
    if len(alanlar) != 3 or alanlar[0][0] != 0x30 or alanlar[2][0] != 3:
        raise ValueError('X.509 sertifikası bekleniyordu')
    tbs = list(_alanlar(alanlar[0][1]))
    kayma = int(bool(tbs) and tbs[0][0] == 0xa0)
    if len(tbs) < kayma + 6 or [a[0] for a in tbs[kayma:kayma + 6]] != [2, 0x30, 0x30, 0x30, 0x30, 0x30]:
        raise ValueError('Geçersiz TBSCertificate alanları')
    return tbs


def aia_adresleri(der):
    """X.509 Authority Information Access içindeki yalnız caIssuers URI'leri."""
    sonuc = []
    for etiket, govde in _tbs(der):
        if etiket != 0xa3:
            continue
        tag, uzantilar, _ = _tlv(govde)
        if tag != 0x30:
            raise ValueError('Geçersiz X.509 uzantıları')
        for tag, uzanti in _alanlar(uzantilar):
            alanlar = list(_alanlar(uzanti))
            if tag != 0x30 or len(alanlar) < 2 or alanlar[0] != (6, _AIA) or alanlar[-1][0] != 4:
                continue
            tag, erisimler, _ = _tlv(alanlar[-1][1])
            if tag != 0x30:
                continue
            for tag, erisim in _alanlar(erisimler):
                aciklama = list(_alanlar(erisim))
                if tag != 0x30 or len(aciklama) != 2 or aciklama[0] != (6, _CA_ISSUERS) or aciklama[1][0] != 0x86:
                    continue
                adres = aciklama[1][1].decode('ascii')
                url = urlsplit(adres)
                if url.scheme in ('http', 'https') and url.hostname and not url.username:
                    sonuc.append(adres)
    return list(dict.fromkeys(sonuc))


def _kok_mu(der):
    alanlar = _tbs(der)
    kayma = int(alanlar[0][0] == 0xa0)
    # Issuer == subject: kök/öz imzalı sertifikayı hiçbir zaman ek güven kökü yapma.
    return alanlar[kayma + 2] == alanlar[kayma + 4]


def _kimlik(der):
    alanlar = _tbs(der)
    kayma = int(alanlar[0][0] == 0xa0)
    return alanlar[kayma + 4], alanlar[kayma + 5]  # subject + SubjectPublicKeyInfo


def _sertifikalar(veri):
    if b'-----BEGIN CERTIFICATE-----' in veri:
        import re
        return [ssl.PEM_cert_to_DER_cert(p.decode('ascii')) for p in
                re.findall(b'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', veri, re.S)]
    try:
        _tbs(veri)
        return [veri]
    except ValueError:
        # Bazı AIA uçları DER yerine PKCS#7 SignedData sertifika kümesi döndürür.
        sonuc = []
        def gez(buf, derinlik=0):
            if derinlik > 8:
                return
            konum = 0
            while konum < len(buf):
                bas = konum
                tag, govde, konum = _tlv(buf, konum)
                parca = buf[bas:konum]
                if tag == 0x30:
                    try:
                        _tbs(parca)
                        sonuc.append(parca)
                        continue
                    except ValueError:
                        pass
                if tag & 0x20:
                    gez(govde, derinlik + 1)
        gez(veri)
        return sonuc


def _uzanti(tur, veri):
    return struct.pack('!HH', tur, len(veri)) + veri


def sunucu_sertifikalari(host, port, zaman_asimi):
    """Doğrulama yapmayan *keşif*: yalnız açık TLS Certificate iletisini okur.

    SSLContext kullanılmaz; bir TLS oturumu kurulmaz, uygulama verisi alınmaz.
    Sertifikalar yalnız AIA adreslerini bulmaya yarar, güven kararı vermez.
    """
    host = host.encode('idna')
    sni = b'\0' + struct.pack('!H', len(host)) + host
    imzalar = bytes.fromhex('0403050306030804080508060401050106010201')
    uzantilar = (_uzanti(0, struct.pack('!H', len(sni)) + sni)
                 + _uzanti(10, bytes.fromhex('000600170018001d'))
                 + _uzanti(11, b'\x01\x00')
                 + _uzanti(13, struct.pack('!H', len(imzalar)) + imzalar)
                 + _uzanti(0xff01, b'\0'))
    sifreler = bytes.fromhex('c02fc030c02bc02cc013c014009c009d002f0035009e009f0033003900ff')
    hello = (b'\x03\x03' + os.urandom(32) + b'\0' + struct.pack('!H', len(sifreler))
             + sifreler + b'\x01\x00' + struct.pack('!H', len(uzantilar)) + uzantilar)
    hello = b'\x01' + len(hello).to_bytes(3, 'big') + hello
    bitis = time.monotonic() + zaman_asimi
    with socket.create_connection((host.decode('ascii'), port), timeout=zaman_asimi) as soket:
        soket.sendall(b'\x16\x03\x01' + struct.pack('!H', len(hello)) + hello)
        def oku(n):
            veri = b''
            while len(veri) < n:
                soket.settimeout(max(0.01, bitis - time.monotonic()))
                parca = soket.recv(n - len(veri))
                if not parca:
                    raise OSError('TLS sertifika keşfi yarıda kesildi')
                veri += parca
            return veri
        el_sikisma, toplam = b'', 0
        while toplam < _SINIR:
            baslik = oku(5)
            n = int.from_bytes(baslik[3:5], 'big')
            if n > 18432:
                raise ValueError('TLS kaydı çok büyük')
            govde = oku(n)
            toplam += n + 5
            if baslik[0] != 22:
                raise OSError('TLS sertifika keşfi reddedildi (kayıt %d)' % baslik[0])
            el_sikisma += govde
            while len(el_sikisma) >= 4:
                n = int.from_bytes(el_sikisma[1:4], 'big')
                if n > _SINIR:
                    raise ValueError('TLS iletisi çok büyük')
                if len(el_sikisma) < n + 4:
                    break
                tur, govde = el_sikisma[0], el_sikisma[4:4 + n]
                el_sikisma = el_sikisma[4 + n:]
                if tur == 11:
                    if len(govde) < 3 or int.from_bytes(govde[:3], 'big') != len(govde) - 3:
                        raise ValueError('Eksik TLS sertifika listesi')
                    sonuc, pos = [], 3
                    while pos < len(govde):
                        uzunluk = int.from_bytes(govde[pos:pos + 3], 'big')
                        pos += 3
                        if not uzunluk or pos + uzunluk > len(govde):
                            raise ValueError('Eksik TLS sertifikası')
                        sonuc.append(govde[pos:pos + uzunluk])
                        pos += uzunluk
                    return sonuc
        raise ValueError('TLS keşif sınırı aşıldı')


@lru_cache(maxsize=1)
def varsayilan_baglam():
    ctx = ssl.create_default_context()
    try:
        import certifi
    except ImportError:
        pass
    else:
        ctx.load_verify_locations(cafile=certifi.where())
    # Python 3.13+ bunu varsayılan açabilir: ara sertifika güven kökü olamaz.
    ctx.verify_flags &= ~getattr(ssl, 'VERIFY_X509_PARTIAL_CHAIN', 0)
    return ctx


def baglam(sertifikalar=(), dusuk_dh=False):
    if not sertifikalar and not dusuk_dh:
        return varsayilan_baglam()
    ctx = ssl.create_default_context()
    # Aynı sistem/certifi köklerini kopyala; indirilen kökler buraya girmez.
    kokler = varsayilan_baglam().get_ca_certs(binary_form=True)
    if kokler:
        ctx.load_verify_locations(cadata=''.join(ssl.DER_cert_to_PEM_cert(c) for c in kokler))
    ctx.verify_flags &= ~getattr(ssl, 'VERIFY_X509_PARTIAL_CHAIN', 0)
    guvenilen = {_kimlik(c) for c in kokler}
    # Aynı anahtarın cross-sign kopyası sistem kökünü gölgelememeli. Özellikle
    # Sectigo R46.p7c artık depoda bulunmayan AAA köküne de alternatif içerir.
    ara = [c for c in sertifikalar if not _kok_mu(c) and _kimlik(c) not in guvenilen]
    if ara:
        ctx.load_verify_locations(cadata=''.join(ssl.DER_cert_to_PEM_cert(c) for c in ara))
    if dusuk_dh:
        ctx.set_ciphers('DEFAULT@SECLEVEL=1')
    return ctx


def ara_sertifikalar(host, port, zaman_asimi):
    anahtar = (host, port)
    with _KILIT:
        if anahtar in _ONBELLEK:
            return _ONBELLEK[anahtar]
    bitis = time.monotonic() + zaman_asimi
    zincir = sunucu_sertifikalari(host, port, zaman_asimi)
    bekleyen, gorulen, ara = list(zincir), set(), []
    # Sunucunun gönderdiği kök bile güven kaynağı sayılmaz.
    for c in zincir[1:]:
        if not _kok_mu(c):
            ara.append(c)
    while bekleyen and len(gorulen) < 8 and time.monotonic() < bitis:
        der = bekleyen.pop(0)
        for url in aia_adresleri(der):
            if url in gorulen or len(gorulen) >= 8:
                continue
            gorulen.add(url)
            try:
                req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (yemekhane AIA)'})
                with urllib.request.urlopen(req, timeout=max(0.01, bitis - time.monotonic()), context=varsayilan_baglam()) as y:
                    veri = y.read(_SINIR + 1)
                if len(veri) > _SINIR:
                    continue
                for c in _sertifikalar(veri):
                    if c not in ara and c not in zincir and not _kok_mu(c):
                        ara.append(c)
                        bekleyen.append(c)
            except (OSError, ValueError, ssl.SSLError):
                continue
    sonuc = tuple(ara)
    with _KILIT:
        _ONBELLEK[anahtar] = sonuc
    return sonuc


def ssl_hatasi(hata):
    neden = getattr(hata, 'reason', hata)
    return neden if isinstance(neden, ssl.SSLError) else None
