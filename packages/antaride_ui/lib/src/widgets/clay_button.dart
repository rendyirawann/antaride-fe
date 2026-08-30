import 'package:flutter/material.dart';

import '../theme/clay_shadows.dart';
import '../theme/clay_tokens.dart';
import 'clay_loader.dart';

enum ClayButtonVariant { primary, secondary, danger, ghost }

/// Tombol clay.
///
/// ============================================================================
///  TOMBOL YANG DITEKAN BENAR-BENAR TENGGELAM
/// ============================================================================
///  Bukan sekadar berubah warna. Kedalamannya berpindah dari `medium` ke
///  `pressed`, dan bayangannya ikut berbalik.
///
///  Alasannya bukan estetika: pada permukaan claymorphism yang kontrasnya
///  rendah, perubahan warna saja hampir tidak terlihat — terutama di layar HP
///  yang terkena cahaya matahari langsung, yang merupakan kondisi normal bagi
///  driver. Perubahan BENTUK terlihat dalam kondisi apa pun.
/// ============================================================================
///
/// ============================================================================
///  KEADAAN MEMUAT MENGUNCI TOMBOLNYA, DAN ITU DISENGAJA
/// ============================================================================
///  `isLoading: true` membuat `onPressed` diabaikan. Tanpa itu, penumpang di
///  jaringan lambat akan menekan "Pesan" tiga kali sebelum responsnya datang —
///  dan walaupun middleware idempotency di backend menutup akibatnya, request
///  keduanya tetap terkirim dan tetap menghabiskan waktu.
///
///  Yang lebih penting: tombol yang tidak berubah setelah ditekan membuat orang
///  menyimpulkan tekanannya tidak terdaftar.
/// ============================================================================
class ClayButton extends StatefulWidget {
  const ClayButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ClayButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final ClayButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;
  final double? height;

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _ditekan = false;

  bool get _aktif => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final (Color latar, Color teks) = _warna(gelap);

    final ClayDepth kedalaman = !_aktif
        ? ClayDepth.flat
        : (_ditekan ? ClayDepth.pressed : ClayDepth.medium);

    final double tinggi = widget.height ?? ClayTokens.minTouchTarget;
    final BorderRadius bentuk = BorderRadius.circular(ClayTokens.radiusMedium);

    // Spinner tombol memakai ClayInlineLoader — tiga titik memantul, sama
    // dengan yang dipakai di baris dan pita di seluruh aplikasi. Cincin Material
    // yang dulu di sini adalah satu-satunya bentuk bersudut tajam di antara
    // permukaan clay, dan itu terlihat.
    final Widget isi = widget.isLoading
        ? ClayInlineLoader(size: 18, color: teks)
        : Row(
            mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: 20, color: teks),
                const SizedBox(width: ClayTokens.space2),
              ],
              /*
               * Label MENGECIL saat sempit, bukan meluap.
               *
               * `Flexible` memberi Row izin memberi label lebih sempit daripada
               * lebar alaminya; `FittedBox(scaleDown)` mengecilkan hurufnya
               * alih-alih memotongnya. Tanpa keduanya, tombol di dalam Row yang
               * sempit — bilah "Pesan sekarang" di layar konfirmasi, "Lewati"
               * di kartu tawaran driver — meluap ke kanan dengan garis kuning
               * hitam di build debug dan padding dalam yang hilang di rilis.
               *
               * Diukur pada HP 320 dp (masih umum di kelas entry Android di
               * Medan): tanpa ini "Pesan sekarang" meluap 22 px, dan "Lewati"
               * hanya bersisa 0,9 px — cukup untuk pecah begitu pengguna
               * menaikkan ukuran teks sistem satu tingkat.
               *
               * scaleDown, bukan `contain`: label yang MEMBESAR di tombol lebar
               * akan membuat tiap tombol punya ukuran huruf berbeda.
               */
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: teks,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,

                      // Tinggi baris 1.0 supaya teks benar-benar terpusat
                      // vertikal di dalam tombol. Nilai bawaan menambah ruang di
                      // bawah huruf dan membuat labelnya terlihat sedikit ke
                      // atas — kecil, tapi terlihat pada tombol pendek.
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          );

    return GestureDetector(
      onTapDown: _aktif ? (_) => setState(() => _ditekan = true) : null,
      onTapUp: _aktif ? (_) => setState(() => _ditekan = false) : null,
      onTapCancel: _aktif ? () => setState(() => _ditekan = false) : null,
      onTap: _aktif ? widget.onPressed : null,

      child: AnimatedContainer(
        /*
         * 90 ms, bukan 200.
         *
         * Umpan balik sentuh harus terasa SEKARANG. Di atas sekitar 120 ms,
         * animasinya berhenti terasa sebagai respons dan mulai terasa sebagai
         * jeda — dan pada tombol, jeda terbaca sebagai aplikasi yang lambat.
         */
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,

        width: widget.expanded ? double.infinity : null,
        height: tinggi,

        decoration: BoxDecoration(
          color: latar,
          borderRadius: bentuk,
          boxShadow: ClayShadows.outer(kedalaman, dark: gelap),
          gradient: ClayShadows.innerGradient(
            kedalaman,
            base: latar,
            dark: gelap,
          ),
          border: widget.variant == ClayButtonVariant.ghost
              ? Border.all(
                  color: gelap
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.5,
                )
              : null,
        ),

        padding: const EdgeInsets.symmetric(horizontal: ClayTokens.space5),
        alignment: Alignment.center,
        child: isi,
      ),
    );
  }

  (Color, Color) _warna(bool gelap) {
    if (!_aktif) {
      /*
       * Tombol nonaktif dibuat lebih redup, TAPI tetap terbaca.
       *
       * Opasitas yang terlalu rendah membuat labelnya tidak bisa dibaca, dan
       * yang terjadi berikutnya: orang tidak tahu tombol itu untuk apa, jadi
       * tidak tahu apa yang harus dilakukan untuk mengaktifkannya. Tombol
       * nonaktif harus memberi tahu tujuannya.
       */
      return (
        gelap ? ClayTokens.surfaceSunkenDark : ClayTokens.surfaceSunken,
        gelap ? ClayTokens.textTertiaryDark : ClayTokens.textTertiary,
      );
    }

    return switch (widget.variant) {
      ClayButtonVariant.primary => (ClayTokens.primary, Colors.white),
      ClayButtonVariant.danger => (ClayTokens.danger, Colors.white),
      ClayButtonVariant.secondary => (
        gelap ? ClayTokens.surfaceRaisedDark : ClayTokens.surfaceRaised,
        ClayTokens.primary,
      ),
      ClayButtonVariant.ghost => (
        Colors.transparent,
        gelap ? ClayTokens.textPrimaryDark : ClayTokens.textPrimary,
      ),
    };
  }
}
