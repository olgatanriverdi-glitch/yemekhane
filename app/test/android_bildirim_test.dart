// Günlük menü bildirimi için Android / paket yapılandırması: izinler, alıcılar, desugaring, bildirim simgesi.
// Dosyalar okunarak denetlenir (cihaz ya da derleme gerekmez); gerçek doğrulama `flutter build apk --debug`tır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String yol) => File(yol).readAsStringSync();

const _manifestYolu = 'android/app/src/main/AndroidManifest.xml';

/// Manifestteki <uses-permission> adları (yorum satırları atılır).
Set<String> _izinler(String manifest) => {
      for (final m in RegExp(r'<uses-permission\s+android:name="([^"]+)"')
          .allMatches(_yorumsuz(manifest)))
        m.group(1)!
    };

String _yorumsuz(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

void main() {
  group('AndroidManifest.xml', () {
    final manifest = _oku(_manifestYolu);
    final yorumsuz = _yorumsuz(manifest);
    final uygulama = yorumsuz.indexOf('<application');

    test(
        'bildirim ve yeniden başlatma izinleri <manifest> altında, INTERNET de yerinde',
        () {
      final izinler = _izinler(manifest);
      expect(izinler, contains('android.permission.POST_NOTIFICATIONS'));
      expect(izinler, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(izinler, contains('android.permission.INTERNET'));
      for (final izin in [
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      ]) {
        expect(yorumsuz.indexOf(izin), lessThan(uygulama),
            reason: '$izin <application> öğesinin dışında olmalı');
      }
    });

    test('tam alarm izni istenmez: bildirimler yaklaşık zamanlanır', () {
      final izinler = _izinler(manifest);
      expect(
          izinler, isNot(contains('android.permission.SCHEDULE_EXACT_ALARM')));
      expect(izinler, isNot(contains('android.permission.USE_EXACT_ALARM')));
      expect(manifest, isNot(contains('USE_FULL_SCREEN_INTENT')));
    });

    test('zamanlanmış bildirim alıcısı <application> içinde ve dışarıya kapalı',
        () {
      final alici = RegExp(
              r'<receiver\s+android:exported="false"\s+android:name="com\.dexterous\.flutterlocalnotifications\.ScheduledNotificationReceiver"\s*/>')
          .firstMatch(yorumsuz);
      expect(alici, isNotNull);
      expect(alici!.start, greaterThan(uygulama));
      expect(yorumsuz.indexOf('</application>'), greaterThan(alici.start));
    });

    test(
        'yeniden başlatma alıcısı açılışta, uygulama güncellenince bildirimleri yeniden kurar',
        () {
      final m = RegExp(
              r'<receiver\s+android:exported="false"\s+android:name="com\.dexterous\.flutterlocalnotifications\.ScheduledNotificationBootReceiver">(.*?)</receiver>',
              dotAll: true)
          .firstMatch(yorumsuz);
      expect(m, isNotNull);
      expect(m!.start, greaterThan(uygulama));
      final eylemler = RegExp(r'<action\s+android:name="([^"]+)"')
          .allMatches(m.group(1)!)
          .map((e) => e.group(1)!)
          .toSet();
      expect(eylemler, contains('android.intent.action.BOOT_COMPLETED'));
      expect(eylemler, contains('android.intent.action.MY_PACKAGE_REPLACED'));
    });

    test('uygulama adı ve simge kaynakları değişmedi', () {
      expect(manifest, contains('android:label="Üni Yemek"'));
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    });
  });

  group('build.gradle.kts', () {
    final gradle = _oku('android/app/build.gradle.kts');

    test('core library desugaring açık ve kitaplığı bağımlılıklarda', () {
      expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
      expect(
          RegExp(r'coreLibraryDesugaring\("com\.android\.tools:desugar_jdk_libs:\d+\.\d+\.\d+"\)')
              .hasMatch(gradle),
          isTrue);
      // desugaring bayrağı compileOptions içinde
      final co = RegExp(r'compileOptions\s*\{(.*?)\}', dotAll: true)
          .firstMatch(gradle)!
          .group(1)!;
      expect(co, contains('isCoreLibraryDesugaringEnabled = true'));
      expect(co, contains('JavaVersion.VERSION_17'));
    });

    test('imza yapılandırması korunur (key.properties varsa release imzası)',
        () {
      expect(gradle, contains('signingConfigs'));
      expect(gradle, contains('key.properties'));
    });
  });

  group('paketler ve eklenti kullanımı', () {
    final pubspec = _oku('pubspec.yaml');

    test(
        'flutter_local_notifications ve timezone eklenmiş; flutter_timezone eklenmemiş',
        () {
      expect(
          pubspec,
          contains(RegExp(r'^  flutter_local_notifications: \^\d+\.\d+\.\d+',
              multiLine: true)));
      expect(pubspec,
          contains(RegExp(r'^  timezone: \^\d+\.\d+\.\d+', multiLine: true)));
      expect(pubspec, isNot(contains('flutter_timezone')),
          reason: 'Türkiye için sabit Europe/Istanbul kullanılır');
    });

    test(
        'eklenti yalnızca bildirim_servisi.dart içinde kullanılır (açılışta eklenti kodu yok)',
        () {
      final kullananlar = [
        for (final f
            in Directory('lib').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart') &&
              f
                  .readAsStringSync()
                  .contains('package:flutter_local_notifications'))
            f.path.split('/').last
      ];
      expect(kullananlar, ['bildirim_servisi.dart']);
    });

    test('tam alarm kipi kullanılmaz: yalnızca inexactAllowWhileIdle', () {
      final kod = _oku('lib/bildirim_servisi.dart');
      expect(kod, contains('AndroidScheduleMode.inexactAllowWhileIdle'));
      expect(kod, isNot(contains('AndroidScheduleMode.exact')));
      expect(kod, isNot(contains('AndroidScheduleMode.alarmClock')));
      expect(kod, isNot(contains('requestExactAlarmsPermission')));
    });
  });

  group('bildirim simgesi', () {
    test('kodda adı geçen ic_bildirim kaynağı var ve tek renkli (beyaz) vektör',
        () {
      expect(_oku('lib/bildirim_servisi.dart'), contains("'ic_bildirim'"));
      final xml = _oku('android/app/src/main/res/drawable/ic_bildirim.xml');
      expect(xml, contains('<vector'));
      expect(xml, contains('android:width="24dp"'));
      expect(xml, contains('android:fillColor="#FFFFFFFF"'));
      expect(xml, contains('android:pathData='));
    });

    test(
        'sürüm derlemesinde kaynak küçültme simgeyi silmesin: res/raw/keep.xml',
        () {
      final keep = _oku('android/app/src/main/res/raw/keep.xml');
      expect(keep, contains('tools:keep="@drawable/ic_bildirim"'));
    });
  });
}
