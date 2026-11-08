import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Topluluk kuralları metninin sürümü. Metin anlamlı biçimde değişirse artırılır: kullanıcıdan yeniden onay istenir.
/// (site/kurallar.html aynı metni taşır; test/topluluk_kurallari_test.dart ikisinin eşliğini denetler.)
const int toplulukKurallariSurum = 1;

/// Kabul edilen sürümün saklandığı SharedPreferences anahtarı.
const String toplulukKurallariAnahtar = 'topluluk_kurallari_surum';

const String toplulukKurallariBaslik = 'Topluluk kuralları';

const String toplulukKurallariGiris =
    'Yorumlar herkese açıktır ve takma adınla birlikte görünür. Yorum yazmadan önce şu kuralları kabul etmen gerekir.';

/// Yasak içerik maddeleri.
const List<String> toplulukKurallariYasaklar = [
  'Hakaret, küfür, aşağılama ve nefret söylemi',
  'Taciz, tehdit ve başkalarını hedef alma',
  'Kişisel bilgi paylaşma (telefon, adres, kimlik, hesap bilgisi; kendinin ya da başkasının)',
  'Spam ve tekrar eden anlamsız yorumlar',
  'Reklam, tanıtım ve bağlantı paylaşma',
  'Yasa dışı içerik ve yasa dışı faaliyetlere çağrı',
];

const String toplulukKurallariKaldirma =
    'Bu kurallara uymayan yorumlar uyarı yapılmadan kaldırılabilir; tekrar eden ihlallerde kullanıcının yorum yazması engellenebilir.';

const String toplulukKurallariEngelleme =
    'Rahatsız edici bir yorumu yorumun yanındaki menüden bildirebilir, yorumun yazarını bildirebilir ya da bu cihazda engelleyebilirsin. Engellediğin kişinin yorumlarını bu cihazda görmezsin.';

String get toplulukKurallariBildirimYolu =>
    'Uygulamaya erişemiyorsan ya da bir şikâyetin varsa $iletisimEposta adresine yazabilirsin.';

/// Bu cihazda kabul edilen sürüm (hiç kabul edilmediyse 0). Depolama hatasında 0 sayılır: kural yeniden sorulur.
Future<int> toplulukKurallariKabulSurumu() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getInt(toplulukKurallariAnahtar) ?? 0;
  } catch (_) {
    return 0;
  }
}

/// Güncel sürüm kabul edildiyse true.
Future<bool> toplulukKurallariKabulEdildi() async =>
    await toplulukKurallariKabulSurumu() >= toplulukKurallariSurum;

Future<void> _kabulKaydet() async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setInt(toplulukKurallariAnahtar, toplulukKurallariSurum);
  } catch (_) {
    // yazılamazsa bu oturumda devam edilir; sonraki yorumda yeniden sorulur
  }
}

/// Kurallar kabul edilmişse true döner (diyalog açılmaz). Edilmemişse (ya da sürüm yükseldiyse) diyalogu gösterir;
/// [Kabul ediyorum] sürümü kaydeder ve true, [Vazgeç] false döner.
Future<bool> toplulukKurallariniOnayla(BuildContext context) async {
  if (await toplulukKurallariKabulEdildi()) return true;
  if (!context.mounted) return false;
  final kabul = await showDialog<bool>(
    context: context,
    builder: (_) => const ToplulukKurallariDiyalogu(onayIste: true),
  );
  if (kabul != true) return false;
  await _kabulKaydet();
  return true;
}

/// Kuralları yalnızca gösterir (Ayarlar > Hakkında).
Future<void> toplulukKurallariniGoster(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (_) => const ToplulukKurallariDiyalogu(onayIste: false),
    );

class ToplulukKurallariDiyalogu extends StatelessWidget {
  /// true: [Kabul ediyorum] / [Vazgeç]; false: yalnızca [Kapat].
  final bool onayIste;
  const ToplulukKurallariDiyalogu({super.key, required this.onayIste});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: const Text(toplulukKurallariBaslik),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(toplulukKurallariGiris),
            const SizedBox(height: 12),
            Text('Şunları paylaşma:',
                style: tema.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final m in toplulukKurallariYasaklar)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(m)),
                    ]),
              ),
            const SizedBox(height: 12),
            const Text(toplulukKurallariKaldirma),
            const SizedBox(height: 8),
            const Text(toplulukKurallariEngelleme),
            const SizedBox(height: 8),
            Text(toplulukKurallariBildirimYolu),
          ],
        ),
      ),
      actions: onayIste
          ? [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Vazgeç')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Kabul ediyorum')),
            ]
          : [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat')),
            ],
    );
  }
}
