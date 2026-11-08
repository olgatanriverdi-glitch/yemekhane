import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_config.dart';

/// Bir öğünün (üniversite + tarih + öğün türü) kimliği: 'ankara_2026-10-02_lunch'
String slotKimligi(String uni, String tarih, String ogun) =>
    '${uni}_${tarih}_$ogun';

/// Bir yemeğin (üniversite + yemek anahtarı) kimliği: 'y_ankara_3fa9c01b2e'. Puanlar yemek bazlıdır, tarihten bağımsızdır.
String yemekSlotKimligi(String uni, String anahtar) => 'y_${uni}_$anahtar';

/// Birden çok yemeğin puan özeti ve kullanıcının kendi puanları (slot -> değer).
class YemekPuanlari {
  final Map<String, PuanOzeti> ozet;
  final Map<String, int> benim;
  const YemekPuanlari(this.ozet, this.benim);
}

class PuanOzeti {
  final double? ortalama;
  final int adet;
  const PuanOzeti(this.ortalama, this.adet);
}

class Yorum {
  final String id, uid, ad, metin;
  final DateTime zaman;

  /// Yorumun ait olduğu öğün / yemek kimliği (bildirirken gönderilir); bilinmiyorsa boş.
  final String slot;
  Yorum(this.id, this.uid, this.ad, this.metin, this.zaman, {this.slot = ''});
}

/// Şikâyete kopyalanan yorum metninin en çok uzunluğu (yorum sınırıyla aynı).
const bildirimMetinSiniri = 300;

/// Bir yorumu bildirirken seçilen neden. [kod] Firestore'a yazılır (firestore.rules'taki liste ile aynı olmalı).
enum YorumBildirimNedeni {
  hakaret('hakaret', 'Hakaret / küfür'),
  spam('spam', 'Spam'),
  uygunsuz('uygunsuz', 'Uygunsuz içerik'),
  diger('diger', 'Diğer');

  final String kod, etiket;
  const YorumBildirimNedeni(this.kod, this.etiket);
}

/// Puan ve yorum deposu. Firebase ayarı yoksa cihazda saklayan yerel sürüm kullanılır (önizleme / çevrimdışı deneme).
abstract class GeriBildirimDeposu {
  bool get cevrimici;
  Future<String> kullaniciId();
  Future<PuanOzeti> puanOzeti(String slot);
  Future<int?> benimPuanim(String slot);
  Future<YemekPuanlari> puanlar(List<String> slotlar);
  Future<void> puanVer(String slot, int yildiz);
  Future<List<Yorum>> yorumlar(String slot);
  Future<void> yorumEkle(String slot, String ad, String metin);
  Future<void> yorumSil(Yorum y);

  /// Başkasının yorumunu moderasyon için bildirir (Firestore'da `reports` koleksiyonuna yazılır). Hata fırlatabilir.
  Future<void> yorumBildir(Yorum y, YorumBildirimNedeni neden);

  /// Kullanıcının kendi yorum ve puanlarını siler, anonim hesabı kapatır ve bu cihazdaki oturum kayıtlarını
  /// temizler. Hata fırlatabilir (ağ, kural reddi...); o durumda yerel oturum bozulmaz, işlem yeniden denenebilir.
  Future<void> verilerimiSil();

  /// Uygulamanın kullandığı depo: gerçek depo (Firebase ayarı yoksa [YerelDepo], varsa [FirestoreDepo]) her durumda
  /// [OnbellekliGeriBildirim] ile sarılır; okuma kotası aynı sorgularla boşa harcanmasın.
  static GeriBildirimDeposu olustur({http.Client? istemci}) {
    final GeriBildirimDeposu depo =
        firebaseProjeId.isEmpty || firebaseApiAnahtari.isEmpty
            ? YerelDepo()
            : FirestoreDepo(
                firebaseProjeId, firebaseApiAnahtari, istemci ?? http.Client());
    return OnbellekliGeriBildirim(depo);
  }
}

