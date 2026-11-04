# Puan ve yorum için Firebase kurulumu (bir kez, ~10 dakika, ücretsiz)

Uygulama puan ve yorumları Firebase **Firestore**'da saklar. Ayar yapılmazsa "deneme modu" çalışır (veriler yalnızca telefonda kalır).

1. https://console.firebase.google.com → **Proje ekle** → ad: `yemekhane` (Analytics kapalı olabilir).
2. Sol menü **Build → Authentication → Get started → Sign-in method → Anonymous → Enable**.
3. **Build → Firestore Database → Create database** → konum: `eur3` (Avrupa) → **Production mode**.
4. Firestore → **Rules** sekmesine bu klasördeki `firestore.rules` dosyasının içeriğini yapıştır → **Publish**.
5. **Proje ayarları (dişli) → General → Your apps → Web (</>)** ile bir web uygulaması ekle. Çıkan `apiKey` ve `projectId` değerlerini al.
6. Bu iki değeri uygulamaya ver:
   * `app/lib/firebase_config.dart` içindeki `defaultValue: ''` alanlarına yaz, **ya da**
   * derlerken: `flutter build web --dart-define=FB_PROJE=PROJE_ID --dart-define=FB_ANAHTAR=API_ANAHTARI`
7. (Önerilen) Google Cloud Console → **APIs & Services → Credentials** → bu API anahtarına **HTTP referrer** kısıtı: `olgatanriverdi-glitch.github.io/*` ve `localhost/*`; iOS/Android için ayrı anahtar kısıtı.

`apiKey` gizli değildir (web uygulamalarında herkese açıktır); güvenliği **Firestore kuralları** sağlar. Uygunsuz yorumu Firebase konsolunda **Firestore → comments** koleksiyonundan silebilirsin.

## Yorum bildirimleri (Google Play kullanıcı içeriği politikası)

Uygulamada başkasının yorumunun yanındaki "..." menüsünden **Bildir** (neden: Hakaret / küfür, Spam, Uygunsuz içerik, Diğer) ve **Bu kişiyi engelle** vardır. Bildirimler Firestore'daki `reports` koleksiyonuna yazılır: `uid`, `commentId`, `slot`, `reason` (`hakaret` / `spam` / `uygunsuz` / `diger`), `createdAt`.

* **Kuralları yeniden yayınla:** `reports` kuralı yeni eklendi. Firestore → **Rules** sekmesine güncel `firestore.rules` içeriğini yapıştırıp **Publish** et. Yayınlamazsan uygulama çalışmaya devam eder ama "Bildir" `Bildirim gönderilemedi` hatası verir (yorumlar ve puanlar etkilenmez).
* **Bildirimleri görmek:** Firebase konsolu → **Firestore Database → Data → reports**. `commentId` alanı `comments` koleksiyonundaki belge kimliğidir; `comments` içinde bu kimliği açıp metne bak. Uygunsuzsa belgeyi **sil** (konsol kuralları atlar). Aynı kişi (`uid`) tekrar tekrar uygunsuz yazıyorsa o `uid`'in tüm yorumlarını `comments` içinde `uid` alanına göre filtreleyip silebilirsin.
* Uygulama bildirimleri **okuyamaz**; kurallar yalnızca geçerli alanlarla oluşturmaya izin verir (okuma, güncelleme, silme yok).
* Bildirimleri düzenli kontrol et (haftada en az bir kez): Play politikası bildirilen içeriğe makul sürede müdahale etmeni bekler.

## Verilerimi sil

Ayarlar → Hakkında → **Yorum ve puanlarımı sil**: uygulama kullanıcının kendi `comments` ve `ratings` belgelerini (`uid` eşleşen) siler (mevcut kurallar sahibine silme izni verir) ve anonim Firebase hesabını kapatır. Ek kural gerekmez. Bu özellik Google Play'in "veri silme" gereksinimini karşılar; adres: `site/hesap-silme.html`.
