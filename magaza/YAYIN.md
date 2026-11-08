# Yayın rehberi: GitHub Pages + Google Play (yeni başlayanlar için)

Sıra önemlidir: önce web sitesi ve gizlilik sayfaları yayında olmalı, çünkü Play Console bu adresleri ister.

## 0. Başlamadan önce yapılacaklar (bir kez)

1. İletişim e-postası `uniyemek0@gmail.com` olarak uygulamaya, gizlilik sayfalarına ve `magaza/LISTE.md`ye işlendi. Bu kutuya bakmayı unutma: silme talepleri buraya gelir.
2. Sürüm: `1.0.0+2`.
3. Firebase kurallarını güncelle (aşağıda 1. adım). Bunu yapmazsan uygulamadaki yorum yazma, puan verme ve "Bildir" düğmeleri hata verir: yeni uygulama bu yazmaları sunucu zamanıyla yapar ve kurallar bunu bekler. Kuralları uygulamadan ÖNCE yayınla ve 5 senaryoyu dene (`FIREBASE.md`).

## 1. Firebase kuralları (5 dakika)

1. https://console.firebase.google.com → `yemekhane` projesi → **Build → Firestore Database → Rules**.
2. Bu depodaki `firestore.rules` dosyasının TAMAMINI kopyalayıp yapıştır → **Publish**.
3. Bildirimleri görmek için: Firestore Database → Data → `reports`. Ayrıntı: `FIREBASE.md`.

## 2. GitHub Pages ile siteyi yayınla

Site ve web uygulaması `.github/workflows/pages.yml` ile otomatik yayınlanır (`main` dalına her gönderimde).

1. GitHub'da depoya git → **Settings → Pages** → "Build and deployment" altında **Source: GitHub Actions** seç (bir kez).
2. Değişiklikleri `main` dalına gönder (push). **Actions** sekmesinde "Siteyi yayınla" yeşil olunca site açılır.
3. Şu adresleri tarayıcıda aç, ikisi de açılmalı ve iletişim adresi `uniyemek0@gmail.com` görünmeli:
   * https://olgatanriverdi-glitch.github.io/yemekhane/gizlilik.html
   * https://olgatanriverdi-glitch.github.io/yemekhane/hesap-silme.html
   * https://olgatanriverdi-glitch.github.io/yemekhane/kurallar.html (topluluk kuralları; uygulamadaki metinle aynı)
4. Flutter sürümü `pages.yml` içinde `3.47.6` olarak sabit (yerelde `flutter --version` ile aynı). Yerel Flutter'ı yükseltince oradaki sürümü de güncelle.

## 3. İmza anahtarı (EN ÖNEMLİ UYARI)

