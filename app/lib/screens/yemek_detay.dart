import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../config.dart';
import '../favoriler.dart';
import '../geri_bildirim.dart';
import '../models.dart';
import '../widgets/ogun_bilgi.dart';
import '../widgets/ogun_karti.dart' show yemekIkonu;
import 'geri_bildirim.dart';

/// Wikimedia Commons fotoğrafı için ağ görüntüsü. Wikimedia genel istemci kimliği taşıyan istekleri sınırladığından
/// web dışında uygulamayı tanıtan bir User-Agent gönderilir ([commonsKullaniciAjani]); tarayıcılar bu başlığın
/// değiştirilmesine izin vermediği için web'de başlık verilmez.
ImageProvider commonsFotoSaglayici(String adres) => NetworkImage(adres,
    headers: kIsWeb ? null : const {'User-Agent': commonsKullaniciAjani});

/// Bir yemeğin ayrıntı sayfası: büyük fotoğraf (yoksa degrade zemin), ad, kalori, favori kalbi, puan,
/// "Bu yemek ne zaman var" ve yorumlar. Bu listeden bir gün seçilirse sayfa o [YemekGorunumu] ile kapanır;
/// çağıran (ana sayfa) o gün ve öğüne geçer. Anahtarı olmayan yemekte (puan, yorum, favori ve gün listesi
/// anahtarla çalışır) yalnızca fotoğraf, ad ve kalori görünür.
///
/// Kapakta önce küçük örnek fotoğraf ([foto]) görünür. [fotoBilgisi] fotoğrafın Commons bilgisini verirse
/// yüksek çözünürlüklü sürüm arka planda yüklenir, yüklenince küçüğün üstüne yumuşakça geçer (yüklenemezse
/// küçük fotoğraf kalır, hata gösterilmez) ve fotoğrafın altına yazar / lisans satırı (atıf) eklenir.
class YemekDetaySayfasi extends StatefulWidget {
  final YemekOgesi yemek;
  final Universite uni;

  /// Okulun menüsü ("Bu yemek ne zaman var" bundan çıkarılır).
  final Menu menu;

  /// 'yyyy-MM-dd'; yaklaşan ve geçmiş günleri ayırır.
  final String bugun;

  /// Yemeğin örnek fotoğrafı (adresi `Depo.yemekFotoUrl`den gelir); yoksa degrade zemin ve simge gösterilir.
  final ImageProvider? foto;
  final GeriBildirimDeposu geriBildirim;

  /// Verilirse (ve yemeğin anahtarı varsa) üst çubukta favori kalbi gösterilir.
  final FavoriDeposu? favoriler;

  /// Yemeğin fotoğraf bilgisini (`Depo.yemekBilgisi`) getirir; sayfa açılınca bir kez çağrılır. Boş verilirse, null
  /// ya da hata dönerse yalnızca küçük fotoğraf gösterilir ve atıf satırı çıkmaz.
  final Future<YemekBilgisi?> Function()? fotoBilgisi;

  /// Yüksek çözünürlüklü fotoğrafın adresinden görüntü sağlayıcı üretir; boşsa [commonsFotoSaglayici]
  /// (testlerde ağsız sahte sağlayıcı verilir).
  final ImageProvider Function(String adres)? buyukFotoOlustur;
  const YemekDetaySayfasi(
      {super.key,
      required this.yemek,
      required this.uni,
      required this.menu,
      required this.bugun,
      required this.geriBildirim,
      this.foto,
      this.favoriler,
      this.fotoBilgisi,
      this.buyukFotoOlustur});

  @override
  State<YemekDetaySayfasi> createState() => _YemekDetaySayfasiState();
}

