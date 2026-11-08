import 'package:flutter/material.dart';

import 'reklam_servisi.dart';
import 'reklam_yoneticisi.dart';

/// "Reklamsız gün": açıklama diyaloğu, ödüllü reklam, sonuç iletisi. Ödül yalnızca izleme tamamlanınca verilir
/// ([ReklamYoneticisi.odulluIzle]); vazgeçince ya da ödül gelmeden kapatılınca hiçbir şey değişmez.
/// Ayarlar'daki satır ve reklam kartındaki düğme bunu kullanır.
Future<void> reklamsizGunIste(BuildContext context, ReklamYoneticisi y) async {
  final mesaj = ScaffoldMessenger.maybeOf(context);
  final gezgin = Navigator.of(context, rootNavigator: true);
  final onay = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Reklamları 24 saat kapat'),
      content: const Text(
          'Kısa bir reklam izle, 24 saat boyunca uygulamada reklam görme.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('İzle')),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  // reklam hazırlanırken (en çok 20 sn) bekleme göstergesi; çift dokunuş engellenir
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (c) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(width: 16),
          Expanded(child: Text('Reklam hazırlanıyor')),
        ]),
      ),
    ),
  );
  final sonuc = await y.odulluIzle();
  if (gezgin.mounted) gezgin.pop();
  switch (sonuc) {
    case OdulluSonuc.odul:
      mesaj
        ?..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Reklamlar 24 saat kapalı.')));
    case OdulluSonuc.yuklenemedi:
      mesaj
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Şu an reklam yok, sonra tekrar dene.')));
    case OdulluSonuc.kapatildi:
      break;
  }
}

/// Ayarlar'da gösterilen kalan süre: "Reklamsız: 14:30'a kadar" (ertesi güne taşıyorsa "yarın 14:30'a kadar").
String reklamsizKalanMetni(DateTime bitis, DateTime simdi) {
  final s = bitis.hour.toString().padLeft(2, '0');
  final d = bitis.minute.toString().padLeft(2, '0');
  final ayniGun = bitis.year == simdi.year &&
      bitis.month == simdi.month &&
      bitis.day == simdi.day;
  // yönelme eki saatin okunuşuna uyar: "14:30'a", "12:12'ye", "06:00'ya", "09:05'e"
  final ek = _yonelmeEki(bitis.minute == 0 ? bitis.hour : bitis.minute);
  return "Reklamsız: ${ayniGun ? '' : 'yarın '}$s:$d'$ek kadar";
}

const _birlerYonelme = {
  1: 'e',
  2: 'ye',
  3: 'e',
  4: 'e',
  5: 'e',
  6: 'ya',
  7: 'ye',
  8: 'e',
  9: 'a'
};
const _onlarYonelme = {1: 'a', 2: 'ye', 3: 'a', 4: 'a', 5: 'ye'};

/// Sayının okunuşunun son sözcüğüne göre yönelme (-e hâli) eki: 0 "sıfır"a, 12 "on iki"ye, 20 "yirmi"ye.
String _yonelmeEki(int n) => n == 0
    ? 'a'
    : n % 10 != 0
        ? _birlerYonelme[n % 10]!
        : (_onlarYonelme[n ~/ 10] ?? 'a');