/// Depo [OnbellekliGeriBildirim] ise önbelleğini boşaltır, değilse (örn. testlerdeki sahte depolar) hiçbir şey yapmaz.
/// Ana sayfa, kullanıcı yenilemek istediğinde (aşağı çekme, Yenile) çağırır: en güncel puan ve yorumlar okunsun.
extension GeriBildirimOnbellegi on GeriBildirimDeposu {
  void onbellekTemizle() {
    final depo = this;
    if (depo is OnbellekliGeriBildirim) depo.temizle();
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
  Future<YemekPuanlari> puanlar(List<String> slotlar) async {
    final p = await _p;
    final ozet = <String, PuanOzeti>{};
    final benim = <String, int>{};
    for (final s in slotlar) {
      final v = p.getInt('yp/$s');
      ozet[s] =
          v == null ? const PuanOzeti(null, 0) : PuanOzeti(v.toDouble(), 1);
      if (v != null) benim[s] = v;
    }
    return YemekPuanlari(ozet, benim);
  }

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
            DateTime.parse(m['zaman'] as String),
            slot: slot)
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

  /// Deneme modunda yorumlar yalnızca bu cihazdadır, bildirilecek bir sunucu yoktur: zararsız, hiçbir şey yapmaz.
  @override
  Future<void> yorumBildir(Yorum y, YorumBildirimNedeni neden) async {}

  @override
  Future<void> verilerimiSil() async {
    final p = await _p;
    for (final k in p.getKeys().toList()) {
      if (k.startsWith('yp/') ||
          k.startsWith('yy/') ||
          k == 'yerel_uid' ||
          k == 'yorum_adi') {
        await p.remove(k);
      }
    }
  }
}

// ---------------------------------------------------------------------------------------------------------------
/// Firestore'a doğrudan REST ile bağlanır (SDK gerekmez; web, iOS ve Android'de aynı kod). Kimlik: Firebase anonim giriş.
class FirestoreDepo implements GeriBildirimDeposu {
  final String proje, anahtar;
  final http.Client _c;

  /// Her ağ isteğinin en çok bekleyeceği süre; dolunca [TimeoutException] fırlar.
  final Duration _zamanAsimi;
  FirestoreDepo(this.proje, this.anahtar, this._c,
      {Duration zamanAsimi = const Duration(seconds: 15)})
      : _zamanAsimi = zamanAsimi;

  String? _token, _yenile, _uid;
  DateTime _bitis = DateTime.fromMillisecondsSinceEpoch(0);

  /// Sürmekte olan oturum açma / yenileme isteği (varsa); bkz. [_oturum].
  Future<void>? _oturumIstegi;

  @override
  bool get cevrimici => true;

  String get _kok =>
      'https://firestore.googleapis.com/v1/projects/$proje/databases/(default)/documents';

  /// Bütün Firebase / Firestore istekleri buradan geçer: [_zamanAsimi] içinde yanıt gelmezse [TimeoutException]
  /// fırlar, istek sonsuza dek beklemez. Çağıranlar bu hatayı diğer ağ hataları gibi yakalar.
  Future<http.Response> _istek(String yontem, Uri adres,
      {Map<String, String>? headers, String? body}) {
    final istek = switch (yontem) {
      'GET' => _c.get(adres, headers: headers),
      'POST' => _c.post(adres, headers: headers, body: body),
      'PATCH' => _c.patch(adres, headers: headers, body: body),
      'DELETE' => _c.delete(adres, headers: headers),
      _ => throw ArgumentError.value(yontem, 'yontem', 'Desteklenmeyen yöntem'),
    };
    return istek.timeout(_zamanAsimi);
  }

  /// Geçerli bir kimlik jetonu olmasını sağlar. Aynı anda gelen çağrılar tek isteği paylaşır: ilk açılışta
  /// puan, yorum ve kullanıcı kimliği birlikte istense de tek anonim hesap açılır ve hepsi aynı kullanıcı kimliğini
  /// görür. İstek bitince ya da hata verince sıfırlanır; sonraki çağrı yeniden dener.
  Future<void> _oturum() =>
      _oturumIstegi ??= _oturumuHazirla().whenComplete(() {
        _oturumIstegi = null;
      });

