import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../geri_bildirim.dart';

/// Bir öğünün altında: 1-5 yıldız puanı + yorumlar.
class GeriBildirimBolumu extends StatefulWidget {
  final GeriBildirimDeposu depo;
  final String slot;
  final bool
      puanGoster; // false: yalnızca yorumlar (puanlar yemek bazlı verilir)
  const GeriBildirimBolumu(
      {super.key,
      required this.depo,
      required this.slot,
      this.puanGoster = true});

  @override
  State<GeriBildirimBolumu> createState() => _GeriBildirimBolumuState();
}

class _GeriBildirimBolumuState extends State<GeriBildirimBolumu> {
  PuanOzeti _ozet = const PuanOzeti(null, 0);
  int? _benim;
  List<Yorum> _yorumlar = [];
  String _uid = '';
  bool _yukleniyor = true, _hata = false, _gonderiliyor = false;
  final _metin = TextEditingController();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = false;
    });
    try {
      final d = widget.depo;
      final sonuc = await Future.wait([
        d.puanOzeti(widget.slot),
        d.benimPuanim(widget.slot),
        d.yorumlar(widget.slot),
        d.kullaniciId()
      ]);
      if (!mounted) return;
      setState(() {
        _ozet = sonuc[0] as PuanOzeti;
        _benim = sonuc[1] as int?;
        _yorumlar = sonuc[2] as List<Yorum>;
        _uid = sonuc[3] as String;
      });
    } catch (_) {
      if (mounted) setState(() => _hata = true);
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  void _mesaj(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _puanVer(int y) async {
    final onceki = _benim;
    setState(() => _benim = y);
    try {
      await widget.depo.puanVer(widget.slot, y);
      final o = await widget.depo.puanOzeti(widget.slot);
      if (mounted) setState(() => _ozet = o);
    } catch (_) {
      if (mounted) setState(() => _benim = onceki);
      _mesaj('Puan kaydedilemedi. İnternet bağlantını kontrol et.');
    }
  }

  Future<String?> _adSor() async {
    final p = await SharedPreferences.getInstance();
    final kayitli = p.getString('yorum_adi');
    if (kayitli != null && kayitli.isNotEmpty) return kayitli;
    if (!mounted) return null;
    final c = TextEditingController();
    final ad = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Takma adın'),
        content: TextField(
            controller: c,
            maxLength: 20,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Örn: Aç Öğrenci')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  ctx, c.text.trim().isEmpty ? 'Anonim' : c.text.trim()),
              child: const Text('Tamam')),
        ],
      ),
    );
    if (ad != null) await p.setString('yorum_adi', ad);
    return ad;
  }

  Future<void> _gonder() async {
    final metin = _metin.text.trim();
    if (metin.isEmpty || _gonderiliyor) return;
    final ad = await _adSor();
    if (ad == null) return;
    setState(() => _gonderiliyor = true);
    try {
      await widget.depo.yorumEkle(widget.slot, ad, metin);
      _metin.clear();
      final l = await widget.depo.yorumlar(widget.slot);
      if (mounted) setState(() => _yorumlar = l);
    } catch (_) {
      _mesaj('Yorum gönderilemedi. Daha sonra tekrar dene.');
    }
    if (mounted) setState(() => _gonderiliyor = false);
  }

  Future<void> _sil(Yorum y) async {
    try {
      await widget.depo.yorumSil(y);
      if (mounted) {
        setState(
            () => _yorumlar = _yorumlar.where((e) => e.id != y.id).toList());
      }
    } catch (_) {
      _mesaj('Yorum silinemedi.');
    }
  }

  String _zaman(DateTime t) {
    final f = DateTime.now().difference(t);
    if (f.inMinutes < 1) return 'şimdi';
    if (f.inMinutes < 60) return '${f.inMinutes} dk önce';
    if (f.inHours < 24) return '${f.inHours} sa önce';
    return '${f.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // --- puan
      if (widget.puanGoster)
        Card(
          elevation: 0,
          color: renk.surfaceContainerLow,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Puan',
                    style: tema.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Icon(Icons.star_rounded, color: renk.primary, size: 22),
                const SizedBox(width: 4),
                Text(
                    _ozet.ortalama == null
                        ? 'Henüz oy yok'
                        : '${_ozet.ortalama!.toStringAsFixed(1)} · ${_ozet.adet} oy',
                    style: tema.textTheme.titleSmall),
              ]),
              const SizedBox(height: 10),
              Text(
                  _benim == null
                      ? 'Bu öğünü nasıl buldun?'
                      : 'Puanın: $_benim / 5 (değiştirmek için dokun)',
                  style: tema.textTheme.bodyMedium
                      ?.copyWith(color: renk.onSurfaceVariant)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 38,
                    tooltip: '$i yıldız',
                    onPressed: () => _puanVer(i),
                    icon: Icon(
                        (_benim ?? 0) >= i
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: renk.primary),
                  ),
              ]),
              if (!widget.depo.cevrimici)
                Text(
                    'Deneme modu: puan ve yorumlar yalnızca bu cihazda saklanır.',
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: renk.onSurfaceVariant)),
            ]),
          ),
        ),
      if (widget.puanGoster) const SizedBox(height: 12),
      // --- yorumlar
      Card(
        elevation: 0,
        color: renk.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Yorumlar${_yorumlar.isEmpty ? '' : ' (${_yorumlar.length})'}',
                style: tema.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  controller: _metin,
                  maxLength: 300,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                      hintText: 'Yorum yaz…',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: IconButton.filled(
                    onPressed: _gonderiliyor ? null : _gonder,
                    icon: _gonderiliyor
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    tooltip: 'Gönder'),
              ),
            ]),
            if (_yukleniyor)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()))
            else if (_hata)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const Expanded(child: Text('Yorumlar yüklenemedi.')),
                  TextButton(
                      onPressed: _yukle, child: const Text('Tekrar dene'))
                ]),
              )
            else if (_yorumlar.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('İlk yorumu sen yaz.',
                      style: tema.textTheme.bodyMedium
                          ?.copyWith(color: renk.onSurfaceVariant)))
            else
              for (final y in _yorumlar)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                            radius: 16,
                            child: Text(
                                y.ad.isEmpty ? '?' : y.ad[0].toUpperCase())),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${y.ad} · ${_zaman(y.zaman)}',
                                    style: tema.textTheme.labelMedium?.copyWith(
                                        color: renk.onSurfaceVariant)),
                                const SizedBox(height: 2),
                                Text(y.metin, style: tema.textTheme.bodyMedium),
                              ]),
                        ),
                        if (y.uid == _uid)
                          IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _sil(y),
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Sil'),
                      ]),
                ),
          ]),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }
}
