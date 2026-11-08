import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../geri_bildirim.dart';
import '../topluluk_kurallari.dart';
import '../yorum_filtresi.dart';
import '../yorum_moderasyon.dart';

/// Bir öğünün altında: 1-5 yıldız puanı + yorumlar.
class GeriBildirimBolumu extends StatefulWidget {
  final GeriBildirimDeposu depo;
  final String slot;
  final bool
      puanGoster; // false: yalnızca yorumlar (puanlar yemek bazlı verilir)

  /// Yorumlar kartının başlığı. Yorumların neye ait olduğunu söylemek için ekrana göre değişir (ana ekranda
  /// "Öğün yorumları", yemek ayrıntısında "Bu yemek hakkında"); sayı varsa sonuna " (3)" eklenir.
  final String baslik;
  const GeriBildirimBolumu(
      {super.key,
      required this.depo,
      required this.slot,
      this.puanGoster = true,
      this.baslik = 'Yorumlar'});

  @override
  State<GeriBildirimBolumu> createState() => _GeriBildirimBolumuState();
}

class _GeriBildirimBolumuState extends State<GeriBildirimBolumu> {
  PuanOzeti _ozet = const PuanOzeti(null, 0);
  int? _benim;
  List<Yorum> _yorumlar = [];
  String _uid = '';
  bool _yukleniyor = true, _hata = false, _gonderiliyor = false;
  // Puan kaydı sürerken (kayıt + özetin yenilenmesi) yeni dokunuşlar yok sayılır: art arda hızlı dokunuşta iki istek
  // yarışmasın, başarısız olanın "önceki" değeri kaydedilmemiş bir puana dönmesin (yemek ayrıntısındaki puan kartı gibi).
  bool _kaydediyor = false;
  final _metin = TextEditingController();
  final _moderasyon = const YorumModerasyonu();

  /// Bu cihazda engellenen kişiler ve gizlenen (bildirilmiş) yorumlar; listede görünmezler.
  Set<String> _engelli = {}, _gizli = {};

