import 'package:flutter/material.dart';

import '../theme/clay_tokens.dart';

/// Tombol bulat kaca buram untuk DI DALAM hero gradien.
///
/// ============================================================================
///  KENAPA SATU BENTUK UNTUK SEMUA TOMBOL DI HERO
/// ============================================================================
///  Hero memuat beberapa jenis tombol: kembali, hamburger, lonceng notifikasi.
///  Semuanya duduk di baris paling ramai di layar — berdampingan dengan jam,
///  sinyal, dan baterai milik sistem.
///
///  Kalau tiap layar menggambar bentuknya sendiri, yang terjadi bukan
///  ketidakcocokan yang mencolok melainkan yang HALUS: lingkaran 40 di satu
///  layar dan 44 di layar sebelahnya, alpha 0.14 dan 0.18. Tidak ada yang bisa
///  menyebut apa yang salah, tapi aplikasinya terasa tidak dikerjakan satu
///  orang.
///
///  Warna putih-alpha, bukan warna pejal: dengan begitu tombol ini ikut aksen
///  APA PUN (hijau penumpang, hijau tua driver, amber merchant) tanpa satu pun
///  cabang warna — sama seperti lingkaran tekstur di hero.
/// ============================================================================
///
/// ============================================================================
///  JANGAN DIPAKAI DI LUAR HERO
/// ============================================================================
///  Kaca buram menuntut latar pekat di belakangnya. Di atas permukaan clay yang
///  pucat, lingkaran putih-alpha ini nyaris tak terlihat — dan tombol yang
///  nyaris tak terlihat lebih buruk daripada tombol yang jelek.
/// ============================================================================
class ClayGlassButton extends StatelessWidget {
  const ClayGlassButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Label untuk pembaca layar. Ikon tanpa label tidak terbaca sama sekali.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Lingkaran terlihat 42 px, area sentuh 48 px (ClayTokens.minTouchTarget).
    // Lingkaran 48 terlalu dominan untuk tombol sekunder, tapi target sentuh
    // tidak boleh ikut mengecil — selisihnya ruang sentuh tak terlihat.
    return SizedBox(
      width: ClayTokens.minTouchTarget,
      height: ClayTokens.minTouchTarget,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),

          // Riak putih, bukan bawaan tema: riak gelap di atas gradien aksen
          // terlihat seperti noda, sama seperti alasan riak di ClaySurface.
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),

          child: Semantics(
            button: true,
            label: semanticLabel,
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
