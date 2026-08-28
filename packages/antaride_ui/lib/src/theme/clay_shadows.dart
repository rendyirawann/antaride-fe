import 'package:flutter/material.dart';

import 'clay_tokens.dart';

/// Kedalaman sebuah permukaan clay.
enum ClayDepth {
  /// Rata dengan latar. Tanpa bayangan luar, hanya garis halus.
  flat,

  /// Sedikit terangkat. Untuk kartu di dalam daftar.
  low,

  /// Terangkat jelas. Untuk kartu utama dan panel.
  medium,

  /// Melayang. Untuk bottom sheet dan dialog.
  high,

  /// Tenggelam ke dalam. Untuk kolom input dan area yang bisa diisi.
  pressed,
}

/// Bayangan claymorphism.
///
/// ============================================================================
///  TIGA BAYANGAN, BUKAN SATU
/// ============================================================================
///  Kartu Material biasa punya satu bayangan luar. Permukaan clay punya tiga,
///  dan ketiganya diperlukan:
///
///    1. Bayangan LUAR gelap    mengangkat elemen dari latarnya
///    2. Bayangan DALAM terang  dari arah cahaya — membuat tepinya membulat
///    3. Bayangan DALAM gelap   dari arah berlawanan — memberi ketebalan
///
///  Yang paling sering dilewatkan adalah nomor 3, dan tanpa dia permukaannya
///  terlihat seperti kertas yang diberi bayangan, bukan benda yang punya
///  ketebalan.
/// ============================================================================
///
/// ============================================================================
///  KENAPA BAYANGAN DALAM DIBUAT DENGAN Container BERLAPIS, BUKAN BoxShadow
/// ============================================================================
///  Flutter TIDAK punya inner shadow pada BoxShadow — `inset` tidak ada di API-nya.
///  Itu batasan nyata, dan cara mengatasinya menentukan hasilnya.
///
///  Yang dipakai di sini: satu Container luar membawa bayangan luar, dan
///  gradient halus di dalamnya meniru bayangan dalam. Gradient bukan tiruan yang
///  sempurna, tapi pada radius besar dan kontras rendah — yang justru ciri
///  claymorphism — bedanya tidak terlihat mata, dan biaya rendernya jauh lebih
///  murah daripada CustomPainter dengan blur berlapis.
///
///  Alternatif yang DITOLAK: `BackdropFilter` untuk setiap kartu. Dia benar
///  secara visual dan mahal secara render — pada daftar order dengan dua puluh
///  kartu, scroll-nya turun ke belasan fps di HP kelas menengah, yang merupakan
///  mayoritas perangkat pengguna di Medan.
/// ============================================================================
class ClayShadows {
  const ClayShadows._();

  /// Bayangan luar untuk sebuah kedalaman.
  static List<BoxShadow> outer(ClayDepth depth, {required bool dark}) {
    final Offset arah = ClayTokens.shadowOffset;

    // Di mode gelap, bayangan gelap hampir tidak terlihat di atas latar gelap.
    // Yang menggantikannya sebagai penanda kedalaman adalah bayangan terang
    // yang lebih menonjol — jadi opasitasnya dibalik proporsinya, bukan
    // sekadar diturunkan.
    final double gelapOpacity = dark ? 0.55 : 0.13;
    final double terangOpacity = dark ? 0.07 : 0.90;

    return switch (depth) {
      ClayDepth.flat => const <BoxShadow>[],

      ClayDepth.low => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: gelapOpacity),
          offset: arah * 3,
          blurRadius: 8,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: terangOpacity),
          offset: -arah * 2,
          blurRadius: 6,
        ),
      ],

      ClayDepth.medium => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: gelapOpacity),
          offset: arah * 6,
          blurRadius: 16,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: terangOpacity),
          offset: -arah * 4,
          blurRadius: 12,
        ),
      ],

      ClayDepth.high => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: gelapOpacity + 0.04),
          offset: arah * 10,
          blurRadius: 28,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: terangOpacity),
          offset: -arah * 6,
          blurRadius: 18,
        ),
      ],

      // Permukaan yang tenggelam TIDAK punya bayangan luar. Kalau ada, dia
      // terlihat mengangkat dan tenggelam sekaligus — dan itu terbaca sebagai
      // kesalahan render, bukan sebagai gaya.
      ClayDepth.pressed => const <BoxShadow>[],
    };
  }

  /// Gradient yang meniru bayangan dalam.
  ///
  /// Arahnya mengikuti [ClayTokens.lightDirection]: sisi yang menghadap cahaya
  /// lebih terang, sisi berlawanan lebih gelap. Itu yang memberi kesan tepi
  /// membulat pada permukaan yang sebenarnya rata.
  static Gradient? innerGradient(
    ClayDepth depth, {
    required Color base,
    required bool dark,
  }) {
    if (depth == ClayDepth.flat) {
      return null;
    }

    final bool tenggelam = depth == ClayDepth.pressed;

    // Kekuatannya kecil dan itu memang tujuannya. Claymorphism yang kontrasnya
    // tinggi berhenti terlihat seperti tanah liat dan mulai terlihat seperti
    // logam yang dipoles.
    final double kekuatan = switch (depth) {
      ClayDepth.low => 0.030,
      ClayDepth.medium => 0.045,
      ClayDepth.high => 0.055,
      ClayDepth.pressed => 0.050,
      ClayDepth.flat => 0,
    };

    final Color terang = dark
        ? Colors.white.withValues(alpha: kekuatan * 0.7)
        : Colors.white.withValues(alpha: kekuatan * 4);

    final Color gelap = Colors.black.withValues(alpha: kekuatan);

    // Permukaan tenggelam membalik arah gradient-nya: yang menghadap cahaya
    // menjadi lebih GELAP, karena bagian itu masuk ke dalam.
    final Alignment awal = tenggelam
        ? Alignment(
            -ClayTokens.lightDirection.dx,
            -ClayTokens.lightDirection.dy,
          )
        : Alignment(ClayTokens.lightDirection.dx, ClayTokens.lightDirection.dy);

    return LinearGradient(
      begin: awal,
      end: Alignment(-awal.x, -awal.y),
      colors: <Color>[
        Color.alphaBlend(terang, base),
        base,
        Color.alphaBlend(gelap, base),
      ],
      stops: const <double>[0.0, 0.55, 1.0],
    );
  }
}
