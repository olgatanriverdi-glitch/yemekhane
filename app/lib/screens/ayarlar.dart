import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../bildirim_ayari.dart';
import '../bildirim_servisi.dart';
import '../config.dart';
import '../geri_bildirim.dart';
import '../kalori_hedefi.dart';
import '../models.dart';
import '../repository.dart';
import '../tema.dart';
import '../yorum_moderasyon.dart';
import '../widgets/bildirim_bolumu.dart';
import '../widgets/kalori_ayari.dart';
import 'tema_secici.dart';
import 'university_picker.dart';

/// Ayarlar ve Hakkında. Başka bir okul seçilirse sayfa kapanır ve seçilen okul kimliğiyle döner
/// (ana sayfa o okulun menüsünü yükler); diğer işlemlerde sayfada kalınır.
class AyarlarSayfasi extends StatefulWidget {
  final TemaAyari temaAyari;
  final Depo depo;

  /// Okul listesi ve seçili okul; okul henüz seçilmediyse [uni] boştur.
  final List<Universite> uniler;
  final Universite? uni;

  /// Ana sayfa bir okulu yüklerken (iskelet) Ayarlar açıldıysa o okulun kimliği. "Aynı okul seçildi" kontrolü
  /// [uni] yerine buna göre yapılır: böylece yüklenen B'den vazgeçip ekrandaki A yeniden seçilebilir. "Okul"
  /// satırı da bu okulun adını gösterir (sayfa açıldığı andaki durumdur; yükleme sonradan bitse de yenilenmez).
  final String? yuklenenId;

  /// Önbellek temizlendikten sonra menüyü yeniden yüklemek için.
  final Future<void> Function() menuyuYenile;

  /// Günlük kalori hedefi ayarı; verilmezse bu bölüm gösterilmez.
  final KaloriHedefi? kaloriHedefi;

  /// Günlük menü bildirimi ayarı; verilmezse (ya da platform bildirimi desteklemiyorsa) bu bölüm gösterilmez.
  final BildirimAyari? bildirim;

  /// Puan / yorum deposu; "Yorum ve puanlarımı sil" bununla çalışır. Verilmezse o satır gösterilmez.
  final GeriBildirimDeposu? geriBildirim;
  const AyarlarSayfasi(
      {super.key,
      required this.temaAyari,
      required this.depo,
      required this.uniler,
      required this.uni,
      required this.menuyuYenile,
      this.yuklenenId,
      this.kaloriHedefi,
      this.bildirim,
      this.geriBildirim});

  @override
  State<AyarlarSayfasi> createState() => _AyarlarSayfasiState();
}

class _AyarlarSayfasiState extends State<AyarlarSayfasi> {
  bool _temizleniyor = false, _siliniyor = false;
  final _moderasyon = const YorumModerasyonu();

  /// Engellenen kişi sayısı (Genel bölümündeki satır).
  int _engelSayisi = 0;

  @override
  void initState() {
    super.initState();
    _engelSayisiniOku();
  }

  Future<void> _engelSayisiniOku() async {
    final n = (await _moderasyon.engellenenler()).length;
    if (mounted) setState(() => _engelSayisi = n);
  }

