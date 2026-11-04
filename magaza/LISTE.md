# Google Play mağaza listesi: Üni Yemek

Her alan Play Console'a olduğu gibi yapıştırılabilir. Karakter sınırları denetlendi. Metinler yalnızca uygulamada gerçekten olan özellikleri anlatır (4 Kasım 2026 sürümü, 0.1.0).

## Temel bilgiler

| Alan | Değer |
|---|---|
| Uygulama adı (en çok 30) | `Üni Yemek: Yemekhane Menüsü` (27 karakter) |
| Kısa açıklama (en çok 80) | `Üniversite yemekhane menüleri: öğle, akşam, vejetaryen. Kalori ve fiyat.` (72 karakter) |
| Paket adı | `com.tolga.yemekhane` (yayınlandıktan sonra DEĞİŞTİRİLEMEZ) |
| Varsayılan dil | Türkçe (tr-TR) |
| Uygulama türü | Uygulama (oyun değil) |
| Ücretsiz / ücretli | Ücretsiz (reklamsız, uygulama içi satın alma yok) |
| Kategori | Yemek ve İçecek (alternatif: Yaşam Tarzı) |
| Etiketler (en çok 5) | Yemek ve İçecek, Eğitim, Yaşam Tarzı |
| Reklam içeriyor mu | Hayır |
| E-posta (herkese açık) | `uniyemek0@gmail.com` (gizlilik sayfalarındaki adresle aynı olmalı) |
| Web sitesi | https://olgatanriverdi-glitch.github.io/yemekhane/ |
| Gizlilik politikası | https://olgatanriverdi-glitch.github.io/yemekhane/gizlilik.html |
| Hesap / veri silme adresi | https://olgatanriverdi-glitch.github.io/yemekhane/hesap-silme.html |

## Tam açıklama (4000 karakter altı)

```
Üni Yemek, üniversite yemekhanesinde bugün ne olduğunu tek bakışta gösterir. Okulunu seç, öğle, akşam ve vejetaryen menüye bak.

MENÜ
• Günlük menü: öğle, akşam ve vejetaryen seçenek (okulun yayınladığı kadarıyla)
• Her yemeğin kalorisi, günün toplam kalorisi, servis saatleri ve öğrenci fiyatı
• Yemekler için örnek fotoğraflar (Wikimedia Commons, açık lisanslı; fotoğraf sahibi ve lisansı ekranda yazar)
• Günler arasında kaydırarak geçiş; "Şimdi" şeridinde servisin başlamasına ya da bitmesine kalan süre
• Menü yayınlanma tarihi yaklaşınca ya da bitince uyarı
• İnternet yokken son indirilen menü açılır

ARA VE PLANLA
• Yemek ara: yemeğin adını yaz, şehirdeki ya da tüm okullardaki menülerde hangi gün olduğunu gör
• Haftalık menü: bir öğünün haftalık özeti, önceki ve sonraki haftalar
• Favori yemekler: kalbe dokun, favorin menüye geldiğinde ana ekranda şeritle haber ver
• Menüyü arkadaşlarınla paylaş (günlük ya da haftalık metin)

PUAN VE YORUM
• Yemeklere 1-5 yıldız puan ver, ortalama puanı gör
• Öğün ve yemek yorumlarını oku, kendi yorumunu yaz (hesap gerekmez, anonim takma adla)
• Başkasının yorumunu bildir ya da kişiyi engelle; yorum ve puanlarını tek dokunuşla sil

KİŞİSELLEŞTİR
• Açık, koyu ve siyah tema; 8 renk paleti
• İsteğe bağlı günlük kalori hedefi: öğünün hedefine oranını gösterir
• İsteğe bağlı günlük menü bildirimi (varsayılan kapalı, saatini sen seçersin)

GİZLİLİK
Reklam yok, konum ve kişi erişimi yok, ad ya da e-posta istenmez. Puan ve yorum için rastgele bir anonim kimlik kullanılır.

ÖNEMLİ NOT
Üni Yemek resmî bir kurum uygulaması değildir. Menüler okulların kendi sitelerinden otomatik derlenir; hatalı ya da eksik olabilir, önemli bilgiler için okulun duyurularına bak. Yemek fotoğrafları örnektir, okuldaki yemek birebir aynı görünmeyebilir.

Okulun listede yok mu? Tanıtım sitesindeki yorumlardan iste.
```

