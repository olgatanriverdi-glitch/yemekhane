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
    final tarihler = menu.tarihler;
    final gun = menu.gunler[_tarih] ?? {};
    final turler = [for (final t in ['lunch', 'dinner', 'vegetarian']) if (_uni!.ogunler.contains(t)) t];
    final aktif = turler.contains(_ogun) ? _ogun : turler.first;
    final ogun = gun[aktif];
    return Column(children: [
      _GunSeridi(tarihler: tarihler, secili: _tarih, bugun: isoTarih(DateTime.now()), degisti: (t) => setState(() { _tarih = t; _uygunOgunSec(); })),
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
        child: ogun == null || ogun.bos
            ? Center(child: Text('Bu gün için ${_ogunAdlari[aktif]?.toLowerCase() ?? ''} menüsü henüz yayınlanmadı.', textAlign: TextAlign.center))
            : _OgunKarti(ogun: ogun, fiyat: _uni!.ogrenciFiyati(aktif)),
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

class _GunSeridi extends StatefulWidget {
  final List<String> tarihler;
  final String secili, bugun;
  final ValueChanged<String> degisti;
  const _GunSeridi({required this.tarihler, required this.secili, required this.bugun, required this.degisti});
  @override
  State<_GunSeridi> createState() => _GunSeridiState();
}

class _GunSeridiState extends State<_GunSeridi> {
  final _kontrol = ScrollController();
  static const _genislik = 72.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final i = widget.tarihler.indexOf(widget.secili);
      if (i > 0 && _kontrol.hasClients) _kontrol.jumpTo((i * _genislik - 120).clamp(0, _kontrol.position.maxScrollExtent));
    });
  }

  @override
  void dispose() { _kontrol.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return SizedBox(
      height: 84,
      child: ListView.builder(
        controller: _kontrol,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: widget.tarihler.length,
        itemBuilder: (_, i) {
          final t = widget.tarihler[i];
          final d = DateTime.parse(t);
          final secili = t == widget.secili;
          final bugun = t == widget.bugun;
          return SizedBox(
            width: _genislik,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Material(
                color: secili ? renk.primary : renk.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => widget.degisti(t),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(gunKisa[d.weekday - 1], style: TextStyle(color: secili ? renk.onPrimary : renk.onSurfaceVariant, fontSize: 12)),
                    Text('${d.day}', style: TextStyle(color: secili ? renk.onPrimary : renk.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                    Container(height: 4, width: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: bugun ? (secili ? renk.onPrimary : renk.primary) : Colors.transparent)),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OgunKarti extends StatelessWidget {
  final Ogun ogun;
  final int? fiyat;
  const _OgunKarti({required this.ogun, this.fiyat});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
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
