import 'package:flutter/material.dart';

/// Öğün türü -> ekranda görünen ad.
const ogunAdlari = {
  'breakfast': 'Kahvaltı',
  'lunch': 'Öğle',
  'dinner': 'Akşam',
  'vegetarian': 'Vejetaryen'
};

/// Öğün türü -> sekme simgesi.
const ogunIkon = {
  'breakfast': Icons.free_breakfast_outlined,
  'lunch': Icons.wb_sunny_outlined,
  'dinner': Icons.nights_stay_outlined,
  'vegetarian': Icons.eco_outlined
};

/// Öğün sekmeleri (Kahvaltı / Öğle / Akşam / Vejetaryen). [turler] okulun sunduğu öğünler,
/// [aktif] seçili olanı. Simge yalnızca en çok 3 sekmede ve en uzun etiketle birlikte sığıyorsa gösterilir;
/// sığmayan simgeli etiket (örn. 320 dp'de "Vejetaryen") okunmayacak kadar küçülürdü, bu yüzden simge atılır.
class OgunSecici extends StatelessWidget {
  final List<String> turler;
  final String aktif;
  final ValueChanged<String> degisti;
  const OgunSecici(
      {super.key,
      required this.turler,
      required this.aktif,
      required this.degisti});

  // simgeli bir segmentin etiket dışı genişliği: simge (18) + boşluk (8) + yatay dolgu (4 + 4)
  static const _simgeliPay = 34.0;

  /// Her segment [segmentGenisligi] dp ise simgeler etiketlerle birlikte sığar mı? Etiket ölçüsü gerçek yazı
  /// stiliyle ve kullanıcının yazı ölçeğiyle hesaplanır.
  bool simgeSigar(BuildContext context, double segmentGenisligi) {
    if (turler.length > 3) return false;
    final stil = Theme.of(context).textTheme.labelLarge;
    final olcek = MediaQuery.textScalerOf(context);
    var enUzun = 0.0;
    for (final t in turler) {
      final olcer = TextPainter(
          text: TextSpan(text: ogunAdlari[t] ?? t, style: stil),
          textDirection: TextDirection.ltr,
          textScaler: olcek,
          maxLines: 1)
        ..layout();
      if (olcer.width > enUzun) enUzun = olcer.width;
      olcer.dispose();
    }
    return enUzun + _simgeliPay <= segmentGenisligi;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: LayoutBuilder(builder: (context, kisit) {
        final simgeli = simgeSigar(context, kisit.maxWidth / turler.length);
        return SegmentedButton<String>(
          segments: [
            for (final t in turler)
              ButtonSegment(
                  value: t,
                  label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(ogunAdlari[t] ?? t, maxLines: 1)),
                  icon: simgeli ? Icon(ogunIkon[t], size: 18) : null)
          ],
          selected: {aktif},
          showSelectedIcon: false,
          // simge atılınca segmentler içeriğe göre daralıp ortada kalmasın: tam genişliğe eşit paylaşılır
          expandedInsets: simgeli ? null : EdgeInsets.zero,
          // standart yoğunluk + dolgulu hedef: segmentler görsel olarak 40 dp, dokunma hedefi 48 dp olur
          // (masaüstü / web varsayılanı "compact" 40 dp bırakırdı)
          style: const ButtonStyle(
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.padded,
              padding:
                  WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4))),
          onSelectionChanged: (s) => degisti(s.first),
        );
      }),
    );
  }
}
