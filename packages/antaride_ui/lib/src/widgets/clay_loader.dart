import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../theme/clay_shadows.dart';
import '../theme/clay_tokens.dart';
import 'clay_surface.dart';

/// Indikator memuat.
///
/// ============================================================================
///  SATU SPINNER UNTUK SELURUH APLIKASI, DAN BUKAN YANG BAWAAN MATERIAL
/// ============================================================================
///  `CircularProgressIndicator` bekerja, dan itu bukan masalahnya. Masalahnya
///  bentuknya: cincin tipis dengan sudut tajam, yang di antara permukaan clay
///  yang semuanya bulat dan lembut terbaca sebagai komponen dari aplikasi lain.
///
///  `SpinKitPulse` dipakai untuk pemuatan halaman penuh — denyut yang melebar
///  dan meredup, satu bentuk bulat, dan gerakannya cocok dengan bahasa visual
///  yang sama.
///
///  Dibungkus di sini, tidak dipanggil langsung dari layar. Konsekuensinya:
///  mengganti spinner nanti menyentuh SATU file, bukan lima puluh layar — dan
///  tidak akan ada layar yang tertinggal dengan spinner versi lama.
/// ============================================================================
class ClayLoader extends StatelessWidget {
  const ClayLoader({super.key, this.size = 44, this.color, this.message});

  final double size;
  final Color? color;

  /// Kalimat di bawah spinner.
  ///
  /// Dipakai untuk pemuatan yang bisa berlangsung lebih dari satu detik — dan
  /// harus menyebutkan APA yang sedang dimuat. Spinner tanpa keterangan pada
  /// jaringan lambat tidak bisa dibedakan dari aplikasi yang menggantung.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SpinKitPulse(size: size, color: color ?? ClayTokens.primary),
          if (message != null) ...<Widget>[
            const SizedBox(height: ClayTokens.space4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Spinner kecil untuk di dalam tombol dan baris.
///
/// `SpinKitThreeBounce` alih-alih denyut: pada ukuran kecil, denyut yang melebar
/// dan meredup hampir tidak terlihat bergerak, sementara tiga titik yang
/// memantul tetap terbaca sebagai "sedang berjalan".
class ClayInlineLoader extends StatelessWidget {
  const ClayInlineLoader({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SpinKitThreeBounce(size: size, color: color ?? Colors.white);
  }
}

/// Overlay memuat di atas layar yang sudah ada isinya.
///
/// ============================================================================
///  DIPAKAI SAAT DATA LAMA MASIH BERGUNA DIBACA
/// ============================================================================
///  Layar pelacakan yang menarik ulang, atau dasbor driver yang menyegarkan
///  status: isinya tetap terlihat di belakang, sedikit diredupkan.
///
///  Yang TIDAK dilakukan: mengganti seluruh layar dengan spinner. Penumpang yang
///  sedang membaca plat nomor driver akan kehilangan angka yang sedang dia
///  cocokkan — dan penarikan berkala terjadi setiap beberapa detik.
/// ============================================================================
class ClayLoadingOverlay extends StatelessWidget {
  const ClayLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: <Widget>[
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: (gelap ? Colors.black : Colors.white).withValues(
                alpha: 0.55,
              ),
              child: ClaySurface(
                depth: ClayDepth.high,
                radius: ClayTokens.radiusLarge,
                padding: const EdgeInsets.all(ClayTokens.space6),
                child: ClayLoader(message: message),
              ),
            ),
          ),
      ],
    );
  }
}
