import 'package:flutter/material.dart';

import '../theme/clay_tokens.dart';

enum ClayMoneySize { small, medium, large, hero }

/// Menampilkan nominal uang.
///
/// ============================================================================
///  TEKS TERFORMAT DATANG DARI BACKEND, BUKAN DIFORMAT DI SINI
/// ============================================================================
///  Setiap nilai uang di API dikirim sebagai `{amount, currency, formatted}`.
///  Widget ini menampilkan `formatted`.
///
///  Alasannya: kalau tiga aplikasi Flutter memformat sendiri, ketiganya harus
///  sepakat soal pemisah ribuan, posisi tanda minus, dan penulisan "Rp". Salah
///  satu akan berbeda — dan yang paling sering: tanda minus. `Rp -5.600` versus
///  `-Rp 5.600` adalah bug yang tidak pernah dianggap penting sampai ada
///  penumpang yang menganggapnya salah cetak dan menelepon CS.
///
///  Backend sudah menanganinya di `Money::format()`. Satu tempat, satu jawaban.
/// ============================================================================
///
/// ============================================================================
///  ANGKA UANG SELALU TABULAR
/// ============================================================================
///  `FontFeature.tabularFigures()` membuat setiap digit selebar yang lain.
///
///  Tanpa itu, kolom nominal di daftar transaksi tidak sejajar — dan kolom
///  Rupiah yang tidak sejajar membuat perbandingan sekilas antar baris tidak
///  mungkin, yang justru menjadi alasan utama daftar itu dibuka.
/// ============================================================================
class ClayMoney extends StatelessWidget {
  const ClayMoney({
    super.key,
    required this.formatted,
    this.size = ClayMoneySize.medium,
    this.color,
    this.strikethrough = false,
  });

  /// Nilai yang sudah diformat backend, misalnya "Rp 25.000" atau "-Rp 5.600".
  final String formatted;

  final ClayMoneySize size;
  final Color? color;

  /// Untuk harga sebelum diskon.
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final (double ukuran, FontWeight bobot) = switch (size) {
      ClayMoneySize.small => (13.0, FontWeight.w600),
      ClayMoneySize.medium => (15.0, FontWeight.w700),
      ClayMoneySize.large => (20.0, FontWeight.w800),
      ClayMoneySize.hero => (32.0, FontWeight.w800),
    };

    /*
     * Nominal negatif otomatis berwarna merah, KECUALI kalau warnanya
     * ditentukan pemanggil.
     *
     * Nominal negatif di aplikasi ini selalu berarti pengurangan — diskon,
     * penyesuaian tarif, potongan komisi. Warna merah membuatnya terbaca tanpa
     * membaca tandanya, dan pada baris rincian ongkos itu perbedaan antara
     * struk yang bisa dipahami sekilas dan yang harus dibaca teliti.
     */
    final bool negatif = formatted.startsWith('-');

    final Color warna =
        color ??
        (negatif
            ? ClayTokens.danger
            : (gelap ? ClayTokens.textPrimaryDark : ClayTokens.money));

    return Text(
      formatted,
      style: TextStyle(
        fontSize: ukuran,
        fontWeight: bobot,
        color: strikethrough
            ? (gelap ? ClayTokens.textTertiaryDark : ClayTokens.textTertiary)
            : warna,
        decoration: strikethrough ? TextDecoration.lineThrough : null,
        height: 1.2,
        fontFamily: 'PlusJakartaSans',

        // Lihat penjelasan di docblock kelas.
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Satu baris rincian ongkos: label di kiri, nominal di kanan.
///
/// Dipakai di struk order dan di layar konfirmasi. Dibuat widget tersendiri
/// karena penyejajarannya harus konsisten di kedua tempat — dan tanpa widget
/// bersama, keduanya akan menyimpang.
class ClayMoneyRow extends StatelessWidget {
  const ClayMoneyRow({
    super.key,
    required this.label,
    required this.formatted,
    this.emphasized = false,
    this.hint,
  });

  final String label;
  final String formatted;

  /// Untuk baris total.
  final bool emphasized;

  /// Keterangan kecil di bawah label, misalnya "termasuk biaya aplikasi".
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ClayTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: emphasized ? 16 : 14,
                    fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
                    color: gelap
                        ? (emphasized
                              ? ClayTokens.textPrimaryDark
                              : ClayTokens.textSecondaryDark)
                        : (emphasized
                              ? ClayTokens.textPrimary
                              : ClayTokens.textSecondary),
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      hint!,
                      style: TextStyle(
                        fontSize: 11,
                        color: gelap
                            ? ClayTokens.textTertiaryDark
                            : ClayTokens.textTertiary,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: ClayTokens.space3),
          ClayMoney(
            formatted: formatted,
            size: emphasized ? ClayMoneySize.large : ClayMoneySize.medium,
          ),
        ],
      ),
    );
  }
}