  Future<void> _oturumuHazirla() async {
    final p = await SharedPreferences.getInstance();
    _yenile ??= p.getString('fb_yenile');
    _uid ??= p.getString('fb_uid');
    if (_token != null &&
        DateTime.now().isBefore(_bitis.subtract(const Duration(minutes: 2)))) {
      return;
    }
    if (_yenile != null) {
      final r = await _istek('POST',
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
      // Yenileme jetonu kalıcı olarak reddedildiyse (geçersiz, süresi dolmuş, kullanıcı silinmiş) aşağıda yeni
      // anonim hesap açılır. Geçici hatada (5xx, 429...) hesap DEĞİŞMEZ: kullanıcının kimliği değişirse kendi
      // yorumundaki "Sil" kaybolur ve "senin puanın" sıfırlanır. Bu yüzden hata fırlatılır; tek uçuş sıfırlanır,
      // sonraki çağrı yenilemeyi yeniden dener.
      if (!_kaliciRet(r.statusCode)) {
        throw Exception('Oturum yenilenemedi (${r.statusCode})');
      }
    }
    final r = await _istek(
        'POST',
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

  /// Jeton yenileme isteğinin yanıtı, yenileme jetonunun artık kullanılamayacağını gösteriyorsa true: 400 (Firebase'in
  /// INVALID_REFRESH_TOKEN, TOKEN_EXPIRED, USER_NOT_FOUND, USER_DISABLED yanıtları), 401 ve 403. Başka her durum
  /// (429, 5xx, beklenmedik kodlar) geçici sayılır.
  static bool _kaliciRet(int kod) => kod == 400 || kod == 401 || kod == 403;

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
    final r = await _istek('POST', Uri.parse('$_kok:runAggregationQuery'),
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
    final r = await _istek('POST', Uri.parse('$_kok:runQuery'),
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

  /// Birçok yemeğin puanlarını tek istekle okur (slot IN [...]); ortalama ve "benim puanım" uygulamada hesaplanır.
  @override
  Future<YemekPuanlari> puanlar(List<String> slotlar) async {
    if (slotlar.isEmpty) return const YemekPuanlari({}, {});
    final uid = await kullaniciId();
    final r = await _istek('POST', Uri.parse('$_kok:runQuery'),
        headers: await _baslik(),
        body: jsonEncode({
          'structuredQuery': {
            'from': [
              {'collectionId': 'ratings'}
            ],
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': 'slot'},
                'op': 'IN',
                'value': {
                  'arrayValue': {
                    'values': [
                      for (final s in slotlar.take(30)) {'stringValue': s}
                    ]
                  }
                }
              }
            },
            'limit': 5000,
          }
        }));
    if (r.statusCode != 200) {
      throw Exception('Puanlar okunamadı (${r.statusCode})');
    }
    final toplam = <String, int>{}, adet = <String, int>{};
    final benim = <String, int>{};
    for (final e in jsonDecode(r.body) as List) {
      final f = (e as Map<String, dynamic>)['document']?['fields']
          as Map<String, dynamic>?;
      final slot = f?['slot']?['stringValue'] as String?;
      final v = f?['stars']?['integerValue'];
      if (slot == null || v == null) continue;
      final y = int.parse('$v');
      toplam[slot] = (toplam[slot] ?? 0) + y;
      adet[slot] = (adet[slot] ?? 0) + 1;
      if (f?['uid']?['stringValue'] == uid) benim[slot] = y;
    }
    return YemekPuanlari({
      for (final s in slotlar)
        s: (adet[s] ?? 0) == 0
            ? const PuanOzeti(null, 0)
            : PuanOzeti(toplam[s]! / adet[s]!, adet[s]!)
    }, benim);
  }

  @override
  Future<int?> benimPuanim(String slot) async {
    final uid = await kullaniciId();
    final r = await _istek('GET', Uri.parse('$_kok/ratings/${slot}_$uid'),
        headers: await _baslik());
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) {
      throw Exception('Puan okunamadı (${r.statusCode})');
    }
    final v = (jsonDecode(r.body) as Map<String, dynamic>)['fields']?['stars']
        ?['integerValue'];
    return v == null ? null : int.parse('$v');
  }

  /// Belge adı (commit isteklerinde tam yol gerekir).
  String get _belgeKok => 'projects/$proje/databases/(default)/documents';

  /// Sunucu zamanı gerektiren yazmalar (`updatedAt == request.time` gibi kurallar) tek `:commit` isteğiyle yapılır;
  /// zaman alanı istemci saatiyle değil `REQUEST_TIME` dönüşümüyle yazılır.
  Future<http.Response> _commit(List<Map<String, dynamic>> yazmalar) async =>
      _istek('POST', Uri.parse('$_kok:commit'),
          headers: await _baslik(), body: jsonEncode({'writes': yazmalar}));

  @override
  Future<void> puanVer(String slot, int yildiz) async {
    final uid = await kullaniciId();
    final r = await _commit([
      {
        'update': {
          'name': '$_belgeKok/ratings/${slot}_$uid',
          'fields': {
            'uid': {'stringValue': uid},
            'slot': {'stringValue': slot},
            'stars': {'integerValue': '$yildiz'},
          }
        },
        'updateTransforms': [
          {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'}
        ],
      }
    ]);
    if (r.statusCode != 200) {
      throw Exception('Puan kaydedilemedi (${r.statusCode})');
    }
  }

  @override
  Future<List<Yorum>> yorumlar(String slot) async {
    final r = await _istek('POST', Uri.parse('$_kok:runQuery'),
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
          DateTime.parse(f['createdAt']['timestampValue'] as String).toLocal(),
          slot: (f['slot']?['stringValue'] ?? slot) as String));
    }
    sonuc.sort((a, b) => b.zaman.compareTo(a.zaman));
    return sonuc;
  }

  static final _rastgele = Random.secure();

  /// Firestore otomatik kimliği gibi 20 karakterlik rastgele belge kimliği.
  static String _yeniBelgeKimligi() {
    const harf =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
        [for (var i = 0; i < 20; i++) harf.codeUnitAt(_rastgele.nextInt(62))]);
  }