class _YemekDetaySayfasiState extends State<YemekDetaySayfasi> {
  final _kontrol = ScrollController();
  // Kapak küçülüp üst çubuk yalnızca araç çubuğu kalınca yemek adı çubukta da görünür.
  final _daraldi = ValueNotifier<bool>(false);
  double _esik = 200;
  // Fotoğraf (küçük ya da yüksek çözünürlüklü) gerçekten yüklendiyse "Örnek fotoğraf" notu ve atıf satırı
  // gösterilir (yer tutucuda gösterilmez). Bildiriciler sayesinde fotoğraf ya da bilgi gelince yalnızca bu
  // satırlar ve kapak yeniden kurulur, sayfanın geri kalanı değil.
  final _fotoVar = ValueNotifier<bool>(false);
  bool _kucukYuklendi = false, _buyukYuklendi = false;
  _FotoIzleyici? _kucukIzleyici, _buyukIzleyici;
  // Commons bilgisi (atıf için) ve ondan kurulan yüksek çözünürlüklü fotoğraf; bilgi yoksa ikisi de null kalır.
  final _bilgi = ValueNotifier<YemekBilgisi?>(null);
  final _buyukFoto = ValueNotifier<ImageProvider?>(null);
  late final Listenable _fotoVeBilgi = Listenable.merge([_fotoVar, _bilgi]);

  String? get _anahtar {
    final k = widget.yemek.anahtar;
    return k == null || k.isEmpty ? null : k;
  }

  @override
  void initState() {
    super.initState();
    _kontrol.addListener(() {
      final d = _kontrol.hasClients && _kontrol.offset > _esik;
      if (d != _daraldi.value) _daraldi.value = d;
    });
    widget.favoriler?.yukle();
    _bilgiyiYukle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final foto = widget.foto;
    if (_kucukIzleyici != null || foto == null) return;
    _kucukIzleyici =
        _FotoIzleyici(foto, createLocalImageConfiguration(context), (yuklendi) {
      _kucukYuklendi = yuklendi;
      _fotoDurumunuGuncelle();
    });
  }

  @override
  void dispose() {
    _kucukIzleyici?.birak();
    _buyukIzleyici?.birak();
    _kontrol.dispose();
    _daraldi.dispose();
    _fotoVar.dispose();
    _bilgi.dispose();
    _buyukFoto.dispose();
    super.dispose();
  }

  void _fotoDurumunuGuncelle() {
    final var_ = _kucukYuklendi || _buyukYuklendi;
    if (var_ != _fotoVar.value) _fotoVar.value = var_;
  }

  /// Fotoğrafın Commons bilgisini ister; gelirse yüksek çözünürlüklü sürüm yüklenmeye başlar ve atıf hazır olur.
  /// Bilgi yoksa ya da alınamazsa hiçbir şey değişmez (küçük fotoğraf kalır, hata gösterilmez).
  Future<void> _bilgiyiYukle() async {
    final getir = widget.fotoBilgisi;
    if (getir == null) return;
    YemekBilgisi? bilgi;
    try {
      bilgi = await getir();
    } catch (_) {
      return;
    }
    if (!mounted || bilgi == null) return;
    final buyuk = (widget.buyukFotoOlustur ??
        commonsFotoSaglayici)(bilgi.yuksekCozunurlukAdresi);
    _bilgi.value = bilgi;
    _buyukIzleyici = _FotoIzleyici(
        buyuk, createLocalImageConfiguration(context), (yuklendi) {
      _buyukYuklendi = yuklendi;
      _fotoDurumunuGuncelle();
    });
    _buyukFoto.value = buyuk;
  }

