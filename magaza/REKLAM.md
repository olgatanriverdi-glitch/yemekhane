# Reklam rehberi (Google AdMob): yeni başlayanlar için

Üni Yemek'te reklamlar içerikle birlikte kayan, "Reklam" etiketli ve "Üni Yemek'i ücretsiz tutar" açıklamalı yerel (native) kartlardır. Renk, köşe ve yazı boyutu etkin temadan gelir (açık, koyu, siyah ve bütün renk paletleri). **Her ekranda en fazla 1 reklam** vardır. Zorla gösterilen tam ekran (geçiş) reklamı, açılış reklamı, otomatik oynayan sesli video, yapışkan banner ve yemek satırlarının arasında reklam yoktur. Tek tam ekran reklam, kullanıcının kendi isteğiyle açtığı ödüllü "Reklamsız gün" reklamıdır. Orta boy yerel şablonda reklamverenin görseli ya da sessiz başlayan videosu bulunabilir. Web sürümünde reklam yoktur.

**Yerleşimler (4 tane):**

| Yerleşim | Nerede | Boyut / koşul |
|---|---|---|
| `ana` | Ana ekran, öğün kartının altı, "Öğün yorumları"ndan önce | Uzun ekranda (kullanılabilir yükseklik en az 700 dp ve yazı ölçeği en çok 1,3) görselli **orta** şablon (daha yüksek getiri); değilse **küçük** şablon. Aynı gün ve öğünde 2 sn kalınca yüklenir. |
| `hafta` | Haftalık menü, 3. gün kartından sonra | Küçük. Haftada 3'ten az kart varsa yok. |
| `arama` | Yemek arama, 5. sonuçtan sonra | Küçük. En az 8 sonuç varsa; sonuçlar 1 sn sabit kalınca yüklenir (yazarken istek atılmaz). |
| `detay` | Yemek ayrıntısı, yorumlardan sonra, sayfanın en altı | Küçük. |

Favoriler, ayarlar, tema seçici, ilk açılış karşılaması ve hata / boş / iskelet durumlarında reklam yoktur. İlk açılış günü ve sonraki **2 gün** reklam çıkmaz (uzaktan ayarlanabilir). Bir oturumda en çok 20 reklam yüklenir. Bellekte en çok 5 reklam tutulur. Reklamla komşu dokunulabilir öğeler arasında en az 16 dp boşluk vardır (yanlışlıkla tıklama olmasın).

**Reklamsız gün (isteğe bağlı, ödüllü reklam):** Kullanıcı Ayarlar'daki "Reklamsız gün kazan" satırından ya da reklam kartının altındaki "Reklamları 24 saat kapat" düğmesinden, kısa bir ödüllü reklam izleyerek **24 saat** hiç reklam görmemeyi seçebilir. Zorlama yoktur: ödül yalnızca izleme tamamlanınca verilir, vazgeçilirse ya da ödül gelmeden kapatılırsa hiçbir şey değişmez. Reklam yüklenemezse "Şu an reklam yok, sonra tekrar dene." yazar.

Tanımlayıcı olmadan alınan **release** derlemede reklam tamamen kapalıdır (SDK başlatılmaz, istek atılmaz, yer ayrılmaz); ödüllü özellik de gizlidir. Yani kimlik vermeden yaptığın bir `.aab` / `.apk` asla test reklamı göstermez; reklamlı sürüm için aşağıdaki adımları yap.

## 1. AdMob hesabı

