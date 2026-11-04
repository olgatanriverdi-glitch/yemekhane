import 'package:flutter/material.dart';

import '../arama.dart';
import '../bildirim_ayari.dart';
import '../favoriler.dart';
import '../geri_bildirim.dart';
import '../gun_secimi.dart';
import '../kalori_hedefi.dart';
import '../models.dart';
import '../paylasim.dart';
import '../repository.dart';
import '../tema.dart';
import '../widgets/ana_icerik.dart';
import '../widgets/diger_menusu.dart';
import '../widgets/durum_ekranlari.dart';
import '../widgets/okul_basligi.dart';
import '../widgets/paylasim_sayfasi.dart';
import '../yukleme_hatasi.dart';
import 'ayarlar.dart';
import 'favoriler.dart';
import 'hafta.dart';
import 'ilk_acilis.dart';
import 'tema_secici.dart';
import 'university_picker.dart';
import 'yemek_ara.dart';

// Bölme öncesi home.dart'tan bu adlarla alınan sınıflar (eski testler) derlensin diye.
export '../widgets/ogun_karti.dart' show OgunKarti, YemekResmi, yemekIkonu;

class AnaSayfa extends StatefulWidget {
  final TemaAyari temaAyari;

  /// Testlerde sahte veri deposu verilebilir; boşsa gerçek [Depo].
  final Depo? depo;

  /// Testlerde sahte puan / yorum deposu verilebilir; boşsa [GeriBildirimDeposu.olustur].
  final GeriBildirimDeposu? geriBildirim;

  /// Testlerde sabit saat verilebilir; boşsa [turkiyeSimdi].
  final DateTime Function()? simdi;

  /// Testlerde sahte favori deposu verilebilir; boşsa kendi [FavoriDeposu]'nu kurar.
  final FavoriDeposu? favoriler;

  /// Testlerde sahte paylaşım servisi verilebilir; boşsa [SharePlusServisi].
  final PaylasimServisi? paylasim;

  /// Günlük kalori hedefi ayarı; boşsa kendi [KaloriHedefi]'ni kurar (uygulamada main.dart verir).
  final KaloriHedefi? kaloriHedefi;

  /// Günlük menü bildirimi ayarı; boşsa kendi [BildirimAyari]'nı kurar (varsayılan kapalı: servise dokunmaz).
  final BildirimAyari? bildirim;
  const AnaSayfa(
      {super.key,
      required this.temaAyari,
      this.depo,
      this.geriBildirim,
      this.simdi,
      this.favoriler,
      this.paylasim,
      this.kaloriHedefi,
      this.bildirim});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> with WidgetsBindingObserver {
  late final Depo _depo = widget.depo ?? Depo();
  late final GeriBildirimDeposu _geriBildirim =
      widget.geriBildirim ?? GeriBildirimDeposu.olustur();
  late final FavoriDeposu _favoriler = widget.favoriler ?? FavoriDeposu();
  late final PaylasimServisi _paylasim =
      widget.paylasim ?? const SharePlusServisi();
  late final KaloriHedefi _kalori = widget.kaloriHedefi ?? KaloriHedefi();
  late final BildirimAyari _bildirim = widget.bildirim ?? BildirimAyari();
  List<Universite> _uniler = [];
  Universite? _uni;
  Menu? _menu;
  String? _hata;
  bool _yukleniyor = true;
  // Kayıtlı okul yok (ilk açılış): menü yerine karşılama gösterilir, okul seçilene kadar kalır.
  bool _karsilama = false;
  // Karşılamadan seçilen okulun menüsü yüklenemediyse kayıt yoktur; "Tekrar dene" bu okulu yeniden dener.
  String? _bekleyenId;
  bool _sessizSuruyor =
      false; // aşağı çekip yenileme sürerken ikinci istek açılmasın
  // Sessiz olmayan her yükleme (okul seçimi, Yenile, Tekrar dene...) bir artırır; sessiz yenileme başladığı
  // andaki numarayı yakalar. Bir bekleyişten sonra numara değiştiyse yanıt eskidir ve hiçbir şey yazmaz.
  int _yuklemeNo = 0;
  // Okul seçimiyle başlayıp süren yüklemenin okulu (bitince null); seçicide "aynı okul" karşılaştırması buna göre yapılır.
  String? _yuklenenId;
  late String
      _bugun; // Türkiye saatine göre; uygulama arka plandan dönünce yenilenir
  late String _tarih;
  String _ogun = 'lunch';
  // Açılışta öğün, okulun servis saatlerine göre (akilliOgun) ilk başarılı yüklemede bir kez seçilir.
  bool _ogunBelirle = true;
  // Son gerçek (çevrimdışı önbellek olmayan) yüklemenin saati; resumed'da 3 saati aşınca sessiz yenilenir.
  DateTime? _sonBasarili;
  // Son gün değişiminin yönü: 1 sonraki gün, -1 önceki gün, 0 yön yok (öğün değişimi, yükleme).
  int _yon = 0;

  DateTime _simdi() => (widget.simdi ?? turkiyeSimdi)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final simdi = _simdi();
    _bugun = isoTarih(simdi);
    _tarih = _bugun;
    _favoriler.yukle();
    _kalori.yukle();
    _bildirim.yukle();
    _favoriler.addListener(_favorileriBildir);
    _yukle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _favoriler.removeListener(_favorileriBildir);
    if (widget.favoriler == null) _favoriler.dispose();
    if (widget.kaloriHedefi == null) _kalori.dispose();
    if (widget.bildirim == null) _bildirim.dispose();
    super.dispose();
  }

