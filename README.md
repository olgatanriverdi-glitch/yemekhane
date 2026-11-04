# Üni Yemek

Üniversite yemekhane menülerini **öğle / akşam / vejetaryen** olarak gösteren mobil uygulama.
Üniversiteler: Ankara Üniversitesi, Gazi, Hacettepe, Ankara Yıldırım Beyazıt (AYBÜ), ODTÜ, Ankara Hacı Bayram Veli (AHBVÜ), Ankara Sosyal Bilimler (ASBÜ) ve
Ankara Müzik ve Güzel Sanatlar (MGÜ), Eskişehir Osmangazi (ESOGÜ), Eskişehir Teknik (ESTÜ), İstanbul'dan İstanbul Üniversitesi (İÜ), İTÜ, Boğaziçi (BÜ), Marmara (MÜ), Galatasaray (GSÜ) ve
Mimar Sinan Güzel Sanatlar (MSGSÜ), İzmir'den Ege (EÜ), Dokuz Eylül (DEÜ) ve İzmir Katip Çelebi (İKÇÜ), Antalya'dan Alanya Alaaddin Keykubat (ALKÜ), Çanakkale Onsekiz Mart (ÇOMÜ),
Sivas'tan Sivas Bilim ve Teknoloji (SBTÜ) ve Sivas Cumhuriyet (CÜ), Erzurum'dan Atatürk Üniversitesi, Trabzon'dan Karadeniz Teknik (KTÜ) ve Trabzon Üniversitesi,
Samsun'dan Ondokuz Mayıs (OMÜ) ve Samsun Üniversitesi, Gebze Teknik (GTÜ), Sakarya (SAÜ), Çukurova (ÇÜ), Bursa Uludağ (BUÜ), Pamukkale (PAÜ), Gaziantep (GAÜN), Süleyman Demirel (SDÜ), Aydın Adnan Menderes (ADÜ), İnönü (İnÜ), Karabük (KBÜ), Muğla Sıtkı Koçman (MSKÜ), Afyon Kocatepe (AKÜ), Trakya (TÜ), Harran (HRÜ), Van Yüzüncü Yıl (YYÜ), Düzce (DÜ), Sakarya Uygulamalı Bilimler (SUBÜ), Bursa Teknik (BTÜ), Necmettin Erbakan (NEÜ), Kayseri (KAYÜ), Nevşehir Hacı Bektaş Veli (NEVÜ), Kırşehir Ahi Evran (KAEÜ), Aksaray (ASÜ), Niğde Ömer Halisdemir (NÖHÜ), Çankırı Karatekin (ÇAKÜ), Kastamonu (KÜ), Sinop (SİNÜ), Amasya (AÜ), Tokat Gaziosmanpaşa (TOGÜ), Ordu (ODÜ), Giresun (GRÜ), Bayburt (BAYÜ), Kafkas (KAÜ), Ardahan (ARÜ), Muş Alparslan (MAUN), Bingöl (BÜ), Munzur (MÜ), Siirt (SİÜ), Şırnak (ŞÜ), Adıyaman (ADYÜ), Kilis 7 Aralık (KİYÜ) ve Hatay Mustafa Kemal (HMKÜ). **Toplam 100 okulun hepsi devlet üniversitesidir.** P9: Osmaniye Korkut Ata, Kahramanmaraş Sütçü İmam, Tarsus, Adana Alparslan Türkeş Bilim ve Teknoloji, Burdur Mehmet Akif Ersoy, Isparta Uygulamalı Bilimler ve Uşak da eklidir. Başka üniversiteler eklenti olarak eklenir.

## Mimari (sunucusuz, bedava)

```
okul sitesi (XLSX/HTML) ──► scraper (Python) ──► data/*.json (GitHub'da) ──► Flutter uygulaması
                              ▲ GitHub Actions günde 3 kez çalıştırır
```

* `scraper/` — ayrıştırıcılar Python standart kütüphanesini kullanır; robot güncel TLS kökleri için `certifi` de kurar. Her üniversite `scraper/yemekhane/universities/` altında bir eklentidir.
* `data/` — üretilen statik JSON. Uygulama bunu `raw.githubusercontent.com` / GitHub Pages üzerinden okur.
* `app/` — Flutter uygulaması (iOS + Android).

### TLS doğrulaması ve canlı kontrol (4 Kasım 2026)
Okul istekleri (POST kullanan Sakarya/İstiklal dahil) `universities/base.py::indir` üzerinden geçer. Sistem köklerine varsa `certifi` kökleri eklenir.
Eksik zincirde TLS 1.2 Certificate iletisi yalnız sertifika/AIA keşfi için okunur; bu bağlantıda HTTP isteği gönderilmez. `caIssuers` adreslerinden DER/PEM/PKCS#7
ara sertifikaları indirilir ve ana makine/port bazında bellekte tutulur. İndirme, ara sertifikalar `load_verify_locations(cadata=...)` ile eklenerek **tam TLS doğrulamasıyla** tekrarlanır.
İndirilen öz imzalı kökler güven kaynağı yapılmaz; `PARTIAL_CHAIN` kapalıdır. Alan adı, süre ve imza zinciri kontrol edilir; zincir sistem veya certifi kökünde bitmelidir.
Munzur'un sunucuda gönderdiği Sectigo R46 öz imzalı kökü bu kuralla eklenmez; güncel certifi köküyle doğrulama başarılıdır. Güvenilir kökte bitmeyen zincir hata olarak kalır.
Yalnız `DH_KEY_TOO_SMALL` hatasında aynı isteğe özel `DEFAULT@SECLEVEL=1` denenir; sertifika doğrulaması açık kalır ve sonraki isteğe taşınmaz. Bu sözdizimi OpenSSL içindir;
eski LibreSSL desteklemez. Keşif bağlantısı TLS 1.2 gerektirir; TLS 1.3 ile normal doğrulamalı indirmeler bundan etkilenmez.

Son tam tarama: Python 3.15.0 / OpenSSL 3.5.9 ile **100/100**, Python 3.9.6 / LibreSSL 2.8.3 ile **99/100** okul veri üretti.
İki taramada da `SSL_CERT_FILE` tanımlanmadı; certifi 2026.10.23 kullanıldı. Eski LibreSSL'de yalnız Batman `TLSV1_ALERT_PROTOCOL_VERSION` nedeniyle erişilemiyor;
aynı okul güncel OpenSSL'de çalıştı. GitHub Actions / Ubuntu / Python 3.12 doğrudan çalıştırılmadı. Ağsız **497 test** her iki Python sürümünde geçti.
Canlı sonuç ve kaynak kapsamı ayrıntıları `.claude/notlar/yemekhane-universite-durumu.md` sonundadır; deneme çıktıları yalnız geçici klasöre yazıldı.

`build.py`, birikimli eski kayıtlar ve günlük eklenen kalemler dahil bütün menüleri `temizle.py` ile yayın öncesinde temizler. Yemek adındaki kalori/gramaj/tarih artıkları
çıkarılır; tek ve açık kalori `kcal` alanına taşınır. Birden fazla seçenek/aralık tek kaloriye çevrilmez; bu durumda yanıltıcı öğün toplamı da kaldırılır.
Bayram/tatil satırları ve KTÜ'nün dört hücreye bölünmüş kutlaması yemek yerine `note` olur. `Hamburger Menü` ve yemek karşılığı içeren parantezler korunur.

### Yemek fotoğrafları
Her yemek adı için Wikimedia Commons'ta telifi serbest (CC) bir örnek görsel aranır (`scraper/yemekhane/dishes.py`), 320 px kare JPEG olarak
`data/dishes/` altında saklanır; aynı adlı yemek tekrar aranmaz, bulunamayan 14 günde bir yeniden denenir. Kaynak/yazar/lisans `data/dishes/index.json`'dadır.
Menüdeki her yemek öğesine `"img": "dishes/<anahtar>.jpg"` eklenir. Görseller yalnızca örnektir; yanlış eşleşmeyi önlemek için arama katıdır
(bulunamazsa fotoğraf yerine sade bir simge gösterilir).

### Servis saatleri ve yemek puanları
`data/index.json` içinde her üniversite için `hours` (öğün -> `{"t": "11:30–14:00", "approx": false}`) bulunur. Okul saati yayınlıyorsa (Hacettepe, AYBÜ, ODTÜ, ASBÜ, MGÜ) oradan okunur;
yayınlamıyorsa tipik saat (öğle 11:00–14:00, akşam 17:00–19:00) `approx: true` ile gelir ve uygulamada "Genelde …" yazar.
Menüdeki her yemek öğesine `key` eklenir (yemek adından türeyen kimlik). Uygulama puanları bu anahtarla yemek bazlı tutar (`y_<üniversite>_<key>`), tarihten bağımsız.

### Menüyü yalnızca resim olarak yayınlayan okullar (ODTÜ, ASBÜ, DEÜ, GTÜ, Trabzon Üniversitesi)
* **ODTÜ** aylık menüyü PDF içinde taranmış JPEG olarak yayınlar. Menü iki yoldan gelir: `scraper/yemekhane/elle_veri/odtu.json` (resimden elle girilmiş ve
  her günün toplam kalorisiyle doğrulanmış günler) ve GitHub Actions'ta tesseract ile PDF'in okunması. OCR'ın okuduğu bir gün yalnızca kalemlerin kalorisi
  yazılı toplama eşitse kabul edilir; elle girilmiş günler önceliklidir, OCR yalnızca girilmemiş günleri doldurur. Actions logunda
  `ODTÜ OCR: ...` satırları OCR'ın kaç günü okuduğunu ve elle girilenle ne kadar örtüştüğünü gösterir.
* **ASBÜ** aylık görselin yanında `webapi.asbu.edu.tr/webapi/Yemekhane/getGununYemegi` günlük JSON'unu yayınlar. JSON elle veriye eklenir; `birikimli = True` önceki günleri korur.
  `v-` önekli yemek normal ana yemeğin vejetaryen karşılığıdır. 4 Kasım canlı JSON'u aylık görselle karşılaştırıldı: normal 988, vejetaryen 746 kcal. Kasım görseli yayımlanmıştır;
  elle dosyada Ekim korunur, Kasım otomatik birikimi 4 Kasım'dan başlar. Aylık görselin gelecek günleri otomatik okunmaz; API boş/hatalıysa elle veri korunur.
* **DEÜ** (`sks.deu.edu.tr/yemek-menusu/`, normal liste -> öğle, vegan liste -> vejetaryen; kalem kalorisi yok, günün toplamı var), **GTÜ** (`gtu.edu.tr` 'Yemek Listesi' sayfasındaki `EKİM 2026 MENÜ.jpg`, 7-8 kalem ve
  kalem kalorisi) ve **Trabzon Üniversitesi** (`sks.trabzon.edu.tr/S/8978`, Excel ekran görüntüsü; her günün toplamı kalem toplamıyla doğrulandı) menüyü her ay yeni bir resim olarak koyar. Üçü de `ElleUniversite`
  sınıfından türer ve menüleri `elle_veri/deu.json`, `gtu.json`, `trabzon.json` dosyalarından okur. **Her ay başında** (Kasım, Aralık...) okul yeni resmi yayınlayınca bu dosyalara yeni ayın günleri eklenmelidir;
  aksi halde ay bitince okul uygulamada boş görünür. Tesseract'ın yerel olarak kurulu olmadığı bu üç okulda otomatik okuma denenmedi.
  **GTÜ 4 Kasım güncellemesi:** tam aylık Kasım dosyası yerine 2–6 Kasım haftalık görseli yayımlanmış; beş gün `gtu.json`'a eklenmiştir. Dosya adı `03 - 06.11.2026 Haftalık Menü Güncel.png`
  olsa da görsel 2 Kasım'ı da içerir. Seçenekli iki yan yemek ayrı kalemdir, toplam kalorileri üretilmez. 6 Kasım'dan sonrası için yeni görsel elle eklenmelidir.
