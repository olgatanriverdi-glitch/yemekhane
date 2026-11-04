// Gerçek bildirim servisi (FlutterBildirimServisi): cihaz yok; eklentinin platform kanalı sahtelenir ve servisin
// eklentiye gönderdiği çağrılar denetlenir. Cihazda bildirim gelmesi burada denenmez.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/bildirim_plani.dart';
import 'package:yemekhane/bildirim_servisi.dart';

const _kanal = MethodChannel('dexterous.com/flutter/local_notifications');

/// Kanala gelen çağrılar ve her çağrıya verilecek yanıtlar.
class _Kanal {
  final List<MethodCall> cagrilar = [];
  bool izin = true;
  bool baslatmaHata = false;
  bool izinHata = false;
  bool planHata = false;

  List<MethodCall> yontem(String ad) =>
      cagrilar.where((c) => c.method == ad).toList();

  Future<Object?> isle(MethodCall c) async {
    cagrilar.add(c);
    switch (c.method) {
      case 'initialize':
        if (baslatmaHata) throw PlatformException(code: 'hata');
        return true;
      case 'requestNotificationsPermission':
        if (izinHata) throw PlatformException(code: 'izin_hatasi');
        return izin;
      case 'zonedSchedule':
        if (planHata) throw PlatformException(code: 'plan_hatasi');
        return null;
    }
    return null;
  }
}

