// Yayın öncesi Android son kontrolü (dosyalar okunarak): yedekleme kapalı, düz metin trafiği yok, bildirim simgesi
// yerinde, tam alarm izni yok. Gerçek doğrulama `flutter build appbundle --release`tir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _yorumsuz(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

void main() {
  final manifest = _yorumsuz(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync());
  final uygulama =
      RegExp(r'<application[^>]*>').firstMatch(manifest)!.group(0)!;

  test('allowBackup kapalı (oturum jetonu ve engel listesi yedeğe girmesin)',
      () {
    expect(uygulama, contains('android:allowBackup="false"'));
  });

  test('usesCleartextTraffic yok: düz metin (http) trafiğine izin verilmez',
      () {
    expect(manifest, isNot(contains('usesCleartextTraffic')));
    expect(manifest, isNot(contains('networkSecurityConfig')));
  });

  test('uygulama adı ve ikonlar tanımlı', () {
    expect(uygulama, contains('android:label="Üni Yemek"'));
    expect(uygulama, contains('android:icon="@mipmap/ic_launcher"'));
    expect(uygulama, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
  });

  test('izinler yalnızca internet ve bildirim; tam alarm, konum, kişi yok', () {
    final izinler = {
      for (final m in RegExp(r'<uses-permission\s+android:name="([^"]+)"')
          .allMatches(manifest))
        m.group(1)!
    };
    expect(izinler, {
      'android.permission.INTERNET',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
    });
  });

  test('bildirim simgesi (ic_bildirim) kaynaklarda var', () {
    expect(
        File('android/app/src/main/res/drawable/ic_bildirim.xml').existsSync(),
        isTrue);
    expect(File('lib/bildirim_servisi.dart').readAsStringSync(),
        contains("'ic_bildirim'"));
  });

  test(
      'yayın imzası key.properties yoksa debug anahtarına düşer, dosya git\'e girmez',
      () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('rootProject.file("key.properties")'));
    final ignore = File('android/.gitignore').readAsStringSync();
    expect(ignore, contains('key.properties'));
    expect(ignore, contains('*.jks'));
  });
}
