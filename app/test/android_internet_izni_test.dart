// Bulgu 1: release APK'da INTERNET izni yoktu (izin yalnızca debug/profile manifestlerindeydi).
// Ana manifestte olmazsa yayın sürümünde hiçbir ağ isteği çalışmaz.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ana AndroidManifest.xml INTERNET iznini ister (release derlemesi için)',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
        RegExp(r'<uses-permission\s+android:name="android\.permission\.INTERNET"\s*/>')
            .hasMatch(manifest),
        isTrue,
        reason:
            'izin src/debug ve src/profile içinde var ama src/main içinde yoksa release uygulaması çevrimdışı kalır');
  });

  test('izin <application> öğesinin dışında, <manifest> altında tanımlıdır',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final izin = manifest.indexOf('android.permission.INTERNET');
    final uygulama = manifest.indexOf('<application');
    expect(izin, greaterThanOrEqualTo(0));
    expect(izin, lessThan(uygulama));
  });
}