  /// Yorum ve kullanıcının `limits/{uid}` belgesi (son yorum zamanı) AYNI `:commit` isteğinde yazılır: kurallar
  /// oran sınırını (son yorumdan en az 20 sn) bu iki yazmanın birlikte gelmesine bağlar.
  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async {
    final uid = await kullaniciId();
    final r = await _commit([
      {
        'update': {
          'name': '$_belgeKok/comments/${_yeniBelgeKimligi()}',
          'fields': {
            'uid': {'stringValue': uid},
            'slot': {'stringValue': slot},
            'name': {'stringValue': ad},
            'text': {'stringValue': metin},
          }
        },
        'updateTransforms': [
          {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}
        ],
        'currentDocument': {'exists': false},
      },
      {
        'update': {'name': '$_belgeKok/limits/$uid', 'fields': {}},
        'updateTransforms': [
          {'fieldPath': 'lastCommentAt', 'setToServerValue': 'REQUEST_TIME'}
        ],
      },
    ]);
    if (r.statusCode != 200) {
      throw Exception('Yorum gönderilemedi (${r.statusCode})');
    }
  }

  @override
  Future<void> yorumSil(Yorum y) async {
    final r = await _istek('DELETE', Uri.parse('$_kok/comments/${y.id}'),
        headers: await _baslik());
    if (r.statusCode != 200) {
      throw Exception('Yorum silinemedi (${r.statusCode})');
    }
  }

  /// Şikâyet belgesi `reports/<bildirenUid>_<yorumId>` kimliğiyle yazılır: aynı kişi aynı yorumu iki kez
  /// bildiremez (ikincisi 409 döner ve "zaten bildirilmiş" sayılır). Yorumun yazarının uid'i ve yorum metninin kopyası
  /// (en çok [bildirimMetinSiniri] karakter) şikâyete eklenir: yorum silinse de inceleme yapılabilir.
  @override
  Future<void> yorumBildir(Yorum y, YorumBildirimNedeni neden) async {
    final uid = await kullaniciId();
    final metin = y.metin.length > bildirimMetinSiniri
        ? y.metin.substring(0, bildirimMetinSiniri)
        : y.metin;
    final r = await _commit([
      {
        'update': {
          'name': '$_belgeKok/reports/${uid}_${y.id}',
          'fields': {
            'uid': {'stringValue': uid},
            'commentId': {'stringValue': y.id},
            'slot': {'stringValue': y.slot},
            'reason': {'stringValue': neden.kod},
            'targetUid': {'stringValue': y.uid},
            'targetText': {'stringValue': metin},
          }
        },
        'updateTransforms': [
          {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}
        ],
        'currentDocument': {'exists': false},
      }
    ]);
    if (r.statusCode == 409) return; // bu yorum zaten bildirilmiş
    if (r.statusCode != 200) {
      throw Exception('Bildirim gönderilemedi (${r.statusCode})');
    }
  }

  /// Bir sorguda silinecek en çok belge sayısı (tek `commit` isteği).
  static const _silmeSayfasi = 100;

  /// Sayfa sayısı üst sınırı: sunucu silmeyi onaylayıp belgeleri yine de döndürürse sonsuz döngüye girilmez.
  static const _enCokSayfa = 200;