  /// Atıf satırına dokununca fotoğrafın Commons sayfasının adresi panoya kopyalanır (bağlantı açma paketi yok).
  Future<void> _atifiKopyala() async {
    final bilgi = _bilgi.value;
    if (bilgi == null) return;
    final messenger = ScaffoldMessenger.of(context);
    String mesaj;
    try {
      await Clipboard.setData(ClipboardData(text: bilgi.sayfa));
      mesaj = 'Fotoğraf sayfasının bağlantısı panoya kopyalandı';
    } catch (_) {
      mesaj = 'Bağlantı kopyalanamadı';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mesaj)));
  }

  Future<void> _favoriDegistir() async {
    final y = widget.yemek;
    final eklendi = await widget.favoriler!.degistir(_anahtar!, y.ad);
    if (!eklendi && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text(
                'En fazla ${FavoriDeposu.enCok} favori ekleyebilirsin. Önce birini çıkar.')));
    }
  }

  Widget _favoriKalbi() => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ListenableBuilder(
          listenable: widget.favoriler!,
          builder: (context, _) {
            final fav = widget.favoriler!.varMi(_anahtar!);
            // ekran okuyucu yemek adını da duyar; tooltip metni aynı kalır
            final etiket = favoriDugmeEtiketi(widget.yemek.ad, favori: fav);
            return IconButton.filledTonal(
              isSelected: fav,
              tooltip: fav ? 'Favorilerden çıkar' : 'Favorilere ekle',
              icon: Icon(Icons.favorite_border, semanticLabel: etiket),
              selectedIcon: Icon(Icons.favorite, semanticLabel: etiket),
              onPressed: _favoriDegistir,
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme;
    final ekran = MediaQuery.sizeOf(context);
    final kapak = (ekran.height * 0.36).clamp(220.0, 340.0);
    _esik = kapak - kToolbarHeight - MediaQuery.paddingOf(context).top - 12;
    // geniş ekranda (tablet, web) içerik ortada ve en çok 720 dp genişlikte kalır
    final yan = math.max(16.0, (ekran.width - 720) / 2);
    final y = widget.yemek;
    final anahtar = _anahtar;
    final slot =
        anahtar == null ? null : yemekSlotKimligi(widget.uni.id, anahtar);
    return Scaffold(
      body: CustomScrollView(
        controller: _kontrol,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: kapak,
            // geri düğmesi ve kalp fotoğrafın üstünde de okunsun diye dolgulu (tema renkli) düğmeler
            leading: BackButton(
                style: IconButton.styleFrom(
                    backgroundColor: renk.surfaceContainerHighest,
                    foregroundColor: renk.onSurfaceVariant)),
            title: ValueListenableBuilder<bool>(
              valueListenable: _daraldi,
              builder: (context, daraldi, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: daraldi
                    ? Text(y.ad,
                        key: const ValueKey('daralmis-baslik'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)
                    : const SizedBox.shrink(key: ValueKey('bos-baslik')),
              ),
            ),
            actions: [
              if (anahtar != null && widget.favoriler != null) _favoriKalbi(),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: ValueListenableBuilder<ImageProvider?>(
                valueListenable: _buyukFoto,
                builder: (context, buyuk, _) =>
                    _Kapak(ad: y.ad, foto: widget.foto, buyukFoto: buyuk),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                yan, 16, yan, 24 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverList.list(children: [
              ListenableBuilder(
                listenable: _fotoVeBilgi,
                builder: (context, _) {
                  if (!_fotoVar.value) return const SizedBox.shrink();
                  // yazar ve lisans bilinmiyorsa atıf satırı yoktur
                  final atif = _bilgi.value?.atif;
                  return Padding(
                    padding:
                        EdgeInsets.fromLTRB(4, 0, 4, atif == null ? 12 : 4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(Icons.info_outline,
                                      size: 16, color: renk.onSurfaceVariant),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      'Örnek fotoğraf, okuldaki yemek birebir aynı görünmeyebilir.',
                                      style: tema.textTheme.bodySmall?.copyWith(
                                          color: renk.onSurfaceVariant)),
                                ),
                              ]),
                          if (atif != null)
                            _AtifSatiri(metin: atif, kopyala: _atifiKopyala),
                        ]),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(y.ad,
                    style: tema.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 16),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  if (y.kcal != null)
                    _Rozet(
                        ikon: Icons.local_fire_department_outlined,
                        metin: '${y.kcal} kkal',
                        vurgulu: true),
                  _Rozet(
                      ikon: Icons.school_outlined,
                      metin: widget.uni.kisa.isEmpty
                          ? widget.uni.ad
                          : widget.uni.kisa),
                ]),
              ),
              if (slot == null)
                const _Kart(
                    child:
                        Text('Bu yemek için puan, yorum ve favori henüz yok.'))
              else ...[
                _PuanKarti(
                    key: ValueKey('puan-$slot'),
                    depo: widget.geriBildirim,
                    slot: slot),
                const SizedBox(height: 8),
                _NeZamanKarti(
                    gorunumler: yemekTarihleri(widget.menu, anahtar!),
                    bugun: widget.bugun,
                    sec: (g) => Navigator.of(context).pop(g)),
                const SizedBox(height: 8),
                GeriBildirimBolumu(
                    key: ValueKey(slot),
                    depo: widget.geriBildirim,
                    slot: slot,
                    puanGoster: false,
                    baslik: 'Bu yemek hakkında'),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

/// Bir [ImageProvider]ın yüklenip yüklenmediğini izler: ilk kare gelince `true`, yükleme hatasında `false` bildirir.
/// Görüntü zaten önbellekteyse bildirim kurulurken eşzamanlı gelebilir. Hata burada yutulur (kapak yer tutucuya
/// döner); [birak] ile dinleyici kaldırılır.
class _FotoIzleyici {
  final ImageStream _akis;
  late final ImageStreamListener _dinleyici;

  _FotoIzleyici(ImageProvider saglayici, ImageConfiguration yapilandirma,
      ValueChanged<bool> degisti)
      : _akis = saglayici.resolve(yapilandirma) {
    _dinleyici = ImageStreamListener((bilgi, _) {
      // dinleyiciye verilen kopya yalnızca "yüklendi" bildirimi için: görüntüyü tutmasın
      bilgi.dispose();
      degisti(true);
    }, onError: (_, __) => degisti(false));
    _akis.addListener(_dinleyici);
  }

  void birak() => _akis.removeListener(_dinleyici);
}

/// Başlıktaki büyük görsel: yemek fotoğrafı; yoksa, yüklenemezse ya da gelene kadar yemek adından simgeli degrade zemin.
/// [buyukFoto] (yüksek çözünürlüklü sürüm) varsa küçük fotoğrafın üstüne yüklenir ve yüklenince ~250 ms'de yumuşakça
/// belirir; yüklenemezse hiçbir şey göstermez, küçük fotoğraf (ya da yer tutucu) kalır.
class _Kapak extends StatelessWidget {
  final String ad;
  final ImageProvider? foto;
  final ImageProvider? buyukFoto;
  const _Kapak({required this.ad, required this.foto, this.buyukFoto});

  /// Yüksek çözünürlüklü sürümün belirme süresi.
  static const _gecis = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final yerTutucu = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              renk.primaryContainer,
              Color.alphaBlend(
                  renk.primary.withValues(alpha: 0.28), renk.primaryContainer)
            ]),
      ),
      child: Center(
        child: ExcludeSemantics(
          child: Icon(yemekIkonu(ad),
              size: 96, color: renk.onPrimaryContainer.withValues(alpha: 0.6)),
        ),
      ),
    );
    if (foto == null && buyukFoto == null) {
      return SizedBox.expand(child: yerTutucu);
    }
    final sure =
        MediaQuery.disableAnimationsOf(context) ? Duration.zero : _gecis;
    return SizedBox.expand(
      child: Semantics(
        image: true,
        label: 'Fotoğraf: $ad',
        child: Stack(fit: StackFit.expand, children: [
          if (foto == null)
            yerTutucu
          else
            Image(
              image: foto!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (c, e, s) => yerTutucu,
              // ilk kare gelene kadar boş kalmasın
              frameBuilder: (c, child, kare, hemen) =>
                  (hemen || kare != null) ? child : yerTutucu,
            ),
          if (buyukFoto != null)
            Image(
              image: buyukFoto!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              // yüklenemezse küçük fotoğraf kalır; hata gösterilmez
              errorBuilder: (c, e, s) => const SizedBox.shrink(),
              // önbellekten hemen gelirse geçiş yok; ağdan geliyorsa ilk kareyle birlikte yumuşakça belirir
              frameBuilder: (c, child, kare, hemen) => hemen
                  ? child
                  : AnimatedOpacity(
                      opacity: kare == null ? 0 : 1,
                      duration: sure,
                      curve: Curves.easeOut,
                      child: child),
            ),
        ]),
      ),
    );
  }
}

/// Fotoğraf atıf satırı ("Fotoğraf: E4024 · CC BY-SA 4.0 · Wikimedia Commons"). Dokunma hedefi >= 48 dp;
/// dokununca [kopyala] çağrılır (fotoğraf sayfasının bağlantısı panoya gider).
class _AtifSatiri extends StatelessWidget {
  final String metin;
  final VoidCallback kopyala;
  const _AtifSatiri({required this.metin, required this.kopyala});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme.onSurfaceVariant;
    // container: düğme kendi anlam düğümü olsun; yanındaki "Örnek fotoğraf" notunun metniyle birleşip not da
    // dokunulabilir görünmesin
    return Semantics(
      container: true,
      button: true,
      onTapHint: 'Fotoğraf sayfasının bağlantısını kopyala',
      child: InkWell(
        onTap: kopyala,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              ExcludeSemantics(child: Icon(Icons.link, size: 16, color: renk)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(metin,
                    style: tema.textTheme.bodySmall?.copyWith(
                        color: renk,
                        decoration: TextDecoration.underline,
                        decorationColor: renk)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Küçük yuvarlak bilgi etiketi (kalori, okul). [vurgulu] ise birincil kap rengiyle.
class _Rozet extends StatelessWidget {
  final IconData ikon;
  final String metin;
  final bool vurgulu;
  const _Rozet({required this.ikon, required this.metin, this.vurgulu = false});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme;
    final on = vurgulu ? renk.onPrimaryContainer : renk.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: vurgulu ? renk.primaryContainer : renk.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ikon, size: 18, color: on),
        const SizedBox(width: 6),
        Flexible(
          child: Text(metin,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.labelLarge
                  ?.copyWith(color: on, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// Sayfadaki bölümlerin kartı; yorumlar kartıyla ([GeriBildirimBolumu]) aynı görünür.
class _Kart extends StatelessWidget {
  final Widget child;
  const _Kart({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// Puan kartı: ortalama, oy sayısı, kullanıcının puanı ve 1-5 yıldız. Puan yemek bazlıdır ([slot] =
/// `yemekSlotKimligi`); önce hemen gösterilir, kayıt başarısızsa eski haline döner ve bildirim çıkar.
class _PuanKarti extends StatefulWidget {
  final GeriBildirimDeposu depo;
  final String slot;
  const _PuanKarti({super.key, required this.depo, required this.slot});

  @override
  State<_PuanKarti> createState() => _PuanKartiState();
}

class _PuanKartiState extends State<_PuanKarti> {
  PuanOzeti _ozet = const PuanOzeti(null, 0);
  int? _benim;
  bool _yukleniyor = true, _hata = false, _kaydediyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  /// Yemeğin puan özetini ve kullanıcının puanını okur. Okunduysa true.
  Future<bool> _oku() async {
    try {
      final p = await widget.depo.puanlar([widget.slot]);
      if (!mounted) return false;
      setState(() {
        _ozet = p.ozet[widget.slot] ?? const PuanOzeti(null, 0);
        _benim = p.benim[widget.slot];
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = false;
    });
    final tamam = await _oku();
    if (mounted) {
      setState(() {
        _yukleniyor = false;
        _hata = !tamam;
      });
    }
  }

  Future<void> _puanVer(int yildiz) async {
    if (_kaydediyor) return;
    final onceki = _benim;
    setState(() {
      _kaydediyor = true;
      _benim = yildiz;
    });
    try {
      await widget.depo.puanVer(widget.slot, yildiz);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _benim = onceki;
        _kaydediyor = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Puan kaydedilemedi. İnternet bağlantını kontrol et.')));
      return;
    }
    await _oku(); // puan kaydedildi; özet okunamazsa görünen ortalama eski kalır
    if (mounted) setState(() => _kaydediyor = false);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme;
    final soluk =
        tema.textTheme.bodyMedium?.copyWith(color: renk.onSurfaceVariant);
    final ort = _ozet.ortalama;
    return _Kart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Puan',
            style: tema.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (_hata)
          Row(children: [
            const Expanded(child: Text('Puanlar yüklenemedi.')),
            TextButton(onPressed: _yukle, child: const Text('Tekrar dene')),
          ])
        else if (_yukleniyor)
          Text('Puanlar yükleniyor…', style: soluk)
        else if (ort == null)
          Text('Henüz oy yok. İlk puanı sen ver.', style: soluk)
        else
          Semantics(
            label: 'Ortalama puan ${ort.toStringAsFixed(1)}, ${_ozet.adet} oy',
            excludeSemantics: true,
            child: Row(children: [
              Icon(Icons.star_rounded, size: 36, color: renk.primary),
              const SizedBox(width: 6),
              Text(ort.toStringAsFixed(1),
                  style: tema.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Flexible(
                  child: Text('Ortalama · ${_ozet.adet} oy', style: soluk)),
            ]),
          ),
        const SizedBox(height: 14),
        Text(
            _benim == null
                ? 'Bu yemeği nasıl buldun?'
                : 'Senin puanın: $_benim / 5 (değiştirmek için dokun)',
            style: soluk),
        const SizedBox(height: 4),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Row(children: [
              for (var i = 1; i <= 5; i++)
                // her yıldız eşit pay alır ama düğme 48 dp'lik daire kalır (geniş oval vurgu olmasın)
                Expanded(
                  child: Center(
                    child: IconButton(
                      iconSize: 32,
                      color: renk.primary,
                      tooltip: '$i yıldız',
                      isSelected: (_benim ?? 0) >= i,
                      icon: const Icon(Icons.star_outline_rounded),
                      selectedIcon: const Icon(Icons.star_rounded),
                      onPressed: () => _puanVer(i),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        if (!widget.depo.cevrimici)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Deneme modu: puanlar yalnızca bu cihazda saklanır.',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: renk.onSurfaceVariant)),
          ),
      ]),
    );
  }
}

/// "Bugün", "Yarın" için tarih de eklenir ("Yarın · 3 Kasım"); diğerleri "Cuma 6 Kasım" biçimindedir.
String _gunMetni(String tarih, String bugun) {
  final etiket = favoriGunEtiketi(tarih, bugun, tamTarih: true);
  final d = DateTime.tryParse(tarih);
  return (etiket == 'Bugün' || etiket == 'Yarın') && d != null
      ? '$etiket · ${d.day} ${ayAdlari[d.month - 1]}'
      : etiket;
}

/// "Bu yemek ne zaman var": yemeğin menüdeki yaklaşan ve geçmiş günleri. Satıra dokununca [sec] çağrılır.
class _NeZamanKarti extends StatefulWidget {
  final List<YemekGorunumu> gorunumler;
  final String bugun;
  final ValueChanged<YemekGorunumu> sec;
  const _NeZamanKarti(
      {required this.gorunumler, required this.bugun, required this.sec});

  @override
  State<_NeZamanKarti> createState() => _NeZamanKartiState();
}

class _NeZamanKartiState extends State<_NeZamanKarti> {
  /// Her grupta ilk açılışta gösterilen en çok satır.
  static const _ilkSatir = 5;
  bool _hepsi = false;

  Widget _baslik(String metin, ThemeData tema) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(metin,
            style: tema.textTheme.labelLarge?.copyWith(
                color: tema.colorScheme.primary, fontWeight: FontWeight.w700)),
      );

  Widget _satir(YemekGorunumu g, IconData ikon) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(ikon),
        title: Text(_gunMetni(g.tarih, widget.bugun)),
        subtitle: Text(ogunAdlari[g.ogun] ?? g.ogun),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => widget.sec(g),
      );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme;
    final bugun = widget.bugun;
    final yaklasan = [
      for (final g in widget.gorunumler)
        if (g.tarih.compareTo(bugun) >= 0) g
    ];
    // geçmiş: en yeni gün başta, aynı günde öğün sırası korunur
    final gecmis = [
      for (final g in widget.gorunumler)
        if (g.tarih.compareTo(bugun) < 0) g
    ]..sort((a, b) => a.tarih == b.tarih
        ? ogunSirasi.indexOf(a.ogun).compareTo(ogunSirasi.indexOf(b.ogun))
        : b.tarih.compareTo(a.tarih));
    final kisalt = yaklasan.length > _ilkSatir || gecmis.length > _ilkSatir;
    final sinir = _hepsi ? 1 << 30 : _ilkSatir;
    return _Kart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bu yemek ne zaman var',
            style: tema.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        if (widget.gorunumler.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Bu yemek yayınlanan menüde görünmüyor.',
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: renk.onSurfaceVariant)),
          )
        else ...[
          _baslik('Yaklaşan günler', tema),
          if (yaklasan.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Yayınlanan menüde yaklaşan gün yok.',
                  style: tema.textTheme.bodyMedium
                      ?.copyWith(color: renk.onSurfaceVariant)),
            ),
          for (final g in yaklasan.take(sinir)) _satir(g, Icons.event_outlined),
          if (gecmis.isNotEmpty) _baslik('Geçmişte', tema),
          for (final g in gecmis.take(sinir)) _satir(g, Icons.history),
          if (kisalt)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _hepsi = !_hepsi),
                child: Text(_hepsi
                    ? 'Daha az göster'
                    : 'Tümünü göster (${widget.gorunumler.length})'),
              ),
            ),
        ],
      ]),
    );
  }
}
