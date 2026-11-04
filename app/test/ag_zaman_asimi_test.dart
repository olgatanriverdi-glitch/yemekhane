// Bulgu 7: yükleme zaman aşımı. Bu dosya Depo'ya eklenecek `agZamanAsimi` parametresini kullanır
// (düzeltmeden önce derlenmez).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/repository.dart';

void main() {
  TestWidgetsFlutterBinding
      .ensureInitialized(); // rootBundle (paket verisi) için
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ağ yanıt vermezse kısa zaman aşımından sonra paket verisine düşülür',
      () async {
    final kapi = Completer<http.Response>();
    final depo = Depo(
        istemci: MockClient((r) => kapi.future),
        agZamanAsimi: const Duration(milliseconds: 50));
    final sw = Stopwatch()..start();
    final menu = await depo.menu('ankara');
    sw.stop();
    expect(menu.tarihler, isNotEmpty);
    expect(depo.cevrimdisi, isTrue);
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
  });
}
