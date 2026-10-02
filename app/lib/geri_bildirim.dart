import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_config.dart';

/// Bir öğünün (üniversite + tarih + öğün türü) kimliği: 'ankara_2026-10-02_lunch'
String slotKimligi(String uni, String tarih, String ogun) =>
    '${uni}_${tarih}_$ogun';

class PuanOzeti {
  final double? ortalama;
  final int adet;
  const PuanOzeti(this.ortalama, this.adet);
}

class Yorum {
  final String id, uid, ad, metin;
  final DateTime zaman;
  Yorum(this.id, this.uid, this.ad, this.metin, this.zaman);
}

/// Puan ve yorum deposu. Firebase ayarı yoksa cihazda saklayan yerel sürüm kullanılır (önizleme / çevrimdışı deneme).
abstract class GeriBildirimDeposu {
  bool get cevrimici;
  Future<String> kullaniciId();
  Future<PuanOzeti> puanOzeti(String slot);
  Future<int?> benimPuanim(String slot);
  Future<void> puanVer(String slot, int yildiz);
  Future<List<Yorum>> yorumlar(String slot);
  Future<void> yorumEkle(String slot, String ad, String metin);
  Future<void> yorumSil(Yorum y);

  static GeriBildirimDeposu olustur({http.Client? istemci}) {
    if (firebaseProjeId.isEmpty || firebaseApiAnahtari.isEmpty) {
      return YerelDepo();
    }
    return FirestoreDepo(
        firebaseProjeId, firebaseApiAnahtari, istemci ?? http.Client());
  }
}

// ---------------------------------------------------------------------------------------------------------------
class YerelDepo implements GeriBildirimDeposu {
  @override
  bool get cevrimici => false;

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  @override
  Future<String> kullaniciId() async {
    final p = await _p;
    var id = p.getString('yerel_uid');
    if (id == null) {
      id = 'yerel${Random().nextInt(1 << 31)}';
      await p.setString('yerel_uid', id);
    }
    return id;
  }

  @override
  Future<PuanOzeti> puanOzeti(String slot) async {
    final p = await _p;
    final v = p.getInt('yp/$slot');
    return v == null ? const PuanOzeti(null, 0) : PuanOzeti(v.toDouble(), 1);
  }

  @override
  Future<int?> benimPuanim(String slot) async => (await _p).getInt('yp/$slot');

  @override
  Future<void> puanVer(String slot, int yildiz) async =>
      (await _p).setInt('yp/$slot', yildiz);

  @override
  Future<List<Yorum>> yorumlar(String slot) async {
    final p = await _p;
    final liste = (p.getStringList('yy/$slot') ?? [])
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
    final uid = await kullaniciId();
    return [
      for (final m in liste)
        Yorum(m['id'] as String, uid, m['ad'] as String, m['metin'] as String,
            DateTime.parse(m['zaman'] as String))
    ]..sort((a, b) => b.zaman.compareTo(a.zaman));
  }

  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async {
    final p = await _p;
    final l = p.getStringList('yy/$slot') ?? [];
    l.add(jsonEncode({
      'id': '${DateTime.now().microsecondsSinceEpoch}',
      'ad': ad,
      'metin': metin,
      'zaman': DateTime.now().toIso8601String()
    }));
    await p.setStringList('yy/$slot', l);
  }

  @override
  Future<void> yorumSil(Yorum y) async {
    final p = await _p;
    for (final k in p.getKeys().where((k) => k.startsWith('yy/')).toList()) {
      final l = p.getStringList(k) ?? [];
      final yeni = l
          .where((e) => (jsonDecode(e) as Map<String, dynamic>)['id'] != y.id)
          .toList();
      if (yeni.length != l.length) await p.setStringList(k, yeni);
    }
  }
}

// ---------------------------------------------------------------------------------------------------------------
/// Firestore'a doğrudan REST ile bağlanır (SDK gerekmez; web, iOS ve Android'de aynı kod). Kimlik: Firebase anonim giriş.
class FirestoreDepo implements GeriBildirimDeposu {
  final String proje, anahtar;
  final http.Client _c;
  FirestoreDepo(this.proje, this.anahtar, this._c);

