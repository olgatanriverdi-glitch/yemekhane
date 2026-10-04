# Üni Yemek

Üniversite yemekhane menülerini **öğle / akşam / vejetaryen** olarak gösteren mobil uygulama.
Üniversiteler: Ankara Üniversitesi, Gazi, Hacettepe, Ankara Yıldırım Beyazıt (AYBÜ), ODTÜ, Ankara Hacı Bayram Veli (AHBVÜ), Ankara Sosyal Bilimler (ASBÜ) ve
Ankara Müzik ve Güzel Sanatlar (MGÜ), Eskişehir Osmangazi (ESOGÜ), Eskişehir Teknik (ESTÜ) ve İstanbul'dan İstanbul Üniversitesi (İÜ), İTÜ, Boğaziçi (BÜ), Marmara (MÜ), Galatasaray (GSÜ) ve
Mimar Sinan Güzel Sanatlar (MSGSÜ). Başka üniversiteler eklenti olarak eklenir.

## Mimari (sunucusuz, bedava)

```
okul sitesi (XLSX/HTML) ──► scraper (Python) ──► data/*.json (GitHub'da) ──► Flutter uygulaması
                              ▲ GitHub Actions günde 3 kez çalıştırır
```

* `scraper/` — Python (yalnızca standart kütüphane). Her üniversite `scraper/yemekhane/universities/` altında bir eklentidir.
* `data/` — üretilen statik JSON. Uygulama bunu `raw.githubusercontent.com` / GitHub Pages üzerinden okur.
* `app/` — Flutter uygulaması (iOS + Android).

### Yemek fotoğrafları
Her yemek adı için Wikimedia Commons'ta telifi serbest (CC) bir örnek görsel aranır (`scraper/yemekhane/dishes.py`), 320 px kare JPEG olarak
`data/dishes/` altında saklanır; aynı adlı yemek tekrar aranmaz, bulunamayan 14 günde bir yeniden denenir. Kaynak/yazar/lisans `data/dishes/index.json`'dadır.
Menüdeki her yemek öğesine `"img": "dishes/<anahtar>.jpg"` eklenir. Görseller yalnızca örnektir; yanlış eşleşmeyi önlemek için arama katıdır
(bulunamazsa fotoğraf yerine sade bir simge gösterilir).

### Servis saatleri ve yemek puanları
`data/index.json` içinde her üniversite için `hours` (öğün -> `{"t": "11:30–14:00", "approx": false}`) bulunur. Okul saati yayınlıyorsa (Hacettepe, AYBÜ, ODTÜ, ASBÜ, MGÜ) oradan okunur;
yayınlamıyorsa tipik saat (öğle 11:00–14:00, akşam 17:00–19:00) `approx: true` ile gelir ve uygulamada "Genelde …" yazar.
Menüdeki her yemek öğesine `key` eklenir (yemek adından türeyen kimlik). Uygulama puanları bu anahtarla yemek bazlı tutar (`y_<üniversite>_<key>`), tarihten bağımsız.

### Menüyü yalnızca resim olarak yayınlayan okullar (ODTÜ, ASBÜ)
* **ODTÜ** aylık menüyü PDF içinde taranmış JPEG olarak yayınlar. Menü iki yoldan gelir: `scraper/yemekhane/elle_veri/odtu.json` (resimden elle girilmiş ve
  her günün toplam kalorisiyle doğrulanmış günler) ve GitHub Actions'ta tesseract ile PDF'in okunması. OCR'ın okuduğu bir gün yalnızca kalemlerin kalorisi
  yazılı toplama eşitse kabul edilir; elle girilmiş günler önceliklidir, OCR yalnızca girilmemiş günleri doldurur. Actions logunda
  `ODTÜ OCR: ...` satırları OCR'ın kaç günü okuduğunu ve elle girilenle ne kadar örtüştüğünü gösterir.
* **ASBÜ** aylık menüyü düşük çözünürlüklü bir resim olarak yayınlar, otomatik okunmaz: menü `elle_veri/asbu.json` dosyasına elle girilir.
  Her ay okul yeni resmi koyunca bu dosyaya o ayın günleri eklenmelidir (aksi halde menü bitince ASBÜ uygulamadan düşer).
