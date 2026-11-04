import 'models.dart' show kucukTr, sadeTr;

/// Yorum göndermeden önce cihazda çalışan basit denetim (Google Play kullanıcı içeriği politikası için ilk savunma).
/// Küfür / hakaret listesi kısa ve yalnızca yaygın sözcükleri kapsar; amaç her şeyi yakalamak değil, açık hakareti
/// göndermeden durdurmaktır. Asıl koruma bildirme, engelleme ve konsoldan silmedir.
enum YorumSorunu {
  /// Küfür ya da hakaret içeriyor.
  uygunsuz,

  /// Bağlantı (http, www ya da alan adı) içeriyor.
  baglanti;

  /// Kullanıcıya gösterilen ret metni.
  String get mesaj => switch (this) {
        YorumSorunu.uygunsuz => 'Yorumun uygunsuz ifade içeriyor.',
        YorumSorunu.baglanti => 'Yorumda bağlantı paylaşılamaz.',
      };
}

/// [metin] gönderilebilirse null, değilse nedenini döner.
YorumSorunu? yorumSorunu(String metin) {
  if (_baglantiVar(metin)) return YorumSorunu.baglanti;
  if (_uygunsuzVar(metin)) return YorumSorunu.uygunsuz;
  return null;
}

// --- bağlantı -------------------------------------------------------------------------------------------------
final _baglantiDeseni = RegExp(
  r'(https?\s*:\s*/\s*/|www\s*\.|\b[a-z0-9-]+\.(com|net|org|edu|gov|info|biz|xyz|io|me|ly|gl|tr|co)\b)',
  caseSensitive: false,
);

bool _baglantiVar(String metin) => _baglantiDeseni.hasMatch(metin);

// --- küfür / hakaret ------------------------------------------------------------------------------------------
// Sözcükler sadeTr biçiminde (aksansız, küçük harf) ve ARDIŞIK TEKRARLARI TEK HARFE İNDİRİLMİŞ yazılır
// ("yarrak" -> "yarak"): "yaaarrak" da aynı biçime iner.

/// Belirteç (kelime) tam olarak bunlardan biriyse eşleşir. Kısa kökler, masum kelimelere karışmasın diye burada.
const _tamEslesen = {
  'amk',
  'aq',
  'amq',
  'pic',
  'ibne',
  'gavat',
  'pust',
  'godos',
  'kahpe',
  'aptal',
  'salak',
  'dangalak',
  'serefsiz',
  'namussuz',
  'haysiyetsiz',
  'gerizekali',
};

/// Belirteç bunlardan biriyle BAŞLIYORSA eşleşir (ekli biçimler: "orospuluk", "amcigi", "siktirgit" ...).
const _onEk = [
  'orospu',
  'orspu',
  'orosbu',
  'pezevenk',
  'yarak',
  'amcik',
  'aminakoy',
  'aminakod',
  'gotveren',
  'gotune',
  'gotunu',
  'siktir',
  'sikeyim',
  'sikerim',
  'sikecem',
  'siktim',
  'ibneler',
  'ibnelik',
];

/// Birden çok sözcükten oluşan ifadeler (sadeTr biçiminde, belirteçler tek boşlukla birleşik).
const _ifadeler = ['amina koy', 'amina kod', 'anani sik', 'bacini sik'];

/// "sik" ancak tek başına bir belirteç olarak ve "ı" harfi YOKKEN küfürdür: "sık sık" (sıkça) ve "sıkı" masumdur,
/// "sikke", "sikayet" gibi kelimeler zaten tam eşleşme olmadığından geçer. Bu yüzden bu kontrol ı'yı sadeleştirmeyen
/// görünümde yapılır.
const _ihtiyatliTam = {'sik'};

bool _uygunsuzVar(String metin) {
  // Görünüm 1: ç ğ ö ş ü sadeleşir, ı KORUNUR ("sık" ile "sik" ayrılsın).
  final ihtiyatli = _belirtecler(_ihtiyatliSadelestir(metin));
  for (final b in ihtiyatli) {
    if (_ihtiyatliTam.contains(_tekrarsiz(b))) return true;
  }
  // Görünüm 2: tam sadeleştirme (ı -> i).
  final tam = _belirtecler(sadeTr(metin));
  final birlesik = tam.map(_tekrarsiz).join(' ');
  for (final i in _ifadeler) {
    if (birlesik.contains(i)) return true;
  }
  for (final b in tam) {
    final t = _tekrarsiz(b);
    if (t.length < 2) continue;
    if (_tamEslesen.contains(t)) return true;
    for (final on in _onEk) {
      if (t.startsWith(on)) return true;
    }
  }
  return false;
}

String _ihtiyatliSadelestir(String s) {
  final k = kucukTr(s);
  final b = StringBuffer();
  for (var i = 0; i < k.length; i++) {
    final c = k[i];
    if (c == '̇') continue;
    b.write(switch (c) {
      'ç' => 'c',
      'ğ' => 'g',
      'ö' => 'o',
      'ş' => 's',
      'ü' => 'u',
      'â' => 'a',
      'î' => 'i',
      'û' => 'u',
      _ => c,
    });
  }
  return b.toString();
}

/// Ardışık aynı harfleri tek harfe indirir ("siiiktir" -> "siktir", "yarrak" -> "yarak").
String _tekrarsiz(String s) {
  final b = StringBuffer();
  String? onceki;
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (c != onceki) b.write(c);
    onceki = c;
  }
  return b.toString();
}

bool _harf(String c) =>
    (c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7a) || c == 'ı';

const _okunus = {
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '@': 'a',
  r'$': 's',
};

/// Metni sözcüklere (belirteçlere) böler: harf olmayan her şey ayraçtır; harflerin yanındaki rakam ve işaretler
/// harfe çevrilir ("s1kt1r" -> "siktir", "@mk" -> "amk"); tek harflik belirteçlerin 3 ya da daha uzun dizisi
/// birleştirilir ("s i k t i r", "a.m.k" -> "siktir", "amk").
List<String> _belirtecler(String metin) {
  // 1) harfe bitişik rakam / işaretler harfe çevrilir
  final yaz = StringBuffer();
  for (var i = 0; i < metin.length; i++) {
    final c = metin[i];
    if (_okunus.containsKey(c)) {
      final onceki = i > 0 && _harf(metin[i - 1]);
      final sonraki = i + 1 < metin.length && _harf(metin[i + 1]);
      yaz.write(onceki || sonraki ? _okunus[c] : ' ');
    } else {
      yaz.write(c);
    }
  }
  // 2) harf olmayanlar ayraç
  final ham = <String>[];
  final simdiki = StringBuffer();
  void bitir() {
    if (simdiki.isNotEmpty) ham.add(simdiki.toString());
    simdiki.clear();
  }

  for (final r in yaz.toString().runes) {
    final c = String.fromCharCode(r);
    if (_harf(c)) {
      simdiki.write(c);
    } else {
      bitir();
    }
  }
  bitir();
  // 3) tek harflik belirteç dizilerini birleştir
  final sonuc = <String>[];
  var i = 0;
  while (i < ham.length) {
    if (ham[i].length == 1) {
      var j = i;
      while (j < ham.length && ham[j].length == 1) {
        j++;
      }
      if (j - i >= 3) {
        sonuc.add(ham.sublist(i, j).join());
      } else {
        sonuc.addAll(ham.sublist(i, j));
      }
      i = j;
    } else {
      sonuc.add(ham[i]);
      i++;
    }
  }
  return sonuc;
}
