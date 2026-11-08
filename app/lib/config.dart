/// Verinin okunacağı adres: GitHub deposundaki `data` klasörünün "raw" adresi (sonunda / olmadan).
/// Örn: https://raw.githubusercontent.com/KULLANICI/yemekhane/main/data
/// Boş bırakılırsa uygulama yalnızca uygulamayla gelen (assets/data) kopyayı kullanır.
const String veriTabanUrl = String.fromEnvironment('VERI_URL',
    defaultValue:
        'https://raw.githubusercontent.com/olgatanriverdi-glitch/yemekhane/main/data');

/// Uygulama sürümü (Ayarlar > Hakkında). pubspec.yaml'daki `version` değerinin '+' öncesiyle aynı olmalı
/// (test/ilk_acilis_ayarlar_test.dart bunu denetler).
const String uygulamaSurumu = '1.0.0';

/// Wikimedia Commons'tan fotoğraf isteyen isteklerde (web dışında) gönderilen tanımlayıcı User-Agent; Wikimedia
/// genel istemci kimliklerini sınırladığı için uygulamayı ve iletişim adresini bildirir.
const String commonsKullaniciAjani =
    'UniYemek/$uygulamaSurumu (https://github.com/olgatanriverdi-glitch/yemekhane)';

/// Tanıtım sitesi (GitHub Pages). Gizlilik politikası ve Google Play'in istediği hesap / veri silme sayfası burada.
const String siteAdresi = 'https://olgatanriverdi-glitch.github.io/yemekhane';
const String gizlilikAdresi = '$siteAdresi/gizlilik.html';
const String hesapSilmeAdresi = '$siteAdresi/hesap-silme.html';

/// Gizlilik ve veri silme sorularının gönderileceği e-posta.
const String iletisimEposta = 'uniyemek0@gmail.com';

const List<String> ayAdlari = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık'
];
const List<String> gunAdlari = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar'
];
const List<String> gunKisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
