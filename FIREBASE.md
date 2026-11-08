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

Uygulamada başkasının yorumunun yanındaki "..." menüsünden **Bildir** (bildirim hem yorumu hem yazarını kapsar; neden: Hakaret / küfür, Spam, Uygunsuz içerik, Diğer) ve **Bu kişiyi engelle** vardır. İlk yorumdan önce kullanıcıya **Topluluk kuralları** gösterilir ve kabul ettirilir (kabul edilen sürüm cihazda `topluluk_kurallari_surum` anahtarında; metin `site/kurallar.html` ile aynıdır).

Bildirimler Firestore'daki `reports` koleksiyonuna yazılır. Belge kimliği `<bildirenUid>_<yorumId>`: aynı kişi aynı yorumu bir kez bildirir. Alanlar: `uid` (bildiren), `commentId`, `slot`, `reason` (`hakaret` / `spam` / `uygunsuz` / `diger`), `targetUid` (yorumun yazarı), `targetText` (yorum metninin kopyası, en çok 300 karakter; yorum silinse de inceleme yapılabilsin), `createdAt` (sunucu zamanı).

* **Kuralları yeniden yayınla:** `reports`, `limits` kuralları ve `createdAt` / `updatedAt` sunucu zamanı doğrulaması yeni. Firestore → **Rules** sekmesine güncel `firestore.rules` içeriğini yapıştırıp **Publish** et. Kuralları uygulamadan önce yayınla; yayınlamazsan yeni uygulama sürümünde yorum yazma, puan verme ve "Bildir" hata verir.
* **Bildirimleri görmek:** Firebase konsolu → **Firestore Database → Data → reports**. `commentId` alanı `comments` koleksiyonundaki belge kimliğidir; yorum silinmiş olsa bile `targetText` ve `targetUid` kalır. Uygunsuzsa `comments` içindeki belgeyi **sil** (konsol kuralları atlar). Aynı kişi (`targetUid`) tekrar tekrar uygunsuz yazıyorsa `comments` içinde `uid` alanına göre filtreleyip hepsini silebilirsin.
* Uygulama başkasının bildirimlerini **okuyamaz**; bildiren yalnızca kendi bildirimlerini okuyabilir ve silebilir (hesap silme bunu kullanır).
* **Saklama (kullanıcıya verilen söz):** başkalarının bir kullanıcı hakkındaki şikâyetleri, hesabı silinse de inceleme bitene kadar, **en çok 90 gün** saklanır. Bunu elle uygula: incelenen ya da 90 günü geçen `reports` belgelerini konsoldan sil (Firestore'da otomatik süre dolumu için **TTL ilkesi** de kurabilirsin: Firestore → Indexes → TTL; bunun için belgeye `silinecekZaman` gibi bir alan eklemek gerekir, bu uygulama yazmaz; elle silmek yeterlidir).
* Bildirimleri düzenli kontrol et (haftada en az bir kez): Play politikası bildirilen içeriğe makul sürede müdahale etmeni bekler.

## Yorum oran sınırı ve sunucu zamanı

* Yorum, tek bir `:commit` isteğinde iki belge yazılarak oluşturulur: `comments/<yeniKimlik>` ve `limits/<uid>` (`lastCommentAt`). Kurallar ikisinin de `request.time` ile yazılmasını ve önceki yorumdan en az **20 saniye** geçmesini zorunlu kılar (`getAfter` / `existsAfter`). Elle REST ile yorum yazan biri de bu sınıra takılır.
* `limits/<uid>` belgesi kişisel veri içermez (anonim kimlik + zaman); okunamaz. Son yorumdan 20 sn geçmeden silinemez (silerek sınırı aşmayı önler); "Yorum ve puanlarımı sil" bunu dener, süre dolmamışsa sessizce atlar (hesap kapanınca hiçbir kimliğe bağlı kalmaz).
* Puan (`ratings`) da `updatedAt == request.time` ile sunucu zamanıyla yazılır.

### Rules Playground ile denenecek 5 senaryo

Firebase konsolu → Firestore → Rules → **Rules Playground** (Simulation type: create/get/delete; Authenticated: açık, Provider: anonymous, Firebase UID: `U1`). Önce kuralları yayınla, sonra:

1. **Geçerli yorum (izin verilmeli).** `comments/C1` create, veri `{uid:"U1", slot:"s1", name:"Ali", text:"Merhaba", createdAt: <request.time>}`. Playground'da aynı yazmanın yanına `limits/U1` `{lastCommentAt: <request.time>}` eklenemez; bu yüzden bu senaryoyu gerçek uygulamadan dene: Ayarlar'dan yeni bir yorum yaz, Firestore → Data'da hem `comments` hem `limits/<uid>` belgesinin oluştuğunu gör.
2. **Oran sınırı (reddedilmeli).** Uygulamada art arda iki yorumu 20 saniyeden kısa aralıkla gönder: ikincisi "Yorum gönderilemedi" demeli, `comments` içinde tek yeni belge olmalı; 20 sn sonra tekrar dene, geçmeli.
3. **Başkası adına yorum (reddedilmeli).** Playground: `comments/C2` create, UID `U1` ama veri `uid:"U2"`. Sonuç: Denied.
4. **Şikâyet: olmayan yoruma (reddedilmeli) ve tekrar (reddedilmeli).** `reports/U1_YOKYORUM` create, veri `{uid:"U1", commentId:"YOKYORUM", slot:"s1", reason:"spam", targetUid:"U2", targetText:"x", createdAt:<request.time>}`: yorum yok → Denied. Var olan başkasının bir yorumu için uygulamadan "Bildir" yap, sonra aynı yorumu tekrar bildirmeyi dene: ikinci istek 409 döner, uygulama bunu "zaten bildirilmiş" sayar, `reports` içinde tek belge kalır. Kendi yorumunu bildirmek (`targetUid == U1`) Denied olmalı.
5. **Silme.** `reports/U1_<yorumId>` delete UID `U1` → Allowed; UID `U2` → Denied. `reports/U1_<yorumId>` get UID `U2` → Denied. `ratings/s1_U1` create `updatedAt` istemci saatiyle (`request.time` değil) → Denied.

## Verilerimi sil

Ayarlar → Hakkında → **Yorum ve puanlarımı sil**: uygulama kullanıcının kendi `comments`, `ratings` ve **gönderdiği `reports`** belgelerini (`uid` eşleşen) siler (kurallar sahibine silme izni verir; `reports` için sorgu `uid == kendi uid` ile sınırlıdır), `limits/<uid>` belgesini silmeyi dener ve anonim Firebase hesabını kapatır. Başkalarının bu kullanıcı hakkındaki şikâyetleri silinmez (yukarıdaki 90 günlük saklama). Bu özellik Google Play'in "veri silme" gereksinimini karşılar; adres: `site/hesap-silme.html`.
