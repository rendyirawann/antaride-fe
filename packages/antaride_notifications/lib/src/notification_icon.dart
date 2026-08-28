import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notification_controller.dart';
import 'notification_screen.dart';

/// Ikon lonceng dengan lencana jumlah belum dibaca.
///
/// ============================================================================
///  MEMBUKA LAYARNYA SENDIRI, BUKAN LEWAT CALLBACK
/// ============================================================================
///  Yang tampak lebih fleksibel: `onTap` yang diisi masing-masing aplikasi.
///  Yang sebenarnya terjadi kalau begitu: dua aplikasi menulis navigasi yang
///  sama, dan salah satunya nanti lupa membungkusnya sehingga menekan loncengnya
///  tidak melakukan apa pun — tanpa galat, karena callback kosong memang sah.
///
///  Tujuannya tidak pernah berbeda: lonceng selalu membuka daftar notifikasi.
///  Jadi ditentukan di sini. Yang MEMANG berbeda per aplikasi — apa yang terjadi
///  saat satu notifikasi ditekan — dialirkan lewat [onOpenAction].
/// ============================================================================
class NotificationIcon extends StatelessWidget {
  const NotificationIcon({
    super.key,
    this.onOpenAction,
    this.color,
    this.tooltip = 'Notifikasi',
  });

  /// Dipanggil saat satu notifikasi ditekan, dengan `action`-nya.
  ///
  /// Bentuk `action` misalnya `{"screen": "order", "order_uuid": "..."}`.
  /// Aplikasi yang menerjemahkannya ke navigasi — paket ini tidak tahu nama
  /// layar di aplikasi mana pun, dan tidak boleh tahu.
  final void Function(BuildContext context, Map<String, dynamic> action)?
  onOpenAction;

  final Color? color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    // `watch`, bukan `read`: lencananya harus berubah sendiri saat notifikasi
    // dibaca di layar lain.
    final int belumDibaca = context.select<NotificationController, int>(
      (NotificationController c) => c.unreadCount,
    );

    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final Color warnaIkon =
        color ??
        (gelap ? ClayTokens.textSecondaryDark : ClayTokens.textSecondary);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => buka(context, onOpenAction: onOpenAction),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
        child: Padding(
          padding: const EdgeInsets.all(ClayTokens.space2),

          child: NotificationBadge(
            child: Icon(
              // Ikonnya BERUBAH BENTUK, bukan hanya bertambah lencana.
              //
              // Lencana kecil di sudut mudah terlewat di layar terang di luar
              // ruangan — dan yang paling sering membaca layar seperti itu adalah
              // driver di jalan.
              belumDibaca > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: warnaIkon,
            ),
          ),
        ),
      ),
    );
  }

  /// Buka layar notifikasi.
  ///
  /// Dipisah sebagai static supaya bisa dipanggil dari tempat lain — misalnya
  /// item menu di sidebar — tanpa harus ada ikon loncengnya di layar.
  static Future<void> buka(
    BuildContext context, {
    void Function(BuildContext context, Map<String, dynamic> action)?
    onOpenAction,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationScreen(onOpenAction: onOpenAction),
      ),
    );
  }
}

/// Menempelkan lencana jumlah belum dibaca ke sudut kanan atas [child].
///
/// ============================================================================
///  DIPISAH DARI IKONNYA SUPAYA BENTUK PEMBUNGKUSNYA BEBAS
/// ============================================================================
///  Ikon lonceng di aplikasi driver duduk di AppBar sebagai ikon biasa. Di
///  beranda penumpang dia duduk di dalam pil `ClaySurface` yang timbul.
///
///  Yang sama di keduanya hanya lencananya. Jadi lencananya yang dijadikan
///  widget, bukan seluruh tombolnya — dan tampilan yang berbeda tidak menuntut
///  angka yang berbeda pula.
/// ============================================================================
class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int belumDibaca = context.select<NotificationController, int>(
      (NotificationController c) => c.unreadCount,
    );

    if (belumDibaca == 0) {
      return child;
    }

    // `clipBehavior: none` supaya lencana yang menonjol keluar dari kotak
    // anaknya tidak terpotong.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned(right: -6, top: -6, child: _Lencana(belumDibaca)),
      ],
    );
  }
}

/// Lencana angka.
///
/// Di atas 99 ditampilkan `99+`. Angka empat digit membuat lencananya melebar
/// sampai menutupi ikonnya sendiri, dan selisih antara 143 dan 1.430 notifikasi
/// belum dibaca tidak mengubah apa pun yang dilakukan pengguna.
class _Lencana extends StatelessWidget {
  const _Lencana(this.jumlah);

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final String teks = jumlah > 99 ? '99+' : '$jumlah';

    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: ClayTokens.danger,
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),

        // Cincin sewarna latar di sekelilingnya. Tanpa ini, lencana merah di
        // atas ikon gelap terlihat menempel jadi satu bentuk yang sulit dibaca.
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        teks,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
