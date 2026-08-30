import 'package:flutter/material.dart';

import '../theme/clay_gradients.dart';
import '../theme/clay_tokens.dart';

/// Tile ikon bergradien aksen — penanda visual sebuah fitur atau kategori.
///
/// ============================================================================
///  KENAPA GRADIEN, BUKAN WARNA AKSEN PEJAL
/// ============================================================================
///  Chip ini satu-satunya bidang beraksen pekat di dalam kartu clay yang
///  serba pucat. Warna pejal di posisi itu terlihat seperti stiker yang
///  ditempel; gradien yang arahnya sama dengan cahaya clay
///  ([ClayGradients.chip]) membuatnya terbaca sebagai benda dalam sistem
///  pencahayaan yang sama. Ikonnya selalu putih — di kedua mode tema,
///  karena latarnya gradien aksen yang sama di kedua mode.
/// ============================================================================
class ClayIconChip extends StatelessWidget {
  const ClayIconChip({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 42,
  });

  final IconData icon;

  /// Warna aksen aplikasi — gradiennya diturunkan, bukan diberikan langsung.
  final Color accent;

  /// Sisi tile. 40–44 di kartu daftar; boleh lebih kecil untuk judul
  /// bottom sheet. Ikonnya ikut setengah sisi supaya proporsinya tetap.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: ClayGradients.chip(accent),
        borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
      ),
      child: Icon(icon, size: size / 2, color: Colors.white),
    );
  }
}