/// Uzak gelecekte (eklentinin kendi "geçmiş değil" denetimini gerçek saatle de geçsin diye) bir gün.
PlanliBildirim _bildirim(int gun, {int saat = 10, int dakika = 30}) =>
    PlanliBildirim(
        kimlik: 20990100 + gun,
        zaman: DateTime.utc(2099, 1, gun, saat, dakika),
        baslik: 'AÜ · bugün öğle',
        metin: 'Mercimek Çorbası, Pilav, Cacık +2');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Kanal kanal;

  setUp(() {
    kanal = _Kanal();
    // gerçek uygulamada Dart eklenti kaydedicisi bunu yapar; testte elle
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kanal, kanal.isle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kanal, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('tembel başlatma', () {
    test('servisi kurmak eklentiye dokunmaz', () {
      FlutterBildirimServisi();
      expect(kanal.cagrilar, isEmpty);
    });

    test('ilk kullanımda bir kez başlatılır: varsayılan simge ve izin isteği',
        () async {
      final s = FlutterBildirimServisi();
      expect(await s.izinIste(), isTrue);
      expect(await s.izinIste(), isTrue);
      expect(kanal.yontem('initialize').length, 1);
      expect(kanal.yontem('initialize').single.arguments,
          containsPair('defaultIcon', 'ic_bildirim'));
      expect(kanal.yontem('requestNotificationsPermission').length, 2);
      expect(kanal.cagrilar.first.method, 'initialize');
    });

    test('başlatma başarısız olursa sonraki kullanımda yeniden denenir',
        () async {
      final s = FlutterBildirimServisi();
      kanal.baslatmaHata = true;
      expect(await s.izinIste(), isFalse);
      kanal.baslatmaHata = false;
      expect(await s.izinIste(), isTrue);
      expect(kanal.yontem('initialize').length, 2);
    });
  });

  group('izin', () {
    test('verilmezse false; istek hata verirse de false (istisna sızmaz)',
        () async {
      final s = FlutterBildirimServisi();
      kanal.izin = false;
      expect(await s.izinIste(), isFalse);
      kanal.izinHata = true;
      expect(await s.izinIste(), isFalse);
    });

    test('bildirim yalnızca Android ve iOS\'ta desteklenir', () {
      expect(bildirimDesteklenir(), isTrue, reason: 'test platformu Android');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(bildirimDesteklenir(), isTrue);
      for (final p in [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = p;
        expect(bildirimDesteklenir(), isFalse, reason: '$p');
      }
    });
  });

  group('planlama', () {
    // 5 Ocak 2099 06:00 UTC = 09:00 Türkiye
    FlutterBildirimServisi servis() =>
        FlutterBildirimServisi(simdi: () => DateTime.utc(2099, 1, 5, 6, 0));

    test(
        'her bildirim yaklaşık zamanlı (tam alarm yok) ve Istanbul saatiyle gider',
        () async {
      await servis().planla([_bildirim(5), _bildirim(6)]);
      final c = kanal.yontem('zonedSchedule');
      expect(c.length, 2);
      final a = c.first.arguments as Map;
      expect(a['id'], 20990105);
      expect(a['title'], 'AÜ · bugün öğle');
      expect(a['body'], 'Mercimek Çorbası, Pilav, Cacık +2');
      expect(a['timeZoneName'], 'Europe/Istanbul');
      expect(a['scheduledDateTime'], '2099-01-05T10:30:00');
      expect(a['scheduledDateTimeISO8601'], '2099-01-05T10:30:00.000+0300');
      expect((c.last.arguments as Map)['id'], 20990106);
      final ozel = a['platformSpecifics'] as Map;
      expect(ozel['scheduleMode'], 'inexactAllowWhileIdle');
      expect(ozel['channelId'], 'gunluk_menu');
      expect(ozel['channelName'], 'Günlük menü');
      expect(ozel['icon'], 'ic_bildirim');
    });

    test('uzun metin genişleyince tam görünsün: BigText stili', () async {
      await servis().planla([_bildirim(5)]);
      final ozel = (kanal.yontem('zonedSchedule').single.arguments
          as Map)['platformSpecifics'] as Map;
      expect(ozel['style'], AndroidNotificationStyle.bigText.index);
      expect(ozel['styleInformation'], isA<Map>());
    });

    test('geçmiş zamanlı bildirim eklentiye gitmez', () async {
      // şimdi 5 Ocak 09:00 Türkiye: 4 Ocak 10:30 ve 5 Ocak 08:00 geçmiş, 5 Ocak 10:30 gelecek
      await servis().planla([
        _bildirim(4),
        _bildirim(5, saat: 8, dakika: 0),
        _bildirim(5),
      ]);
      final c = kanal.yontem('zonedSchedule');
      expect(c.length, 1);
      expect((c.single.arguments as Map)['scheduledDateTime'],
          '2099-01-05T10:30:00');
    });

    test('boş liste eklentiyi başlatmaz bile', () async {
      await servis().planla(const []);
      expect(kanal.cagrilar, isEmpty);
    });

    test('tek bildirimin hatası diğerlerini düşürmez', () async {
      kanal.planHata = true;
      await servis().planla([_bildirim(5), _bildirim(6)]);
      expect(kanal.yontem('zonedSchedule').length, 2,
          reason: 'ikisi de denendi, istisna dışarı çıkmadı');
    });

    test('hepsiniIptal yalnızca kurulmuş bildirimleri iptal eder', () async {
      await servis().hepsiniIptal();
      expect(kanal.yontem('cancelAllPendingNotifications').length, 1);
      expect(kanal.yontem('cancelAll'), isEmpty,
          reason: 'bildirim çekmecesindekilere dokunulmaz');
    });

    test('Istanbul zamanı: duvar saati Türkiye saati olarak yorumlanır', () {
      final z = istanbulZamani(DateTime.utc(2026, 11, 2, 10, 30));
      expect(z.location.name, 'Europe/Istanbul');
      expect(z.timeZoneOffset, const Duration(hours: 3));
      expect(z.toUtc(), DateTime.utc(2026, 11, 2, 7, 30));
      // Türkiye'de yaz saati yok: yazın da kışın da UTC+3
      expect(istanbulZamani(DateTime.utc(2026, 7, 15, 10, 30)).toUtc(),
          DateTime.utc(2026, 7, 15, 7, 30));
      expect(istanbulZamani(DateTime.utc(2027, 1, 15, 10, 30)).toUtc(),
          DateTime.utc(2027, 1, 15, 7, 30));
      expect(bildirimZamanDilimi, 'Europe/Istanbul');
    });

    test('PlanliBildirim.utcAn ile Istanbul zamanı aynı anı verir', () {
      final b = _bildirim(5);
      expect(istanbulZamani(b.zaman).toUtc(), b.utcAn);
    });
  });
}