Uygulamayı imzalayan anahtar `~/.android-anahtar/yemekhane.jks` dosyasındadır; şifreleri `app/android/key.properties` içindedir (ikisi de git'e girmez).

* **Bu iki dosyayı şimdi yedekle:** USB bellek ya da şifreli bulut klasörü, en az iki ayrı yere. Anahtar dosyasını VE şifrelerini birlikte sakla.
* Anahtarı kaybedersen uygulamayı bir daha GÜNCELLEYEMEZSİN (yeni uygulama açıp kullanıcıları taşımak gerekir).
* Play Console'da yüklerken "Play Uygulama İmzalama" önerilirse **kabul et**: sen "yükleme anahtarı" ile imzalarsın, asıl imza anahtarını Google saklar; yükleme anahtarını kaybedersen Google'a başvurup sıfırlatabilirsin. Yine de yedek al.
* Anahtarı sohbet, e-posta ya da GitHub'a koyma.
* Anahtarın parmak izi (Play'de karşılaştırma gerekirse): SHA-256 `A0:70:51:6A:C1:D8:11:67:2F:67:96:36:AC:81:B9:CF:C4:00:78:7B:CF:83:CC:2B:88:4B:46:FC:4F:DB:03:35` (sahibi: `CN=Uni Yemek, O=Tolga, C=TR`).

## 4. Yayın paketini üret

```bash
cd app
ANDROID_HOME=~/Library/Android/sdk ~/development/flutter/bin/flutter build appbundle --release
```

Çıktı: `app/build/app/outputs/bundle/release/app-release.aab` (Play'e bu yüklenir; ~56 MB). Test için doğrudan telefona kurulacak APK: `flutter build apk --release` → `app/build/app/outputs/flutter-apk/app-release.apk`.

Her yeni yüklemede `app/pubspec.yaml` içindeki `version: 1.0.0+2` değerinin `+` sonrası (sürüm kodu) **artmalıdır** (`+2`, `+3`...). Aynı kodla ikinci yükleme reddedilir. `+` öncesi (0.1.0) kullanıcının gördüğü sürümdür; değiştirirsen `app/lib/config.dart` içindeki `uygulamaSurumu` ile aynı tut (test bunu denetler).

## 5. Play Console hesabı

1. https://play.google.com/console → geliştirici hesabı aç (tek seferlik 25 USD kayıt ücreti, kimlik doğrulaması). Kişisel hesap seçersen **kapalı test şartı** geçerlidir (`LISTE.md` en altı).
2. **Uygulama oluştur:** ad `Üni Yemek: Yemekhane Menüsü`, dil Türkçe, uygulama, ücretsiz, bildirimleri kabul et.

## 6. Uygulama içeriği formları (Panel → "Uygulamanı ayarla")

Hepsi için hazır yanıtlar `magaza/LISTE.md` içinde:

1. **Gizlilik politikası:** gizlilik.html adresi.
2. **Reklamlar:** **Evet** (Google AdMob). Reklam kimliği beyanı: Evet (reklamcılık). Gerçek reklam kimlikleriyle derleme adımı (yerel + ödüllü birim, iki `--dart-define`): `REKLAM.md`; kimlik verilmeden alınan release'te reklam kapalıdır ve test reklamı çıkmaz. Yayından sonra reklamı kapatıp açmak için `data/ayarlar.json` (`REKLAM.md` bölüm 10).
   **app-ads.txt ZORUNLU** (yeni AdMob uygulamaları, Ocak 2025'ten beri): `olgatanriverdi-glitch.github.io` adlı herkese açık bir depo aç, kökünde `app-ads.txt` yayınla (örnek: `magaza/app-ads.txt.ornek`, `pub-` kimliğini AdMob'dan al), Play Console'da geliştirici **Web sitesi** alanına aynı alan adını (`https://olgatanriverdi-glitch.github.io`) yaz, AdMob'da **Uygulamayı doğrula > Güncellemeleri denetle** de. Doğrulanmadan reklam tam açılmaz. Ayrıntı ve "doğrulanmadı" notu: `REKLAM.md` bölüm 5.
3. **Uygulama erişimi:** Tüm işlevler özel erişim olmadan kullanılabilir.
4. **İçerik derecelendirme:** anket (kullanıcı içeriği: Evet). Sonuç, reklam içerik filtresiyle uyumlu olmalı (varsayılan G; farklıysa `data/ayarlar.json` > `reklam.maxIcerik`).
5. **Hedef kitle:** 18 ve üzeri (içerik derecesinden ayrı bir seçimdir; reklamlar yine uygulamanın içerik derecesine uymalıdır).
6. **Veri güvenliği:** LISTE.md tablosu; silme adresi `hesap-silme.html`.
7. **Haber / COVID / Devlet / Finans beyanları:** Hayır. **Sağlık uygulamaları beyanı:** formu DOLDUR (sağlık özelliği olmayan uygulamalar da doldurur); günlük kalori hedefi özelliği nedeniyle "Beslenme ve kilo yönetimi" sorusunu `LISTE.md` "Hedef kitle ve içerik" bölümündeki yönlendirmeye göre yanıtla. **İzinler:** Reklam kimliği Evet; ön plan hizmeti kullanımı yok (`LISTE.md` "İzin beyanları").
8. **Kullanıcı tarafından oluşturulan içerik:** Play sorarsa moderasyon yolları yazılı: ilk yorumdan önce topluluk kuralları kabulü, yorumu ve yazarını bildir, kişiyi engelle, süzgeç, sunucuda oran sınırı, konsoldan silme.

## 7. Mağaza girişi (Büyüyüp gelişme → Mağaza varlığı → Ana mağaza girişi)

* Ad, kısa ve tam açıklama: `LISTE.md`.
* Simge: `magaza/gorseller/ikon-512x512.png`.
* Öne çıkan görsel: `magaza/gorseller/one-cikan-gorsel-1024x500.png` (alfasız 24 bit PNG).
* Telefon ekran görüntüleri: `magaza/ekranlar/*.png` (1170x2340, alfasız 24 bit PNG, en az 2; önerilen sıra `LISTE.md`'de).
* Kategori: Yemek ve İçecek; iletişim e-postası, web sitesi.

## 8. Test ve üretim

1. **Test → Kapalı test** kanalı aç → `.aab` dosyasını yükle → test kullanıcıları (en az 12 e-posta) ekle → yayınla → katılım bağlantısını testçilere gönder. 14 gün kesintisiz sürmeli.
2. Süre dolunca **Panel → Üretime erişim iste** formunu doldur; onaylanınca **Üretim** kanalına aynı `.aab`'yi (ya da sürüm kodu artmış yenisini) yükle → incelemeye gönder (birkaç gün sürebilir).
3. Yayınlandıktan sonra: Firestore `reports` koleksiyonunu haftada bir kontrol et (`FIREBASE.md`).

## Sık karşılaşılan sorunlar

* **"Sürüm kodu zaten kullanıldı":** `pubspec.yaml` içindeki `+N` değerini artır, yeniden derle.
* **"Gizlilik politikası adresi açılmıyor":** Pages ayarı Source: GitHub Actions mı, Actions sekmesi yeşil mi bak; GitHub Pages ilk yayında birkaç dakika sürebilir.
* **Ekran görüntüsü reddedildi:** her kenar 320-3840 px, uzun kenar kısa kenarın en çok 2 katı olmalı; mevcut görseller 1170x2340 ile tam sınırda geçerlidir. Reddedilirse `app/tool/magaza_ekranlari_test.dart` içindeki pencere yüksekliğini (780) bir miktar azaltıp yeniden üret.
* **Ekran görüntüsü 1080 px:** Play'in "öne çıkarılma" tavsiyesi uzun kenar için büyük görsel ister; mevcutlar kısa kenarda 1170 px olduğundan yeterlidir.
* **Bildirim izni:** Android 13+ cihazlarda bildirim ayarı açılırken izin istenir; reddedilirse anahtar kapalı kalır.
* **Uygulama güncellemesi sonrası eski kullanıcı verisi:** yedekleme kapalı olduğundan (manifest `allowBackup=false`) telefon değişiminde oturum ve engel listesi taşınmaz; bu bilinçli bir tercihtir.