  Future<void> _engelleriYonet() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_engelSayisi == 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Engellediğin kimse yok')));
      return;
    }
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Engeller kaldırılsın mı?'),
        content: Text(
            '$_engelSayisi kişinin engeli kalkar ve yorumları yeniden görünür.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Engelleri kaldır')),
        ],
      ),
    );
    if (onay != true) return;
    await _moderasyon.engelleriTemizle();
    await _engelSayisiniOku();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Engeller kaldırıldı')));
  }

  Future<void> _verileriSil() async {
    final depo = widget.geriBildirim;
    if (depo == null || _siliniyor) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yorum ve puanların silinsin mi?'),
        content: const Text(
            'Verdiğin bütün puanlar ve yazdığın bütün yorumlar sunucudan kalıcı olarak silinir, anonim hesabın '
            'kapatılır. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _siliniyor = true);
    String mesaj;
    var basarili = false;
    try {
      await depo.verilerimiSil();
      mesaj = 'Yorum ve puanların silindi';
      basarili = true;
    } catch (_) {
      mesaj =
          'Veriler silinemedi. İnternet bağlantını kontrol edip tekrar dene.';
    }
    if (mounted) setState(() => _siliniyor = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mesaj)));
    // ekrandaki puan ve yorumlar silinenleri göstermesin
    if (basarili && mounted) await widget.menuyuYenile();
  }

  /// Sayfanın seçili saydığı okul: ana sayfa bir okulu yüklüyorsa (iskelet) kullanıcının son seçimi olan o,
  /// yoksa gösterilen okul. "Okul" satırı, veri kaynağı ve seçicideki işaret hep bunu izler; böylece B yüklenirken
  /// Ayarlar'da hâlâ A yazmaz. Yüklenen okul listede bulunamazsa gösterilen okula düşülür.
  Universite? get _seciliOkul {
    final id = widget.yuklenenId;
    if (id != null) {
      for (final u in widget.uniler) {
        if (u.id == id) return u;
      }
    }
    return widget.uni;
  }

  Future<void> _okulSec() async {
    final son = await widget.depo.sonSecilenler();
    if (!mounted) return;
    final secilen = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => UniversitePicker(
            uniler: widget.uniler,
            secili: _seciliOkul?.id,
            sonSecilenler: son)));
    if (!mounted || secilen == null) return;
    if (secilen == (widget.yuklenenId ?? widget.uni?.id)) return;
    Navigator.of(context).pop(secilen);
  }

  Future<void> _onbellekTemizle() async {
    if (_temizleniyor) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Önbellek temizlensin mi?'),
        content: const Text(
            'Cihazda saklanan menü kopyaları silinir ve menü yeniden yüklenir. '
            'Okul seçimin, temanın, puanların ve yorumların silinmez.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Temizle')),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    _temizleniyor = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.depo.onbellekTemizle();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Önbellek temizlendi')));
      await widget.menuyuYenile();
    } finally {
      _temizleniyor = false;
    }
  }

  Future<void> _kaynagiKopyala(String adres) async {
    final messenger = ScaffoldMessenger.of(context);
    String mesaj;
    try {
      await Clipboard.setData(ClipboardData(text: adres));
      mesaj = 'Bağlantı panoya kopyalandı';
    } catch (_) {
      mesaj = 'Bağlantı kopyalanamadı';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mesaj)));
  }

  @override
  Widget build(BuildContext context) {
    final uni = _seciliOkul;
    final kaynak = uni?.kaynak ?? '';
    final kalori = widget.kaloriHedefi, bildirim = widget.bildirim;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _Baslik('Genel'),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Okul'),
              subtitle: Text(uni?.ad ?? 'Seçilmedi'),
              trailing: const Icon(Icons.chevron_right),
              enabled: widget.uniler.isNotEmpty,
              onTap: widget.uniler.isEmpty ? null : _okulSec,
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Tema'),
              subtitle: const Text('Açık, koyu ve renk seçimi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => temaSeciciGoster(context, widget.temaAyari),
            ),
            if (kalori != null) KaloriHedefiAyari(kaloriHedefi: kalori),
            if (bildirim != null && bildirimDesteklenir())
              BildirimAyariBolumu(ayar: bildirim),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Önbelleği temizle'),
              subtitle: const Text('İndirilen menü kopyalarını siler'),
              onTap: _onbellekTemizle,
            ),
            const _Baslik('Hakkında'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Sürüm'),
              subtitle: Text(uygulamaSurumu),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Veri kaynağı'),
              subtitle: Text(
                  uni == null
                      ? 'Okul seçilmedi'
                      : (kaynak.isEmpty ? 'Kaynak adresi yok' : kaynak),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              trailing: kaynak.isEmpty ? null : const Icon(Icons.copy),
              onTap: kaynak.isEmpty ? null : () => _kaynagiKopyala(kaynak),
            ),
            const _Not(Icons.auto_awesome_outlined,
                'Menüler okul sitelerinden otomatik derlenir; hatalı ya da eksik olabilir. Önemli bir bilgi için okulun duyurularına bak.'),
            const _Not(Icons.photo_outlined,
                'Yemek fotoğrafları örnektir (Wikimedia Commons, CC lisanslı); okuldaki yemek birebir aynı görünmeyebilir.'),
            const _Not(
                Icons.visibility_off_outlined, 'Puan ve yorumlar anonimdir.'),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Gizlilik politikası'),
              subtitle: const Text('Adresi panoya kopyalar'),
              trailing: const Icon(Icons.copy),
              onTap: () => _kaynagiKopyala(gizlilikAdresi),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text('Engellenen kişiler ($_engelSayisi)'),
              subtitle: const Text('Yorumları bu cihazda gizlenen kişiler'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _engelleriYonet,
            ),
            if (widget.geriBildirim != null)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Yorum ve puanlarımı sil'),
                subtitle: const Text(
                    'Verdiğin puanları ve yazdığın yorumları kalıcı olarak siler'),
                trailing: _siliniyor
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                enabled: !_siliniyor,
                onTap: _verileriSil,
              ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Açık kaynak lisansları'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Üni Yemek',
                  applicationVersion: uygulamaSurumu),
            ),
          ],
        ),
      ),
    );
  }
}

class _Baslik extends StatelessWidget {
  final String metin;
  const _Baslik(this.metin);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(metin,
            style: tema.textTheme.labelLarge?.copyWith(
                color: tema.colorScheme.primary, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Hakkında bölümündeki etkileşimsiz bilgi notu.
class _Not extends StatelessWidget {
  final IconData ikon;
  final String metin;
  const _Not(this.ikon, this.metin);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExcludeSemantics(
            child:
                Icon(ikon, size: 24, color: tema.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 16),
        Expanded(
            child: Text(metin,
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant))),
      ]),
    );
  }
}
