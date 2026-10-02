import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('yerel depo: puan ve yorum', () async {
    final d = YerelDepo();
    expect(d.cevrimici, false);
    expect((await d.puanOzeti('s')).adet, 0);
    await d.puanVer('s', 4);
    expect(await d.benimPuanim('s'), 4);
    expect((await d.puanOzeti('s')).ortalama, 4.0);
    await d.yorumEkle('s', 'Ali', 'Güzeldi');
    await d.yorumEkle('s', 'Ayşe', 'Tuzsuz');
    final l = await d.yorumlar('s');
    expect(l.length, 2);
    expect(l.first.ad, 'Ayşe'); // en yeni üstte
    await d.yorumSil(l.first);
    expect((await d.yorumlar('s')).length, 1);
  });

  test('firestore depo: dizin yoksa ortalama yedekle hesaplanır', () async {
    final istemci = MockClient((r) async {
      final u = r.url.toString();
      if (u.contains('accounts:signUp')) {
        return http.Response(
            jsonEncode({
              'idToken': 'T',
              'refreshToken': 'R',
              'localId': 'U1',
              'expiresIn': '3600'
            }),
            200);
      }
      if (u.contains(':runAggregationQuery')) {
        return http.Response('{"error":{"status":"FAILED_PRECONDITION"}}', 400);
      }
      if (u.contains(':runQuery')) {
        Map d(int s) => {
              'document': {
                'name': 'x/y/z',
                'fields': {
                  'stars': {'integerValue': '$s'}
                }
              }
            };
        return http.Response(
            jsonEncode([
              d(5),
              d(4),
              d(3),
              {'readTime': 'x'}
            ]),
            200);
      }
      return http.Response('{}', 200);
    });
    final o = await FirestoreDepo('p', 'K', istemci).puanOzeti('s');
    expect(o.adet, 3);
    expect(o.ortalama, 4.0);
  });

  test('firestore depo: giriş, puan, yorum (sahte sunucu)', () async {
    final istekler = <String>[];
    final istemci = MockClient((r) async {
      istekler.add(
          '${r.method} ${r.url.path}${r.url.path.contains(':') ? '' : ''}');
      final u = r.url.toString();
      if (u.contains('accounts:signUp')) {
        return http.Response(
            jsonEncode({
              'idToken': 'T',
              'refreshToken': 'R',
              'localId': 'U1',
              'expiresIn': '3600'
            }),
            200);
      }
      expect(r.headers['Authorization'], 'Bearer T');
      if (u.contains(':runAggregationQuery')) {
        return http.Response(
            jsonEncode([
              {
                'result': {
                  'aggregateFields': {
                    'n': {'integerValue': '3'},
                    'ort': {'doubleValue': 4.333}
                  }
                }
              }
            ]),
            200);
      }
      if (u.contains(':runQuery')) {
        return http.Response(
            jsonEncode([
              {
                'document': {
                  'name':
                      'projects/p/databases/(default)/documents/comments/C1',
                  'fields': {
                    'uid': {'stringValue': 'U1'},
                    'name': {'stringValue': 'Ali'},
                    'text': {'stringValue': 'Harika'},
                    'createdAt': {'timestampValue': '2026-10-02T10:00:00Z'}
                  }
                }
              },
              {'readTime': '2026-10-02T10:00:01Z'}
            ]),
            200);
      }
      if (u.contains('/ratings/') && r.method == 'GET') {
        return http.Response('{}', 404);
      }
      if (r.method == 'PATCH') {
        final f = (jsonDecode(r.body) as Map)['fields'] as Map;
        expect(f['stars']['integerValue'], '5');
        expect(f['uid']['stringValue'], 'U1');
        expect(u.contains('/ratings/s_U1'), true);
        return http.Response('{}', 200);
      }
      if (r.method == 'POST' && u.endsWith('/comments')) {
        final f = (jsonDecode(r.body) as Map)['fields'] as Map;
        expect(f['text']['stringValue'], 'Merhaba');
        return http.Response('{}', 200);
      }
      return http.Response('{}', 200);
    });
    final d = FirestoreDepo('p', 'K', istemci);
    expect(await d.kullaniciId(), 'U1');
    final o = await d.puanOzeti('s');
    expect(o.adet, 3);
    expect(o.ortalama, closeTo(4.333, 0.001));
    expect(await d.benimPuanim('s'), isNull);
    await d.puanVer('s', 5);
    final y = await d.yorumlar('s');
    expect(y.length, 1);
    expect(y.first.id, 'C1');
    expect(y.first.ad, 'Ali');
    await d.yorumEkle('s', 'Ali', 'Merhaba');
    expect(
        istekler.where((e) => e.contains('signUp')).length, 1); // tek kez giriş
  });
}
