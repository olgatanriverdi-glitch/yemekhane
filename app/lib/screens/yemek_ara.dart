import 'dart:async';

import 'package:flutter/material.dart';

import '../arama.dart';
import '../favoriler.dart' show favoriGunEtiketi;
import '../models.dart';
import '../repository.dart';
import '../widgets/ogun_bilgi.dart';

enum _Kapsam { sehir, tumu }

/// Tam ekran yemek arama: seçili okulun şehrindeki okulların (ya da tüm okulların) bugünden sonraki
/// menülerinde arar. Bir sonuca dokununca sayfa o [AramaSonucu] ile kapanır; ana sayfa o okula,
/// güne ve öğüne geçer. Menüler paralel yüklenir, geldikçe sonuçlara eklenir.
class YemekAraSayfasi extends StatefulWidget {
  final Depo depo;
  final List<Universite> uniler;

  /// Ana sayfada seçili okul; şehir kapsamı buna göre belirlenir.
  final Universite uni;

  /// Seçili okulun ana sayfada zaten yüklü menüsü (tekrar indirilmez).
  final Menu? menu;

  /// 'yyyy-MM-dd'; bu günden öncesi aranmaz.
  final String bugun;
  const YemekAraSayfasi(
      {super.key,
      required this.depo,
      required this.uniler,
      required this.uni,
      required this.bugun,
      this.menu});

  @override
  State<YemekAraSayfasi> createState() => _YemekAraSayfasiState();
}

class _YemekAraSayfasiState extends State<YemekAraSayfasi> {
  static const _bekleme = Duration(milliseconds: 250);

  final _ctrl = TextEditingController();
  Timer? _bekle;
  String _sorgu = '';
  bool _yaziBos = true;
  late final List<Universite> _hepsi;
  late final List<Universite> _sehir;
  late _Kapsam _kapsam;

  /// okul kimliği -> menü; null değer "alınamadı" demektir. Kapsam değişince yeniden kullanılır.
  final Map<String, Menu?> _menuler = {};

  /// Şu an istenmiş, henüz bitmemiş okullar.
  final Set<String> _istekte = {};
  List<AramaSonucu> _sonuclar = const [];
  List<({String? baslik, AramaSonucu? sonuc})> _satirlar = const [];

  @override
  void initState() {
    super.initState();
    final u = widget.uni;
    _hepsi = [
      ...widget.uniler,
      if (!widget.uniler.any((x) => x.id == u.id)) u,
    ];
    final sehirAdi = sadeTr(u.sehir);
    _sehir = [
      for (final x in _hepsi)
        if (x.id == u.id ||
            (sehirAdi.isNotEmpty && sadeTr(x.sehir) == sehirAdi))
          x
    ];
    // şehirde tek okul varsa "şehir" kapsamının anlamı yok: doğrudan tüm okullar
    _kapsam = _sehir.length <= 1 ? _Kapsam.tumu : _Kapsam.sehir;
    if (widget.menu != null) _menuler[u.id] = widget.menu;
    _ctrl.addListener(() {
      final bos = _ctrl.text.isEmpty;
      if (bos != _yaziBos) setState(() => _yaziBos = bos);
    });
    _yukle();
  }