  /// Kullanıcının kendi `comments` ve `ratings` belgelerini (uid == kullanıcı) sayfa sayfa siler, sonra anonim
  /// hesabı `accounts:delete` ile kapatır ve yerel oturum kayıtlarını temizler. Hiç oturum açılmamışsa (cihazda
  /// yenileme jetonu yok) sunucuda silinecek bir şey de yoktur: yalnızca yerel kayıtlar temizlenir. Herhangi bir
  /// adım hata verirse hata fırlatılır ve yerel oturum KORUNUR (aynı kimlikle yeniden denenebilsin).
  @override
  Future<void> verilerimiSil() async {
    final p = await SharedPreferences.getInstance();
    if ((_yenile ?? p.getString('fb_yenile')) != null) {
      final uid = await kullaniciId();
      await _sahibininBelgeleriniSil('comments', uid);
      await _sahibininBelgeleriniSil('ratings', uid);
      // kullanıcının KENDİ gönderdiği şikâyetler de silinir; başkalarının onun hakkındaki şikâyetleri moderasyon için
      // saklanır (bkz. site/hesap-silme.html)
      await _sahibininBelgeleriniSil('reports', uid);
      await _oranSiniriniSil(uid);
      await _hesabiSil();
    }
    _token = _yenile = _uid = null;
    _bitis = DateTime.fromMillisecondsSinceEpoch(0);
    await p.remove('fb_yenile');
    await p.remove('fb_uid');
    await p.remove('yorum_adi');
  }

  /// Oran sınırı belgesi (`limits/<uid>`, yalnızca son yorum zamanı). Kurallar, son yorumdan 20 sn geçmeden silmeye
  /// izin vermez (sınırı silerek aşmayı önlemek için); bu yüzden hata sessizce yutulur: belge kişisel veri
  /// içermez (anonim kimlik + zaman) ve hesap kapatılınca hiçbir kimliğe bağlı kalmaz.
  Future<void> _oranSiniriniSil(String uid) async {
    try {
      await _istek('DELETE', Uri.parse('$_kok/limits/$uid'),
          headers: await _baslik());
    } catch (_) {}
  }

  Future<void> _sahibininBelgeleriniSil(String koleksiyon, String uid) async {
    for (var sayfa = 0; sayfa < _enCokSayfa; sayfa++) {
      final r = await _istek('POST', Uri.parse('$_kok:runQuery'),
          headers: await _baslik(),
          body: jsonEncode({
            'structuredQuery': {
              'from': [
                {'collectionId': koleksiyon}
              ],
              'select': {
                'fields': [
                  {'fieldPath': '__name__'}
                ]
              },
              'where': {
                'fieldFilter': {
                  'field': {'fieldPath': 'uid'},
                  'op': 'EQUAL',
                  'value': {'stringValue': uid}
                }
              },
              'limit': _silmeSayfasi,
            }
          }));
      if (r.statusCode != 200) {
        throw Exception('Veriler okunamadı (${r.statusCode})');
      }
      final adlar = <String>[];
      for (final e in jsonDecode(r.body) as List) {
        final ad = (e as Map<String, dynamic>)['document']?['name'];
        if (ad is String) adlar.add(ad);
      }
      if (adlar.isEmpty) return;
      final s = await _istek('POST', Uri.parse('$_kok:commit'),
          headers: await _baslik(),
          body: jsonEncode({
            'writes': [
              for (final ad in adlar) {'delete': ad}
            ]
          }));
      if (s.statusCode != 200) {
        throw Exception('Veriler silinemedi (${s.statusCode})');
      }
      if (adlar.length < _silmeSayfasi) return;
    }
  }

