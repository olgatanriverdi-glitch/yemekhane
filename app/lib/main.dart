import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'bildirim_ayari.dart';
import 'kalori_hedefi.dart';
import 'screens/home.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  temaLisanslariniKaydet();
  final ayar = TemaAyari();
  final kalori = KaloriHedefi();
  final bildirim = BildirimAyari();
  // kayıtlı tema ve kalori hedefi ilk karede uygulansın (varsayılanla yanıp sönmesin); bildirim ayarı yalnızca
  // okunur, kapalıysa bildirim eklentisine hiç dokunulmaz
  await Future.wait([ayar.yukle(), kalori.yukle(), bildirim.yukle()]);
  runApp(
      YemekhaneApp(ayar: ayar, kaloriHedefi: kalori, bildirimAyari: bildirim));
}

class YemekhaneApp extends StatelessWidget {
  final TemaAyari ayar;

  /// Günlük kalori hedefi ayarı; boşsa ana sayfa kendi ayarını kurar.
  final KaloriHedefi? kaloriHedefi;

  /// Günlük menü bildirimi ayarı; boşsa ana sayfa kendi ayarını kurar.
  final BildirimAyari? bildirimAyari;

  /// Testlerde ana sayfanın yerine gösterilecek ekran (gerçek ağa / diske gitmemek için); uygulamada boştur.
  final Widget? ana;
  const YemekhaneApp(
      {super.key,
      required this.ayar,
      this.kaloriHedefi,
      this.bildirimAyari,
      this.ana});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ayar,
      builder: (context, _) => MaterialApp(
        title: 'Üni Yemek',
        debugShowCheckedModeBanner: false,
        // Türkçe: lisans sayfası, tarih / saat seçiciler ve sistem tooltip'leri (Geri, Kapat...) Türkçe gelir
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ayar.tema(Brightness.light),
        darkTheme: ayar.tema(Brightness.dark),
        themeMode: ayar.mod,
        themeAnimationDuration: const Duration(milliseconds: 300),
        themeAnimationCurve: Curves.easeOutCubic,
        builder: (context, child) => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: child)),
        ),
        home: ana ??
            AnaSayfa(
                temaAyari: ayar,
                kaloriHedefi: kaloriHedefi,
                bildirim: bildirimAyari),
      ),
    );
  }
}

/// Yazı tipi lisansı, Ayarlar > Lisanslar sayfasında çevrimdışı da okunabilir.
void temaLisanslariniKaydet() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['Manrope'], _manropeLisans);
  });
}

// pubspec yalnızca fonts bölümünü ekler; OFL metni ek bir asset kaydı gerektirmez.
const _manropeLisans =
    r'''Copyright 2018 The Manrope Project Authors (https://github.com/googlefonts/manrope)

This Font Software is licensed under the SIL Open Font License, Version 1.1.
This license is copied below, and is also available with a FAQ at:
http://scripts.sil.org/OFL


-----------------------------------------------------------
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
-----------------------------------------------------------

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font creation
efforts of academic and linguistic communities, and to provide a free and
open framework in which fonts may be shared and improved in partnership
with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves. The
fonts, including any derivative works, can be bundled, embedded,
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works. The fonts and derivatives,
however, cannot be released under any other type of license. The
requirement for fonts to remain under this license does not apply
to any document created using the fonts or their derivatives.

DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such. This may
include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software components as
distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to, deleting,
or substituting -- in part or in whole -- any of the components of the
Original Version, by changing formats or by porting the Font Software to a
new environment.

"Author" refers to any designer, engineer, programmer, technical
writer or other person who contributed to the Font Software.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining
a copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components,
in Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or
in the appropriate machine-readable metadata fields within text or
binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless explicit written permission is granted by the corresponding
Copyright Holder. This restriction only applies to the primary font name as
presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any
Modified Version, except to acknowledge the contribution(s) of the
Copyright Holder(s) and the Author(s) or with their explicit written
permission.

5) The Font Software, modified or unmodified, in part or in whole,
must be distributed entirely under this license, and must not be
distributed under any other license. The requirement for fonts to
remain under this license does not apply to any document created
using the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are
not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
OTHER DEALINGS IN THE FONT SOFTWARE.
''';
