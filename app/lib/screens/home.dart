import 'package:flutter/material.dart';

import '../config.dart';
import '../models.dart';
import '../repository.dart';
import 'university_picker.dart';

const _ogunAdlari = {'lunch': 'Öğle', 'dinner': 'Akşam', 'vegetarian': 'Vejetaryen'};
const _ogunIkon = {'lunch': Icons.wb_sunny_outlined, 'dinner': Icons.nights_stay_outlined, 'vegetarian': Icons.eco_outlined};

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final _depo = Depo();
  List<Universite> _uniler = [];
  Universite? _uni;
  Menu? _menu;
  String? _hata;
  bool _yukleniyor = true;
  late String _tarih;
  String _ogun = 'lunch';

  @override
  void initState() {
    super.initState();
    final simdi = DateTime.now();
    _tarih = isoTarih(simdi);
    _ogun = simdi.hour >= 15 ? 'dinner' : 'lunch'; // öğleden sonra akşam menüsünü göster
    _yukle();
  }

  Future<void> _yukle({String? universiteId}) async {
    setState(() { _yukleniyor = true; _hata = null; });
    try {
      _uniler = await _depo.universiteler();
      final kayitli = universiteId ?? await _depo.seciliUniversite();
      _uni = _uniler.firstWhere((u) => u.id == kayitli, orElse: () => _uniler.first);
      await _depo.universiteSec(_uni!.id);
      _menu = await _depo.menu(_uni!.id);
      // bugün menüde yoksa en yakın günü seç
      if (!_menu!.gunler.containsKey(_tarih)) {
        final t = _menu!.tarihler;
        _tarih = t.firstWhere((x) => x.compareTo(_tarih) >= 0, orElse: () => t.last);
      }
      _uygunOgunSec();
    } catch (e) {
      _hata = 'Menü yüklenemedi. İnternet bağlantını kontrol et.';
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  // Gün değişince / ilk açılışta: seçili öğün o gün boşsa (okul yayınlamamış olabilir) dolu olan ilk öğüne geç.
  // Kullanıcı sekmeye kendisi basarsa dokunulmaz.
  void _uygunOgunSec() {
    final gun = _menu?.gunler[_tarih];
    if (gun == null) return;
    if (gun[_ogun] != null && !gun[_ogun]!.bos) return;
    for (final t in ['lunch', 'dinner', 'vegetarian']) {
      if (gun[t] != null && !gun[t]!.bos) { _ogun = t; return; }
    }
  }

  void _gunSec(String t) => setState(() { _tarih = t; _uygunOgunSec(); });

  Future<void> _uniSec() async {
    final secilen = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => UniversitePicker(uniler: _uniler, secili: _uni?.id)));
    if (secilen != null && secilen != _uni?.id) _yukle(universiteId: secilen);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _uniler.isEmpty ? null : _uniSec,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(_uni?.ad ?? 'Yemekhane', overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down),
            ]),
          ),
        ),
        actions: [IconButton(onPressed: _yukleniyor ? null : () => _yukle(), icon: const Icon(Icons.refresh), tooltip: 'Yenile')],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _hata != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_hata!), const SizedBox(height: 12), FilledButton(onPressed: _yukle, child: const Text('Tekrar dene'))]))
              : _icerik(tema),
    );
  }

  Widget _icerik(ThemeData tema) {
    final menu = _menu!;
    final bugun = isoTarih(DateTime.now());
    var tarihler = menu.tarihler.where((t) => t.compareTo(bugun) >= 0).toList();   // geçmiş günler gösterilmez
    if (tarihler.isEmpty) tarihler = menu.tarihler.reversed.take(7).toList().reversed.toList();
    final gun = menu.gunler[_tarih] ?? {};
    final turler = [for (final t in ['lunch', 'dinner', 'vegetarian']) if (_uni!.ogunler.contains(t)) t];
    final aktif = turler.contains(_ogun) ? _ogun : turler.first;
    final ogun = gun[aktif];
    return Column(children: [
      _GunBasligi(tarihler: tarihler, secili: _tarih, bugun: bugun, degisti: _gunSec),
      _HaftaSeridi(tarihler: tarihler, secili: _tarih, bugun: bugun, degisti: _gunSec),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SegmentedButton<String>(
          segments: [for (final t in turler) ButtonSegment(value: t, label: FittedBox(fit: BoxFit.scaleDown, child: Text(_ogunAdlari[t] ?? t, maxLines: 1)), icon: Icon(_ogunIkon[t], size: 18))],
          selected: {aktif},
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact, padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4))),
          onSelectionChanged: (s) => setState(() => _ogun = s.first),
        ),
      ),
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            final i = tarihler.indexOf(_tarih);
            if (v < -250 && i >= 0 && i < tarihler.length - 1) _gunSec(tarihler[i + 1]);
            if (v > 250 && i > 0) _gunSec(tarihler[i - 1]);
          },
          child: ogun == null || ogun.bos
            ? (aktif == 'vegetarian' ? _EtsizOneri(gun: gun) : Center(child: Text('Bu gün için ${_ogunAdlari[aktif]?.toLowerCase() ?? ''} menüsü henüz yayınlanmadı.', textAlign: TextAlign.center)))
            : _OgunKarti(ogun: ogun, fiyat: _uni!.ogrenciFiyati(aktif), fotoUrl: _depo.fotoUrl(_uni!.id, ogun.foto)),
        ),
      ),
      if (menu.guncellendi != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('Son güncelleme: ${menu.guncellendi!.day} ${ayAdlari[menu.guncellendi!.month - 1]} ${menu.guncellendi!.hour.toString().padLeft(2, '0')}:${menu.guncellendi!.minute.toString().padLeft(2, '0')}',
              style: tema.textTheme.bodySmall),
        ),
    ]);
  }
}

