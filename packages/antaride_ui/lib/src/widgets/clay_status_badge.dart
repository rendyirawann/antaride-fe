import 'package:flutter/material.dart';

import '../theme/clay_tokens.dart';

/// Lencana status order.
///
/// ============================================================================
///  WARNA DIPETAKAN DARI STATUS, DI SATU TEMPAT
/// ============================================================================
///  Status order muncul di enam layar berbeda: beranda, pelacakan, riwayat,
///  detail, notifikasi, dan daftar order driver. Kalau setiap layar memetakan
///  warnanya sendiri, akan ada layar yang menampilkan `driver_arriving` dengan
///  warna berbeda dari layar lain.
///
///  Itu terlihat kecil dan berakibat nyata: pengguna belajar arti warna dalam
///  beberapa hari pemakaian, dan warna yang tidak konsisten membatalkan
///  pembelajaran itu. Setelahnya, warnanya berhenti membawa informasi.
/// ============================================================================
///
///  Label-nya datang dari backend (`status_label`), bukan diterjemahkan di sini.
///  Alasan yang sama seperti nominal uang: satu sumber, satu jawaban, dan tiga
///  aplikasi tidak bisa menyimpang.
class ClayStatusBadge extends StatelessWidget {
  const ClayStatusBadge({
    super.key,
    required this.status,
    required this.label,
    this.compact = false,
  });

  /// Nilai mentah, misalnya `driver_arriving`.
  final String status;

  /// Teks yang ditampilkan, dari backend.
  final String label;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color warna = warnaUntuk(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? ClayTokens.space2 : ClayTokens.space3,
        vertical: compact ? ClayTokens.space1 : ClayTokens.space2,
      ),
      decoration: BoxDecoration(
        // Latar transparan dari warna statusnya, bukan warna penuh.
        //
        // Lencana berwarna penuh bersaing dengan tombol utama di layar yang
        // sama — dan pada layar pelacakan, keduanya selalu muncul bersamaan.
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? ClayTokens.space1 : ClayTokens.space2),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: warna,
              fontFamily: ClayTokens.fontFamily,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Warna untuk sebuah status. Publik supaya layar lain bisa memakainya untuk
  /// hal selain lencana — garis pada peta, misalnya.
  static Color warnaUntuk(String status) {
    return switch (status) {
      // Sedang berlangsung: biru. Netral, tidak menuntut tindakan.
      'searching' || 'created' => ClayTokens.info,

      // Sudah ada driver: hijau, warna "berjalan lancar".
      'accepted' || 'driver_arriving' => ClayTokens.primary,

      // Driver SUDAH TIBA: kuning, karena ini satu-satunya status yang menuntut
      // penumpang bertindak sekarang — keluar dan bertemu drivernya.
      'driver_arrived' => ClayTokens.warning,

      'in_progress' => ClayTokens.primary,
      'completed' => ClayTokens.success,

      // Ketiga bentuk kegagalan memakai warna yang sama, tapi label-nya berbeda
      // — dan label yang berbeda itu datang dari backend.
      'cancelled' || 'no_driver' || 'expired' => ClayTokens.danger,

      _ => ClayTokens.textTertiary,
    };
  }
}