  /// Anonim hesabı kapatır. Hesap zaten yoksa (USER_NOT_FOUND) iş görülmüş sayılır.
  Future<void> _hesabiSil() async {
    await _oturum();
    final r = await _istek(
        'POST',
        Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$anahtar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': _token}));
    if (r.statusCode != 200 && !r.body.contains('USER_NOT_FOUND')) {
      throw Exception('Hesap silinemedi (${r.statusCode})');
    }
  }
}

// ---------------------------------------------------------------------------------------------------------------
/// Okuma sonuçlarını bellekte kısa süre ([omur], varsayılan 5 dakika) tutan sarmalayıcı. Firestore'un ücretsiz okuma
/// kotası (günde 50 bin) kullanıcı sayısıyla birlikte erimesin diye aynı puan / yorum sorguları her gün ve öğün
/// geçişinde, her ayrıntı sayfası açılışında yeniden atılmaz. Önbellek yalnızca bellektedir (uygulama kapanınca gider).
///
/// - Önbelleğe alınan okumalar: [puanlar] (slot KÜMESİNE göre: sıra ve tekrar önemsiz), [puanOzeti], [benimPuanim],
///   [yorumlar]. [kullaniciId] ve [cevrimici] olduğu gibi içteki depodan gelir.
/// - Yazma ([puanVer], [yorumEkle], [yorumSil]) bitince (başarısız olsa da: sunucuda uygulanmış olabilir) etkilediği
///   kayıtlar düşer. [puanVer]: o slotun özeti, benim puanım ve o slotu içeren her [puanlar] kümesi. [yorumEkle]: o
///   slotun yorumları. [yorumSil]: silinen yorumun slotu bilinmediğinden ([Yorum]'da slot yok) bütün yorum kayıtları.
///   Yazma sürerken başlamış okumaların sonucu da saklanmaz (eski değer önbelleğe girmesin).
/// - Hatayla biten okuma saklanmaz; aynı anda gelen aynı okumalar tek isteği paylaşır.
/// - Çağırana her seferinde kopya verilir: dönen liste / harita değiştirilse de saklanan değer bozulmaz.
/// - [temizle] hepsini boşaltır.
class OnbellekliGeriBildirim implements GeriBildirimDeposu {
  final GeriBildirimDeposu _ic;
  final _OkumaOnbellegi<PuanOzeti> _ozetler;
  final _OkumaOnbellegi<int?> _benimler;
  final _OkumaOnbellegi<YemekPuanlari> _puanlar;
  final _OkumaOnbellegi<List<Yorum>> _yorumlar;

  /// [saat] ve [omur] testlerde sahte saat ve kısa ömür vermek içindir; boşsa gerçek saat ve 5 dakika.
  OnbellekliGeriBildirim(GeriBildirimDeposu ic,
      {DateTime Function()? saat, Duration omur = const Duration(minutes: 5)})
      : this._(ic, saat ?? DateTime.now, omur);

  OnbellekliGeriBildirim._(this._ic, DateTime Function() saat, Duration omur)
      : _ozetler = _OkumaOnbellegi<PuanOzeti>(saat, omur, (d) => d),
        _benimler = _OkumaOnbellegi<int?>(saat, omur, (d) => d),
        _puanlar = _OkumaOnbellegi<YemekPuanlari>(
            saat, omur, (p) => YemekPuanlari(Map.of(p.ozet), Map.of(p.benim))),
        _yorumlar = _OkumaOnbellegi<List<Yorum>>(saat, omur, (l) => List.of(l));

  /// Bütün okuma kayıtlarını ve sürmekte olan okumaları düşürür; sonraki okumalar içteki depoya gider.
  void temizle() {
    _ozetler.temizle();
    _benimler.temizle();
    _puanlar.temizle();
    _yorumlar.temizle();
  }

  @override
  bool get cevrimici => _ic.cevrimici;

  @override
  Future<String> kullaniciId() => _ic.kullaniciId();

  @override
  Future<PuanOzeti> puanOzeti(String slot) =>
      _ozetler.oku(slot, {slot}, () => _ic.puanOzeti(slot));

  @override
  Future<int?> benimPuanim(String slot) =>
      _benimler.oku(slot, {slot}, () => _ic.benimPuanim(slot));

  @override
  Future<YemekPuanlari> puanlar(List<String> slotlar) {
    if (slotlar.isEmpty) return _ic.puanlar(slotlar);
    final kume = slotlar.toSet();
    // sıra ve tekrar önemsiz: aynı slot kümesi tek kayıttır (\u0000 slot kimliklerinde geçmez)
    final anahtar = (kume.toList()..sort()).join('\u0000');
    return _puanlar.oku(anahtar, kume, () => _ic.puanlar(slotlar));
  }

  @override
  Future<void> puanVer(String slot, int yildiz) async {
    try {
      await _ic.puanVer(slot, yildiz);
    } finally {
      _ozetler.slotuDusur(slot);
      _benimler.slotuDusur(slot);
      _puanlar.slotuDusur(slot);
    }
  }