  // Uygulama gece açık kalıp sabah öne gelirse gün değişmiştir: bugüne dön.
  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    if (durum != AppLifecycleState.resumed) return;
    final simdi = _simdi();
    final bugun = isoTarih(simdi);
    if (bugun != _bugun) {
      setState(() {
        _yon = 0;
        _bugun = bugun;
        _tarih = bugun;
        if (_uni != null) {
          _ogun = akilliOgun(_uni!, simdi);
        } else {
          _ogunBelirle = true;
        }
        _tarih = tarihiSinirla(_menu, _tarih);
        _uygunOgunSec();
      });
    }
    // uzun süre arka planda kaldıysa menü sessizce yenilenir (hata bildirimi yok)
    final son = _sonBasarili;
    if (son == null || simdi.difference(son) >= const Duration(hours: 3)) {
      _yukle(sessiz: true, otomatik: true);
    }
  }

  /// Okulu ve menüyü yükler. [sessiz] true ise (aşağı çekip yenileme) iskelet gösterilmez, mevcut menü ekranda
  /// kalır ve başladığı andaki okul yenilenir; hata olursa kısa bir bildirim çıkar ([otomatik] true ise o da
  /// çıkmaz: kullanıcının istemediği arka plan yenilemesi). [hedef] verilirse (yemek aramasından gelinmişse) menü
  /// yüklenince o gün ve öğüne geçilir. Araya başka bir yükleme girerse ([_yuklemeNo]) eski yanıt atılır. Okul
  /// değiştirmeyen, otomatik olmayan yükleme (aşağı çekme, Yenile...) puan / yorum önbelleğini de boşaltır.
  Future<void> _yukle(
      {String? universiteId,
      bool sessiz = false,
      bool otomatik = false,
      AramaSonucu? hedef}) async {
    String? sabitOkul;
    if (sessiz) {
      if (_yukleniyor || _sessizSuruyor || _menu == null) return;
      _sessizSuruyor = true;
      sabitOkul = _uni?.id;
    } else {
      _yuklemeNo++;
      _yuklenenId = universiteId;
      setState(() {
        _yukleniyor = true;
        _hata = null;
      });
    }
    if (!otomatik && universiteId == null) _geriBildirim.onbellekTemizle();
    final no = _yuklemeNo;
    bool eski() => no != _yuklemeNo;
    try {
      final uniler = await _depo.universiteler();
      if (eski()) return;
      if (uniler.isEmpty) throw const BosOkulListesi();
      final kayitli = universiteId ??
          sabitOkul ??
          _bekleyenId ??
          await _depo.seciliUniversite();
      if (eski()) return;
      if (kayitli == null || kayitli.isEmpty) {
        // ilk açılış: kullanıcı seçmeden hiçbir okul (Ankara dahil) seçilmez, universiteSec çağrılmaz
        _uniler = uniler;
        _uni = null;
        _menu = null;
        _karsilama = true;
        if (mounted) setState(() => _yukleniyor = false);
        return;
      }
      final uni =
          uniler.firstWhere((u) => u.id == kayitli, orElse: () => uniler.first);
      // önce menüyü yükle: başarısızsa önceki okul ve menü olduğu gibi kalır
      final menu = await _depo.menu(uni.id);
      if (eski()) return;
      // öğün uygunluğuna yalnızca ilk yüklemede, okul değişince ya da aramadan gelince bakılır;
      // düz yenileme kullanıcının bilerek açtığı (boş olabilen) sekmeyi değiştirmez
      final ogunKontrol = _ogunBelirle || universiteId != null || hedef != null;
      _uniler = uniler;
      _uni = uni;
      _menu = menu;
      _karsilama = false;
      _bekleyenId = null;
      _yon = 0;
      if (!_depo.cevrimdisi) _sonBasarili = _simdi();
      if (hedef != null && hedef.okul.id == uni.id) {
        _tarih = hedef.tarih;
        _ogun = hedef.ogun;
      } else if (_ogunBelirle) {
        _ogun = akilliOgun(uni, _simdi());
      }
      _ogunBelirle = false;
      _tarih = tarihiSinirla(_menu, _tarih);
      if (ogunKontrol) _uygunOgunSec();
      await _depo.universiteSec(uni.id);
      if (eski()) return;
      _bildirimiGuncelle();
    } catch (e) {
      if (eski()) return;
      final mesaj = yuklemeHatasiMetni(e);
      if (_menu != null) {
        // önceki menü ekranda kalır, hata kısa bir bildirimle gösterilir
        if (mounted && !otomatik) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(mesaj)));
        }
      } else {
        _hata = mesaj;
        if (universiteId != null) _bekleyenId = universiteId;
      }
    } finally {
      if (sessiz) _sessizSuruyor = false;
    }
    // sessiz yenileme iskeleti hiç açmadığından _yukleniyor'u değiştirmez
    if (!sessiz) _yuklenenId = null;
    if (mounted) setState(() => _yukleniyor = sessiz && _yukleniyor);
  }

  // Menü başarıyla yüklenince ve favoriler değişince: günlük menü bildirimi (ayar açıksa) yeniden kurulur.
  void _bildirimiGuncelle() {
    final uni = _uni, menu = _menu;
    if (uni != null && menu != null) {
      // saat kaynağı olarak State'in kendisi değil, işlev verilir (ayar sayfadan uzun yaşayabilir)
      _bildirim.durumuBildir(
          uni, menu, _favoriler.anahtarlar, widget.simdi ?? turkiyeSimdi);
    }
  }

  void _favorileriBildir() => _bildirim.favorileriBildir(_favoriler.anahtarlar);

  // Gün / okul değişince ve ilk açılışta: seçili öğün o gün boşsa (okul yayınlamamış olabilir) dolu olan
  // ilk öğüne geç. Kullanıcı sekmeye kendisi basarsa ve düz yenilemede dokunulmaz.
  void _uygunOgunSec() => _ogun = uygunOgun(_menu, _tarih, _ogun);

  void _gunSec(String t) => setState(() {
        _yon = t.compareTo(_tarih).sign;
        _tarih = t;
        _uygunOgunSec();
      });

  // Favori şeridine dokununca: o günün o öğününe geç (menüde yemek olduğu bilinir).
  void _eslesmeyeGit(String tarih, String ogun) => setState(() {
        _yon = tarih.compareTo(_tarih).sign;
        _tarih = tarih;
        _ogun = ogun;
      });

  void _favorileriAc() => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FavorilerSayfasi(
          favoriler: _favoriler, uni: _uni, menu: _menu, bugun: _bugun)));

  /// Yemek arama sayfasını açar; bir sonuç seçilirse o okula, güne ve öğüne geçer.
  Future<void> _yemekAra() async {
    final uni = _uni;
    if (uni == null || _menu == null) return;
    final sonuc = await Navigator.of(context).push<AramaSonucu>(
        MaterialPageRoute(
            builder: (_) => YemekAraSayfasi(
                depo: _depo,
                uniler: _uniler,
                uni: uni,
                menu: _menu,
                bugun: _bugun)));
    if (sonuc == null || !mounted) return;
    // "Aynı okul" hedefe göre: B yüklenirken ekrandaki A'dan sonuç seçilirse A'ya dönülür, B'nin yanıtı elenir.
    if (sonuc.okul.id == _hedefId) {
      _eslesmeyeGit(sonuc.tarih, sonuc.ogun);
    } else {
      _yukle(universiteId: sonuc.okul.id, hedef: sonuc);
    }
  }

  // Ekranda gösterilen öğün; seçili öğün okulda yoksa okulun ilk öğünü.
  String get _aktifOgun => aktifOgun(_uni!, _ogun);

  /// Haftalık menüyü açar; bir günün kartına dokunulursa o güne geçer.
  Future<void> _haftaAc() async {
    final tarih = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => HaftaSayfasi(
            uni: _uni!,
            menu: _menu!,
            bugun: _bugun,
            tarih: _tarih,
            ogun: _aktifOgun,
            favoriler: _favoriler,
            paylasim: _paylasim)));
    if (tarih != null && mounted) _gunSec(tarih);
  }

  void _paylasAc() => paylasimSayfasiGoster(context,
      servis: _paylasim,
      uni: _uni!,
      tarih: _tarih,
      gun: _menu!.gunler[_tarih] ?? const {},
      ogun: _aktifOgun);

  /// Seçicide "aynı okul" karşılaştırmasının tabanı: yüklenmekte olan okul, yoksa gösterilen okul. B yüklenirken
  /// ekrandaki A yeniden seçilirse A != B olduğundan yeni yükleme başlar ve B'nin yanıtı atılır.
  String? get _hedefId => _yuklenenId ?? _uni?.id;

  Future<void> _uniSec() async {
    final son = await _depo.sonSecilenler();
    if (!mounted) return;
    final secilen = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => UniversitePicker(
            uniler: _uniler, secili: _hedefId, sonSecilenler: son)));
    if (secilen != null && secilen != _hedefId) _yukle(universiteId: secilen);
  }

  Future<void> _ayarlariAc() async {
    final secilen = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => AyarlarSayfasi(
            temaAyari: widget.temaAyari,
            depo: _depo,
            uniler: _uniler,
            uni: _uni,
            yuklenenId: _yuklenenId,
            kaloriHedefi: _kalori,
            bildirim: _bildirim,
            menuyuYenile: () => _yukle())));
    if (secilen != null && secilen != _hedefId) _yukle(universiteId: secilen);
  }

  @override
  Widget build(BuildContext context) {
    final menuVar = _uni != null && _menu != null;
    return Scaffold(
      appBar: AppBar(
        // karşılamada başlık sayfanın kendisinde; okul seçimi büyük düğmeyle yapılır
        title: _karsilama && !_yukleniyor && _hata == null
            ? null
            : OkulBasligi(
                ad: _uni?.ad ?? 'Üni Yemek',
                sec: _uniler.isEmpty ? null : _uniSec),
        // 320 dp'de okul adı sıkışmasın diye az kullanılanlar (Haftalık menü, Paylaş, Tema, Yenile, Ayarlar) "Diğer" menüsünde
        actions: [
          IconButton(
              onPressed: menuVar ? _yemekAra : null,
              icon: const Icon(Icons.search),
              tooltip: 'Yemek ara'),
          IconButton(
              onPressed: _favorileriAc,
              icon: const Icon(Icons.favorite_border),
              tooltip: 'Favoriler'),
          DigerMenusu(
              haftaAc: menuVar ? _haftaAc : null,
              paylasAc: menuVar ? _paylasAc : null,
              temaAc: () => temaSeciciGoster(context, widget.temaAyari),
              ayarlarAc: _ayarlariAc,
              yenile: _yukleniyor ? null : () => _yukle()),
        ],
      ),
      // Android 15+ kenardan kenara: gezinme çubuğunun altına içerik girmesin (üstü AppBar karşılar)
      body: SafeArea(
        top: false,
        child: _yukleniyor
            ? const IskeletGovde()
            : _hata != null
                ? HataEkrani(
                    mesaj: _hata!,
                    tekrar: _yukle,
                    okulSec: _uniler.isNotEmpty ? _uniSec : null)
                : _karsilama
                    ? IlkAcilis(okulSec: _uniSec)
                    : _icerik(),
      ),
    );
  }

  Widget _icerik() => AnaIcerik(
      uni: _uni!,
      menu: _menu!,
      bugun: _bugun,
      tarih: _tarih,
      ogun: _ogun,
      yon: _yon,
      depo: _depo,
      geriBildirim: _geriBildirim,
      favoriler: _favoriler,
      kaloriHedefi: _kalori,
      simdi: _simdi,
      gunSec: _gunSec,
      eslesmeyeGit: _eslesmeyeGit,
      ogunSec: (t) => setState(() {
            _yon = 0;
            _ogun = t;
          }),
      yenile: () => _yukle(sessiz: true));
}
