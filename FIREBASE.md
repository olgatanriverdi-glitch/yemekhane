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
