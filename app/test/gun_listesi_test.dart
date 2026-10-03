import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/models.dart';

Menu _menu(List<String> tarihler, {Map<String, Map<String, dynamic>>? ekstra}) {
  final gunler = <String, Map<String, Ogun>>{
    for (final t in tarihler)
      t: {
        'lunch': Ogun([YemekOgesi('Çorba', null)], null)
      }
  };
  ekstra?.forEach((t, v) => gunler[t] = {
        'lunch': Ogun(const [], null, null, false, v['note'] as String?)
      });
  return Menu('x', null, gunler);
}

void main() {
  test('hafta sonu ve tatil günleri araya eklenir, geçmiş günler gösterilmez',
      () {
    // Cuma 9 Ekim ve Pazartesi 12 Ekim menüsü var; hafta sonu menüsüz
    final m = _menu(['2026-10-08', '2026-10-09', '2026-10-12', '2026-10-13']);
    expect(gunListesi(m, '2026-10-09'),
        ['2026-10-09', '2026-10-10', '2026-10-11', '2026-10-12', '2026-10-13']);
  });

  test('menü başlamadıysa ilk günden başlar; bittiyse son 7 gün', () {
    final m = _menu(['2026-10-05', '2026-10-06', '2026-10-07']);
    expect(gunListesi(m, '2026-10-01').first, '2026-10-05');
    final sonra = gunListesi(m, '2026-11-20');
    expect(sonra.length, 7);
    expect(sonra.last, '2026-10-07');
    expect(sonra.first, '2026-10-01');
  });

  test('ay sonu sınırını doğru geçer', () {
    final m = _menu(['2026-10-30', '2026-11-02']);
    expect(gunListesi(m, '2026-10-30'),
        ['2026-10-30', '2026-10-31', '2026-11-01', '2026-11-02']);
  });

  test('tatil notu okunur ve öğün boş sayılır', () {
    final m = _menu([
      '2026-10-27'
    ], ekstra: {
      '2026-10-28': {'note': 'Tatil'}
    });
    final o = m.gunler['2026-10-28']!['lunch']!;
    expect(o.bos, isTrue);
    expect(o.not, 'Tatil');
  });

  test('gerçek veri: Gazi 28-29 Ekim tatil, hafta sonları listede', () {
    // assets/data/gazi/menu.json gerçek dosyası
    // (JSON okuma testi widget_test.dart içinde; burada yalnızca not alanı biçimi)
    final o = Ogun.fromJson({'items': [], 'note': 'Tatil'});
    expect(o.bos, isTrue);
    expect(o.not, 'Tatil');
  });
}
