import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz_veri;
import 'package:timezone/timezone.dart' as tz;

import 'bildirim_plani.dart';

/// Bildirim zamanlarının yorumlandığı zaman dilimi: Türkiye (UTC+3, yaz saati yok).
const bildirimZamanDilimi = 'Europe/Istanbul';

/// Günlük menü bildirimlerini cihaza kuran servis. Uygulama yalnızca bu arayüzü bilir; gerçek uygulama
/// [FlutterBildirimServisi]ni kullanır, testlerde sahtesi verilir.
abstract class BildirimServisi {
  /// Bildirim göstermek için izin ister (Android 13+ POST_NOTIFICATIONS). true: bildirim gösterilebilir.
  /// İzin verilmemişse, istek açılamıyorsa ya da platform desteklemiyorsa false.
  Future<bool> izinIste();

  /// [bildirimler]i kurar. Aynı kimlikli (aynı günün) bildirim varsa yerine geçer.
  Future<void> planla(List<PlanliBildirim> bildirimler);

  /// Kurulmuş (henüz gösterilmemiş) bütün bildirimleri iptal eder.
  Future<void> hepsiniIptal();
}

/// Günlük menü bildirimi bu platformda destekleniyor mu? Yalnızca Android ve iOS (web ve masaüstünde ayar
/// gösterilmez).
bool bildirimDesteklenir() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool _zamanDilimiHazir = false;

tz.Location _istanbul() {
  if (!_zamanDilimiHazir) {
    tz_veri.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(bildirimZamanDilimi));
    _zamanDilimiHazir = true;
  }
  return tz.getLocation(bildirimZamanDilimi);
}

/// [duvarSaati]nin yıl, ay, gün, saat ve dakika alanlarını Europe/Istanbul'daki zaman olarak yorumlar (cihazın
/// saat dilimi ne olursa olsun). [PlanliBildirim.zaman] bu biçimdedir.
tz.TZDateTime istanbulZamani(DateTime duvarSaati) => tz.TZDateTime(
    _istanbul(),
    duvarSaati.year,
    duvarSaati.month,
    duvarSaati.day,
    duvarSaati.hour,
    duvarSaati.minute);

/// `flutter_local_notifications` ile gerçek bildirimleri kuran servis (Android ve iOS).
///
/// Eklenti ve saat dilimi veritabanı yalnızca ilk kullanımda başlatılır: bildirim ayarı kapalıyken uygulama
/// açılışında hiçbir eklenti kodu çalışmaz. Tam alarm izni kullanılmaz; bildirimler "yaklaşık" zamanlanır
/// (`inexactAllowWhileIdle`), saat birkaç dakika kayabilir. Cihazda denenmemiştir.
class FlutterBildirimServisi implements BildirimServisi {
  /// [simdi] yalnızca "geçmiş saati atla" denetimi içindir (testlerde sabit saat); boşsa [DateTime.now].
  FlutterBildirimServisi({DateTime Function()? simdi})
      : _simdi = simdi ?? DateTime.now;

  final DateTime Function() _simdi;

  static const _kanalKimligi = 'gunluk_menu';
  static const _simge =
      'ic_bildirim'; // android/app/src/main/res/drawable/ic_bildirim.xml

  Future<FlutterLocalNotificationsPlugin>? _eklenti;

  /// Eklentiyi ilk çağrıda başlatır ve sonrakilerde aynı işlemi döndürür; başlatma başarısız olursa bir
  /// sonraki çağrı yeniden dener.
  Future<FlutterLocalNotificationsPlugin> _hazirla() {
    final mevcut = _eklenti;
    if (mevcut != null) return mevcut;
    final yeni = _baslat();
    _eklenti = yeni;
    yeni.then((_) {}, onError: (Object _) {
      if (identical(_eklenti, yeni)) _eklenti = null;
    });
    return yeni;
  }

  Future<FlutterLocalNotificationsPlugin> _baslat() async {
    _istanbul();
    final eklenti = FlutterLocalNotificationsPlugin();
    await eklenti.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings(_simge),
            // izin, "Bildirim" anahtarı açılırken izinIste ile istenir; başlatma izin penceresi açmasın
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false)));
    return eklenti;
  }

  @override
  Future<bool> izinIste() async {
    try {
      final eklenti = await _hazirla();
      final android = eklenti.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = eklenti.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> planla(List<PlanliBildirim> bildirimler) async {
    if (bildirimler.isEmpty) return;
    final eklenti = await _hazirla();
    final su = _simdi();
    for (final b in bildirimler) {
      final zaman = istanbulZamani(b.zaman);
      // eklenti geçmiş zamanı reddeder; planlama sırasında geçen an da geçmiş sayılır
      if (!zaman.isAfter(su)) continue;
      try {
        await eklenti.zonedSchedule(
            id: b.kimlik,
            scheduledDate: zaman,
            notificationDetails: _ayrintilar(b.metin),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: b.baslik,
            body: b.metin);
      } catch (_) {
        // tek bir bildirimin hatası diğerlerinin kurulmasını engellemesin
      }
    }
  }

  @override
  Future<void> hepsiniIptal() async {
    final eklenti = await _hazirla();
    // yalnızca kurulmuş olanlar: bildirim çekmecesinde duran bir bildirime dokunulmaz
    await eklenti.cancelAllPendingNotifications();
  }

  /// Uzun yemek listesi genişletilince tam görünsün diye BigText stili.
  static NotificationDetails _ayrintilar(String metin) => NotificationDetails(
        android: AndroidNotificationDetails(_kanalKimligi, 'Günlük menü',
            channelDescription: 'Günün menüsünü seçtiğin saatte bildirir.',
            icon: _simge,
            styleInformation: BigTextStyleInformation(metin)),
        iOS: const DarwinNotificationDetails(),
      );
}
