import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';

/// Layar sementara selama sesi diperiksa.
///
/// ============================================================================
///  KENAPA BUKAN LAYAR KOSONG ATAU SPINNER SAJA
/// ============================================================================
///  Pemeriksaan sesi membaca secure storage lalu memanggil API — biasanya di
///  bawah satu detik, tapi bisa lebih lama di jaringan yang buruk.
///
///  Layar kosong selama itu terbaca sebagai aplikasi yang gagal dibuka.
///  Spinner sendirian terbaca sebagai memuat sesuatu yang tidak jelas. Logo
///  dengan spinner terbaca sebagai aplikasi yang sedang bersiap — dan itu yang
///  memang sedang terjadi.
/// ============================================================================
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ClaySurface(
              depth: ClayDepth.high,
              radius: ClayTokens.radiusLarge,
              padding: const EdgeInsets.all(ClayTokens.space6),
              child: const Icon(
                Icons.two_wheeler_rounded,
                size: 48,
                color: ClayTokens.primary,
              ),
            ),
            const SizedBox(height: ClayTokens.space6),
            Text(
              'Antaride',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: gelap
                    ? ClayTokens.textPrimaryDark
                    : ClayTokens.textPrimary,
              ),
            ),
            const SizedBox(height: ClayTokens.space2),
            Text(
              'Medan, dalam satu aplikasi',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
              ),
            ),
            const SizedBox(height: ClayTokens.space10),
            const ClayLoader(size: 38),
          ],
        ),
      ),
    );
  }
}