/// Üstte büyük "Bugün / Cuma · 2 Ekim" başlığı ve yanlarda önceki / sonraki gün okları.
class _GunBasligi extends StatelessWidget {
  final List<String> tarihler;
  final String secili, bugun;
  final ValueChanged<String> degisti;
  const _GunBasligi({required this.tarihler, required this.secili, required this.bugun, required this.degisti});

  String _etiket(DateTime d, String t) {
    final fark = DateTime(d.year, d.month, d.day).difference(DateTime.parse(bugun)).inDays;
    if (fark == 0) return 'Bugün';
    if (fark == 1) return 'Yarın';
    return gunAdlari[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final i = tarihler.indexOf(secili);
    final d = DateTime.parse(secili);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(children: [
        IconButton.filledTonal(onPressed: i > 0 ? () => degisti(tarihler[i - 1]) : null, icon: const Icon(Icons.chevron_left), tooltip: 'Önceki gün'),
        Expanded(
          child: Column(children: [
            Text(_etiket(d, secili), style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text('${d.day} ${ayAdlari[d.month - 1]} ${d.year} · ${gunAdlari[d.weekday - 1]}', style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ]),
        ),
        IconButton.filledTonal(onPressed: i >= 0 && i < tarihler.length - 1 ? () => degisti(tarihler[i + 1]) : null, icon: const Icon(Icons.chevron_right), tooltip: 'Sonraki gün'),
      ]),
    );
  }
}

/// Seçili günün etrafındaki 7 gün: eşit genişlikte, kaydırma yok. Dokununca o güne geçer.
class _HaftaSeridi extends StatelessWidget {
  final List<String> tarihler;
  final String secili, bugun;
  final ValueChanged<String> degisti;
  const _HaftaSeridi({required this.tarihler, required this.secili, required this.bugun, required this.degisti});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final n = tarihler.length;
    final i = tarihler.indexOf(secili).clamp(0, n - 1);
    final baslangic = (i - 3).clamp(0, (n - 7).clamp(0, n));
    final pencere = tarihler.sublist(baslangic, (baslangic + 7).clamp(0, n));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(children: [
        for (final t in pencere)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: _GunHucresi(tarih: t, secili: t == secili, bugun: t == bugun, renk: renk, tikla: () => degisti(t)),
            ),
          ),
      ]),
    );
  }
}

