import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'bildirim_ayari.dart';
import 'kalori_hedefi.dart';
import 'screens/home.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ayar = TemaAyari();
  final kalori = KaloriHedefi();
  final bildirim = BildirimAyari();
  // kayıtlı tema ve kalori hedefi ilk karede uygulansın (varsayılanla yanıp sönmesin); bildirim ayarı yalnızca
  // okunur, kapalıysa bildirim eklentisine hiç dokunulmaz
  await Future.wait([ayar.yukle(), kalori.yukle(), bildirim.yukle()]);
  runApp(
      YemekhaneApp(ayar: ayar, kaloriHedefi: kalori, bildirimAyari: bildirim));
}

class YemekhaneApp extends StatelessWidget {
  final TemaAyari ayar;

  /// Günlük kalori hedefi ayarı; boşsa ana sayfa kendi ayarını kurar.
  final KaloriHedefi? kaloriHedefi;

  /// Günlük menü bildirimi ayarı; boşsa ana sayfa kendi ayarını kurar.
  final BildirimAyari? bildirimAyari;

  /// Testlerde ana sayfanın yerine gösterilecek ekran (gerçek ağa / diske gitmemek için); uygulamada boştur.
  final Widget? ana;
  const YemekhaneApp(
      {super.key,
      required this.ayar,
      this.kaloriHedefi,
      this.bildirimAyari,
      this.ana});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ayar,
      builder: (context, _) => MaterialApp(
        title: 'Üni Yemek',
        debugShowCheckedModeBanner: false,
        // Türkçe: lisans sayfası, tarih / saat seçiciler ve sistem tooltip'leri (Geri, Kapat...) Türkçe gelir
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ayar.tema(Brightness.light),
        darkTheme: ayar.tema(Brightness.dark),
        themeMode: ayar.mod,
        themeAnimationDuration: const Duration(milliseconds: 300),
        themeAnimationCurve: Curves.easeOutCubic,
        builder: (context, child) => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: child)),
        ),
        home: ana ??
            AnaSayfa(
                temaAyari: ayar,
                kaloriHedefi: kaloriHedefi,
                bildirim: bildirimAyari),
      ),
    );
  }
}
