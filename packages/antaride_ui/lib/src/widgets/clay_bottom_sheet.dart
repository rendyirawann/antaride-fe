import 'package:flutter/material.dart';

import '../theme/clay_shadows.dart';
import '../theme/clay_tokens.dart';

/// Bottom sheet clay.
///
/// ============================================================================
///  BOTTOM SHEET ADALAH POLA UTAMA APLIKASI INI, BUKAN DIALOG
/// ============================================================================
///  Pemesanan, konfirmasi harga, pelacakan driver, pemilihan alasan pembatalan
///  — semuanya bottom sheet.
///
///  Alasannya bukan tren: aplikasi ride-hailing dipakai satu tangan sambil
///  berdiri, dan bagian bawah layar adalah satu-satunya area yang bisa dijangkau
///  jempol tanpa memindahkan pegangan. Dialog yang muncul di tengah layar
///  menuntut tangan kedua.
///
///  Yang juga penting: bottom sheet TIDAK menutupi peta seluruhnya. Penumpang
///  yang sedang menunggu driver perlu melihat drivernya bergerak sambil membaca
///  detailnya.
/// ============================================================================
class ClayBottomSheet extends StatelessWidget {
  const ClayBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
    this.padding = const EdgeInsets.all(ClayTokens.space5),
  });

  final Widget child;
  final String? title;
  final bool showHandle;
  final EdgeInsetsGeometry padding;

  /// Tampilkan sebagai modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,

      // `enableDrag` mengikuti `isDismissible`. Sheet yang tidak bisa ditutup
      // tapi bisa digeser akan tersangkut separuh jalan, dan itu terlihat rusak.
      enableDrag: isDismissible,

      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      elevation: 0,

      /*
       * Barrier lebih gelap dari bawaan Material (0.32 versus ~0.15).
       *
       * Pada permukaan clay yang kontrasnya rendah, barrier terang membuat batas
       * antara sheet dan latarnya hampir tidak terlihat — dan sheet yang batasnya
       * tidak jelas terbaca sebagai bagian dari halaman, bukan sebagai lapisan di
       * atasnya.
       */
      barrierColor: Colors.black.withValues(alpha: 0.32),

      builder: (BuildContext context) => ClayBottomSheet(
        title: title,
        showHandle: isDismissible,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final Color latar = gelap
        ? ClayTokens.surfaceRaisedDark
        : ClayTokens.surfaceRaised;

    return Container(
      decoration: BoxDecoration(
        color: latar,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ClayTokens.radiusLarge),
        ),
        boxShadow: ClayShadows.outer(ClayDepth.high, dark: gelap),
      ),

      child: SafeArea(
        top: false,
        child: Padding(
          /*
           * Padding bawah menambahkan tinggi keyboard.
           *
           * Tanpa ini, sheet yang punya kolom input akan tertutup keyboard —
           * dan pengguna mengetik ke kolom yang tidak dia lihat. Ini bug paling
           * umum pada bottom sheet, dan satu-satunya penyebabnya adalah lupa
           * memperhitungkan viewInsets.
           */
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showHandle)
                Padding(
                  padding: const EdgeInsets.only(top: ClayTokens.space3),
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: gelap
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(
                        ClayTokens.radiusPill,
                      ),
                    ),
                  ),
                ),

              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: ClayTokens.space5,
                    left: ClayTokens.space5,
                    right: ClayTokens.space5,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: gelap
                            ? ClayTokens.textPrimaryDark
                            : ClayTokens.textPrimary,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
                ),

              Flexible(
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