  @override
  Future<List<Yorum>> yorumlar(String slot) =>
      _yorumlar.oku(slot, {slot}, () => _ic.yorumlar(slot));

  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async {
    try {
      await _ic.yorumEkle(slot, ad, metin);
    } finally {
      _yorumlar.slotuDusur(slot);
    }
  }

  @override
  Future<void> yorumSil(Yorum y) async {
    try {
      await _ic.yorumSil(y);
    } finally {
      _yorumlar.temizle();
    }
  }

  @override
  Future<void> yorumBildir(Yorum y, YorumBildirimNedeni neden) =>
      _ic.yorumBildir(y, neden);

  /// Silme bitince (başarısız olsa da: kısmen silinmiş olabilir) bütün önbellek boşaltılır.
  @override
  Future<void> verilerimiSil() async {
    try {
      await _ic.verilerimiSil();
    } finally {
      temizle();
    }
  }
}

/// [_OkumaOnbellegi]ndeki bir okuma sonucu: [deger], [zaman]'da alındı; [slotlar] hangi slotları ilgilendirdiği.
class _Kayit<T> {
  final T deger;
  final DateTime zaman;
  final Set<String> slotlar;
  _Kayit(this.deger, this.zaman, this.slotlar);
}

/// Sürmekte olan bir okuma isteği; aynı anahtarla gelen okumalar [istek]i paylaşır.
class _Surec<T> {
  final Set<String> slotlar;
  late final Future<T> istek;
  _Surec(this.slotlar);
}

/// [OnbellekliGeriBildirim]in tek bir okuma türü için önbelleği: anahtar -> kayıt ve sürmekte olan istekler.
class _OkumaOnbellegi<T> {
  final DateTime Function() _saat;
  final Duration _omur;

  /// Çağırana verilen kopya: saklanan değerin kendisi dışarı çıkmaz.
  final T Function(T) _kopya;
  final Map<String, _Kayit<T>> _kayitlar = {};
  final Map<String, _Surec<T>> _surenler = {};
  _OkumaOnbellegi(this._saat, this._omur, this._kopya);

  /// Kayıt ömrü içindeyse taze. Saat geriye alınmışsa (geçen süre eksi) kayda güvenilmez: yeniden okunur.
  bool _taze(_Kayit<T> kayit) {
    final gecen = _saat().difference(kayit.zaman);
    return !gecen.isNegative && gecen < _omur;
  }

  /// [anahtar]ın taze kaydı varsa onu, yoksa sürmekte olan isteği, o da yoksa [getir] ile yeni bir istek açarak
  /// döner. Başarılı sonuç saklanır; hata saklanmaz. Okuma sürerken [slotuDusur] / [temizle] çağrılırsa o okumanın
  /// sonucu (eski olabilir) saklanmaz, çağıranlara yine de döner.
  Future<T> oku(
      String anahtar, Set<String> slotlar, Future<T> Function() getir) {
    final kayit = _kayitlar[anahtar];
    if (kayit != null) {
      if (_taze(kayit)) return Future<T>.value(_kopya(kayit.deger));
      _kayitlar.remove(anahtar);
    }
    var surec = _surenler[anahtar];
    if (surec == null) {
      final yeni = surec = _Surec<T>(slotlar);
      yeni.istek = Future<T>.sync(getir).then((deger) {
        // araya yazma / temizle girdiyse (istek artık kayıtlı değil) eski olabilecek sonuç saklanmaz
        if (identical(_surenler[anahtar], yeni)) {
          // süresi dolmuş kayıtlar birikmesin
          _kayitlar.removeWhere((_, k) => !_taze(k));
          _kayitlar[anahtar] = _Kayit<T>(deger, _saat(), slotlar);
        }
        return deger;
      }).whenComplete(() {
        if (identical(_surenler[anahtar], yeni)) _surenler.remove(anahtar);
      });
      _surenler[anahtar] = yeni;
    }
    return surec.istek.then(_kopya);
  }

  /// [slot]u ilgilendiren kayıtları ve sürmekte olan istekleri düşürür.
  void slotuDusur(String slot) {
    _kayitlar.removeWhere((_, k) => k.slotlar.contains(slot));
    _surenler.removeWhere((_, s) => s.slotlar.contains(slot));
  }

  void temizle() {
    _kayitlar.clear();
    _surenler.clear();
  }
}