1. https://admob.google.com adresine Play Console hesabındaki Google hesabınla gir, hesabı aç (ülke Türkiye, saat dilimi Istanbul, para birimi TRY ya da USD; sonradan DEĞİŞTİRİLEMEZ).
2. **Uygulamalar > Uygulama ekle**: platform Android, "Uygulama Google Play'de yayında mı?": henüz değilse **Hayır** (yayından sonra Play'e bağlarsın). Ad: `Üni Yemek`.
3. Oluşan **Uygulama kimliği** `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` biçimindedir (`~` işaretli). Not al.
4. **Reklam birimi ekle > Yerel gelişmiş (Native advanced)**: ad `yerel-satir-ici`. Oluşan **Reklam birimi kimliği** `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ` biçimindedir (`/` işaretli). Not al. Dört yerleşimin hepsi bu **tek** yerel birimi kullanır (şablon boyutu kodda seçilir). Uygulama kimliği ile birim kimliğini karıştırma.
5. **Reklam birimi ekle > Ödüllü (Rewarded)**: ad `reklamsiz-gun`. Ödül ayarı: 1 adet, ad "Reklamsız gün" (uygulama ödül değerini kullanmaz, bir şey fark etmez; "Ödül miktarı ve türü" alanını boş bırakmak yerine varsayılanı bırak). Kimliği not al (`/` işaretli).
6. iOS de yapacaksan aynı adımları iOS uygulaması için ayrıca tekrarla (yerel + ödüllü).

## 2. Kimlikler nereye yazılır

| Kimlik | Nereye | Nasıl |
|---|---|---|
| Android **uygulama** kimliği (`~`) | `app/android/key.properties` | `admobAppId=ca-app-pub-XXXX~YYYY` satırı ekle (dosya git'e girmez). Yoksa Google'ın test uygulama kimliği kullanılır. |
| Android **birim** kimliği (`/`) | derleme komutu | `--dart-define=ADMOB_NATIVE_ANDROID=ca-app-pub-XXXX/ZZZZ` |
| Android **ödüllü** birim kimliği (`/`) | derleme komutu | `--dart-define=ADMOB_ODULLU_ANDROID=ca-app-pub-XXXX/WWWW` |
| iOS uygulama kimliği | `app/ios/Runner/Info.plist` | `GADApplicationIdentifier` değerini değiştir (şu an Google test kimliği). |
| iOS birim kimliği | derleme komutu | `--dart-define=ADMOB_NATIVE_IOS=ca-app-pub-XXXX/ZZZZ` |
| iOS ödüllü birim kimliği | derleme komutu | `--dart-define=ADMOB_ODULLU_IOS=ca-app-pub-XXXX/WWWW` |

Birim kimlikleri koda yazılmaz, git'e girmez: yalnızca derleme komutunda verilir.

## 3. Derleme komutu

```bash
cd app
ANDROID_HOME=~/Library/Android/sdk ~/development/flutter/bin/flutter build appbundle --release \
  --dart-define=ADMOB_NATIVE_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ \
  --dart-define=ADMOB_ODULLU_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/WWWWWWWWWW
```

Aynı bayraklar `flutter build apk --release` için de geçerlidir. Yerel birim kimliğini vermezsen release'te reklam kapalı olur (güvenli varsayılan). Yalnızca ödüllü kimliği vermezsen reklamlar çalışır ama "Reklamsız gün" özelliği gizlenir. `flutter run` (debug) ile kimlik vermeden çalıştırırsan Google'ın herkese açık TEST reklamları (yerel ve ödüllü) görünür; test reklamlarına tıklamak güvenlidir.

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

Uygulama Google'ın rıza aracını (UMP) kullanır: ilk reklam isteğinden önce rıza bilgisi güncellenir; rıza gereken bölgelerde Google'ın formu bir kez çıkar. Kullanıcı Ayarlar > "Reklam tercihleri" formunu kapattığında rıza değişmiş olabilir: uygulama hazırlık sonucunu sıfırlar, bellekteki ve yüklenmekte olan reklamları geçersiz kılar ve bir sonraki reklam isteğinden önce rızayı yeniden denetler (rıza geri alındıysa reklam istenmez). Kod yalnızca Google'ın `canRequestAds` sonucuna bakar: false ise istek atılmaz; true ise (ör. rıza verilmedi ama sınırlı reklam uygun) yalnızca UMP tercihlerine uygun türde reklam istenir. Bu, kullanıcının kişiselleştirmeyi onayladığı anlamına gelmez. Rıza gerekiyorsa Ayarlar > Hakkında'da "Reklam tercihleri" satırı görünür. **AdMob > Gizlilik ve mesajlaşma** bölümünden bir **Avrupa düzenlemeleri** mesajı oluşturup uygulamaya bağlaman gerekir; mesaj yoksa form çıkmaz. Türkiye'de rıza zorunlu değildir; uygulama reklamı kişiselleştirmeyi ayrıca kapatmaz (gizlilik sayfası bunu söyler). Sayfa: https://olgatanriverdi-glitch.github.io/yemekhane/gizlilik.html

iOS: reklam kimliği (IDFA) için App Tracking Transparency istemi bu sürümde yoktur; iOS yayını yapacaksan `NSUserTrackingUsageDescription` ve ATT isteği eklenmelidir. SKAdNetwork: Info.plist'e yalnızca Google'ın kendi kimliği (`cstr6suwn9.skadnetwork`) konuldu; Google'ın yayımladığı güncel tam listeyi (AdMob belgeleri > iOS > Başlarken) iOS yayınından önce ekle.

## 7. Engellenecek kategoriler (AdMob > Engelleme denetimleri > Genel kategoriler)

Öğrencilere yönelik bir uygulama olduğundan şu kategorileri engelle: **Alkol, Kumar ve bahis, Flört, Siyaset ve seçim, Din ve ruhani, Cinsel içerik / yetişkin, Dini ve siyasi kampanyalar, Mali hizmetler (ödünç para/kripto) ve sağlık/diyet vaatleri** isteğe bağlı. Uygulama ayrıca kod tarafında varsayılan olarak yalnızca "G" içerik derecesi ister (`maxAdContentRating = G`; `data/ayarlar.json` > `reklam.maxIcerik` ile `PG`/`T`ye çıkarılabilir). Hassas kategori engelleri hesapta bir kez yapılır; doluluğu biraz düşürür.

## 8. Ödeme eşikleri ve gelir beklentisi

* AdMob ödeme eşiği genel olarak (ülkeye göre değişir; AdMob > Ödemeler sayfasında gör) yaklaşık 70 USD'dir; bakiye eşiğe ulaşınca ödeme sonraki ay yapılır. Ayrıca adres PIN'i (posta ile gelir) ve vergi bilgileri doldurulmalıdır, aksi halde ödeme bekler.
* **Gelir beklentisi (kesin rakam değil, TAHMİN):** Tek yerel reklam, günde birkaç kez görülen bir yemek uygulamasında, Türkiye'de 1000 gösterim başına gelir (eCPM) genelde çok düşüktür (kabaca 0,1-1 USD). Örneğin günlük 1000 aktif kullanıcı ve kullanıcı başı ortalama 2 reklam gösterimiyle ayda yaklaşık 60 bin gösterim olur; bu yaklaşık 6-60 USD/ay eder, yani eşiğe aylar sürebilir. İlk günlerdeki reklamsız süre, 2 sn bekleme ve kaydırılmayan reklamlar gösterimi daha da azaltır. v2'de dört yerleşim ve uzun ekranda görselli (orta) şablon gösterim başına geliri artırabilir, ödüllü reklam ise izleyen kullanıcıdan genelde tek gösterimde yerel karttan daha yüksek gelir getirir; ancak ödüllü reklamı izleyen kullanıcı 24 saat yerel reklam görmez, yani net etki belirsizdir. Bunlar tahmindir: kesin kazanç vaadi değildir, gerçek etkiyi AdMob'da yerleşim ve birim bazında izle. Gerçek rakamlar AdMob panelinde görünür; buradakiler yalnızca büyüklük fikri verir.

## 9. Doğrulama listesi (yayından önce)

1. `--dart-define` ile gerçek birim kimliğiyle `.aab` derle; `android/key.properties`'te `admobAppId` olduğundan emin ol.
2. Birleşik manifestte `com.google.android.gms.ads.APPLICATION_ID` ve `com.google.android.gms.permission.AD_ID` olduğunu kontrol et: `app/build/app/intermediates/merged_manifests/release/` altındaki `AndroidManifest.xml`.
3. Play Console > Uygulama içeriği: **Reklamlar: Evet**, **Reklam kimliği: Evet (reklamcılık)**, Veri güvenliği tablosuna reklam satırlarını ekle (`LISTE.md`).
4. Kapalı testte gerçek bir cihazda reklamın "Reklam" etiketiyle öğün kartının altında açıldığını, yer ayırmadan yumuşakça belirdiğini gör. Bu görünüm gerçek cihazda henüz denenmedi: reklam şablonu Google'ın yerel kodudur ve test ortamında çalışmaz.

## 10. Uzaktan ayar: yayından sonra reklamları açıp kapatma

Uygulama güncellemesi yayınlamadan reklamları yönetmek için depodaki **`data/ayarlar.json`** dosyası kullanılır (uygulamayla gelen yedeği `app/assets/data/ayarlar.json`). Bu dosyayı veri robotu (scraper) **değiştirmez ve silmez**; yalnızca sen GitHub'da düzenlersin. Uygulama dosyayı menüler gibi okur (internet, önbellek, uygulamayla gelen kopya) ve ilk açılış gününden sonra, reklam gösterilmeden önce bir kez bakar. Dosya yoksa ya da bozuksa uygulama güvenli varsayılanı kullanır (aşağıdaki değerler) ve hiç çökmez.

```json
{
  "reklam": {
    "aktif": true,
    "lutufGun": 2,
    "oturumSiniri": 20,
    "yerlesimler": { "ana": true, "hafta": true, "arama": true, "detay": true },
    "anaBuyuk": true,
    "odullu": true,
    "maxIcerik": "G"
  },
  "updated": "2026-11-08T12:00:00+03:00"
}
```

| Alan | Anlamı | Varsayılan |
|---|---|---|
| `aktif` | `false` yaparsan tüm reklamlar kapanır, Google SDK'sı hiç başlatılmaz. Acil durum düğmesidir. | `true` |
| `lutufGun` | İlk açılış gününden sonra kaç gün reklamsız (0-30). | `2` |
| `oturumSiniri` | Uygulama açıkken en çok kaç reklam yüklensin (0-200). | `20` |
| `yerlesimler` | `ana`, `hafta`, `arama`, `detay` tek tek `false` yapılarak kapatılır; yazılmayan yerleşim açık sayılır. | hepsi `true` |
| `anaBuyuk` | `false` yaparsan ana ekranda görselli orta şablon kullanılmaz, hep küçük şablon olur. | `true` |
| `odullu` | `false` yaparsan "Reklamsız gün" özelliği gizlenir. | `true` |
| `maxIcerik` | İstenen reklamların en yüksek içerik derecesi: `"G"` (herkese uygun; PEGI 3 / Everyone hedefi), `"PG"` ya da `"T"`. Bozuk ya da bilinmeyen değer `G` sayılır. Play'in içerik derecelendirmesi (IARC) sonucu G'den yüksek çıkarsa buradan yükseltirsin. **Hedef kitle yaşı (18+) bu ayardan bağımsızdır:** reklamlar uygulamanın içerik derecesine uygun olmalıdır; 18+ seçmek bunu kaldırmaz. | `"G"` |

Değişiklik, kullanıcıların cihazındaki önbelleğe bağlı olarak bir sonraki açılışlarında yürürlüğe girer. Anlık değildir. Bozuk bir alan (yanlış tür, aralık dışı sayı) yalnızca o alanın varsayılana dönmesine yol açar. Dosya adındaki `updated` alanı uygulamanın yeni kopyayı eski paket kopyasına tercih etmesi içindir: dosyayı değiştirince `updated` tarihini de güncelle.
