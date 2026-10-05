import 'package:flutter/material.dart';

import 'screens/home.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ayar = TemaAyari();
  await ayar
      .yukle(); // kayıtlı tema ilk karede uygulansın (varsayılan renkle yanıp sönmesin)
  runApp(YemekhaneApp(ayar: ayar));
}

class YemekhaneApp extends StatelessWidget {
  final TemaAyari ayar;
  const YemekhaneApp({super.key, required this.ayar});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ayar,
      builder: (context, _) => MaterialApp(
        title: 'Üni Yemek',
        debugShowCheckedModeBanner: false,
        theme: ayar.tema(Brightness.light),
        darkTheme: ayar.tema(Brightness.dark),
        themeMode: ayar.mod,
        builder: (context, child) => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: child)),
        ),
        home: AnaSayfa(temaAyari: ayar),
      ),
    );
  }
}