  @override
  void dispose() {
    _bekle?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  List<Universite> get _kapsamUniler =>
      _kapsam == _Kapsam.tumu ? _hepsi : _sehir;

  /// Kapsamdaki, henüz yüklenmemiş (ya da alınamamış) ve istekte olmayan okulları ister.
  void _yukle() {
    final eksik = [
      for (final u in _kapsamUniler)
        if (_menuler[u.id] == null && !_istekte.contains(u.id)) u.id
    ];
    if (eksik.isEmpty) return;
    _istekte.addAll(eksik);
    unawaited(_istek(eksik));
  }

  Future<void> _istek(List<String> idler) async {
    try {
      await widget.depo.menuler(idler, biten: (id, menu) {
        _istekte.remove(id);
        _menuler[id] = menu;
        if (mounted) setState(_hesapla);
      });
    } catch (_) {
      // depo beklenmedik bir hata verirse aşağıda kalanlar "alınamadı" sayılır
    }
    for (final id in idler) {
      if (_istekte.remove(id)) _menuler[id] = null;
    }
    if (mounted) setState(_hesapla);
  }

  void _hesapla() {
    _sonuclar = yemekAra({
      for (final u in _kapsamUniler)
        if (_menuler[u.id] != null) u: _menuler[u.id]!
    }, _sorgu, widget.bugun);
    final satirlar = <({String? baslik, AramaSonucu? sonuc})>[];
    String? son;
    for (final s in _sonuclar) {
      if (s.tarih != son) {
        son = s.tarih;
        satirlar.add((
          baslik: favoriGunEtiketi(s.tarih, widget.bugun, tamTarih: true),
          sonuc: null
        ));
      }
      satirlar.add((baslik: null, sonuc: s));
    }
    _satirlar = satirlar;
  }

  void _yazildi(String s) {
    _bekle?.cancel();
    _bekle = Timer(_bekleme, () => _sorguUygula(s));
  }

  void _sorguUygula(String s) {
    _bekle?.cancel();
    if (!mounted) return;
    setState(() {
      _sorgu = s;
      _hesapla();
    });
  }

  void _temizle() {
    _ctrl.clear();
    _sorguUygula('');
  }

  void _kapsamSec(_Kapsam k) {
    if (k == _kapsam) return;
    setState(() {
      _kapsam = k;
      _yukle();
      _hesapla();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ids = [for (final u in _kapsamUniler) u.id];
    final toplam = ids.length;
    final bitenler = ids.where((id) => !_istekte.contains(id)).length;
    final yukleniyor = bitenler < toplam;
    final yuklenen = ids.where((id) => _menuler[id] != null).length;
    final hatali = ids
        .where((id) => !_istekte.contains(id) && _menuler.containsKey(id))
        .where((id) => _menuler[id] == null)
        .length;
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _yazildi,
          onSubmitted: _sorguUygula,
          style: tema.textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: 'Yemek ara',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _yaziBos
                ? null
                : IconButton(
                    onPressed: _temizle,
                    icon: const Icon(Icons.close),
                    tooltip: 'Temizle'),
          ),
        ),
      ),
      // yalnızca kapsam seçimi sabit; ilerleme, hata ve sonuçlar birlikte kayar (klavye açıkken
      // ve büyük yazıda sıkışmasınlar). SafeArea: Android 15+ kenardan kenara düzende sonuçlar gezinme
      // çubuğunun altına girmesin (üstü AppBar karşılar; klavye açıkken alt boşluk zaten sıfırdır)
      body: SafeArea(
        top: false,
        child: Column(children: [
          _kapsamSatiri(),
          Expanded(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                if (yukleniyor)
                  SliverToBoxAdapter(child: _ilerleme(bitenler, toplam)),
                if (hatali > 0)
                  SliverToBoxAdapter(
                      child: _hataSatiri(hatali, yukleniyor, tema)),
                ..._govde(tema, yukleniyor, yuklenen, hatali),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _kapsamSatiri() {
    final sehir = widget.uni.sehir;
    final etiketler = {
      _Kapsam.sehir: sehir.isEmpty ? 'Bu okul' : 'Şehir: $sehir',
      _Kapsam.tumu: 'Tüm okullar',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 4, children: [
          for (final k in _Kapsam.values)
            ChoiceChip(
              label: Text(etiketler[k]!),
              selected: _kapsam == k,
              onSelected: (_) => _kapsamSec(k),
            ),
        ]),
      ),
    );
  }

  Widget _ilerleme(int biten, int toplam) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$biten/$toplam okul yüklendi',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          LinearProgressIndicator(
              value: toplam == 0 ? null : biten / toplam,
              semanticsLabel: 'Okul menüleri yükleniyor'),
        ]),
      );

  /// "N okulun menüsü alınamadı" ve (yükleme bittiyse) "Tekrar dene". Dar ekranda düğme alt satıra geçer.
  Widget _hataSatiri(int hatali, bool yukleniyor, ThemeData tema) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: tema.colorScheme.error),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('$hatali okulun menüsü alınamadı',
                      style: tema.textTheme.bodySmall
                          ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
                ),
              ]),
              if (!yukleniyor)
                TextButton(
                    onPressed: () => setState(_yukle),
                    child: const Text('Tekrar dene')),
            ]),
      );

  List<Widget> _govde(
      ThemeData tema, bool yukleniyor, int yuklenen, int hatali) {
    Widget mesaj(IconData ikon, String baslik, [String? alt]) =>
        SliverFillRemaining(
            hasScrollBody: false,
            child: _Mesaj(ikon: ikon, baslik: baslik, alt: alt));
    if (!aramaSorgusuGecerli(_sorgu)) {
      return [
        mesaj(Icons.search, 'Aramak için yemek adını yaz',
            'En az $aramaEnAzHarf harf yaz. Bugünden sonraki menülerde aranır.')
      ];
    }
    if (_satirlar.isEmpty) {
      if (yukleniyor) {
        return [mesaj(Icons.hourglass_empty, 'Menüler yükleniyor')];
      }
      if (yuklenen == 0 && hatali > 0) {
        return [
          mesaj(Icons.cloud_off_outlined, 'Menüler alınamadı',
              'İnternet bağlantını kontrol edip tekrar dene.')
        ];
      }
      return [
        mesaj(
            Icons.search_off,
            'Sonuç bulunamadı',
            _kapsam == _Kapsam.sehir
                ? 'Bu şehirdeki okullarda eşleşen yemek yok. "Tüm okullar"ı deneyebilirsin.'
                : 'Bugünden sonraki menülerde eşleşen yemek yok.')
      ];
    }
    final sinirda = _sonuclar.length >= aramaEnCok;
    return [
      SliverList.builder(
        itemCount: _satirlar.length + (sinirda ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _satirlar.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  'İlk $aramaEnCok sonuç gösteriliyor. Aramayı daraltabilirsin.',
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            );
          }
          final s = _satirlar[i];
          if (s.baslik != null) {
            return Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(s.baslik!,
                    style: tema.textTheme.titleSmall?.copyWith(
                        color: tema.colorScheme.primary,
                        fontWeight: FontWeight.w700)),
              ),
            );
          }
          final r = s.sonuc!;
          final okul = r.okul.kisa.isNotEmpty ? r.okul.kisa : r.okul.ad;
          return ListTile(
            title: Text(r.ad, maxLines: 3, overflow: TextOverflow.ellipsis),
            subtitle: Text('$okul · ${ogunAdlari[r.ogun] ?? r.ogun}',
                maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.of(context).pop(r),
          );
        },
      ),
    ];
  }
}

/// Ortada simge, başlık ve (varsa) açıklama: boş / yükleniyor / sonuç yok durumları.
class _Mesaj extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String? alt;
  const _Mesaj({required this.ikon, required this.baslik, this.alt});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(
              child: Icon(ikon, size: 48, color: tema.colorScheme.primary)),
          const SizedBox(height: 12),
          Text(baslik,
              textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
          if (alt != null) ...[
            const SizedBox(height: 6),
            Text(alt!,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}
