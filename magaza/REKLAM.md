# Reklam rehberi (Google AdMob): yeni başlayanlar için

Üni Yemek'te tek bir reklam yeri vardır: ana ekranda, öğün kartının altında ve "Öğün yorumları"ndan önce, "Reklam" etiketli küçük bir yerel (native) kart. Tam ekran, açılışta çıkan, videolu, sesli, yapışkan alt bannerlı reklam yoktur; yemek listesinin içinde reklam yoktur. İlk açılıştan sonraki 3 gün (ilk gün dahil 4 gün) reklam çıkmaz. Aynı gün ve öğünde 2 saniye kalmadan istek atılmaz. Bir oturumda en çok 10 reklam yüklenir. Web sürümünde reklam yoktur.

Tanımlayıcı olmadan alınan **release** derlemede reklam tamamen kapalıdır (SDK başlatılmaz, istek atılmaz, yer ayrılmaz). Yani kimlik vermeden yaptığın bir `.aab` / `.apk` asla test reklamı göstermez; reklamlı sürüm için aşağıdaki adımları yap.

## 1. AdMob hesabı

1. https://admob.google.com adresine Play Console hesabındaki Google hesabınla gir, hesabı aç (ülke Türkiye, saat dilimi Istanbul, para birimi TRY ya da USD; sonradan DEĞİŞTİRİLEMEZ).
2. **Uygulamalar > Uygulama ekle**: platform Android, "Uygulama Google Play'de yayında mı?": henüz değilse **Hayır** (yayından sonra Play'e bağlarsın). Ad: `Üni Yemek`.
3. Oluşan **Uygulama kimliği** `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` biçimindedir (`~` işaretli). Not al.
4. **Reklam birimi ekle > Yerel gelişmiş (Native advanced)**: ad `ana-ekran-yerel`. Oluşan **Reklam birimi kimliği** `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ` biçimindedir (`/` işaretli). Not al. Uygulama kimliği ile birim kimliğini karıştırma.
5. iOS de yapacaksan aynı adımları iOS uygulaması için ayrıca tekrarla.

## 2. Kimlikler nereye yazılır

| Kimlik | Nereye | Nasıl |
|---|---|---|
| Android **uygulama** kimliği (`~`) | `app/android/key.properties` | `admobAppId=ca-app-pub-XXXX~YYYY` satırı ekle (dosya git'e girmez). Yoksa Google'ın test uygulama kimliği kullanılır. |
| Android **birim** kimliği (`/`) | derleme komutu | `--dart-define=ADMOB_NATIVE_ANDROID=ca-app-pub-XXXX/ZZZZ` |
| iOS uygulama kimliği | `app/ios/Runner/Info.plist` | `GADApplicationIdentifier` değerini değiştir (şu an Google test kimliği). |
| iOS birim kimliği | derleme komutu | `--dart-define=ADMOB_NATIVE_IOS=ca-app-pub-XXXX/ZZZZ` |

Birim kimlikleri koda yazılmaz, git'e girmez: yalnızca derleme komutunda verilir.

## 3. Derleme komutu

```bash
cd app
ANDROID_HOME=~/Library/Android/sdk ~/development/flutter/bin/flutter build appbundle --release \
  --dart-define=ADMOB_NATIVE_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ
```

Aynı bayrak `flutter build apk --release` için de geçerlidir. `--dart-define` vermezsen release'te reklam kapalı olur (güvenli varsayılan). `flutter run` (debug) ile kimlik vermeden çalıştırırsan Google'ın herkese açık TEST reklamları görünür; test reklamlarına tıklamak güvenlidir.

## 4. Kendi reklamına tıklama (HESAP KAPANIR)

Gerçek kimlikli sürümde (release) **kendi reklamına asla tıklama**, arkadaşlarından da tıklamasını isteme. Geçersiz trafik AdMob hesabının kalıcı kapatılmasına yol açar. Kendin denemek için:

1. AdMob > **Ayarlar > Test cihazları**: cihazının reklam kimliğini (logcat'te "Use RequestConfiguration.Builder().setTestDeviceIds" satırında yazar) ekle. (Bu kodda test cihazı listesi yoktur; elle eklemek istersen `gercek_reklam_servisi.dart` içindeki `RequestConfiguration`'a `testDeviceIds` ekle, yayına gitmeden çıkar.)
2. Ya da hiç gerçek kimlikli sürüm denemeden debug derlemeyle (Google test reklamı) dene.

## 5. app-ads.txt (ZORUNLU: yeni AdMob uygulamaları için)

Google'ın belgesine göre (https://support.google.com/admob/answer/14538460) Ocak 2025'ten beri AdMob'da yeni kurulan uygulamalar `app-ads.txt` ile **doğrulanmalıdır**; doğrulanmadan uygulama "tam reklam sunamaz" ve hazırlık incelemesine (app readiness review) geçmez. İstisna yalnızca Play / App Store dışındaki mağazalardır. Yani bu adım atlanamaz.

**Google dosyayı nerede arar?** (https://support.google.com/admob/answer/9363762) Play'deki "Web sitesi" adresinden yalnızca **alan adını** (hostname) alır ve `https://<alan-adı>/app-ads.txt` adresine bakar; adresteki alt yol (`/yemekhane`) dikkate alınmaz. `www.` ve `m.` önekleri atılır; bir alt alan adı seviyesi denenir, sonra üst alan adı.

Bu projenin sitesi `https://olgatanriverdi-glitch.github.io/yemekhane/` alt yolundadır. Alan adı `olgatanriverdi-glitch.github.io` olduğundan Google `https://olgatanriverdi-glitch.github.io/app-ads.txt` adresine bakar. Bu adres bu depodaki (`yemekhane`) siteden DEĞİL, **kullanıcı sitesi deposundan** gelir. Dosyayı `site/` klasörüne koymak işe yaramaz.

**Adımlar (yeni başlayan için):**

1. AdMob'da Android uygulamasını ekledikten sonra **Uygulamalar > Tüm uygulamalar > app-ads.txt > AdMob'da app-ads.txt nasıl kurulur** sayfasından kendi satırını kopyala. Biçim `google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`; `pub-` kimliği AdMob hesabının yayıncı kimliğidir (uygulama kimliğindeki `~` öncesi sayılar ile aynı). Örnek dosya: `magaza/app-ads.txt.ornek` (yer tutuculu; gerçek kimliği AdMob'dan al, tahmin etme).
2. GitHub'da `olgatanriverdi-glitch.github.io` adlı **herkese açık** yeni bir depo aç (Settings > Pages kaynağı: `main` dalı, `/ (root)`). Deponun kökünde `app-ads.txt` adıyla düz metin dosyasını oluştur (içine yalnızca o satır/satırlar; HTML değil).
3. Tarayıcıda `https://olgatanriverdi-glitch.github.io/app-ads.txt` adresini aç; satırı düz metin olarak görmelisin. Yayına girmesi birkaç dakika sürebilir.
4. **Play Console > Mağazada yer alma (Grow users > Store presence) > Mağaza ayarları > Mağaza girişi iletişim bilgileri > Web sitesi** alanına aynı alan adını yaz: `https://olgatanriverdi-glitch.github.io` (alt yolun bir önemi yok ama alan adı aynı olmalı; `/yemekhane` eklesen de çalışır). Google değişikliği algılaması için 24 saate kadar süre tanır.
5. AdMob > **Uygulamalar > uygulama > Uygulama ayarları > Uygulamayı doğrula > Güncellemeleri denetle**. Doğrulanınca hazırlık incelemesi başlar; bitene dek reklam tam açılmaz.

**Doğrulanmadı:** Bu çözümün (`github.io` kullanıcı sitesi alt alanında dosya) AdMob tarafından kabul edildiği bir panelde denenmedi. Belgeye göre alan adı kökündeki dosya yeterlidir, ancak Google'ın taramasının `github.io` alt alanları için ek kısıt koyup koymadığını belgeden doğrulayamadık. AdMob "Güncellemeleri denetle" adımı reddederse **kendi alan adı** al (yılda birkaç yüz TL), GitHub Pages'e bağla (depo Settings > Pages > Custom domain), kökünde `app-ads.txt` yayınla ve Play'deki web sitesini ona çevir; bu en sağlam yoldur.

## 6. Rıza (AB / Birleşik Krallık) ve gizlilik

Uygulama Google'ın rıza aracını (UMP) kullanır: ilk reklam isteğinden önce rıza bilgisi güncellenir; rıza gereken bölgelerde Google'ın formu bir kez çıkar. Kod yalnızca Google'ın `canRequestAds` sonucuna bakar: false ise istek atılmaz; true ise (ör. rıza verilmedi ama sınırlı reklam uygun) yalnızca UMP tercihlerine uygun türde reklam istenir. Bu, kullanıcının kişiselleştirmeyi onayladığı anlamına gelmez. Rıza gerekiyorsa Ayarlar > Hakkında'da "Reklam tercihleri" satırı görünür. **AdMob > Gizlilik ve mesajlaşma** bölümünden bir **Avrupa düzenlemeleri** mesajı oluşturup uygulamaya bağlaman gerekir; mesaj yoksa form çıkmaz. Türkiye'de rıza zorunlu değildir; uygulama reklamı kişiselleştirmeyi ayrıca kapatmaz (gizlilik sayfası bunu söyler). Sayfa: https://olgatanriverdi-glitch.github.io/yemekhane/gizlilik.html

iOS: reklam kimliği (IDFA) için App Tracking Transparency istemi bu sürümde yoktur; iOS yayını yapacaksan `NSUserTrackingUsageDescription` ve ATT isteği eklenmelidir. SKAdNetwork: Info.plist'e yalnızca Google'ın kendi kimliği (`cstr6suwn9.skadnetwork`) konuldu; Google'ın yayımladığı güncel tam listeyi (AdMob belgeleri > iOS > Başlarken) iOS yayınından önce ekle.

## 7. Engellenecek kategoriler (AdMob > Engelleme denetimleri > Genel kategoriler)

Öğrencilere yönelik bir uygulama olduğundan şu kategorileri engelle: **Alkol, Kumar ve bahis, Flört, Siyaset ve seçim, Din ve ruhani, Cinsel içerik / yetişkin, Dini ve siyasi kampanyalar, Mali hizmetler (ödünç para/kripto) ve sağlık/diyet vaatleri** isteğe bağlı. Uygulama ayrıca kod tarafında en çok "T" içerik derecesi ister (`maxAdContentRating`). Hassas kategori engelleri hesapta bir kez yapılır; doluluğu biraz düşürür.

## 8. Ödeme eşikleri ve gelir beklentisi

* AdMob ödeme eşiği genel olarak (ülkeye göre değişir; AdMob > Ödemeler sayfasında gör) yaklaşık 70 USD'dir; bakiye eşiğe ulaşınca ödeme sonraki ay yapılır. Ayrıca adres PIN'i (posta ile gelir) ve vergi bilgileri doldurulmalıdır, aksi halde ödeme bekler.
* **Gelir beklentisi (kesin rakam değil, TAHMİN):** Tek yerel reklam, günde birkaç kez görülen bir yemek uygulamasında, Türkiye'de 1000 gösterim başına gelir (eCPM) genelde çok düşüktür (kabaca 0,1-1 USD). Örneğin günlük 1000 aktif kullanıcı ve kullanıcı başı ortalama 2 reklam gösterimiyle ayda yaklaşık 60 bin gösterim olur; bu yaklaşık 6-60 USD/ay eder, yani eşiğe aylar sürebilir. İlk günlerdeki reklamsız süre, 2 sn bekleme ve kaydırılmayan reklamlar gösterimi daha da azaltır. Gerçek rakamlar AdMob panelinde görünür; buradakiler yalnızca büyüklük fikri verir.

## 9. Doğrulama listesi (yayından önce)

1. `--dart-define` ile gerçek birim kimliğiyle `.aab` derle; `android/key.properties`'te `admobAppId` olduğundan emin ol.
2. Birleşik manifestte `com.google.android.gms.ads.APPLICATION_ID` ve `com.google.android.gms.permission.AD_ID` olduğunu kontrol et: `app/build/app/intermediates/merged_manifests/release/` altındaki `AndroidManifest.xml`.
3. Play Console > Uygulama içeriği: **Reklamlar: Evet**, **Reklam kimliği: Evet (reklamcılık)**, Veri güvenliği tablosuna reklam satırlarını ekle (`LISTE.md`).
4. Kapalı testte gerçek bir cihazda reklamın "Reklam" etiketiyle öğün kartının altında açıldığını, yer ayırmadan yumuşakça belirdiğini gör. Bu görünüm gerçek cihazda henüz denenmedi: reklam şablonu Google'ın yerel kodudur ve test ortamında çalışmaz.
