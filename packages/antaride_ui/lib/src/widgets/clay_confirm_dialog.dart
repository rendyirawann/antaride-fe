import 'package:flutter/material.dart';

import '../theme/clay_shadows.dart';
import '../theme/clay_tokens.dart';
import 'clay_button.dart';
import 'clay_icon_chip.dart';
import 'clay_surface.dart';

/// Dialog konfirmasi dalam wadah clay.
///
/// ============================================================================
///  KENAPA KOMPONEN BERSAMA, BUKAN SATU KELAS PRIVAT PER LAYAR
/// ============================================================================
///  Dialog "Keluar?" yang SAMA PERSIS pernah muncul dua rupa di dalam satu
///  aplikasi: wadah clay kalau ditekan dari sidebar, `AlertDialog` Material
///  mentah kalau ditekan dari halaman Profil — kotak datar tanpa ikon, dengan
///  judul dan kalimat yang identik.
///
///  Penyebabnya bukan kecerobohan satu orang: dialognya memang ditulis di dua
///  berkas oleh dua tangan yang tidak saling melihat. Selama bentuknya hidup di
///  kelas privat masing-masing layar, perbedaan seperti itu akan lahir lagi
///  setiap kali ada dialog baru.
/// ============================================================================
///
/// ============================================================================
///  HIERARKI BAHAYA DARI CHIP GRADIEN, BUKAN DARI WARNA TEKS SAJA
/// ============================================================================
///  Aksi berbahaya ditandai tiga lapis: chip ikon bergradien [accent] di
///  puncak, tombol utama varian danger, dan tombol batal sebagai varian
///  sekunder yang lebih tenang. `AlertDialog` bawaan hanya punya satu lapis —
///  warna teks — dan itu hilang di layar yang terkena matahari langsung.
/// ============================================================================
///
/// Kontraknya `bool`: [tampilkan] mengembalikan `true` hanya kalau tombol
/// utamanya ditekan, `null`/`false` untuk batal maupun tutup di luar. Semua
/// pemanggil sudah bergantung pada bentuk itu — jangan diubah jadi enum.
class ClayConfirmDialog extends StatelessWidget {
  const ClayConfirmDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Batal',
    this.accent = ClayTokens.danger,
    this.destructive = true,
    this.hanyaInformasi = false,
  });

  /// Tanpa tombol batal — lihat [beritahu].
  final bool hanyaInformasi;

  final IconData icon;
  final String title;
  final String message;

  final String confirmLabel;
  final String cancelLabel;

  /// Warna chip ikon. Bawaannya danger — konfirmasi yang bukan aksi berbahaya
  /// jarang perlu dialog sama sekali.
  final Color accent;

  /// Tombol utama memakai varian danger. Matikan untuk konfirmasi biasa.
  final bool destructive;

  /// Dialog INFORMASI satu tombol.
  ///
  /// Bentuknya sama dengan konfirmasi — chip ikon, judul, pesan — tapi tanpa
  /// pilihan: yang membacanya tidak sedang memutuskan apa pun, dia sedang
  /// diberi tahu hasil sesuatu yang sudah terjadi.
  ///
  /// Ada di sini, bukan sebagai `AlertDialog` di layar yang membutuhkannya:
  /// satu dialog Material mentah di tengah aplikasi clay terlihat seperti
  /// bagian yang belum selesai dikerjakan.
  static Future<void> beritahu(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String buttonLabel = 'Mengerti',
    Color accent = ClayTokens.primary,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext _) => ClayConfirmDialog(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: buttonLabel,
        accent: accent,
        destructive: false,
        hanyaInformasi: true,
      ),
    );
  }

  /// Menampilkan dialog dan mengembalikan `true` kalau dikonfirmasi.
  static Future<bool> tampilkan(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Batal',
    Color accent = ClayTokens.danger,
    bool destructive = true,
  }) async {
    final bool? jawab = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => ClayConfirmDialog(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        accent: accent,
        destructive: destructive,
      ),
    );

    // Ditutup dengan menyentuh di luar mengembalikan null. Itu BUKAN
    // persetujuan — dan menyamakan null dengan true adalah cara aplikasi
    // mengeluarkan orang yang tidak menekan apa pun.
    return jawab ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      // Wadahnya ClaySurface, jadi Material milik Dialog dibuat tak terlihat —
      // dua permukaan bertumpuk menghasilkan bayangan ganda.
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: ClayTokens.space6),
      child: ClaySurface(
        depth: ClayDepth.high,
        radius: ClayTokens.radiusLarge,
        padding: const EdgeInsets.all(ClayTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClayIconChip(icon: icon, accent: accent, size: 48),

            const SizedBox(height: ClayTokens.space4),

            Text(
              title,
              style: TextStyle(
                fontFamily: ClayTokens.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: gelap
                    ? ClayTokens.textPrimaryDark
                    : ClayTokens.textPrimary,
              ),
            ),

            const SizedBox(height: ClayTokens.space2),

            Text(
              message,
              style: TextStyle(
                fontFamily: ClayTokens.fontFamily,
                fontSize: 13.5,
                height: 1.5,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
              ),
            ),

            const SizedBox(height: ClayTokens.space6),

            // Kedua tombol dibungkus `Expanded` — syarat aturan keras:
            // ClayButton di dalam Row harus `expanded: false` KECUALI dibungkus
            // Expanded, kalau tidak lebar tak terhingganya mendorong tombol
            // sebelahnya keluar layar.
            Row(
              children: <Widget>[
                if (!hanyaInformasi) ...<Widget>[
                  Expanded(
                    child: ClayButton(
                      label: cancelLabel,
                      variant: ClayButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: ClayTokens.space3),
                ],
                Expanded(
                  child: ClayButton(
                    label: confirmLabel,
                    variant: destructive
                        ? ClayButtonVariant.danger
                        : ClayButtonVariant.primary,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