Eklemeden önce denetle: "8 renk paleti", "Siyah tema", "tüm okullar araması", "bildirim" ve "paylaş" özelliklerinin sürümde olduğu doğrulandı (kod ve testler). Okul sayısı bilerek yazılmadı: liste büyüyor.

## Görseller (magaza/ klasöründe)

| Play alanı | Dosya | Boyut |
|---|---|---|
| Uygulama simgesi | `gorseller/ikon-512x512.png` | 512x512, PNG |
| Öne çıkan görsel | `gorseller/one-cikan-gorsel-1024x500.png` | 1024x500, PNG |
| Telefon ekran görüntüleri (en az 2, en çok 8) | `ekranlar/01-...` ile `07-...` | 1170x2340 (oran 2:1), PNG |

Ekran görüntüleri gerçek uygulamanın gerçek verisiyle (Ankara Üniversitesi, 4 Kasım 2026 menüsü) çizildi; `app/tool/magaza_ekranlari_test.dart` ile yeniden üretilir. Her kenar 320-3840 px ve uzun kenar kısa kenarın en çok 2 katı olmalı: 1170x2340 tam 2:1 olduğu için sınırda ve geçerli. Önerilen sıra: 01 ana ekran, 02 yemek ayrıntısı, 04 haftalık menü, 03 yemek arama, 07 ana ekran (koyu), 05 tema, 06 ayarlar.
7 inç / 10 inç tablet ekran görüntüsü zorunlu değildir (tablet desteği isteğe bağlıdır).

## İçerik derecelendirme anketi (IARC) önerilen yanıtlar

Kategori: "Yardımcı program, üretkenlik, iletişim veya diğer" (oyun değil).

| Soru | Yanıt |
|---|---|
| Şiddet, kan, cinsel içerik, küfür (uygulamanın kendi içeriği) | Hayır |
| Kumar, uyuşturucu, alkol, tütün | Hayır |
| Kullanıcılar etkileşime girebilir mi / kullanıcı içeriği paylaşabilir mi | **Evet**: kullanıcılar herkese açık yorum yazabilir |
| Kullanıcılar konum paylaşabilir mi | Hayır |
| Dijital satın alma | Hayır |
| Kullanıcı içeriği için moderasyon | Evet: gönderim öncesi küfür/bağlantı süzgeci, yorum bildirme, kişi engelleme, bildirimlerin konsoldan incelenip silinmesi |

Beklenen sonuç: kullanıcı içeriği nedeniyle genel olarak "PEGI 3 / Everyone" olup "Kullanıcılar etkileşime girer" notu çıkar. Anket sonucunu Play'in verdiği şekilde kabul et.

Kullanıcı içeriği politikası için hazır olanlar: bildir menüsü, kişi engelleme, yorum süzgeci, kurallar notu, bildirilenleri konsoldan silme (bkz. `FIREBASE.md`). Bildirimleri en az haftada bir kontrol et.

## Veri güvenliği formu (kodla doğrulanmış)

