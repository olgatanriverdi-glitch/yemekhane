# Üni Yemek

Üniversite yemekhane menülerini **öğle / akşam / vejetaryen** olarak gösteren mobil uygulama.
Üniversiteler: Ankara Üniversitesi, Gazi, Hacettepe, Ankara Yıldırım Beyazıt (AYBÜ), ODTÜ, Ankara Hacı Bayram Veli (AHBVÜ), Ankara Sosyal Bilimler (ASBÜ) ve
Ankara Müzik ve Güzel Sanatlar (MGÜ). Başka üniversiteler eklenti olarak eklenir.

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
