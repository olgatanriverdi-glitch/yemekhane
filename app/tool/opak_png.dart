// Mağaza görselleri için alfa kanalsız (24 bit, RGB) PNG yazımı. Google Play ekran görüntüsü ve öne çıkan görsel
// alanları JPEG ya da alfasız 24 bit PNG ister; Flutter'ın kendi PNG çıktısı RGBA'dır.
// Kullanan: tool/magaza_ekranlari_test.dart, tool/magaza_gorseli_test.dart. Doğrulama: test/magaza_gorselleri_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

final List<int> _crcTablosu = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bayt) {
  var c = 0xFFFFFFFF;
  for (final b in bayt) {
    c = _crcTablosu[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _dortBayt(int n) => Uint8List(4)..buffer.asByteData().setUint32(0, n);

/// `ui.ImageByteFormat.rawRgba` (alfa ön çarpımlı) verisini BEYAZ opak zemine birleştirip sekiz bitlik RGB PNG
/// (IHDR renk tipi 2) üretir: çıktıda alfa kanalı yoktur.
Uint8List opakPng(int genislik, int yukseklik, ByteData rgba) {
  final satirlar = BytesBuilder(copy: false);
  for (var y = 0; y < yukseklik; y++) {
    satirlar.addByte(0); // satır süzgeci yok
    for (var x = 0; x < genislik; x++) {
      final i = (y * genislik + x) * 4;
      final a = rgba.getUint8(i + 3);
      // ön çarpımlı renk + (1 - alfa) * beyaz
      for (var k = 0; k < 3; k++) {
        final v = rgba.getUint8(i + k) + (255 - a);
        satirlar.addByte(v > 255 ? 255 : v);
      }
    }
  }
  final baslik = BytesBuilder()
    ..add(_dortBayt(genislik))
    ..add(_dortBayt(yukseklik))
    ..add(const [8, 2, 0, 0, 0]); // 8 bit, RGB, sıkıştırma/süzgeç/geçişsiz
  final cikti = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void parca(String tur, List<int> veri) {
    final govde = [...ascii.encode(tur), ...veri];
    cikti
      ..add(_dortBayt(veri.length))
      ..add(govde)
      ..add(_dortBayt(_crc32(govde)));
  }

  parca('IHDR', baslik.toBytes());
  parca('IDAT', zlib.encode(satirlar.toBytes()));
  parca('IEND', const []);
  return cikti.toBytes();
}

/// PNG baytlarının IHDR bölümündeki (bit derinliği, renk tipi). Renk tipi 2 = RGB (alfasız), 6 = RGBA.
({int bitDerinligi, int renkTipi}) pngRenkBilgisi(List<int> bayt) {
  // 8 bayt imza + 4 uzunluk + 4 'IHDR' + 4 genişlik + 4 yükseklik -> bit derinliği 24, renk tipi 25
  return (bitDerinligi: bayt[24], renkTipi: bayt[25]);
}
