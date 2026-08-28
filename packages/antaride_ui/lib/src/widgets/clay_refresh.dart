import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

import '../theme/clay_tokens.dart';

/// Tarik-untuk-menyegarkan dan muat-saat-menggulir, dalam satu widget.
///
/// ============================================================================
///  KENAPA easy_refresh, BUKAN RefreshIndicator BAWAAN
/// ============================================================================
///  `RefreshIndicator` hanya menangani tarik dari ATAS. Muat-saat-menggulir
///  harus ditulis sendiri dengan `ScrollController` dan pendengar posisi — dan
///  itu yang sebelumnya ada di layar riwayat dan dompet, dua kali, dengan ambang
///  yang ditulis ulang di masing-masing.
///
///  Yang salah dari menulisnya sendiri bukan jumlah barisnya, tapi hal-hal yang
///  mudah terlewat:
///
///    * pemicu ganda saat pengguna menggulir cepat melewati ambangnya
///    * keadaan "sudah habis" yang harus berhenti memicu request
///    * kegagalan halaman berikutnya yang tidak boleh mengosongkan yang sudah
///      tampil
///
///  `easy_refresh` sudah menangani ketiganya, dan sudah diuji di banyak
///  perangkat. Dibungkus di sini supaya teksnya berbahasa Indonesia dan warnanya
///  mengikuti tema clay — dan supaya ketiga aplikasi memakai hal yang sama.
/// ============================================================================
///
/// ============================================================================
///  [onLoad] NULL BERARTI TIDAK ADA HALAMAN BERIKUTNYA
/// ============================================================================
///  Layar yang isinya tidak berhalaman — dasbor driver, beranda penumpang —
///  cukup mengosongkan [onLoad]. Footer-nya tidak akan muncul sama sekali.
///
///  Untuk daftar berhalaman, kembalikan [IndicatorResult.noMore] dari [onLoad]
///  begitu cursor-nya habis. Tanpa itu, footer akan terus memicu request untuk
///  halaman yang tidak ada.
/// ============================================================================
class ClayRefresh extends StatelessWidget {
  const ClayRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.onLoad,
    this.controller,
  });

  final Widget child;

  /// Dipanggil saat pengguna menarik dari atas.
  final Future<void> Function() onRefresh;

  /// Dipanggil saat gulirannya mendekati dasar. Null berarti tidak berhalaman.
  ///
  /// Kembalikan [IndicatorResult.noMore] saat sudah habis.
  final Future<IndicatorResult> Function()? onLoad;

  final EasyRefreshController? controller;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final Color teks = gelap
        ? ClayTokens.textSecondaryDark
        : ClayTokens.textSecondary;

    final TextStyle gaya = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: teks,
    );

    return EasyRefresh(
      controller: controller,

      header: ClassicHeader(
        // Seluruh teksnya bahasa Indonesia. Bawaan paketnya bahasa Inggris, dan
        // "Pull to refresh" di tengah aplikasi berbahasa Indonesia terbaca
        // sebagai bagian yang belum selesai dikerjakan.
        dragText: 'Tarik untuk menyegarkan',
        armedText: 'Lepaskan untuk menyegarkan',
        readyText: 'Menyegarkan…',
        processingText: 'Menyegarkan…',
        processedText: 'Selesai',
        failedText: 'Gagal menyegarkan',
        noMoreText: 'Tidak ada yang baru',

        // Cap waktu "terakhir diperbarui" dimatikan. Dia menambah satu baris
        // teks yang berubah setiap detik, dan pada layar yang menyegarkan sendiri
        // secara berkala angkanya tidak berarti apa pun bagi pengguna.
        showMessage: false,

        textStyle: gaya,
        iconTheme: IconThemeData(color: teks, size: 20),
        progressIndicatorSize: 20,
        progressIndicatorStrokeWidth: 2.2,
        triggerOffset: 70,

        // `clamping: false` — konten ikut bergeser saat ditarik, bukan
        // indikatornya saja yang muncul di atasnya. Itu yang membuat tarikannya
        // terasa mengikuti jari.
        clamping: false,
      ),

      footer: onLoad == null
          ? null
          : ClassicFooter(
              dragText: 'Tarik untuk memuat lagi',
              armedText: 'Lepaskan untuk memuat',
              readyText: 'Memuat…',
              processingText: 'Memuat…',
              processedText: 'Selesai',
              failedText: 'Gagal memuat',
              noMoreText: 'Sudah sampai yang paling awal',
              showMessage: false,
              textStyle: gaya,
              iconTheme: IconThemeData(color: teks, size: 20),
              progressIndicatorSize: 20,
              progressIndicatorStrokeWidth: 2.2,

              /*
               * `infiniteOffset: 70` — halaman berikutnya dimuat 70 piksel
               * SEBELUM dasar, bukan setelah pengguna menariknya.
               *
               * Untuk riwayat yang dibaca dengan menggulir, memaksa tarikan di
               * setiap halaman berarti guliran yang terputus setiap dua puluh
               * baris. Yang menunggu sampai dasar juga selalu menampilkan
               * spinner, karena request-nya baru dimulai setelah pengguna tidak
               * punya apa pun lagi untuk dibaca.
               */
              infiniteOffset: 70,
            ),

      onRefresh: onRefresh,
      onLoad: onLoad,
      child: child,
    );
  }
}