  String? _token, _yenile, _uid;
  DateTime _bitis = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  bool get cevrimici => true;

  String get _kok =>
      'https://firestore.googleapis.com/v1/projects/$proje/databases/(default)/documents';

  Future<void> _oturum() async {
    final p = await SharedPreferences.getInstance();
    _yenile ??= p.getString('fb_yenile');
    _uid ??= p.getString('fb_uid');
    if (_token != null &&
        DateTime.now().isBefore(_bitis.subtract(const Duration(minutes: 2)))) {
      return;
    }
    if (_yenile != null) {
      final r = await _c.post(
          Uri.parse('https://securetoken.googleapis.com/v1/token?key=$anahtar'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'grant_type=refresh_token&refresh_token=$_yenile');
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        _token = j['id_token'] as String;
        _yenile = j['refresh_token'] as String;
        _uid = j['user_id'] as String;
        _bitis = DateTime.now()
            .add(Duration(seconds: int.parse('${j['expires_in']}')));
        await p.setString('fb_yenile', _yenile!);
        await p.setString('fb_uid', _uid!);
        return;
      }
    }
    final r = await _c.post(
        Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$anahtar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'returnSecureToken': true}));
    if (r.statusCode != 200) {
      throw Exception('Anonim giriş başarısız (${r.statusCode})');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    _token = j['idToken'] as String;
    _yenile = j['refreshToken'] as String;
    _uid = j['localId'] as String;
    _bitis =
        DateTime.now().add(Duration(seconds: int.parse('${j['expiresIn']}')));
    await p.setString('fb_yenile', _yenile!);
    await p.setString('fb_uid', _uid!);
  }

  Future<Map<String, String>> _baslik() async {
    await _oturum();
    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json'
    };
  }

  @override
  Future<String> kullaniciId() async {
    await _oturum();
    return _uid!;
  }

  Map<String, dynamic> _slotSorgusu(String koleksiyon, String slot,
          {int? limit}) =>
      {
        'from': [
          {'collectionId': koleksiyon}
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'slot'},
            'op': 'EQUAL',
            'value': {'stringValue': slot}
          }
        },
        if (limit != null) 'limit': limit,
      };

  @override
  Future<PuanOzeti> puanOzeti(String slot) async {
    final r = await _c.post(Uri.parse('$_kok:runAggregationQuery'),
        headers: await _baslik(),
        body: jsonEncode({
          'structuredAggregationQuery': {
            'structuredQuery': _slotSorgusu('ratings', slot),
            'aggregations': [
              {'alias': 'n', 'count': {}},
              {
                'alias': 'ort',
                'avg': {
                  'field': {'fieldPath': 'stars'}
                }
              },
            ],
          }
        }));
    if (r.statusCode == 400 || r.statusCode == 412) {
      return _puanOzetiYedek(
          slot); // bileşik dizin henüz yok: ortalamayı uygulamada hesapla
    }
    if (r.statusCode != 200) {
      throw Exception('Puan okunamadı (${r.statusCode})');
    }
    final liste = jsonDecode(r.body) as List;
    final f = (liste.first as Map<String, dynamic>)['result']
        ?['aggregateFields'] as Map<String, dynamic>?;
    if (f == null) return const PuanOzeti(null, 0);
    final n = int.tryParse('${f['n']?['integerValue'] ?? 0}') ?? 0;
    final ort = f['ort'];
    final d = ort == null ? null : (ort['doubleValue'] ?? ort['integerValue']);
    return PuanOzeti(n == 0 || d == null ? null : double.parse('$d'), n);
  }

  /// Dizin gerektirmeyen yedek: öğünün puanlarını (en fazla 1000) çekip ortalamasını hesaplar.
  Future<PuanOzeti> _puanOzetiYedek(String slot) async {
    final r = await _c.post(Uri.parse('$_kok:runQuery'),
        headers: await _baslik(),
        body: jsonEncode(
            {'structuredQuery': _slotSorgusu('ratings', slot, limit: 1000)}));
    if (r.statusCode != 200) {
      throw Exception('Puan okunamadı (${r.statusCode})');
    }
    var toplam = 0, adet = 0;
    for (final e in jsonDecode(r.body) as List) {
      final f = (e as Map<String, dynamic>)['document']?['fields']
          as Map<String, dynamic>?;
      final v = f?['stars']?['integerValue'];
      if (v != null) {
        toplam += int.parse('$v');
        adet++;
      }
    }
    return adet == 0
        ? const PuanOzeti(null, 0)
        : PuanOzeti(toplam / adet, adet);
  }

  @override
  Future<int?> benimPuanim(String slot) async {
    final uid = await kullaniciId();
    final r = await _c.get(Uri.parse('$_kok/ratings/${slot}_$uid'),
        headers: await _baslik());
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) {
      throw Exception('Puan okunamadı (${r.statusCode})');
    }
    final v = (jsonDecode(r.body) as Map<String, dynamic>)['fields']?['stars']
        ?['integerValue'];
    return v == null ? null : int.parse('$v');
  }

  @override
  Future<void> puanVer(String slot, int yildiz) async {
    final uid = await kullaniciId();
    final r = await _c.patch(Uri.parse('$_kok/ratings/${slot}_$uid'),
        headers: await _baslik(),
        body: jsonEncode({
          'fields': {
            'uid': {'stringValue': uid},
            'slot': {'stringValue': slot},
            'stars': {'integerValue': '$yildiz'},
            'updatedAt': {
              'timestampValue': DateTime.now().toUtc().toIso8601String()
            },
          }
        }));
    if (r.statusCode != 200) {
      throw Exception('Puan kaydedilemedi (${r.statusCode})');
    }
  }

  @override
  Future<List<Yorum>> yorumlar(String slot) async {
    final r = await _c.post(Uri.parse('$_kok:runQuery'),
        headers: await _baslik(),
        body: jsonEncode(
            {'structuredQuery': _slotSorgusu('comments', slot, limit: 100)}));
    if (r.statusCode != 200) {
      throw Exception('Yorumlar okunamadı (${r.statusCode})');
    }
    final sonuc = <Yorum>[];
    for (final e in jsonDecode(r.body) as List) {
      final d =
          (e as Map<String, dynamic>)['document'] as Map<String, dynamic>?;
      if (d == null) continue;
      final f = d['fields'] as Map<String, dynamic>;
      sonuc.add(Yorum(
          (d['name'] as String).split('/').last,
          f['uid']['stringValue'] as String,
          (f['name']?['stringValue'] ?? 'Anonim') as String,
          f['text']['stringValue'] as String,
          DateTime.parse(f['createdAt']['timestampValue'] as String)
              .toLocal()));
    }
    sonuc.sort((a, b) => b.zaman.compareTo(a.zaman));
    return sonuc;
  }

  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async {
    final uid = await kullaniciId();
    final r = await _c.post(Uri.parse('$_kok/comments'),
        headers: await _baslik(),
        body: jsonEncode({
          'fields': {
            'uid': {'stringValue': uid},
            'slot': {'stringValue': slot},
            'name': {'stringValue': ad},
            'text': {'stringValue': metin},
            'createdAt': {
              'timestampValue': DateTime.now().toUtc().toIso8601String()
            },
          }
        }));
    if (r.statusCode != 200) {
      throw Exception('Yorum gönderilemedi (${r.statusCode})');
    }
  }

  @override
  Future<void> yorumSil(Yorum y) async {
    final r = await _c.delete(Uri.parse('$_kok/comments/${y.id}'),
        headers: await _baslik());
    if (r.statusCode != 200) {
      throw Exception('Yorum silinemedi (${r.statusCode})');
    }
  }
}