* `elle_veri/<id>.json` biçimi `data/<id>/menu.json` ile aynıdır (`{"days": {"2026-10-01": {"lunch": {...}}}}`).

### Metin tabanlı PDF yayınlayan okullar (ESTÜ, ÇOMÜ, Samsun Üniversitesi)
`scraper/yemekhane/pdf.py`, Word vb. çıkışlı PDF'lerden konumlu metin çıkarır (yalnızca standart kütüphane; ToUnicode tablolarıyla Türkçe harfler doğru gelir; 2 baytlı literal dizgiler ve dolaylı `/Font N 0 R` sözlükleri desteklenir).
`sayfa_metinleri(..., ctm=True)` `q/Q/cm` dönüşümlerini uygular (Canva çıkışlı PDF'lerde her metin bloğu kendi matrisiyle yazılır), `satirlari_birlestir` karakter karakter yazılmış metni satırlara toplar.
ESTÜ'nün aylık menüsü böyle bir PDF'tir: sütunlar haftanın günlerine göre ortak bir ızgaradan bulunur (tek tek başlıklara güvenilmez; bayram günlerinde başlık yoktur),
adı `*` ile biten satır etsiz alternatiftir. Taranmış (resim) PDF'lerde metin yoktur, onlar için OCR gerekir (ODTÜ).

### İstanbul okulları: veri kaynakları
* **İÜ:** `sks.istanbul.edu.tr/meals-by-date?date=...&category=breakfast|lunch|dinner|vegan` JSON'u gün gün sorgulanır (`vegan` -> vejetaryen öğün). Ücret yalnızca taranmış karar olarak yayınlandığı için yok.
* **İTÜ:** ana sayfadaki menü çerçevesinin kaynağı (`bilgiekrani.itu.edu.tr/.../yemek-menu.aspx?tip=itu-ogle-yemegi-genel&&value=6.10.2026`) gün gün sorgulanır; menü ~2 hafta ileriye yayınlanır.
  Bu adres okulun 'uzerinde-calisilan' (üzerinde çalışılan) klasöründedir: yer değiştirirse İTÜ okunamaz hale gelir. Saat ve ücret `sks.itu.edu.tr` tablolarından okunur.
* **Boğaziçi:** eski `aylik-menu/YYYY-AA` adresi 404 verir. Yeni `tr/calendar` görünümünün `tr/json_calendar?type=&date=YYYY-AA-01&last_date=YYYY-AA-GG` JSON'u kullanılır; Kasım'da 30 gün öğle/akşam vardır.
  Yeni aylık JSON vegan karşılığı ve kalori yayınlamaz; bunlar tahmin edilmez. **Marmara:** `sks.marmara.edu.tr/yemek` haftalık tablolar (normal + alternatif ana yemek, vejetaryen).
* **GSÜ:** yalnızca öğlen PDF'i okunur (akşam PDF'inde harfler eksik, vegan PDF'lerinin düzeni farklı); satır girdi sayısı gün sayısına uymayan haftalar atlanır.
* **MSGSÜ:** aylık PDF'in adresi WordPress medya API'sinden bulunur.

### İzmir, Antalya, Çanakkale, Sivas, Erzurum, Trabzon, Samsun ve Gebze okulları: veri kaynakları
* **OMÜ:** 'Günün Yemeği' penceresindeki `<table class='gununyemegi'>` artık tarih/yemek başlıklarını dikey verir; eski aylık biçim de desteklenir. Günlük kaynak nedeniyle `birikimli = True`; 4 yemek, kalori yok. **SBTÜ:** `www.sivas.edu.tr/yemek-listesi`,
  sekmeli (öğün türü) haftalık kartlar, kalemli kalori (seçmeli yemek `a/b` + `262/285 kal` ayrı öğe olur ve günün toplamı yazılmaz). **Sivas Cumhuriyet:** `cumhuriyet.edu.tr/yemeklistesi/index.php` takvim ızgarası; içinde
  bulunulan günün hücresi tarih yerine 'BUGÜN' yazar (tarih komşu hücrelerden çıkarılır), tatil hücresinde 'RESMİ TATİL' yazar.
* **KTÜ:** `sks.ktu.edu.tr/yemeklistesi` (ktu.edu.tr bunu iframe ile gösterir) tablosu; hücrelerde kalori ve alerjen kodları (`(1,4)`) vardır, `/` ile ayrılan seçenekler ayrı öğe olur, 'Kalorisi' sütunu anlamsızdır (`-5000`).
* **Ege:** `sksdb.ege.edu.tr/tr-8417/aylik_yemek_menuleri.html` her öğün için bir Word (.docx) dosyası listeler; dosya içinde Pazartesi-Pazar takvim tablosu vardır (hafta sonu da servis var). Dosyada ay/yıl yazmaz: ay bağlantı
  metninden, yıl ayın 1'inin düştüğü sütundan bulunur (tutmuyorsa dosya eski yıldandır, atlanır). Alınanlar: öğle, akşam, vejetaryen öğle; kahvaltı eski `.DOC` biçiminde olduğu için alınmıyor.
* **ÇOMÜ:** `sks.comu.edu.tr/tr/sayfa/yemek-listesi-65.html` ekler listesindeki iki Canva PDF'i (normal ve vegan -> vejetaryen). Metin gerçek metindir ama her karakter ayrı konumlandığı için `pdf.sayfa_metinleri(ctm=True)` ile sayfa
  koordinatları alınır; hücreler başlık sütunundan/satırından bulunur. `KASIM - 2026` başlığı desteklenir; Kasım PDF'leri 2–27 Kasım'da 20 gün içerir (30 Kasım kaynakta yoktur).
  Servis saati PDF'ten okunur. **Samsun Üniversitesi:** `sks.samsun.edu.tr/yemek-listesi/` sayfasının bağlandığı aylık Excel PDF'i (kalemli kalori ve toplam).
* **ALKÜ** (`sksdb.alanya.edu.tr` carousel'i, yalnızca içinde bulunulan hafta), **İKÇÜ** (`ikcu.edu.tr/yemeklistesi`, yalnızca bugün+yarın, yılsız tarih) ve **Atatürk Üniversitesi** (SKS ana sayfasındaki 'Bugün/Yarın' kartları,
  yalnızca 'Merkez Yemekhane') geçmiş tutmaz: bu eklentiler `birikimli = True`'dur, `build.py` önceki çalıştırmalarda kaydedilen günleri (`data/<id>/menu.json`) yeni veriyle birleştirir. Robot günde 3 kez çalıştığı için
  her gün yakalanır; ilk çalıştırmada yalnızca o günler vardır.

### P1 partisi okulları (Sakarya, Çukurova, Bursa Uludağ, Pamukkale, Gaziantep): veri kaynakları
* **Sakarya:** `menu.sabis.sakarya.edu.tr` (SABİS, giriş gerekmez). `POST /Home/GetirAylikMenu` (`year`, `month`, `diyetMi=false`) kart ızgarası HTML'i döner; başlıkta yıl yok, kalori satırın `title` özniteliğinde
  ('Kalori: 160'; 0 = bilinmiyor). Okul öğün adı yazmaz, günde tek liste olduğu için öğle sayılır; diyet menüsü alınmaz. Bu, okulun bilgi sistemi uç noktasıdır: adres/parametre değişirse bozulur.
* **Çukurova:** `yemekhane.cu.edu.tr` ana sayfasındaki 'Aylık Liste' (sayfa Windows-1254 kodlu); tek öğün (öğle), kalemli kalori ve 'Toplam' var.
* **Bursa Uludağ:** `uludag.edu.tr/yemek` aylık sekmeleri: Öğrenci öğle -> lunch, Öğrenci akşam -> dinner, Vejetaryen öğle -> vegetarian; kalori yok, alerjen numaraları ('(1,3,4)') atılır, 'RESMİ TATİL' günü tatil notu olur. Personel menüsü alınmaz.
* **Pamukkale:** `www.pau.edu.tr/pau/tr/yemekMenuleri` yalnızca güncel haftayı (5 iş günü) gösterir (`birikimli = True`). 'Yemekhane' -> lunch (akşam bloğu varsa dinner), 'Vejetaryen' -> vegetarian; Turuncu Salon, Konuk Evi, Tekno Kafe vb. alınmaz.
* **Gaziantep:** `www.gaziantep.edu.tr/yemek/` (`gantep.edu.tr` buraya yönlenir) sayfasındaki aylık tablo; tek öğün, kalemli kalori ('MEYVE (ŞEFTALİ 72 kcal)' biçimi desteklenir).

### P2 partisi okulları (Süleyman Demirel, Aydın Adnan Menderes, İnönü, Karabük): veri kaynakları
* **Süleyman Demirel:** `w3.sdu.edu.tr/aylik-yemek-listesi` (`yemekhane.sdu.edu.tr` buraya yönlenir) 'Tarih / Öğle / Akşam' tablosu; öğle -> lunch, akşam -> dinner. Parantezdeki kalori öğünün toplamıdır (kalem kalorisi yok); '-' yazan günler (resmî tatil/yarım gün) atlanır.
* **Aydın Adnan Menderes:** `www.adu.edu.tr/tr/yemek-listesi` 'Bu Hafta' + 'Önümüzdeki Hafta' kartları; tek öğün (öğle), kalori yok, yalnızca iki hafta göründüğü için `birikimli = True`.
* **İnönü:** `www.inonu.edu.tr/yemek` Vue ile çizilir; veri `panel.inonu.edu.tr/servlet/food?type=list&date=YYYY-MM-DD` JSON'undan gelir (gün başına bir istek; bugünden 2 gün önce - 3 hafta sonra taranır, `birikimli = True`). Kalem kalorisi ('250 kalori') var; `food_type` 'G' dışındaki kayıtlar alınmaz. Bu, okulun site API'sidir: adres değişirse bozulur.
* **Karabük:** `sks.karabuk.edu.tr` ana sayfasındaki 'Aylık Yemek Listesi' bağlantısı aylık tek sayfalık gerçek-metin PDF'ine gider (dosya adı ay değişince değişir, bağlantı sayfadan okunur).
  Ekim'in sözcüklü tarihleri ve Kasım'ın `02.11.2026 PAZARTESİ` başlıkları, boşluklu kalorileri desteklenir. Kasım PDF'i 2–30 Kasım, 21 gün olarak iki Python sürümünde canlı doğrulandı; TLS ortak indiriciden geçer.

### P3 partisi okulları (1 Kasım 2026): veri kaynakları
P3'te altı okul eklendi; tamamı tek liste yayınlar ve öğle (`lunch`) olarak alınır. Kaynakta ayrı akşam/vejetaryen öğün bulunmadığından bu öğünler üretilmez.

* **Muğla Sıtkı Koçman:** `www.mu.edu.tr/tr/yemek` aylık HTML listesi; 2–30 Kasım arasında 20 gün. Kaynak 6 Kasım'ı yayınlamamış, o gün doldurulmaz. Kalori alanları boş ve toplam `0 cal` olduğundan kalori bilinmiyor sayılır. Menü kısaltmaları açılır.
* **Afyon Kocatepe:** `skultur.aku.edu.tr/2025/08/29/yemek-listesi/` sayfasındaki güncel PDF bağlantısı izlenir (sayfanın 2025 tarihli olması dosyanın tarihini göstermez). Kasım 2026 gerçek metin PDF'i, haftalık tarih aralıkları ve beş gün sütunuyla okunur; 2–27 Kasım, 20 gün, kalem ve toplam kalori. PDF'te 30 Kasım yok. **Kırılgan:** yalnız Kasım 2026 düzeniyle denendi; tarih aralığı/hafta sütunları değişirse kontrol edilmeli.
* **Trakya:** `www.trakya.edu.tr/yemeklistesi` varsayılan **Merkez Kampüsler** aylık HTML kartları; 2–30 Kasım, 21 gün. Kalori kartın toplamıdır; hastane ve ilçe kampüsleri alınmaz.
* **Harran:** `www.harran.edu.tr/idari/daire-baskanliklari/saglik-kultur-ve-spor-daire-baskanligi/baglantilar/yemek-menusu` aylık HTML tablosu; 2–30 Kasım, 21 gün. Yemek satırının altındaki satır kalem kalorilerini içerir. İki ana yemek **seçenekli** olduğundan her ikisinin kalorisi korunur ama günlük toplam üretilmez. **Kırılgan:** yemek/kalori satırlarının eşleşmesine bağlıdır.
* **Van Yüzüncü Yıl:** `www.yyu.edu.tr/yemek-listesi` tarihli HTML kartları; 2–5 Kasım, 4 gün, kalem ve toplam kalori. **Kırılgan:** yalnız birkaç gün yayınlanır; `birikimli = True` ile önceki günler korunur.
* **Düzce:** `duzce.edu.tr/sayfa/1B29/yemek-menusu` içindeki `data-menu-date` tarihli HTML kartları; Kasım listesi henüz yok, en güncel Ekim menüsü 22 gün (1–30 Ekim, 29 Ekim tatil notu dahil). Kalori yayınlanmaz. Ana yemek seçenekleri tek öğle listesinde korunur; `veya` ayıracı yemek sayılmaz, alternatifler ayrı vejetaryen öğün olarak etiketlenmez. **Kırılgan:** sayfanın kimlikli adresi ve kart öznitelikleri değişebilir.

Altı kaynak Python 3.9'da TLS doğrulaması açık ve `SSL_CERT_FILE=/etc/ssl/cert.pem` ile canlı okundu. Veriler geçici klasörde `YEMEK_ARAMA_LIMIT=0` ile üretildi; yalnız yeni okullar kopyalandı, mevcut okul menüleri ve `data/dishes` değiştirilmedi. Ağsız kontroller: `scraper/tests/test_p3_okullar.py` (kırpılmış gerçek HTML bölümleri ve AKÜ'nün tek sayfalık PDF'i).

### P4 partisi okulları (1 Kasım 2026): veri kaynakları
**P4 bitti, sırada P5.** Yedi okul, tatil notları dahil toplam 121 tarihli kayıt eklendi. Yedisinin de yayınlanan menüsü öğle (`lunch`) listesidir; etsiz/seçenekli yemeklerden ayrıca vejetaryen öğün üretilmez. Kasım bulunmayan kaynaklarda en güncel Ekim listesi alınır.

* **Sakarya Uygulamalı Bilimler (`subu`):** [SKS Merkez Yemek Menüsü](https://sks.subu.edu.tr/tr/merkez-yemek-menusu) aylık HTML takvimi; 1–30 Ekim, 22 tarih (28–29 Ekim tatil). Tarih satırı ve altındaki beş sütunlu yemek satırı eşleştirilir. Kalori yayınlanmaz. İlçelerin farklı listesi karıştırılmaz.
* **Bursa Teknik (`btu`):** [SKS ana sayfasındaki Yemek Listesi](https://sks.btu.edu.tr/tr) bağlantısı ay değişince izlenir; [erişilebilir Ekim PDF'i](https://depo.btu.edu.tr/img/sayfa/1790775471_eb123e325ccad93461c3.pdf) gerçek metindir. 1–30 Ekim, 22 tarih (29 Ekim tatil), beş yemek hücresi ve öğün toplam kalorisi. Hücredeki `/` ana yemek seçenekleri birlikte korunur. Kaynak 9 Ekim için yemek adları yerine beş hücrede de “Antep Günü” yazar. **Kırılgan:** PDF sütun sınırları yalnız Ekim 2026 düzeniyle denendi. Beslenme alt sayfasındaki daha yeni menü bağlantısı bu kontrolde 404 verdi; eklenti SKS ana sayfasının çalışan bağlantısını kullanır. Öğrenci saati ve katkı payı beslenme sayfası/ücret PDF'inden okunur.
* **Necmettin Erbakan (`neu`):** [Kampüs Kart](https://kampuskart.erbakan.edu.tr/) uygulamasının girişsiz [aylık menü JSON'u](https://yemekhane-api.erbakan.edu.tr/api/webogrenci/aylikmenu); 2 Kasım–4 Aralık, 24 gün (Kasım'da 20 gün, Aralık'ın ilk dört günü). 26 Kasım kaynakta yok, doldurulmaz. Kalem kalorisi `0` ise bilinmiyor sayılır; tüm kalemler bilinmiyorsa toplam hesaplanmaz. 5 Kasım kaydında öğün adı boş/kimliği `0`, tek standart liste olduğu için öğle kabul edilir. Özel menüler alınmaz; API alan adları değişirse kontrol gerekir.
* **Kayseri (`kayseri`):** [SKS Yemek Listesi](https://sksd.kayseri.edu.tr/tr/i/1-2/yemek-listesi) haftalık HTML başlıkları ve listeleri; 2–6 Kasım, 5 gün. Kalori yoktur. `birikimli = True`; öğrenci servis saati aynı sayfadaki tablodan okunur.
* **Nevşehir Hacı Bektaş Veli (`nevsehir`):** [SKS Aylık Menü](https://sks.nevsehir.edu.tr/tr/aylik-menu) HTML'ine gömülmüş `menuVerileri` JSON dizisi; JavaScript çalıştırılmadan ayrıştırılır. 26 Ekim–13 Kasım, 15 tarih (28–29 Ekim tatil), öğün toplam kalorisi. Yorumdaki örnek menüler alınmaz. Vejetaryen sekmesi kapalı ve ilgili alanlar `-`; ayrı vejetaryen öğün yok. **Kırılgan:** dizi adı/alanları ve son virgüllü JSON düzeni; birkaç haftalık pencere için `birikimli = True`. Öğrenci ücretleri resmî ücret tablosundan okunur.
* **Kırşehir Ahi Evran (`ahievran`):** [SKS Yemek Listesi](https://idari.ahievran.edu.tr/sksdb/yemek/yemek-listesi/tr/118) tarihli HTML tablosu; 23 Ekim–6 Kasım, 11 tarih (28–29 Ekim tatil), kalem ve toplam kalori. “Aylık Liste” başlığı yaklaşık iki haftalık pencere içerir, `birikimli = True`. Alerjen açıklamaları yemek adından ayrılır; kapanmayan kalori parantezleri de okunur. Öğrenci rezervasyonlu/rezervasyonsuz ücretleri resmî tablodan alınır. **Kırılgan:** yerel Python'da sistem sertifika dosyasıyla da TLS zinciri doğrulanamadı; veri doğrulaması açık `curl` indirmesinden üretildi. Robot ortamındaki TLS henüz denenmedi.
* **Aksaray (`aksaray`):** [SKS Yemek Listesi](https://sks.aksaray.edu.tr/yemek-listesi) aylık HTML tablosu; 1–30 Ekim, 22 tarih (29 Ekim tatil). Kalem ve yazılı toplam kalori korunur; kaynaktaki toplam/kalem farkı düzeltilmez. **Kırılgan:** kaynak `02.10.206` ve `09.06.2026` yazıyor; bu iki kayıt başlığın Ekim 2026 ay/yılı, komşu tarihler ve hafta günüyle doğrulanarak 2 ve 9 Ekim'e alınır. Bozuk kalori parantezi ve iki hücreye bölünmüş tatil yazısı desteklenir.

Yeni ayrıştırıcıların 39 ağsız testi `scraper/tests/test_p4_okullar.py` içindedir (kırpılmış gerçek HTML/JSON ve tek sayfalık PDF fixture'ları). Tüm 257 test hem Python 3.9.6'da hem varsayılan Python 3.15.0'da geçti. Son dağıtım verisi Python 3.9.6 ile, gerçek curl indirmeleri kullanılarak geçici klasörde `YEMEK_ARAMA_LIMIT=0` ile üretildi; yalnız yeni okul menüleri ve `photos/index.json` kopyalandı. Mevcut okul menüleri ve `data/dishes` korundu; indeks ve asset kayıtları klasörler oluşturulduktan sonra eklendi. TLS doğrulaması kapatılmadı. Flutter ve GitHub Actions çalıştırılmadı.

### P5 partisi okulları (1 Kasım 2026): veri kaynakları
**P5 bitti, sırada P6.** Beş okul, toplam 112 tarihli kayıt eklendi: 104 yemek menüsü ve Sinop'un 8 hafta sonu tatil notu. Beşinin de tek listesi öğle (`lunch`) kabul edilir; ayrıca akşam veya vejetaryen menü üretilmez. Aylık kaynaklar olduğu için `birikimli = False`.

* **Niğde Ömer Halisdemir (`ohu`):** [resmî Yemek Menüsü](https://www.ohu.edu.tr/yemekmenu), aylık HTML tablosu; 2–30 Kasım, 21 gün. Dört yemek ve son yemeğin ardından yazılan öğün toplam kalorisi okunur; `--` yer tutucuları atılır. `GARNİ.SOSLU` kısaltması açılır; kalem kalorisi yayınlanmaz.
* **Çankırı Karatekin (`karatekin`):** [resmî Aylık Yemek Listesi](https://www.karatekin.edu.tr/yemek-listesi), HTML kartları; en güncel dolu ay 1–30 Ekim, 21 gün. [ÇAKÜ Portal](https://cakuportal.karatekin.edu.tr/admin/meal/list) Kasım 2026 için boş kartlar gösteriyor. **Kırılgan:** ana sayfa 2021'den başlayan yaklaşık 3 MB arşivi tek yanıtta veriyor; indirme yavaşlayabiliyor ve kısa zaman aşımında kesilebiliyor. Eklenti arşivden yalnız son dolu ayı alır. 13–16 Ekim'de kalori yoktur; diğer günlerde kalem/yazılı toplam korunur. Seçenekli ana yemek tek kalemdir; 29 Ekim kaynakta yoktur. 30 Ekim'in son yemeği canlı HTML'de **Cacık** olarak yazılıdır.
* **Kastamonu (`kastamonu`):** [resmî Yemek Listesi](https://www.kastamonu.edu.tr/tr/yemeklistesi), HTML'e gömülü Next.js JSON'u; 2–27 Kasım, 20 gün. `self.__next_f.push` dizgileri JSON olarak çözülür, JavaScript çalıştırılmaz. Yalnız `yemekhaneId=1` Merkezi Yemekhane alınır; Konukevi ve Parlayan Yıldız listeleri karıştırılmaz. Kalem kalorileri okunup toplanır; `Ç.` ve `TAV.` açılır. 30 Kasım kaynağın merkez listesinde yoktur. Aynı sayfadan öğrenci ücreti 50 TL, öğle 11:30–13:30 ve akşam 16:30–18:00 servis saatleri okunur; tek menü akşam öğününe çoğaltılmaz. **Kırılgan:** Flight dizgi biçimi ve menü alanları değişirse kontrol gerekir.
* **Sinop (`sinop`):** [SKS Yemek Listesi](https://sksdb.sinop.edu.tr/yemek-listesi/), aylık HTML tablosu; 2–30 Kasım, 29 kayıt (21 menü, 8 hafta sonu tatili). 1 Kasım'ın `Bilgi Yok` kaydı atılır. Öğün toplam kalorisi korunur; `Mevye` yazımı `Meyve` olarak düzenlenir. 26 Kasım'da yalnız üç yemek vardır, dördüncü eklenmez.
* **Amasya (`amasya`):** [herkese açık Yemek Listesi](https://yemek.amasya.edu.tr/yemek-listesi-public) görünümünün [aylık JSON isteği](https://yemek.amasya.edu.tr/api/hizli-menu/taslak?yil=2026&ay=11); 2–30 Kasım, 21 gün. Menü görünümünün kullandığı GET isteği giriş/çerez gerektirmez. Dört yemek ve öğün toplam kalorisi okunur; sıfır/eksik kalori bilinmiyor sayılır. Güncel ay boşsa önceki aya bakılır, Ocak/Aralık geçişi desteklenir. **Kırılgan:** adresinde `taslak` geçen uç public sayfanın da kaynağıdır; URL/`gunler` alanları değişirse kontrol gerekir.

34 yeni ağsız test `scraper/tests/test_p5_okullar.py` içindedir; altı kırpılmış gerçek HTML/JSON fixture'ı kullanılır. **291 test, OK**: Python 3.9.6 ve 3.15.0. Sinop ve Amasya'nın ilk yerel canlı Python denemesi zaman aşımı verdi, sırayla yapılan tekrar okumaları geçti. Niğde ve Kastamonu ilk okumada geçti; Çankırı'nın büyük arşivi ilk Python okumasında 180 saniye sonunda zaman aşımı verdi. Veri TLS doğrulaması açık `curl -L -A "Mozilla/5.0"` indirmelerinden üretildi. `SSL_CERT_FILE=/etc/ssl/cert.pem` kullanıldı, TLS doğrulaması kapatılmadı. Python 3.9.6 ile `YEMEK_ARAMA_LIMIT=0` ve geçici build klasörü kullanıldı; yalnız beş yeni okulun `menu.json` ve `photos/index.json` dosyaları kopyalandı. Eski menüler ve `data/dishes` korundu; indeks ve asset satırları klasörler oluştuktan sonra eklendi. Flutter, gerçek fotoğraf araması/OCR ve GitHub Actions çalıştırılmadı; commit/push yapılmadı.

### P6 partisi okulları (1 Kasım 2026): veri kaynakları
**P6 bitti, sırada P7.** Dört okul, toplam 86 tarihli kayıt eklendi: 84 yemek menüsü ve Ordu/Bayburt'un birer 29 Ekim tatil kaydı. Dördünün de tek listesi öğle (`lunch`) kabul edilir; aylık kaynaklar nedeniyle `birikimli = False`.

* **Tokat Gaziosmanpaşa (`gop`):** [Sosyal Tesisler Aylık Menü](https://sosyaltesisler.gop.edu.tr/arasayfa_detay.aspx?arasayfaID=16) sayfasından güncel [Kasım PDF'i](https://sosyaltesisler.gop.edu.tr/images/update/KASIM%2026%20L%C4%B0STE%20%283%29.pdf) dinamik bulunur. 2–30 Kasım, 21 gün; dört yemek, kalem kalorileri ve yazılı öğün toplamı. Kafe/restoran menüsü alınmaz. **Kırılgan:** PDF'te yıl yazmaz; yakın yıl, tüm gün/hafta günü başlıklarıyla doğrulanır. Uzun yemek adları küçük punto ve yarım birim kaymış konumla yazılmıştır; satırlar 1–4 numaralarından eşleştirilir. Yalnız Kasım 2026 düzeniyle denendi.
* **Ordu (`odu`):** [SKS ana sayfasındaki Yemek Listesi](https://sksdb.odu.edu.tr/) bağlantısının [Ekim PDF'i](https://sksdb.odu.edu.tr/files/other/yemeklisteleri/ekim2026.pdf), iki sayfalık gerçek metin. 1–30 Ekim, 22 tarih (21 menü + 29 Ekim tatili); PDF'e taşan 28–30 Eylül alınmaz. Altı yemek hücresi ve hücre içindeki seçenekler korunur; kalori yayınlanmaz. [Yemekhane Hizmetleri](https://sksdb.odu.edu.tr/Page/62/yemekhane_hizmetleri) öğrenci öğle saatini 11:30–13:00, akşamı 16:30–18:30 verir; sayfanın güncellenme tarihi 2022'dir. Tek menü ayrıca akşam öğününe çoğaltılmaz. **Kırılgan:** parçalanmış tarihler, bir birim yukarı taşan hücre satırları ve sütun sınırları; yalnız Ekim 2026 düzeniyle denendi.
* **Giresun (`giresun`):** [SKS ana sayfasının](https://sksdb.giresun.edu.tr/) bağladığı [Kasım PDF'i](https://sksdb.giresun.edu.tr/Files/ckFiles/sksdb-giresun-edu-tr/KASIM%202026%20YEMEK%20MEN%C3%9C.pdf), tek sayfalık gerçek metin. 2–30 Kasım, 21 gün; dört yemek. 13 günde tek toplam kalori vardır; 8 günde iki alternatifin toplamları farklıdır ve tek sayıya çevrilmeden kaynak notunda korunur (ör. 880/905 kcal). Kalem kalorisi uydurulmaz. **Kırılgan:** her PDF `BT` bloğu ayrı okunur; sarılmış ana yemek ve enerji satırları aynı hücrede birleştirilir. Ortak `pdf.py` değiştirilmedi. Ücret sayfasının 2026 PDF'i yalnız resim olduğundan ücret okunmadı.
* **Bayburt (`bayburt`):** [resmî Yemek Menüsü](https://bayburt.edu.tr/tr/food-menu) görünümünün kullandığı [aylık dosya JSON'u](https://apiportal.bayburt.edu.tr/api/web/other/yemekmenu/getmonltyinfo/tr) güncel [Ekim PDF'ine](https://apifile.bayburt.edu.tr/file/portal/yemekuploads/262A9C2C-9EF1-4A8E-8BD7-646C293F0764.pdf) bağlanır. 1–30 Ekim, 22 tarih (21 menü + 29 Ekim tatili). Günlük API 1–2 Kasım'da boş olsa da aylık kaynak okunur. PDF'te kalori yoktur; farklı günlük kaydın kalorisi taşınmaz. **Kırılgan:** API'nin yazımı `getmonltyinfo`, `response.upload_object.filepath` alanı ve beş sütunlu PDF düzeni; imzalar tablonun altından ayıklanır. Yalnız Ekim 2026 düzeniyle denendi.

34 yeni ağsız test ve dokuz gerçek fixture (üç kırpılmış menü bağlantısı HTML'i, bir servis saati HTML'i, aylık JSON ve dört menü PDF'i). **325 test, OK**: Python 3.9.6 ve 3.15.0. Dört okulun canlı Python 3.9 okuması ilk turda geçti; `SSL_CERT_FILE=/etc/ssl/cert.pem` kullanıldı, TLS doğrulaması kapatılmadı. Son veriler gerçek `curl -L -A "Mozilla/5.0"` indirmelerinden, Python 3.9 ve `YEMEK_ARAMA_LIMIT=0` ile geçici `scratchpad/codex-p6/uretilen39` klasöründe üretildi. Yalnız dört yeni okulun `menu.json` ve `photos/index.json` dosyaları kopyalandı. Mevcut 840 veri/asset dosyasının SHA-256 kontrolü geçti; `data/dishes` korunur. İndeks ve pubspec kayıtları okul klasörleri hazırlandıktan sonra en son eklenir. Her okulun üretimi `scratchpad/codex-p6/ilerleme.md` dosyasına hemen kaydedildi. Flutter, gerçek fotoğraf araması/OCR ve GitHub Actions çalıştırılmadı; commit/push yapılmadı.

### P7 partisi okulları (1 Kasım 2026): veri kaynakları

**P7 bitti, sırada P8.** Beş okul eklendi; toplam 65 devlet üniversitesi. Yeni 70 tarihli kaydın 67'si yemek menüsü, üçü tatil notudur. Tamamı öğle (`lunch`) listesidir. Kafkas'ın dört haftalık, Muş'un haftalık kaynağı `birikimli = True`; diğer üç okul aylık tablo/JSON arşivi yayınlar.

* **Kafkas (`kafkas`):** [SKS ana sayfasındaki Yemek Listesi](https://www.kafkas.edu.tr/skdb) bağlantısından [güncel metin PDF'i](https://www.kafkas.edu.tr/belgeler/65d827f1-34d4-4749-991b-9fa7f77d0bdf..pdf) dinamik bulunur. 19 Ekim–13 Kasım, 19 tarih: 18 menü + 28 Ekim yarım gün/tatil notu. Dört yemek, 72 kalem kalorisi ve toplamlar doğrulandı. 29 Ekim hücresinin bayram yazısı yalnız resim olduğu için o hücre eklenmez. İkinci sayfa glutensizdir; normal/vejetaryen menüye katılmaz. **Kırılgan:** tek `TJ` dizisi birden fazla günün metnini taşır; CID `/W` genişlikleriyle sütunlar ayrılır. Yalnız bu dört haftalık PDF düzeniyle denendi; ortak `pdf.py` değiştirilmedi.
* **Ardahan (`ardahan`):** [yemek otomasyonunun](https://yemek.ardahan.edu.tr/) girişsiz [GET `/api/menus` JSON arşivi](https://yemek.ardahan.edu.tr/api/menus) okunur; en güncel ay seçilir. Kasım'da şu an 2–4 Kasım olmak üzere üç normal menü var. Sitede günlük görünüm olsa da API geçmiş ayları da tuttuğundan günlük isteklerle tarama/birikim gerekmez. Güncel günlerin kalorileri `0/null`, bilinmiyor sayılır; eski kayıtlardaki kalem ve toplam kaloriler ayrıştırılabilir. Çölyak listesi vejetaryen değildir, alınmaz. **Kırılgan:** `type`, `date`, `calories_json`, `totalCalories` alanları; 29 Ekim'de yalnız çölyak tatil kaydı bulunduğundan normal menüye taşınmaz.
* **Muş Alparslan (`alparslan`):** [yeni SKS Haftalık Yemek Menüsü](https://nsks.alparslan.edu.tr/sayfa/50/haftalik-yemek-menusu) sayfasının [güncel metin PDF'i](https://nsks.alparslan.edu.tr/uploads/nsks/belge/EKiM_4_1792756301_6adb4a4de2db5.pdf), 26–30 Ekim: dört menü + 29 Ekim Cumhuriyet Bayramı notu. Eski SKS sitesi 12–16 Ekim dosyasına bağlıdır; yeni site kullanılır. İki ana yemek seçmelidir; beş kalem ve kalem kalorileri korunur, iki alternatif toplanmaz. Mevsim Salata'nın kalorisi kaynakta yoktur. [Öğrenci ücreti](https://nsks.alparslan.edu.tr/sayfa/53/universitemizde-alinan-yemek-ucretleri) HTML tablosundan 35 TL okunur. **Kırılgan:** beş sütun, parçalanmış tarih/sözcük/kalori; yalnız ilk menü sayfası okunur, sonraki alerjen/tarif sayfaları alınmaz. İki Ekim haftasıyla denendi.
* **Bingöl (`bingol`):** [SKS Yemek Listesi](https://sks.bingol.edu.tr/yemek-listesi), aylık HTML tablosu; 2–30 Kasım, 21 gün, dörder yemek. Yalnız bazı kalemlerde kalori vardır; eksik kalemlerle toplam üretilmez. 25 Kasım'ın `Ayran 60-70 KCAL` aralığı tek sayıya dönüştürülmeden öğün notunda korunur. Kısaltmalar açılır; garnitürler ana yemeğin adında kalır.
* **Munzur (`munzur`):** [SKS Yemek Listesi](https://sks.munzur.edu.tr/yemek-listesi), aylık HTML tablosu; 1–30 Ekim, 22 tarih (21 menü + 29 Ekim tatili). Kasım henüz yayınlanmamıştır. Ayrı hücrelere yazılan `RESMİ` / `TATİL` birleştirilir; masaüstü/mobil tablo kopyaları tek kayıt olur. Kalori yayınlanmaz.

35 yeni ağsız test ve dokuz gerçek fixture `scraper/tests/test_p7_okullar.py` içindedir. HTML/JSON'lar kırpılmıştır; Muş'un iki PDF'i fontlar korunarak menü sayfasına indirgenmiştir, Kafkas'ın iki sayfası glutensiz listeyi dışlama kontrolü için korunur. **360 test, OK**: Python 3.9.6 ve 3.15.0. Beş okul canlı Python 3.9 okumasında geçti; Muş ilk turda zaman aşımına uğradı, sıralı tekrarında menü ve ücret okundu. `SSL_CERT_FILE=/etc/ssl/cert.pem` kullanıldı; TLS doğrulaması kapatılmadı.

Veriler gerçek `curl -L -A "Mozilla/5.0"` indirmelerinden, Python 3.9 ve `YEMEK_ARAMA_LIMIT=0` ile `scratchpad/codex-p7/uretilen39` altında üretildi. Yalnız yeni beş okulun `menu.json` ve boş `photos/index.json` dosyaları iki veri klasörüne kopyalandı; üretimlerin hemen ardından `scratchpad/codex-p7/ilerleme.md` güncellendi. Eski 938 veri/asset dosyasının SHA-256 kontrolü geçti; mevcut okul menüleri ve `data/dishes` değişmedi. İndeksler ve pubspec asset satırları okul klasörleri hazırlandıktan sonra en son eklenir; pubspec'teki diğer işçinin paketleri korunur. İndirmeleri okuyan yardımcı Python komutları `-I` ile çalıştırıldı. Flutter, gerçek fotoğraf araması/OCR ve GitHub Actions çalıştırılmadı; commit/push yapılmadı.

### P8 partisi okulları (1 Kasım 2026): veri kaynakları

**P8 bitti, sırada P9.** Beş okul eklendi; toplam 70 devlet üniversitesi. Yeni 66 tarihin 65'inde yemek menüsü, birinde tatil notu vardır. Adıyaman'da öğle ve akşam, diğer dört okulda yalnız öğle (`lunch`) okunur. Adıyaman günlük kaynak olduğundan `birikimli = True`; diğerleri aylık listelerdir.

* **Siirt (`siirt`):** [resmî Yemek Listesi](https://www.siirt.edu.tr/yemeklistesi.html), ay seçicili HTML. Kasım'da şu an yalnız **2 Kasım**, dört yemek ve 850 kcal yayımlanmış. Ekim'in 22 tarihli listesi de ay seçici formundan indirilip test edildi; 28 ve 29 Ekim'in `TATİL` kayıtları korunur. **Kırılgan:** yıl yazmaz; seçili ay ve gün numarasına bugüne en yakın yıl atanır. Kasım verisi Ekim ile birleştirilmez; yayımlanmamış gün eklenmez.
* **Şırnak (`sirnak`):** [SKS aylık arşivinden](https://sks.sirnak.edu.tr/tr/menu/yemek-listesi/4533) [en güncel metin PDF'i](https://sks.sirnak.edu.tr/file/menuFiles/ekim-2026-yemek-listesi_8120e87b-1f8f-4592-b6ee-8b1cbaf7a02e.pdf) dinamik seçilir. Kasım henüz yok; **1–30 Ekim, 22 tarih** (21 menü + 29 Ekim resmî tatili). Beş sütun tarih başlıklarının konumlarıyla ayrılır; her menü dört kalemdir. Yedi gün tek toplam kalori taşır; 14 günün seçeneklere göre iki toplamı notta korunur, toplanmaz. [2026 ücret PDF'inden](https://sks.sirnak.edu.tr/file/menuFiles/2026-yemek-ucretleri_f6d7c13c-e955-466a-b96b-7989fd5d8c6e.pdf) öğrenci **30 TL** okunur. **Kırılgan:** yalnız Ekim 2026 PDF düzeniyle denendi; ortak `pdf.py` değiştirilmedi.
* **Adıyaman (`adiyaman`):** [SKS Yemek Menüsü](https://sksdb.adiyaman.edu.tr/tr/yemekhane/yemek-menusu), günlük HTML; şu an **2 Kasım**, dört öğle + dört akşam yemeği. Sütun sırası [resmî CSS'in](https://static.adiyaman.edu.tr/css/style.min.css?v0408) mobil `Öğle` / `Akşam` etiketleriyle doğrulandı. Kaynaktaki `kcal kcal` yer tutucusu bilinmeyen kaloridir. Ana site ve “Aylık” bağlantısı da aynı günlük sayfayı gösterir; tarihli kayıtlar biriktirilir. **Kırılgan:** iç içe `mt-meals` / `item` div'leri ve sütun sırası.
* **Kilis 7 Aralık (`kilis`):** [SKS Yemek Listesi](https://sks.kilis.edu.tr/tr/page/5088), aylık öğle HTML tablosu; Kasım henüz yok, **1–30 Ekim, 21 menü**. Hafta sonu ve 29 Ekim hücreleri boştur, menü/tatil kaydı yapılmaz. Kalori yayımlanmaz. Kısaltmalar açılır; açık yazım hataları (SOYE, ŞEKERPARRE, BÖRREK, FASÜLYE) düzeltilir. [Beslenme sayfasından](https://sks.kilis.edu.tr/tr/page/5065) öğrenci öğle saati **11:00–13:00** okunur; personelin 12:00–13:00 saati alınmaz.
* **Hatay Mustafa Kemal (`mku`):** [Yemekhane Aylık Yemek Listesi](https://yemekgosterim.mku.edu.tr/home/yemekhane), HTML kartları; **2–30 Kasım, 21 gün**, dörder yemek ve kalem/toplam kalorileri. Havuzbaşı restoranının listesi alınmaz. **Kırılgan:** `menu-card`, `tarih`, `menu-list` sınıfları; kartta yazılı toplam korunur.

38 yeni ağsız test `scraper/tests/test_p8_okullar.py` içindedir. Sekiz kırpılmış gerçek HTML/CSS fixture'ı ve Şırnak'ın iki tek sayfalık metin PDF'i kullanılır; tam kaynaklarla fixture çıktılarının eşitliği doğrulandı. **398 test, OK**: Python 3.9.6 ve 3.15.0. Beş okulun canlı Python 3.9 okuması ilk turda geçti; `SSL_CERT_FILE=/etc/ssl/cert.pem` ile TLS doğrulaması açık kaldı.

Veriler gerçek `curl -L -A "Mozilla/5.0"` indirmelerinden, Python 3.9 ve `YEMEK_ARAMA_LIMIT=0` ile `scratchpad/codex-p8/uretilen39` altında üretildi. Yalnız yeni beş okulun `menu.json` ve boş `photos/index.json` dosyaları iki veri klasörüne kopyalandı; her üretimden hemen sonra `scratchpad/codex-p8/ilerleme.md` güncellendi. Mevcut okul menüleri ve `data/dishes` SHA-256 ile korundu. İndekslere yalnız yeni kayıtlar, pubspec'e yalnız klasörler hazırlandıktan sonra yeni asset satırları en son eklenir; diğer işçinin paketleri korunur. İndirmeleri okuyan yardımcı Python komutları `-I` ile çalıştırıldı. Flutter, fotoğraf araması/OCR ve GitHub Actions çalıştırılmadı; commit/push yapılmadı.

### P9 partisi (4 Kasım 2026)

Yedi okul, tamamı Kasım 2026; toplam 130 tarih. Menü türü aksi belirtilmedikçe öğle (`lunch`).

| Okul / kimlik | Kaynak | Gün | Ayrıntı |
|---|---|---:|---|
| Osmaniye Korkut Ata / `osmaniye` | [Aylık HTML](https://www6.osmaniye.edu.tr/yemekmenu) | 21 | 2–30 Kasım; dört yemek, yazılı toplam kalori; Ekim arşivi karıştırılmaz. |
| Kahramanmaraş Sütçü İmam / `ksu` | [Aylık HTML](https://yemeklistesi.ksu.edu.tr/) | 21 | 2–30 Kasım; dört kalem kalorisi; günlük kopya tekilleştirilir. |
| Tarsus / `tarsus` | [Aylık HTML](https://sks.tarsus.edu.tr/tr/page/yemek-listesi/2581) | 21 | Beş yemek, kalori yok. “SENİN MENÜN” hücresindeki 4 Kasım ancak 3 ve 5 Kasım komşularıyla doğrulanır; seçenekler vejetaryen diye etiketlenmez. [Öğrenci ücreti](https://sks.tarsus.edu.tr/tr/page/yemekhane-ve-kantin/2687) 35 TL. |
| Adana Alparslan Türkeş BTÜ / `atu` | [UBYS aylık HTML](https://ubys.atu.edu.tr/Yemekhane) | 21 | Dört yemek, kalem/toplam kalori; öğrenci karta yükleme 30 TL, günlük öğrenci 90 TL. |
| Burdur Mehmet Akif Ersoy / `maku` | [İki haftalık HTML](https://mehmetakif.edu.tr/tr/content/10606/haftalik-yemek-listesi) | 10 | 2–13 Kasım; merkez/Bucak listesi, ilçe listesi hariç; toplam kalori, `birikimli`. |
| Isparta Uygulamalı Bilimler / `isubu` | [Aylık HTML](https://yemek.isparta.edu.tr/menu) | 20 | 2–27 Kasım; merkez/100. Yıl yerleşkeleri ilk tablo, ilçe sekmesi hariç; “Bugün” komşu tarih ve sütundan bulunur; toplam kalori. |
| Uşak / `usak` | [HTML menü penceresi](https://yemek.usak.edu.tr/yemekhane) | 16 | 4–25 Kasım; öğle + açıkça etiketlenmiş vejetaryen seçenek. Alerjen harfleri çıkarılır; İngilizce kopya alınmaz. Eksik kalori üretilmez; `birikimli`. 20 Kasım etiketsiz iki seçenek tek öğle kaleminde korunur; iki kalori ve iki toplam öğün notunda tutulur, tek kalem/toplam kalorisi sayılmaz. |

Gerçek HTML kırpıntılarıyla 17 yeni ağsız test eklendi. Veriler Python 3.9, TLS doğrulaması açık curl indirmeleri ve `YEMEK_ARAMA_LIMIT=0` ile geçici klasörde üretildi; yalnız yeni okul klasörleri kopyalandı. Klasörler hazırlandıktan sonra iki index ve pubspec güncellendi. **415 test, OK** (Python 3.9 ve varsayılan Python). Flutter çalıştırılmadı.

### P10 partisi (4 Kasım 2026)

Yedi devlet üniversitesi, Kasım 2026'da 96 tarih eklendi. Tümü öğle; NKÜ'de açıkça etiketli vejetaryen ana yemek de vardır.

| Okul / kimlik | Kaynak | Gün | Ayrıntı |
|---|---|---:|---|
| Balıkesir / `balikesir` | [Haftalık HTML](https://balikesir.edu.tr/yemek-listesi) | 5 | 2–6 Kasım; dört kalem ve toplam kalori. Yılsız başlık hafta günüyle doğrulanır, birikimli. |
| Bandırma Onyedi Eylül / `bandirma` | [Dinamik aylık metin PDF](https://sksdb.bandirma.edu.tr/tr/sksdb/s/Yemek-Menusu-2725) | 21 | 2–30 Kasım; altı kalem, 125 kalemin kalorisi var, 12 Kasım sütlü irmik helvasının kalorisi boş. Seçenekler için toplam hesaplanmaz. PDF dipnotundan öğle 11:30–14:00, akşam 16:00–17:30; menü akşama çoğaltılmaz. Aynı sayfanın ücret kararı PDF'inden öğrenci 55 TL. |
| Tekirdağ Namık Kemal / `nku` | [SKS HTML](https://sks.nku.edu.tr/YemekListesi/0/s/6200/7411) | 4 | 3–6 Kasım penceresi; birikimli, dört yemek ve varsa vejetaryen seçenek. [Saat](https://sks.nku.edu.tr/YemekSaatleri/0/s/14804/19073) öğle 11:00–14:00; [öğrenci ücreti](https://sks.nku.edu.tr/YemekFiyatlari_i%C3%A7erik/0/s/14798/19059) 37 TL. |
| Kırklareli / `klu` | [Takvime gömülü JSON](https://sks.klu.edu.tr/Takvimler/73-yemek-takvimi.klu) | 21 | 2–30 Kasım; textarea güvenli JSON olarak çözülür, eski arşiv karıştırılmaz; kalori yok. |
| Bilecik Şeyh Edebali / `bilecik` | [Dinamik aylık metin PDF](https://bilecik.edu.tr/sks/Icerik/Yemek_Men%C3%BCs%C3%BC_cc6e6) | 21 | 2–30 Kasım; dört yemek, kalori yok; parçalanmış tarih/sözcükler birleştirilir. [Saat](https://bilecik.edu.tr/sks/Icerik/Yemek_Saatleri) 11:00–14:00; [ön lisans/lisans 50, lisansüstü 60 TL](https://bilecik.edu.tr/sks/Icerik/Yemek_%C3%9Ccretleri_67696). |
| Yalova / `yalova` | [Aylık öğle HTML](https://menu.yalova.edu.tr/Home/) | 21 | 2–30 Kasım; kalem ve yazılı toplam kalori; tooltip içindeki malzemeler yemek adına alınmaz. |
| Hitit / `hitit` | [Merkez HTML](https://hitit.edu.tr/tr/hitit/yemek-listesi) | 3 | 4–6 Kasım; dört yemek, kalori yok; birikimli. [Servis saati](https://hitit.edu.tr/tr/shmyo/yemek-hizmeti-uygulamalari-hakkinda) 11:45–13:30. |

**Kocaeli Sağlık ve Teknoloji Üniversitesi kapsam dışıdır:** [kurumun resmî sayfası](https://kocaelisaglik.edu.tr/universite) ve [YÖK'ün yayımladığı kuruluş hükmü](https://vakif.yok.gov.tr/files/5/VAKIF/Y%C3%BCksek%C3%B6%C4%9Fretim%20Kurumlar%C4%B1%20Te%C5%9Fkilat%20Kanunu.pdf) vakıf üniversitesi olduğunu doğrular. Menü araştırmasına/eklenti listesine alınmadı.

17 yeni ağsız test ve gerçek kırpılmış kaynaklar (iki tek sayfalık PDF dahil); tam kaynak ile fixture çıktıları eşit. **432 test, OK**: varsayılan Python ve Python 3.9. Veri/iki index/pubspec tamamlandı; yalnız yeni okul verileri kopyalandı. PDF sütun sınırları yalnız Kasım 2026 düzeniyle denendi.

### İş günü yeniden denemeleri (4 Kasım 2026)

13 okul yeniden denendi; on okul, toplam 105 Kasım 2026 tarihi eklendi. Erciyes öğle ve akşam, diğerleri öğle menüsüdür. Eski boş menü/DNS/erişim notları aşağıdaki güncel sonuçlarla değiştirildi.

| Okul / kimlik | Kaynak | Gün | Ayrıntı |
|---|---|---:|---|
| Yozgat Bozok / `bozok` | [HTML aylık özet](https://yemek.bozok.edu.tr/) | 12 | 2–17 Kasım; dört yemek ve toplam kalori, gluten yıldızları çıkarılır; kısa pencere birikimli. |
| Bartın / `bartin` | [Form içindeki tarih/yemek sabitleri](https://form.bartin.edu.tr/rapor/form/yemek-menu.html) | 21 | 2–30 Kasım; JavaScript çalıştırılmaz. Kalem kalorileri, virgülle yan yemekler ve seçenekli içecekler; seçenekler toplanmaz. |
| Recep Tayyip Erdoğan / `rte` | [Günlük HTML](https://erdogan.edu.tr/Website/Contents.aspx?LangID=1&PageID=1156) | 1 | 4 Kasım; dört kalem kalorisi, toplam 785; birikimli. |
| Gümüşhane / `gumushane` | [Aylık JSON](https://www.gumushane.edu.tr/api/Page/130) | 21 | 2–30 Kasım; yıl/ay alanları ve gün başına beş yuvanın ilk dört yemeği, boş günler atılır; kalori yok. |
| Bitlis Eren / `bitlis` | [Tarihli HTML](https://www.beu.edu.tr/YemekListesi) | 3 | 4–6 Kasım; dört yemek, seçenekler aynı kalemde; birikimli. |
| Batman / `batman` | [HTML öğrenci listesi](https://batman.edu.tr/yemek-listesi) | 10 | 2–13 Kasım; dört kalem kalorisi. Bugün tarihinin div, diğerlerinin span olması desteklenir; birikimli. |
| Erciyes / `erciyes` | [Öğrenci HTML menüsü](https://erciyes.edu.tr/tr/2/ogrenci-yemek-listesi) | 3 | 4–6 Kasım; 4 ve 5 Kasım öğle+akşam, 6 Kasım yalnız öğle. Boş akşam/0 toplam atılır; kalem ve toplam kalori; birikimli. |
| Erzurum Teknik / `etu` | [Günün ve ilerleyen günlerin HTML'i](https://servis.erzurum.edu.tr/yemeklistesi/) | 10 | 4–17 Kasım; dört kalem kalorisi. Yılsız tarihler yakın yıl/hafta günüyle doğrulanır; gramajlar alınmaz; birikimli. |
| Ağrı İbrahim Çeçen / `agri` | [Ana sayfa HTML menüsü](https://www.agri.edu.tr/) | 3 | 4–6 Kasım; son yemeğe bitişik toplam kalori ayrılır; protein/gram yemek değildir; birikimli. |
| Hakkari / `hakkari` | [Merkezi Yemekhane aylık HTML](https://www.hakkari.edu.tr/yemek-listesi/1/merkezi-yemekhane) | 21 | 2–30 Kasım; dört yemek; tek kalori kaleme, iki seçenek kalorisi ve iki toplam öğün notuna yazılır, toplanmaz. |

18 yeni ağsız test; tam kaynak ile kırpılmış fixture sonuçları eşit. **450 test, OK**: Python 3.9 ve varsayılan Python. Geçici build, iki index ve pubspec tamamlandı. Flutter, fotoğraf araması/OCR yapılmadı.

### P11: YÖK karşılaştırması (4 Kasım 2026)

[YÖK Devlet Üniversiteleri listesi](https://www.yok.gov.tr/tr/university?type=1) indirildi; **128 kurum** `data/index.json` ve önceki deneme notlarıyla ad bazında karşılaştırıldı. Hiç denenmemiş dokuz kurum bulundu; altısı eklendi, üçünde güncel okunabilir menü bulunamadı. Vakıflar karşılaştırmaya alınmadı. Yeni altı okulun tamamı öğle (`lunch`), toplam **104 Kasım 2026 tarihi**:

| Okul / kimlik | Kaynak | Gün | Ayrıntı |
|---|---|---:|---|
| Gaziantep İslam Bilim ve Teknoloji / `gibtu` | [HTML](https://www.gibtu.edu.tr/yemeklistesi.aspx) | 19 | 4–30 Kasım; Windows-1254, dört yemek, kalori yok. Geçmiş günler kaybolduğu için birikimli. |
| Karamanoğlu Mehmetbey / `kmu` | [Aylık HTML](https://kmu.edu.tr/yemekhane) | 21 | 2–30 Kasım; başlıkta yıl/ay, satırda gün; dört yemek ve yazılı toplam kalori. |
| Malatya Turgut Özal / `mtu` | [Günlük SKS HTML](https://sksdb.ozal.edu.tr/tr/yemek_listesi) | 1 | 4 Kasım; dört yemek, kalori yok, birikimli. Aylık PNG otomatik okunmadı; günlük metin kaynağı kullanıldı. |
| İskenderun Teknik / `iste` | [SKS duyurusundan aylık metin PDF](https://iste.edu.tr/sksdb) | 21 | 2–30 Kasım; dört kalem kalorisi. [Kasım PDF'i](https://iste.edu.tr/files/7149_files_1793080297.pdf) duyurudan dinamik bulunur; gramaj ve kalori sütunları ayrılır, parçalanmış rakamlar ve 0,9 birim yükselmiş uzun yemek adları birleştirilir. |
| Kütahya Sağlık Bilimleri / `ksbu` | [SKS aylık metin PDF bağlantısı](https://sks.ksbu.edu.tr/defaultx/slide/5613/ksbu-yemek-listesi) | 21 | 2–30 Kasım; dört yemek ve tek günlük enerji toplamı. CID harf genişlikleri ve `.05` çizim ölçeğiyle sözcükler yeniden birleştirilir; sarılmış makarna/yoğurt satırları korunur. Çölyak menüsü alınmaz. |
| İstiklal Bilim ve Teknoloji / `istiklal` | [Angular CMS'nin girişsiz JSON'u](https://www.istiklal.edu.tr/sksdb/beslenme-ve-kafeterya) | 21 | 2–30 Kasım; `https://istiklal.edu.tr/api/pages/get` ve `/posts/get` okuma POST'ları; `args-ahbv-food-list` içindeki gerçek tarihli arşivden güncel ay seçilir. Dört yemek ve toplam kalori; JavaScript çalıştırılmaz. YÖK'teki güncel ad kullanıldı (eski adı Kahramanmaraş İstiklal). |

**P11'de eklenemeyen üç kurum:**

* **Afyonkarahisar Sağlık Bilimleri — yalnız resim:** [SKS yemek listesi](https://skultur.afsu.edu.tr/yemek-listesi/) Kasım 2026'yı `kasim-yemek-2.jpg` olarak yayınlar; güncel öğrenci metin/PDF alternatifi bulunamadı. Hastane menüsü yerine alınmadı.
* **Abdullah Gül — güncel menü yok:** [SKS menü sayfasının](https://sks-tr.agu.edu.tr/yemek-menuesue) en yeni bağlantısı Aralık 2025 PDF'idir; PDF'in içindeki başlık ve tarihler de 2025'tir. Ana site/SKS'de 2026 menüsü bulunamadı; 2025 listesi 2026'ya çevrilmedi.
* **Türkiye Uluslararası İslam, Bilim ve Teknoloji — menü yok:** [ana site](https://tibu.edu.tr/) ve [SKS](https://sks.tibu.edu.tr/) incelendi; “Yemek Listesi” bağlantısı `#`, tarihli yemek içeriği yok.

**Kapsam dışı:** Millî Savunma Üniversitesi, Polis Akademisi ve Jandarma ve Sahil Güvenlik Akademisi, özel kabul ve kurum hizmetine yönelik eğitim veren kurumlar oldukları için kullanıcının kapsam talebine göre atlandı; menüleri denenmedi. Türkiye dışındaki ortak üniversiteler ve vakıflar alınmadı. Türk-Japon, YÖK ana sayfasındaki ayrı kurum bağlantısında yer aldığından aşağıdaki durum tablosuna ek satırla dahil edildi; önceki “menü yok” tespiti bu görevde yeniden denenmedi.

19 yeni ağsız test, gerçek kırpılmış HTML/JSON ve iki tek sayfalık PDF; tam kaynak/fixture çıktıları eşit. **469 test, OK** (varsayılan Python ve Python 3.9). PDF ayrıştırıcıları yalnız Kasım 2026 düzeniyle denendi. Altı okulun verisi geçici build ile üretildi; iki index ve pubspec okul klasörleri hazırlandıktan sonra güncellendi. Fotoğraf araması/OCR/Flutter çalıştırılmadı.

### Okunamayan okullar

**4 Kasım 2026 yeniden denemeleri:**

* **Kütahya Dumlupınar — menü yok:** [öğrenci listesi](https://www.dpu.edu.tr/index/yemek) iş gününde de “Bu güne ait yemek bilgisi bulunamamıştır” diyor; personel menüsü dolu. [SKS beslenme sayfası](https://sks.dpu.edu.tr/tr/index/sayfa/1798/beslenme-hizmetleri-sube-mudurlugu) güncel öğrenci aylık menüsüne bağlanmıyor.
* **Bolu Abant İzzet Baysal — erişilemiyor:** [ana sitenin](https://www.ibu.edu.tr/) verdiği [resmî menü adresi](https://uyg.ibu.edu.tr/yemekListesi/) HTTPS ve HTTP'de bağlantı zaman aşımı verdi; eski SKS alan adı DNS hatası. Menü eklentisi eklenmedi.
* **Kocaeli — menü bulunamadı:** [SKS Next.js](https://sksdb.kocaeli.edu.tr/) Flight metni çözüldü, kod parçaları (köşeli parantezli yollar URL kodlanarak) indirildi. Girişsiz `https://api.kocaeli.edu.tr/api/` API'si, `Admin/Isp/GetIspCodeByName`, `Menu/GetAll` ve `Page/GetBySlug` uçları doğrulandı; SKS'nin genel birim kodu 1086'dır. [Beslenme Hizmetleri](https://sksdb.kocaeli.edu.tr/sayfalar/beslenme-hizmetleri-birimi-3b6) JSON içeriği yalnız görevler/servis saatlerini veriyor; menü/PDF eki yok. SKS/ana site menü bağlantıları ve JS parçalarında öğrenci yemek menüsü uç noktası bulunamadı. Hastane personel PDF'leri öğrenci listesi yerine alınmadı.
* **Mersin — yalnız resim:** [SKS Kurum Yemekhane Hizmetleri](https://sks.mersin.edu.tr/tr/idari/saglik-kultur-ve-spor-daire-baskanligi/hizmetlerimiz/kurum-yemekhane-hizmetleri/) Kasım 2026 merkez menüsünü WebP yayınlar; görselin ay/yılı gözle doğrulandı. Saat/ücret metinleri menü değildir, hastane/kreş listeleri alınmadı.

**Önceki partilerdeki son tespitler (1 Kasım 2026 veya aşağıda belirtilen tarih; bu görevde yeniden denenmeyenler):**

| Okul | Durum / son neden |
|---|---|
| Mardin Artuklu | Yalnız resim: [SKS](https://www.artuklu.edu.tr/saglik-kultur-spor-baskanligi) Ekim JPEG; ana sitedeki PDF Kasım 2025. |
| Iğdır | Yalnız resim: [SKS aylık menü](https://sks.igdir.edu.tr/aylk-yemek-listsi) JPG; eski alternatif 500. |
| Artvin Çoruh | Yalnız resim: [resmî menü](https://www.artvin.edu.tr/tr/yemek) `menu.jpg`; eski SKS DNS hatası. |
| Erzincan Binali Yıldırım | Yalnız resim: [SKS](https://sks.ebyu.edu.tr/yemek-menusu/) `Yemek-Menusu.jpeg`. |
| Zonguldak Bülent Ecevit | Yalnız resim: [Kasım öğle/akşam](https://w3.beun.edu.tr/hizmetler/yemek-listesi.html) JPG. |
| Konya Teknik | Yalnız resim: [Yemek Menüsü](https://www.ktun.edu.tr/tr/Birim/Index/?brm=0/ZiZm1h8DwpGheFpqAvXw==) Ekim PNG; rezervasyon giriş ister. |
| Dicle | Yalnız resim: SKS öğrenci aylık JPG (27 Ekim). |
| Manisa Celal Bayar | Yalnız resim: [merkez menüsü](https://sks.mcbu.edu.tr/Sayfa/YemekListesiMerkez) JPG (27 Ekim). |
| Kırıkkale | Yalnız resim: SKS aylık JPG (27 Ekim). |
| Akdeniz | Yalnız resim: merkez yemekhane haftalık görsel. |
| Fırat | Erişilemiyor: SKS 403; alternatif öğrenci menüsü bulunamadı, Üniversite Evi öğrenci menüsü sayılmadı (27 Ekim). |
| Selçuk | Erişilemiyor: [yemek sitesi](https://yemek.selcuk.edu.tr/) SSO girişi ister (11 Ekim). |
| Anadolu | Erişilemiyor: öğrenci menüsü Anadolu hesabı arkasında; à la carte restoran listeleri alınmadı. |
| İstanbul Üniversitesi-Cerrahpaşa | Erişilemiyor: SKS güvenlik doğrulamalı CMS. |
| Yıldız Teknik | Erişilemiyor: SKS zaman aşımı; beslenme sayfasında güncel menü yok. |
| Türk-Alman | Erişilemiyor: otomatik istek 403. |
| İstanbul Medeniyet | Menü yok: menü sayfası boş. |
| Sağlık Bilimleri | Menü yok: herkese açık öğrenci menüsü bulunamadı. |
| Türk-Japon Bilim ve Teknoloji | Menü yok: açık öğrenci menüsü bulunamadı. |
| İzmir Yüksek Teknoloji Enstitüsü | Menü yok: açık menü bulunamadı. |
| İzmir Demokrasi | Menü yok: açık menü bulunamadı. |
| İzmir Bakırçay | Menü yok: açık menü bulunamadı. |

Kocaeli Sağlık ve Teknoloji, İstanbul Sağlık ve Teknoloji, Alanya Hamdullah Emin Paşa ve Kapadokya vakıftır; devlet üniversitesi taramasına alınmaz. Geçici scraper hatasında `build` eski okul kaydını ve menüsünü korur.

### JSON biçimi
`data/index.json`: üniversite listesi, her biri için `meals`, `prices`, `firstDay`, `lastDay`.
`data/<id>/menu.json`: `{"days": {"2026-10-02": {"lunch": {"items":[{"name":"Yayla Çorba","kcal":168,"img":"dishes/ab12cd34ef.jpg"}], "kcal":1910}, "dinner": {...}, "vegetarian": {...}}}}`

## Çalıştırma
```bash
cd scraper
python3 -m unittest discover -s tests -t .      # testler
python3 -m yemekhane.build                       # ../data klasörünü günceller
```

## Yeni üniversite ekleme
1. `scraper/yemekhane/universities/<id>.py` oluştur, `Universite` sınıfından türet; `menuler()` aynı biçimde sözlük döndürsün.
2. `universities/__init__.py` içindeki `KAYITLI` listesine ekle.
3. Fixture + test ekle (`tests/`). Uygulamada başka bir değişiklik gerekmez: üniversite listesi `index.json`'dan gelir.
4. Okul menüyü yalnızca resim olarak yayınlıyorsa menüyü `elle_veri/<id>.json` içine gir (`yemekhane/elle.py`); eklenti `ElleUniversite`'den türer.
5. Okul yalnızca bugünün/haftanın menüsünü yayınlıyorsa eklentiye `birikimli = True` yaz (build önceki günleri korur).
6. Yeni okulun `data/<id>/` klasörü için `app/pubspec.yaml`'a `assets/data/<id>/` satırı ve `app/assets/data/` altına menü kopyası eklenir.

## Uygulama
Flutter uygulaması (`app/`), Android APK olarak dağıtılır. Özellikler:

* **İlk açılış:** kayıtlı okul yoksa karşılama ekranı açılır, okul seçilmeden menü gösterilmez.
* **Ana ekran:** gün çubuğu (kaydırarak ya da oklarla gün değiştirme, aşağı çekip yenileme), öğün sekmeleri (açılışta okulun servis saatine göre sıradaki öğün), öğün özeti (toplam kalori, servis saati, öğrenci fiyatı), "Öğle yemeğine 25 dk" geri sayımı, okul yeni menüyü yayınlamadıysa uyarı bandı, çevrimdışıyken son bilinen veri.
* **Yemek detayı:** yemeğe dokununca büyük (Wikimedia Commons'tan yüksek çözünürlüklü) fotoğraf ve atıf, puan verme, yemeğin menüdeki diğer günleri, yemeğe özel yorumlar.
* **Favoriler:** kalp düğmesi; favori bu hafta menüdeyse ana ekranda şerit ("Favorin Mantı: Cuma (öğle)").
* **Yemek arama:** "bugün nerede mantı var": şehirdeki ya da tüm okullarda, Türkçe harf duyarsız.
* **Haftalık menü ve paylaşım:** haftanın menüsü tek ekranda; öğün, gün ya da hafta metin olarak paylaşılır/panoya kopyalanır.
* **Günlük menü bildirimi (isteğe bağlı, varsayılan kapalı):** Ayarlar'dan açılır, saati seçilir; favori menüdeyse öne çıkarır. Bildirim, uygulamanın son açıldığı andaki menüyle planlanır.
* **Kalori hedefi (isteğe bağlı):** öğünün günlük hedefin yüzde kaçı olduğunu gösterir (genel bilgidir, tıbbi tavsiye değildir).
* **Görünüm:** 8 elle ayarlanmış palet (Safran varsayılan) ve Sistem/Açık/Koyu/Siyah mod; tüm paletler WCAG AA kontrast testinden geçer. Arayüz ve sistem metinleri Türkçedir.
* **Puan ve yorumlar:** Firebase (anonim oturum); okumalar 5 dakika bellekte tutulur (kota), yenileme önbelleği boşaltır.

Testler: `cd app && flutter analyze && flutter test`. Uygulama ikonu `app/tool/ikon_uret_test.dart` ile çizilir (`flutter test tool/ikon_uret_test.dart`).
Release APK `app/android/key.properties` (git'e girmez) içindeki anahtarla imzalanır; anahtar yoksa debug anahtarı kullanılır. Aynı anahtarla imzalanan yeni APK eskisinin üzerine kurulabilir.

Flutter kurulumundan sonra: `cd app && flutter create . --project-name yemekhane --org com.tolga && flutter pub get && flutter run`
(`flutter create .` yalnızca eksik platform klasörlerini ekler; `lib/` ve `pubspec.yaml` korunur.)
`app/lib/config.dart` içindeki `veriTabanUrl` değerini kendi GitHub deponun raw adresiyle değiştir.


## Tüm devlet üniversitelerinin durumu (4 Kasım 2026)

[YÖK devlet üniversiteleri sayfasındaki](https://www.yok.gov.tr/tr/university?type=1) 128 kurum ve YÖK ana sayfasının ayrı bağlantısında bulunan Türk-Japon ile 129 satır: **100 eklendi, 12 yalnız resim, 10 menü yok, 7 erişilemiyor**. “Menü yok”, güncel açık öğrenci metin kaynağı bulunamadığı anlamındadır; eski yıl menüsü de bu gruptadır. Giriş/güvenlik doğrulaması erişilemiyor grubundadır.

Bu tabloda önceki partilerdeki tespitler de korunur: bu görevde P9/P10, belirtilen 13 yeniden deneme ve P11'in dokuz yeni adayı araştırıldı. Önceden başarısız olan diğer 22 okulun ağı bu görevde yeniden denenmedi; son neden/tarihleri “Okunamayan okullar” bölümündedir. Eski 70 ekli okulun menüleri yeniden üretilmedi. Kapsam dışında bırakılan MSÜ/Polis/Jandarma kurumları bu tablonun sayısına dahil değildir.

| Devlet üniversitesi | Durum |
|---|---|
| Abdullah Gül Üniversitesi | menü yok |
| Adana Alparslan Türkeş Bilim ve Teknoloji Üniversitesi | eklendi |
| Adıyaman Üniversitesi | eklendi |
| Afyon Kocatepe Üniversitesi | eklendi |
| Afyonkarahisar Sağlık Bilimleri Üniversitesi | yalnız resim |
| Akdeniz Üniversitesi | yalnız resim |
| Aksaray Üniversitesi | eklendi |
| Alanya Alaaddin Keykubat Üniversitesi | eklendi |
| Amasya Üniversitesi | eklendi |
| Anadolu Üniversitesi | erişilemiyor |
| Ankara Hacı Bayram Veli Üniversitesi | eklendi |
| Ankara Müzik ve Güzel Sanatlar Üniversitesi | eklendi |
| Ankara Sosyal Bilimler Üniversitesi | eklendi |
| Ankara Yıldırım Beyazıt Üniversitesi | eklendi |
| Ankara Üniversitesi | eklendi |
| Ardahan Üniversitesi | eklendi |
| Artvin Çoruh Üniversitesi | yalnız resim |
| Atatürk Üniversitesi | eklendi |
| Aydın Adnan Menderes Üniversitesi | eklendi |
| Ağrı İbrahim Çeçen Üniversitesi | eklendi |
| Balıkesir Üniversitesi | eklendi |
| Bandırma Onyedi Eylül Üniversitesi | eklendi |
| Bartın Üniversitesi | eklendi |
| Batman Üniversitesi | eklendi |
| Bayburt Üniversitesi | eklendi |
| Bolu Abant İzzet Baysal Üniversitesi | erişilemiyor |
| Boğaziçi Üniversitesi | eklendi |
| Burdur Mehmet Akif Ersoy Üniversitesi | eklendi |
| Bursa Teknik Üniversitesi | eklendi |
| Bursa Uludağ Üniversitesi | eklendi |
| Bilecik Şeyh Edebali Üniversitesi | eklendi |
| Bingöl Üniversitesi | eklendi |
| Bitlis Eren Üniversitesi | eklendi |
| Dokuz Eylül Üniversitesi | eklendi |
| Düzce Üniversitesi | eklendi |
| Dicle Üniversitesi | yalnız resim |
| Ege Üniversitesi | eklendi |
| Erciyes Üniversitesi | eklendi |
| Erzurum Teknik Üniversitesi | eklendi |
| Erzincan Binali Yıldırım Üniversitesi | yalnız resim |
| Eskişehir Osmangazi Üniversitesi | eklendi |
| Eskişehir Teknik Üniversitesi | eklendi |
| Fırat Üniversitesi | erişilemiyor |
| Galatasaray Üniversitesi | eklendi |
| Gazi Üniversitesi | eklendi |
| Gaziantep Üniversitesi | eklendi |
| Gaziantep İslam Bilim ve Teknoloji Üniversitesi | eklendi |
| Gebze Teknik Üniversitesi | eklendi |
| Gümüşhane Üniversitesi | eklendi |
| Giresun Üniversitesi | eklendi |
| Hacettepe Üniversitesi | eklendi |
| Hakkari Üniversitesi | eklendi |
| Harran Üniversitesi | eklendi |
| Hatay Mustafa Kemal Üniversitesi | eklendi |
| Hitit Üniversitesi | eklendi |
| Isparta Uygulamalı Bilimler Üniversitesi | eklendi |
| Iğdır Üniversitesi | yalnız resim |
| Kafkas Üniversitesi | eklendi |
| Kahramanmaraş Sütçü İmam Üniversitesi | eklendi |
| Karabük Üniversitesi | eklendi |
| Karadeniz Teknik Üniversitesi | eklendi |
| Karamanoğlu Mehmetbey Üniversitesi | eklendi |
| Kastamonu Üniversitesi | eklendi |
| Kayseri Üniversitesi | eklendi |
| Kırıkkale Üniversitesi | yalnız resim |
| Kırklareli Üniversitesi | eklendi |
| Kırşehir Ahi Evran Üniversitesi | eklendi |
| Kocaeli Üniversitesi | menü yok |
| Konya Teknik Üniversitesi | yalnız resim |
| Kütahya Dumlupınar Üniversitesi | menü yok |
| Kütahya Sağlık Bilimleri Üniversitesi | eklendi |
| Kilis 7 Aralık Üniversitesi | eklendi |
| Malatya Turgut Özal Üniversitesi | eklendi |
| Manisa Celal Bayar Üniversitesi | yalnız resim |
| Mardin Artuklu Üniversitesi | yalnız resim |
| Marmara Üniversitesi | eklendi |
| Mersin Üniversitesi | yalnız resim |
| Munzur Üniversitesi | eklendi |
| Muğla Sıtkı Koçman Üniversitesi | eklendi |
| Muş Alparslan Üniversitesi | eklendi |
| Mimar Sinan Güzel Sanatlar Üniversitesi | eklendi |
| Necmettin Erbakan Üniversitesi | eklendi |
| Nevşehir Hacı Bektaş Veli Üniversitesi | eklendi |
| Niğde Ömer Halisdemir Üniversitesi | eklendi |
| Ondokuz Mayıs Üniversitesi | eklendi |
| Ordu Üniversitesi | eklendi |
| Orta Doğu Teknik Üniversitesi | eklendi |
| Osmaniye Korkut Ata Üniversitesi | eklendi |
| Pamukkale Üniversitesi | eklendi |
| Recep Tayyip Erdoğan Üniversitesi | eklendi |
| Sakarya Uygulamalı Bilimler Üniversitesi | eklendi |
| Sakarya Üniversitesi | eklendi |
| Samsun Üniversitesi | eklendi |
| Sağlık Bilimleri Üniversitesi | menü yok |
| Selçuk Üniversitesi | erişilemiyor |
| Süleyman Demirel Üniversitesi | eklendi |
| Sinop Üniversitesi | eklendi |
| Sivas Bilim ve Teknoloji Üniversitesi | eklendi |
| Sivas Cumhuriyet Üniversitesi | eklendi |
| Siirt Üniversitesi | eklendi |
| Tarsus Üniversitesi | eklendi |
| Tekirdağ Namık Kemal Üniversitesi | eklendi |
| Tokat Gaziosmanpaşa Üniversitesi | eklendi |
| Trabzon Üniversitesi | eklendi |
| Trakya Üniversitesi | eklendi |
| Türk-Alman Üniversitesi | erişilemiyor |
| Türkiye Uluslararası İslam, Bilim Ve Teknoloji Üniversitesi | menü yok |
| Uşak Üniversitesi | eklendi |
| Van Yüzüncü Yıl Üniversitesi | eklendi |
| Yalova Üniversitesi | eklendi |
| Yıldız Teknik Üniversitesi | erişilemiyor |
| Yozgat Bozok Üniversitesi | eklendi |
| Zonguldak Bülent Ecevit Üniversitesi | yalnız resim |
| Çanakkale Onsekiz Mart Üniversitesi | eklendi |
| Çankırı Karatekin Üniversitesi | eklendi |
| Çukurova Üniversitesi | eklendi |
| İnönü Üniversitesi | eklendi |
| İskenderun Teknik Üniversitesi | eklendi |
| İstanbul Medeniyet Üniversitesi | menü yok |
| İstanbul Teknik Üniversitesi | eklendi |
| İstanbul Üniversitesi | eklendi |
| İstanbul Üniversitesi-Cerrahpaşa | erişilemiyor |
| İstiklal Bilim ve Teknoloji Üniversitesi | eklendi |
| İzmir Bakırçay Üniversitesi | menü yok |
| İzmir Demokrasi Üniversitesi | menü yok |
| İzmir Katip Çelebi Üniversitesi | eklendi |
| İzmir Yüksek Teknoloji Enstitüsü | menü yok |
| Şırnak Üniversitesi | eklendi |
| Türk-Japon Bilim ve Teknoloji Üniversitesi | menü yok |


Son doğrulama: **471 test, OK** (Python 3.9.6 ve 3.15.0). Tarsus'un 35 TL ve Bandırma'nın 55 TL öğrenci ücretleri için son kontrolde iki ağsız test daha eklendi; iki ücret canlı Python 3.9 okumasında da doğrulandı. Yeni 30 okulun 29'u `SSL_CERT_FILE=/etc/ssl/cert.pem` ile canlı Python 3.9 okumasında geçti. Batman, yerel 3.9'un LibreSSL 2.8.3 ortamında (`HAS_TLSv1_3=False`) hem kök hem www adresinde `TLSV1_ALERT_PROTOCOL_VERSION` verdi; OpenSSL 3.5.9 kullanan Python 3.15 ile canlı **10 gün** okundu. Veri TLS doğrulaması açık curl kaynağından üretildi; TLS doğrulaması kapatılmadı. GitHub Actions ortamı çalıştırılmadı. Kırılgan kaynaklara bu yerel TLS farkı da dahildir.

SHA-256 kontrolünde **983 eski dosya değişmedi**; iki index'in her birindeki önceki 70 kayıt kendi eski haliyle korundu. İki index'in önceden farklı olan eski kayıtları eşitlenmedi; yeni 30 kayıt birbiriyle eşittir. Yeni menü/asset kopyaları eşit, 435 tarihin tamamı Kasım 2026; pubspec'teki bütün asset klasörleri mevcut. Dört yeni test dosyası, 43 kaynak fixture'ı, 30 eklenti ve iki küçük ortak yardımcı eklendi. Flutter, fotoğraf araması/OCR ve commit/push yapılmadı.