Doğrulama: `app/lib/geri_bildirim.dart` (Firebase REST: anonim giriş, `ratings`, `comments`, `reports`, hesap silme), `app/lib/repository.dart` (GitHub'dan menü indirme), `app/android/.../AndroidManifest.xml` (izinler: internet, bildirim, yeniden başlatma sonrası bildirimi kurma, titreşim), `app/pubspec.yaml` (analitik, reklam ya da çökme raporu paketi yok).

Genel sorular:
* Uygulama veri topluyor mu / paylaşıyor mu: **Evet, topluyor.**
* Aktarım sırasında şifreleniyor mu: **Evet** (tüm istekler HTTPS).
* Kullanıcılar veri silme isteyebilir mi: **Evet.** Uygulama içi yol: Ayarlar > Hakkında > Yorum ve puanlarımı sil. Silme adresi: https://olgatanriverdi-glitch.github.io/yemekhane/hesap-silme.html
* Hesap oluşturma yöntemi: Hesap yok (anonim otomatik kimlik). "Uygulama hesap oluşturmaya izin vermiyor" ya da yalnızca anonim kimlik olduğunu belirt.

Toplanan veri türleri (yalnızca bunlar işaretlenir):

| Play veri türü | Toplanıyor | Paylaşılıyor | Zorunlu mu | Amaç | Not |
|---|---|---|---|---|---|
| Kişisel bilgiler > Kullanıcı kimlikleri | Evet | Hayır | Zorunlu (puan/yorum özelliğini kullanırken otomatik oluşur) | Uygulama işlevselliği, Hesap yönetimi | Firebase anonim UID; ad/e-posta ile bağlı değil |
| Uygulama etkinliği > Diğer kullanıcı tarafından oluşturulan içerik | Evet | Hayır | İsteğe bağlı | Uygulama işlevselliği | Yıldız puanları, yorum metni, takma ad, bildirim nedeni |

"Paylaşılıyor" için: Firebase (Google) veriyi bizim adımıza işleyen hizmet sağlayıcıdır; Play tanımına göre bu "paylaşım" sayılmaz. Yorumlar uygulamayı kullanan herkese gösterilir; bu, kullanıcının kendi başlattığı herkese açık yayındır. Gizlilik politikası bunu açıkça söyler.

İşaretlenmeyecekler (kodda yok): konum, kişiler, finansal bilgi, sağlık, mesajlar (SMS/e-posta), fotoğraf/video, ses, dosyalar, takvim, web geçmişi, uygulama performansı (çökme günlüğü yok), cihaz ya da diğer kimlikler (reklam kimliği yok), arama geçmişi (aramalar cihazda kalır).

Not: İstek sırasında IP adresi Google, GitHub ve Wikimedia sunucularında doğal olarak görünür; bu üçüncü taraf altyapı günlükleridir, uygulama IP'yi kendisi toplamaz ya da saklamaz. Play ile uyumlu olması için gizlilik politikasında bu üç hizmet adıyla belirtildi.

## Hedef kitle ve içerik

* Hedef yaş: **18 ve üzeri** (üniversite öğrencileri ve yetişkinler). 13 yaş altı seçme; "Aileler" programına girme. Gerekçe: uygulama kullanıcı içeriği barındırır ve çocuklara yönelik değildir. (Üniversite öğrencisi 17 yaşında olabilir; 18+ seçmek Play'in çocuk politikalarını tetiklemeden güvenli seçenektir. 16-17 yaşı da dahil etmek istersen "13+" yerine "16 ve üzeri" aralığını seç ama o zaman kullanıcı içeriği moderasyonunu daha sıkı sorgularlar.)
* Çocukları çekecek görsel/dil yok; reklam yok.
* Haber, sağlık, finans, devlet uygulaması beyanı: Hayır. Uygulama resmî bir kurum adına değil; ekranda ve açıklamada "resmî uygulama değildir" yazar. Kalori bilgisi okul menüsünden alınır, tıbbi tavsiye değildir (kalori hedefi ekranında uyarı var); "Sağlık" beyanı gerekmez.

## Kapalı test zorunluluğu (yeni kişisel geliştirici hesapları)

2023-11-13'ten sonra açılan **kişisel** geliştirici hesaplarında üretime çıkmadan önce **en az 12 test kullanıcısı, kesintisiz 14 gün** kapalı test yapılması gerekir (Play bu kuralı değiştirebilir; Play Console > Panel > "Üretime erişim iste" bölümünde güncel koşulu oku).

* Kapalı test kanalı aç, test kullanıcıları listesine en az 12 Gmail adresi ekle (liste yerine bir Google Grubu da olur), katılım bağlantısını paylaş.
* Testçilerin 12'si de 14 gün boyunca testte kalmalı (çıkan olursa sayı düşer; 15-20 kişi topla).
* 14 gün dolunca Console'da "Üretime erişim iste" formunu doldur (testten ne öğrendiğin, geri bildirim). Onay birkaç gün sürebilir.
* Organizasyon (şirket) hesabıysa bu şart yoktur.

## Sürüm notu (ilk yayın)

```
İlk sürüm: okulunun günlük yemek menüsü, kalori ve fiyat, yemek arama, favoriler, haftalık menü, puan ve yorum.
```
