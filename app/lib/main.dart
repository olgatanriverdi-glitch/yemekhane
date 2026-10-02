import 'package:flutter/material.dart';

import 'screens/home.dart';

void main() => runApp(const YemekhaneApp());

class YemekhaneApp extends StatelessWidget {
  const YemekhaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData tema(Brightness b) => ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8892B), brightness: b),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        );
    return MaterialApp(
      title: 'Yemekhane',
      debugShowCheckedModeBanner: false,
      theme: tema(Brightness.light),
      darkTheme: tema(Brightness.dark),
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child)),
      ),
      home: const AnaSayfa(),
    );
  }
}
