/// Okul listesi boş geldiğinde fırlatılır; ana sayfa bunu bağlantı hatasından ayrı bir mesajla gösterir.
class BosOkulListesi implements Exception {
  const BosOkulListesi();
}

/// Ana sayfa yüklemesi [hata] ile bittiğinde kullanıcıya gösterilen kısa açıklama.
String yuklemeHatasiMetni(Object hata) => hata is BosOkulListesi
    ? 'Üniversite listesi boş. Birazdan tekrar dene.'
    : 'Menü yüklenemedi. İnternet bağlantını kontrol et.';