  /// Engellenmemiş ve gizlenmemiş yorumlar (ekranda gösterilen).
  List<Yorum> get _gorunen => [
        for (final y in _yorumlar)
          if (!_gizli.contains(y.id) && !_engelli.contains(y.uid)) y
      ];

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
      // puan kartı yalnızca puanGoster iken görünür; gizliyken (puanlar yemek bazlı verilir) görünmeyen sonuç için
      // iki ağ isteği daha atılmaz
      final ozet = widget.puanGoster
          ? d.puanOzeti(widget.slot)
          : Future.value(const PuanOzeti(null, 0));
      final benim =
          widget.puanGoster ? d.benimPuanim(widget.slot) : Future<int?>.value();
      final sonuc = await Future.wait([
        ozet,
        benim,
        d.yorumlar(widget.slot),
        d.kullaniciId(),
        _moderasyon.engellenenler(),
        _moderasyon.gizlenenYorumlar(),
      ]);
      if (!mounted) return;
      setState(() {
        _engelli = sonuc[4] as Set<String>;
        _gizli = sonuc[5] as Set<String>;
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

  // Sayfa kapandıktan sonra biten isteklerin (puan, yorum, silme) hatası sessizce yutulur: kapanmış bir sayfanın
  // context'i kullanılamaz.
  void _mesaj(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _puanVer(int y) async {
    if (_kaydediyor) return;
    final onceki = _benim;
    setState(() {
      _kaydediyor = true;
      _benim = y;
    });
    try {
      await widget.depo.puanVer(widget.slot, y);
    } catch (_) {
      if (mounted) {
        setState(() {
          _benim = onceki;
          _kaydediyor = false;
        });
      }
      _mesaj('Puan kaydedilemedi. İnternet bağlantını kontrol et.');
      return;
    }
    // Puan kaydedildi: özet okunamazsa (ağ hatası, zaman aşımı) seçilen puan kalır, ortalama eskisi gibi görünür.
    // Kaydedilmiş bir puanı "kaydedilemedi" diyerek geri almak yanlış olurdu (yemek ayrıntısındaki puan kartı gibi).
    try {
      final o = await widget.depo.puanOzeti(widget.slot);
      if (mounted) setState(() => _ozet = o);
    } catch (_) {}
    if (mounted) setState(() => _kaydediyor = false);
  }

  /// Yorum için takma adı döndürür: kayıtlıysa o, değilse soru kutusundan. Cihaz depolaması okunamaz ya da
  /// yazılamazsa hata yutulur: ad yine sorulur ve yorum gönderilir, yalnızca ad hatırlanmayabilir.
  Future<String?> _adSor() async {
    try {
      final p = await SharedPreferences.getInstance();
      final kayitli = p.getString('yorum_adi');
      if (kayitli != null && kayitli.isNotEmpty) return kayitli;
    } catch (_) {}
    if (!mounted) return null;
    final ad = await showDialog<String>(
        context: context, builder: (_) => const _AdSorDiyalogu());
    if (ad != null) {
      try {
        await (await SharedPreferences.getInstance())
            .setString('yorum_adi', ad);
      } catch (_) {}
    }
    return ad;
  }

  Future<void> _gonder() async {
    final metin = _metin.text.trim();
    if (metin.isEmpty || _gonderiliyor) return;
    final sorun = yorumSorunu(metin);
    if (sorun != null) {
      _mesaj(sorun.mesaj);
      return;
    }
    // kullanıcı içeriği politikası: ilk yorumdan (ve takma ad seçiminden) önce topluluk kuralları kabul edilir
    if (!await toplulukKurallariniOnayla(context)) return;
    if (!mounted) return;
    final ad = await _adSor();
    if (ad == null || !mounted) return;
    if (yorumSorunu(ad) != null) {
      // uygunsuz takma ad hatırlanmasın: bir sonraki denemede yeniden sorulur
      try {
        await (await SharedPreferences.getInstance()).remove('yorum_adi');
      } catch (_) {}
      _mesaj('Takma adın uygun değil. Başka bir ad dene.');
      return;
    }
    setState(() => _gonderiliyor = true);
    try {
      await widget.depo.yorumEkle(widget.slot, ad, metin);
      if (mounted) _metin.clear();
      try {
        final l = await widget.depo.yorumlar(widget.slot);
        if (mounted) setState(() => _yorumlar = l);
      } catch (_) {
        // yorum kaydedildi: "gönderilemedi" denirse kullanıcı aynı yorumu yeniden yazıp çift yorum bırakır
        _mesaj('Yorumun gönderildi, liste şimdilik yenilenemedi.');
      }
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

  Future<void> _bildir(Yorum y) async {
    final neden = await showDialog<YorumBildirimNedeni>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Bu yorumu ve yazarını neden bildiriyorsun?'),
        children: [
          for (final n in YorumBildirimNedeni.values)
            SimpleDialogOption(
                onPressed: () => Navigator.of(c).pop(n), child: Text(n.etiket)),
        ],
      ),
    );
    if (neden == null || !mounted) return;
    try {
      await widget.depo.yorumBildir(y, neden);
    } catch (_) {
      _mesaj('Bildirim gönderilemedi');
      return;
    }
    // bildirilen yorum bu cihazda hemen gizlenir
    await _moderasyon.yorumuGizle(y.id);
    if (mounted) setState(() => _gizli = {..._gizli, y.id});
    _mesaj('Teşekkürler, bildirimin alındı');
  }

  Future<void> _engelle(Yorum y) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Bu kişi engellensin mi?'),
        content: const Text(
            'Bu kişinin yorumları bu cihazda hiçbir yerde görünmez. Engeli Ayarlar\'dan kaldırabilirsin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Engelle')),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    await _moderasyon.engelle(y.uid);
    if (mounted) setState(() => _engelli = {..._engelli, y.uid});
    _mesaj('Kişi engellendi');
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
    final yorumlar = _gorunen;
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
            Text(
                '${widget.baslik}${yorumlar.isEmpty ? '' : ' (${yorumlar.length})'}',
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
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  'Yorumlar herkese açıktır. Hakaret ve kişisel bilgi paylaşma.',
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: renk.onSurfaceVariant)),
            ),
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
            else if (yorumlar.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('İlk yorumu sen yaz.',
                      style: tema.textTheme.bodyMedium
                          ?.copyWith(color: renk.onSurfaceVariant)))
            else
              for (final y in yorumlar)
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
                          // dokunma hedefi 48 dp (compact yoğunluk 40 dp bırakırdı)
                          IconButton(
                              onPressed: () => _sil(y),
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Sil')
                        else
                          PopupMenuButton<_YorumIslemi>(
                            tooltip: 'Yorum seçenekleri',
                            icon: const Icon(Icons.more_vert, size: 20),
                            style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48)),
                            onSelected: (i) => switch (i) {
                              _YorumIslemi.bildir => _bildir(y),
                              _YorumIslemi.engelle => _engelle(y),
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: _YorumIslemi.bildir,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Bildir'),
                                        Text('Yorumu ve yazarını',
                                            style: TextStyle(fontSize: 12)),
                                      ])),
                              PopupMenuItem(
                                  value: _YorumIslemi.engelle,
                                  child: Text('Bu kişiyi engelle')),
                            ],
                          ),
                      ]),
                ),
          ]),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }
}

enum _YorumIslemi { bildir, engelle }

/// Takma ad sorusu. Metin denetleyicisi diyalogla birlikte (kapanış animasyonu bittikten sonra) atılır.
class _AdSorDiyalogu extends StatefulWidget {
  const _AdSorDiyalogu();

  @override
  State<_AdSorDiyalogu> createState() => _AdSorDiyalogusState();
}

class _AdSorDiyalogusState extends State<_AdSorDiyalogu> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Takma adın'),
        content: TextField(
            controller: _c,
            maxLength: 20,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Örn: Aç Öğrenci')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  context, _c.text.trim().isEmpty ? 'Anonim' : _c.text.trim()),
              child: const Text('Tamam')),
        ],
      );
}
