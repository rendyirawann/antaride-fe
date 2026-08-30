import 'package:flutter/material.dart';

import '../theme/clay_tokens.dart';

/// Label bagian: UPPERCASE kecil di atas sekelompok kartu.
///
/// ============================================================================
///  KENAPA WIDGET, BUKAN SEKADAR TextStyle BERSAMA
/// ============================================================================
///  Label bagian muncul di puluhan layar, dan penyimpangannya nyaris tak
///  terlihat per layar: letterSpacing 1.0 di satu tempat, 1.2 di tempat lain,
///  lupa uppercase di tempat ketiga. Baru saat dua layar bersebelahan
///  penyimpangan itu terbaca — dan saat itu sudah tersebar. Widget yang
///  meng-uppercase SENDIRI menghilangkan seluruh kelas kesalahan itu.
///
///  Warnanya tertiary, bukan secondary: label ini penunjuk arah, bukan isi.
///  Kalau bersaing kontras dengan judul kartu di bawahnya, keduanya kalah.
/// ============================================================================
class ClaySectionLabel extends StatelessWidget {
  const ClaySectionLabel(this.text, {super.key});

  /// Teks label. Boleh ditulis biasa — di-uppercase di sini.
  final String text;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: gelap ? ClayTokens.textTertiaryDark : ClayTokens.textTertiary,
      ),
    );
  }
}