class _GunHucresi extends StatelessWidget {
  final String tarih;
  final bool secili, bugun;
  final ColorScheme renk;
  final VoidCallback tikla;
  const _GunHucresi({required this.tarih, required this.secili, required this.bugun, required this.renk, required this.tikla});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse(tarih);
    final haftaSonu = d.weekday >= 6;
    final yaziRenk = secili ? renk.onPrimary : (haftaSonu ? renk.onSurfaceVariant.withValues(alpha: 0.7) : renk.onSurface);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: secili ? renk.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: secili ? renk.primary : (bugun ? renk.primary.withValues(alpha: 0.7) : renk.outlineVariant.withValues(alpha: 0.5)), width: bugun && !secili ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: tikla,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(gunKisa[d.weekday - 1], style: TextStyle(color: yaziRenk, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${d.day}', style: TextStyle(color: yaziRenk, fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class _OgunKarti extends StatelessWidget {
  final Ogun ogun;
  final int? fiyat;
  final String? fotoUrl;
  const _OgunKarti({required this.ogun, this.fiyat, this.fotoUrl});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (fotoUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: Image.network(
                  fotoUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, child, p) => p == null ? child : Container(color: tema.colorScheme.surfaceContainerHighest, child: const Center(child: CircularProgressIndicator())),
                  errorBuilder: (c, e, s) => Container(color: tema.colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.restaurant, size: 40))),
                ),
              ),
            ),
          ),
        Card(
          elevation: 0,
          color: tema.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final o in ogun.ogeler)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(child: Text(o.ad, style: tema.textTheme.titleMedium)),
                    if (o.kcal != null) Text('${o.kcal} kkal', style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
                  ]),
                ),
              if (ogun.kcal != null || fiyat != null) const Divider(height: 28),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (ogun.kcal != null) Chip(avatar: const Icon(Icons.local_fire_department_outlined, size: 18), label: Text('Toplam ${ogun.kcal} kkal')),
                if (fiyat != null) Chip(avatar: const Icon(Icons.payments_outlined, size: 18), label: Text('Öğrenci $fiyat ₺')),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Okul o gün vejetaryen menü yayınlamadıysa: öğle ve akşam menüsündeki etsiz görünen yemekleri öneri olarak gösterir.
class _EtsizOneri extends StatelessWidget {
  final Map<String, Ogun> gun;
  const _EtsizOneri({required this.gun});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final bolumler = <Widget>[];
    for (final tur in ['lunch', 'dinner']) {
      final o = gun[tur];
      if (o == null || o.bos) continue;
      final etsiz = o.ogeler.where((e) => etsizMi(e.ad)).toList();
      if (etsiz.isEmpty) continue;
      bolumler.add(Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text('${_ogunAdlari[tur]} menüsünden etsiz görünenler', style: tema.textTheme.titleSmall?.copyWith(color: tema.colorScheme.primary)),
      ));
      for (final e in etsiz) {
        bolumler.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Icon(Icons.eco_outlined, size: 18, color: tema.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(e.ad, style: tema.textTheme.titleMedium)),
            if (e.kcal != null) Text('${e.kcal} kkal', style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ]),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: tema.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Okul bu gün için ayrı bir vejetaryen menü yayınlamadı.', style: tema.textTheme.titleMedium),
              if (bolumler.isNotEmpty) ...bolumler else const Padding(padding: EdgeInsets.only(top: 12), child: Text('Bu günün menüsünde etsiz görünen yemek bulunamadı.')),
              const Divider(height: 28),
              Text('Bu liste otomatik tahmindir (yemek adlarına göre). Çorba ve yemeklerin içeriği değişebilir; kesin bilgi için yemekhane görevlisine sor.',
                  style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ],
    );
  }
}
