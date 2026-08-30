import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';

import 'media_outcome.dart';
import 'media_picker.dart';

/// Pemilih sumber foto beserta seluruh penanganan izinnya.
///
/// ============================================================================
///  SATU PEMANGGILAN UNTUK SELURUH ALURNYA
/// ============================================================================
///  Layar memanggil [show] dan mendapat [MediaPicked] atau null. Yang ditangani
///  di dalam sini:
///
///    * memilih kamera atau galeri,
///    * memeriksa dan meminta izin,
///    * menampilkan pesan untuk izin yang ditolak,
///    * menawarkan tombol Pengaturan untuk izin yang ditolak PERMANEN,
///    * memberi tahu kalau kamera dipakai aplikasi lain.
///
///  Alasan digabung: lima layar yang menangani izin sendiri-sendiri akan
///  menghasilkan lima perilaku, dan yang paling mudah terlewat justru yang paling
///  merusak — "ditolak permanen" yang diperlakukan sebagai pembatalan
///  menghasilkan tombol yang diam. Pengguna menekannya berkali-kali, dan dialog
///  izinnya memang tidak akan pernah muncul lagi.
/// ============================================================================
class MediaSourceSheet {
  const MediaSourceSheet._();

  /// Tampilkan pemilih, lalu ambil fotonya.
  ///
  /// [hanyaKamera] menghilangkan pilihan galeri, dan pemilihnya dilewati
  /// sepenuhnya — kamera langsung terbuka.
  ///
  /// ==========================================================================
  ///  KENAPA [hanyaKamera] ADA, DAN KAPAN DIA WAJIB
  /// ==========================================================================
  ///  Foto BUKTI ANTAR harus diambil di tempat, saat itu. Kalau galeri
  ///  diizinkan, driver bisa mengunggah foto paket yang sama untuk sepuluh order
  ///  berbeda — dan foto bukti kehilangan seluruh gunanya justru pada saat dia
  ///  paling dibutuhkan: sengketa "barang saya tidak pernah datang".
  ///
  ///  Ini BUKAN penjagaan yang sungguh-sungguh. Driver yang bertekad tetap bisa
  ///  memotret foto di layar HP lain. Yang dibeli hanya menghilangkan jalan yang
  ///  paling mudah — dan untuk kecurangan yang untungnya kecil, itu biasanya
  ///  cukup.
  ///
  ///  Penjagaan yang sungguh-sungguh ada di backend: waktu unggah dibandingkan
  ///  dengan waktu penyelesaian order.
  /// ==========================================================================
  static Future<MediaPicked?> show({
    required BuildContext context,
    String title = 'Ambil foto',
    String namaDasar = 'foto',
    bool hanyaKamera = false,
    MediaPicker picker = const MediaPicker(),
  }) async {
    final MediaSource? sumber = hanyaKamera
        ? MediaSource.camera
        : await _pilihSumber(context: context, title: title);

    if (sumber == null || !context.mounted) {
      return null;
    }

    final MediaOutcome hasil = await picker.pick(
      source: sumber,
      namaDasar: namaDasar,
    );

    if (!context.mounted) {
      return null;
    }

    switch (hasil) {
      case MediaPicked():
        return hasil;

      case MediaCancelled():
        // Pengguna sendiri yang membatalkan. Tidak ada yang perlu ditampilkan —
        // pesan "dibatalkan" untuk tindakan yang dia lakukan sendiri hanya
        // menambah satu ketukan lagi untuk menutupnya.
        return null;

      case MediaPermissionDenied(message: final String pesan):
        _pesan(context, pesan);

        return null;

      case MediaPermissionPermanentlyDenied(message: final String pesan):
        await _dialogPengaturan(context, pesan, picker);

        return null;

      case MediaFailed(message: final String pesan):
        _pesan(context, pesan);

        return null;
    }
  }

  // ---------------------------------------------------------------------------

  static Future<MediaSource?> _pilihSumber({
    required BuildContext context,
    required String title,
  }) {
    return ClayBottomSheet.show<MediaSource>(
      context: context,
      title: title,

      /*
       * `Builder` bukan hiasan.
       *
       * `ClayBottomSheet.show` menerima `child` — widget yang sudah dibangun,
       * bukan builder. Kalau `Navigator.of(context).pop(...)` di dalam `onTap`
       * menangkap context DI LUAR sheet, yang di-pop adalah route di bawahnya:
       * halaman yang sedang dibuka pengguna, bukan sheet-nya.
       *
       * `Builder` memberi context yang berada DI DALAM subtree sheet, jadi
       * `Navigator.of` menemukan route sheet itu sendiri.
       */
      child: Builder(
        builder: (BuildContext sheet) => Column(
          children: <Widget>[
            _Pilihan(
              icon: Icons.photo_camera_rounded,
              label: 'Kamera',
              keterangan: 'Ambil foto sekarang',
              onTap: () => Navigator.of(sheet).pop(MediaSource.camera),
            ),
            const SizedBox(height: ClayTokens.space3),
            _Pilihan(
              icon: Icons.photo_library_rounded,
              label: 'Galeri',
              keterangan: 'Pilih foto yang sudah ada',
              onTap: () => Navigator.of(sheet).pop(MediaSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  static void _pesan(BuildContext context, String teks) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(teks), behavior: SnackBarBehavior.floating),
    );
  }

  /// Dialog untuk izin yang ditolak permanen.
  ///
  /// Dialog, bukan snackbar. Snackbar hilang sendiri setelah beberapa detik, dan
  /// pesan yang menyebut langkah-langkah di pengaturan tidak bisa diikuti dalam
  /// waktu itu — pengguna masih membacanya saat pesannya sudah hilang.
  static Future<void> _dialogPengaturan(
    BuildContext context,
    String pesan,
    MediaPicker picker,
  ) async {
    /*
     * Aksen `warning`, bukan aksen aplikasi.
     *
     * Paket ini dipakai ketiga aplikasi sekaligus — dan tidak menerima warna
     * merek dari pemanggilnya. Memilih salah satu aksen aplikasi di sini berarti
     * dialog hijau penumpang muncul di tengah aplikasi merchant yang amber.
     *
     * `warning` netral terhadap ketiganya dan tepat maknanya: ada yang
     * menghalangi, tapi tidak ada yang rusak dan tidak ada yang hilang.
     */
    final bool buka = await ClayConfirmDialog.tampilkan(
      context,
      icon: Icons.lock_outline_rounded,
      title: 'Izin diperlukan',
      message: pesan,
      confirmLabel: 'Buka Pengaturan',
      cancelLabel: 'Nanti',
      accent: ClayTokens.warning,

      // Membuka pengaturan tidak menghapus apa pun.
      destructive: false,
    );

    if (buka) {
      await picker.openSettings();
    }
  }
}

class _Pilihan extends StatelessWidget {
  const _Pilihan({
    required this.icon,
    required this.label,
    required this.keterangan,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String keterangan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.low,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          ClaySurface(
            depth: ClayDepth.pressed,
            radius: ClayTokens.radiusSmall,
            padding: const EdgeInsets.all(ClayTokens.space3),
            child: Icon(icon, size: 22, color: ClayTokens.primary),
          ),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: gelap
                        ? ClayTokens.textPrimaryDark
                        : ClayTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  keterangan,
                  style: TextStyle(
                    fontSize: 12,
                    color: gelap
                        ? ClayTokens.textSecondaryDark
                        : ClayTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: gelap
                ? ClayTokens.textTertiaryDark
                : ClayTokens.textTertiary,
          ),
        ],
      ),
    );
  }
}
