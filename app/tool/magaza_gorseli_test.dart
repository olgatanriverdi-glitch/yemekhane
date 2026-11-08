// Google Play 1024x500 öne çıkan görsel üreticisi. `flutter test` bunu çalıştırmaz (tool/ klasörü); yenilemek için
// app klasöründe: ~/development/flutter/bin/flutter test tool/magaza_gorseli_test.dart
// Safran zemin, uygulama ikonu (web/icons/Icon-512.png, tool/ikon_uret_test.dart üretir), ad ve slogan.
// Test ortamının varsayılan yazı tipi (Ahem) kutu çizdiğinden Manrope uygulama varlıklarından dosyalardan yüklenir.
// Çıktı: ../magaza/gorseller/one-cikan-gorsel-1024x500.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/tema.dart';

import 'opak_png.dart';

Color _ton(double ton, double doygunluk, double aciklik) =>
    HSLColor.fromAHSL(1, ton % 360, doygunluk, aciklik).toColor();

void _yaz(Canvas c, String metin, Offset yer, double boyut, FontWeight kalinlik,
    Color renk, double enCok) {
  final p = TextPainter(
      text: TextSpan(
          text: metin,
          style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: boyut,
              fontWeight: kalinlik,
              color: renk,
              height: 1.15)),
      textDirection: TextDirection.ltr)
    ..layout(maxWidth: enCok);
  p.paint(c, yer);
}

void main() {
  testWidgets('öne çıkan görsel 1024x500', (t) async {
    // uygulamanın kendi yazı tipi (Manrope)
    final manrope = FontLoader('Manrope')
      ..addFont(Future.value(ByteData.sublistView(
          File('assets/fonts/Manrope-Variable.ttf').readAsBytesSync())));
    await manrope.load();
    await t.runAsync(() async {
      final palet = temaRenkleri.first;
      final marka = _ton(palet.ton, palet.doygunluk, 0.50);
      final derin = _ton(palet.ton, palet.doygunluk, 0.415);
      final krem = _ton(palet.yuzeyTon, 0.90, 0.95);
      final kodek = await ui.instantiateImageCodec(
          File('web/icons/Icon-512.png').readAsBytesSync());
      final ikon = (await kodek.getNextFrame()).image;

      final kayit = ui.PictureRecorder();
      final c = Canvas(kayit);
      c.drawRect(const Rect.fromLTWH(0, 0, 1024, 500), Paint()..color = marka);
      // sağ alta hafif koyu geniş daire: tek renk, derinlik için
      c.drawCircle(const Offset(1010, 520), 330,
          Paint()..color = derin.withValues(alpha: 0.55));
      // ikon: 300 px, yuvarlak köşeli, hafif gölge
      const ikonYeri = Rect.fromLTWH(84, 100, 300, 300);
      final kose = RRect.fromRectAndRadius(ikonYeri, const Radius.circular(68));
      c.save();
      c.clipRRect(kose);
      c.drawImageRect(
          ikon,
          Rect.fromLTWH(0, 0, ikon.width.toDouble(), ikon.height.toDouble()),
          ikonYeri,
          Paint()..filterQuality = FilterQuality.high);
      c.restore();
      c.drawRRect(
          kose,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..color = krem);
      _yaz(c, 'Üni Yemek', const Offset(432, 150), 92, FontWeight.w700, krem,
          560);
      _yaz(c, 'Bugün yemekhanede ne var?', const Offset(436, 268), 36,
          FontWeight.w500, krem, 560);
      _yaz(c, 'Menü, kalori ve öğrenci fiyatı.', const Offset(436, 330), 26,
          FontWeight.w400, krem.withValues(alpha: 0.9), 540);

      final resim = await kayit.endRecording().toImage(1024, 500);
      // Google Play alfasız 24 bit PNG ister (tool/opak_png.dart)
      final ham = (await resim.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      File('../magaza/gorseller/one-cikan-gorsel-1024x500.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(opakPng(resim.width, resim.height, ham));
    });
  });
}
