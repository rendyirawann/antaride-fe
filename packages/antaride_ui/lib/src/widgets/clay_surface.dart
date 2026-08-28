import 'package:flutter/material.dart';

import '../theme/clay_shadows.dart';
import '../theme/clay_tokens.dart';

/// Permukaan clay: satu widget yang menjadi dasar seluruh kartu, panel, dan
/// tombol di aplikasi ini.
///
/// ============================================================================
///  SATU WIDGET, BUKAN SATU PER JENIS
/// ============================================================================
///  Alternatifnya adalah ClayCard, ClayPanel, ClayButton, ClayInput — masing
///  masing dengan bayangannya sendiri. Yang terjadi kalau begitu: empat
///  implementasi bayangan yang harus sepakat, dan yang satu akan tertinggal
///  setiap kali ada penyesuaian.
///
///  Gejalanya di layar: kartu dan tombol di baris yang sama tercahayai berbeda,
///  dan tidak ada yang bisa menunjuk kenapa antarmukanya "terasa aneh".
///
///  Widget yang lebih spesifik ada, tapi semuanya MEMBUNGKUS yang ini.
/// ============================================================================
class ClaySurface extends StatelessWidget {
  const ClaySurface({
    super.key,
    required this.child,
    this.depth = ClayDepth.medium,
    this.radius = ClayTokens.radiusMedium,
    this.padding = const EdgeInsets.all(ClayTokens.space4),
    this.margin,
    this.color,
    this.width,
    this.height,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final ClayDepth depth;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final Color dasar =
        color ??
        (gelap
            ? (depth == ClayDepth.pressed
                  ? ClayTokens.surfaceSunkenDark
                  : ClayTokens.surfaceRaisedDark)
            : (depth == ClayDepth.pressed
                  ? ClayTokens.surfaceSunken
                  : ClayTokens.surfaceRaised));

    final BorderRadius bentuk = BorderRadius.circular(radius);

    Widget permukaan = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: dasar,
        borderRadius: bentuk,
        boxShadow: ClayShadows.outer(depth, dark: gelap),
        gradient: ClayShadows.innerGradient(depth, base: dasar, dark: gelap),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1.5),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return permukaan;
    }

    /*
     * Material + InkWell dibungkus di LUAR Container, bukan di dalam.
     *
     * Kalau di dalam, riak sentuhnya digambar di atas gradient dan terlihat
     * sebagai kotak abu-abu yang menutupi seluruh kartu — termasuk sudut
     * membulatnya. Di luar, dengan `clipBehavior`, riaknya mengikuti bentuk
     * kartunya.
     *
     * `color: Colors.transparent` pada Material diperlukan supaya dia tidak
     * menggambar latarnya sendiri di atas gradient yang sudah benar.
     */
    return Material(
      color: Colors.transparent,
      borderRadius: bentuk,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: bentuk,

        // Warna riak diturunkan dari warna utama, bukan hitam bawaan Material.
        // Riak hitam di atas permukaan clay yang terang terlihat seperti kotoran.
        splashColor: ClayTokens.primary.withValues(alpha: 0.10),
        highlightColor: ClayTokens.primary.withValues(alpha: 0.05),

        child: permukaan,
      ),
    );
  }
}

/// Kartu clay: permukaan dengan padding dan margin yang lazim untuk daftar.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.onTap,
    this.depth = ClayDepth.low,
    this.padding = const EdgeInsets.all(ClayTokens.space4),
    this.margin = const EdgeInsets.only(bottom: ClayTokens.space3),
  });

  final Widget child;
  final VoidCallback? onTap;
  final ClayDepth depth;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: depth,
      radius: ClayTokens.radiusMedium,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }
}
