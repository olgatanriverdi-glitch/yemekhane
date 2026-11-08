// Yorum gönderim öncesi yerel süzgeç: küfür / hakaret ve bağlantı reddedilir; masum kelimeler (sikke, şikayet, sık sık,
// sıkıntı...) aşırıya kaçmadan geçer.
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/yorum_filtresi.dart';

void main() {
  group('uygunsuz ifade', () {
    for (final metin in [
      'siktir git',
      'SİKTİR',
      'siiiiktir',
      's i k t i r',
      's.i.k.t.i.r',
      's1ktir',
      'sik',
      'SİK',
      'siiik',
      'amk',
      'AMK',
      'a m k',
      '@mk',
      'aq',
      'yarrak gibi yemek',
      'yaaarrak',
      'orospu çocuğu',
      'orospuluk bu',
      'o r o s p u',
      'pezevenk',
      'piç',
      'ibne',
      'götveren',
      'aminakoyim',
      'amına koyayım',
      'aptal aşçılar',
      'Salak gibi bir yemek',
      'şerefsiz',
      'sikeyim böyle yemeği',
      'Yemek çok kötüydü, siktir.',
    ]) {
      test('reddedilir: $metin', () {
        expect(yorumSorunu(metin), YorumSorunu.uygunsuz);
      });
    }
  });

  group('masum kelimeler geçer', () {
    for (final metin in [
      'sikke',
      'sikkeli madeni para',
      'şikayet ediyorum',
      'Şikâyet',
      'sık sık geliyorum',
      'SIK SIK',
      'sık',
      'sıkıldım',
      'sıkıntı yok',
      'sıkı bir menü',
      'sıkıcıydı',
      'Amina',
      'amin',
      'Çorba tuzsuzdu ama pilav güzeldi.',
      'Yemekler sıcak ve lezzetliydi',
      'Mantı çok iyiydi, porsiyon az',
      'Ankara Üniversitesi yemekhanesi',
      'Kasım ayında menü değişti',
      'mal gibi kalabalık',
      'Fiyat 50 ₺, 2.5 saat bekledim',
      'a b',
      'siyah',
      'Aksam yemegi',
      'kalite',
      'Pazartesi öğle',
    ]) {
      test('geçer: $metin', () {
        expect(yorumSorunu(metin), isNull);
      });
    }
  });

  group('bağlantı', () {
    for (final metin in [
      'bak http://ornek.com/menu',
      'https://ornek.org',
      'www.ornek.com',
      'WWW.ORNEK.COM',
      'yemek.com güzel',
      'site.com.tr var',
      'kanalım t.me',
      'http : // ornek',
    ]) {
      test('reddedilir: $metin', () {
        expect(yorumSorunu(metin), YorumSorunu.baglanti);
      });
    }

    test('düz cümle ve ondalık sayı bağlantı sayılmaz', () {
      expect(yorumSorunu('Güzeldi. Çok güzeldi.'), isNull);
      expect(yorumSorunu('3.5 puan veririm'), isNull);
    });
  });

  test('ret metinleri', () {
    expect(YorumSorunu.uygunsuz.mesaj, 'Yorumun uygunsuz ifade içeriyor.');
    expect(YorumSorunu.baglanti.mesaj, isNotEmpty);
  });

  test('bağlantı, uygunsuz ifadeden önce bildirilir', () {
    expect(yorumSorunu('siktir www.ornek.com'), YorumSorunu.baglanti);
  });
}