* `elle_veri/<id>.json` biçimi `data/<id>/menu.json` ile aynıdır (`{"days": {"2026-10-01": {"lunch": {...}}}}`).

### Metin tabanlı PDF yayınlayan okullar (ESTÜ)
`scraper/yemekhane/pdf.py`, Word vb. çıkışlı PDF'lerden konumlu metin çıkarır (yalnızca standart kütüphane; ToUnicode tablolarıyla Türkçe harfler doğru gelir).
ESTÜ'nün aylık menüsü böyle bir PDF'tir: sütunlar haftanın günlerine göre ortak bir ızgaradan bulunur (tek tek başlıklara güvenilmez; bayram günlerinde başlık yoktur),
adı `*` ile biten satır etsiz alternatiftir. Taranmış (resim) PDF'lerde metin yoktur, onlar için OCR gerekir (ODTÜ).

### İstanbul okulları: veri kaynakları
* **İÜ:** `sks.istanbul.edu.tr/meals-by-date?date=...&category=breakfast|lunch|dinner|vegan` JSON'u gün gün sorgulanır (`vegan` -> vejetaryen öğün). Ücret yalnızca taranmış karar olarak yayınlandığı için yok.
* **İTÜ:** ana sayfadaki menü çerçevesinin kaynağı (`bilgiekrani.itu.edu.tr/.../yemek-menu.aspx?tip=itu-ogle-yemegi-genel&&value=6.10.2026`) gün gün sorgulanır; menü ~2 hafta ileriye yayınlanır.
  Bu adres okulun 'uzerinde-calisilan' (üzerinde çalışılan) klasöründedir: yer değiştirirse İTÜ okunamaz hale gelir. Saat ve ücret `sks.itu.edu.tr` tablolarından okunur.
* **Boğaziçi:** `yemekhane.bogazici.edu.tr/aylik-menu/YYYY-AA` takvim sayfası (öğle, akşam, öğlenin vegan alternatifi). **Marmara:** `sks.marmara.edu.tr/yemek` haftalık tablolar (normal + alternatif ana yemek, vejetaryen).
* **GSÜ:** yalnızca öğlen PDF'i okunur (akşam PDF'inde harfler eksik, vegan PDF'lerinin düzeni farklı); satır girdi sayısı gün sayısına uymayan haftalar atlanır.
* **MSGSÜ:** aylık PDF'in adresi WordPress medya API'sinden bulunur.

### Okunamayan okullar
* **İstanbul'da eklenmeyenler:** İstanbul Üniversitesi-Cerrahpaşa (SKS sitesi güvenlik doğrulamalı bir CMS), Yıldız Teknik (`sks.yildiz.edu.tr` bağlantı zaman aşımı veriyor, `beslenme.yildiz.edu.tr` güncel menüyü vermiyor),
  İstanbul Medeniyet (menü sayfası boş), Türk-Alman (siteye otomatik erişim 403), Sağlık Bilimleri, İstanbul Sağlık ve Teknoloji, Türk-Japon (menü yayınlamıyor/bulunamadı).
* **Anadolu Üniversitesi:** öğrenci yemekhanesinin menüsü yalnızca Anadolu hesabıyla girişten sonra görülüyor (yemekhane.anadolu.edu.tr); herkese açık sayfalarda yalnızca personel lokali, Akademik Kulüp ve Taşbina gibi à la carte restoranların menüleri var. Bu yüzden eklenmedi.
* Bir okul geçici olarak okunamazsa (sunucu yavaş/kapalı) `build` onu listeden düşürmez: önceki `index.json` kaydı ve `menu.json` korunur, hata günlüğe yazılır.

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
4. Okul menüyü yalnızca resim olarak yayınlıyorsa menüyü `elle_veri/<id>.json` içine gir (`yemekhane/elle.py`).

## Uygulama
Flutter kurulumundan sonra: `cd app && flutter create . --project-name yemekhane --org com.tolga && flutter pub get && flutter run`
(`flutter create .` yalnızca eksik platform klasörlerini ekler; `lib/` ve `pubspec.yaml` korunur.)
`app/lib/config.dart` içindeki `veriTabanUrl` değerini kendi GitHub deponun raw adresiyle değiştir.
