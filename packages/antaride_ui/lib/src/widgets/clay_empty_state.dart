import 'package:flutter/material.dart';

import '../theme/clay_tokens.dart';
import 'clay_button.dart';

/// Keadaan kosong dan keadaan galat.
///
/// ============================================================================
///  KEADAAN KOSONG SELALU MENYEBUTKAN LANGKAH BERIKUTNYA
/// ============================================================================
///  "Belum ada order" tidak memberi tahu apa pun tentang apa yang harus
///  dilakukan. "Belum ada order — pesan pertama Anda dari beranda" memberi tahu.
///
///  Yang membuat ini penting bukan kesopanan: layar kosong tanpa arah adalah
///  tempat orang berhenti memakai aplikasi. Dan layar kosong PALING SERING
///  dilihat oleh pengguna BARU — yaitu orang yang paling belum memutuskan
///  apakah akan terus memakainya.
/// ============================================================================
class ClayEmptyState extends StatelessWidget {
  const ClayEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;

  /// Wajib, dan harus menyebutkan langkah berikutnya. Lihat docblock kelas.
  final String message;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ClayTokens.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: gelap
                    ? ClayTokens.surfaceSunkenDark
                    : ClayTokens.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: gelap
                    ? ClayTokens.textTertiaryDark
                    : ClayTokens.textTertiary,
              ),
            ),

            const SizedBox(height: ClayTokens.space6),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: gelap
                    ? ClayTokens.textPrimaryDark
                    : ClayTokens.textPrimary,
                fontFamily: 'PlusJakartaSans',
              ),
            ),

            const SizedBox(height: ClayTokens.space2),

            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
                fontFamily: 'PlusJakartaSans',
              ),
            ),

            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: ClayTokens.space6),
              SizedBox(
                width: 220,
                child: ClayButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Keadaan galat.
///
/// ============================================================================
///  PESAN GALAT DATANG DARI BACKEND, DAN ITU DISENGAJA
/// ============================================================================
///  Backend Antaride mengirim pesan yang sudah ditulis untuk dibaca pengguna —
///  "Saldo tidak cukup. Saldo Anda Rp 12.000, kurang Rp 13.000", bukan
///  "INSUFFICIENT_BALANCE".
///
///  Menampilkan pesan generik "Terjadi kesalahan" di sini akan MEMBUANG seluruh
///  usaha itu. Yang membuat pesan galat berguna adalah menyebutkan apa yang
///  gagal dan langkah berikutnya, dan backend sudah tahu keduanya.
///
///  Pesan generik hanya dipakai kalau memang tidak ada pesan dari backend —
///  misalnya saat jaringannya mati sebelum request terkirim.
/// ============================================================================
class ClayErrorState extends StatelessWidget {
  const ClayErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Coba lagi',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return ClayEmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Tidak bisa dimuat',
      message: message,
      actionLabel: onRetry == null ? null : retryLabel,
      onAction: onRetry,
    );
  }
}
