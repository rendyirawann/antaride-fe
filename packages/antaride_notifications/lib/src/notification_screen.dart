import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notification_controller.dart';

/// Daftar notifikasi in-app.
///
/// ============================================================================
///  DIPAKAI APLIKASI PENUMPANG DAN DRIVER, TANPA CABANG DI DALAMNYA
/// ============================================================================
///  Tidak ada `if (isDriver)` di file ini. Dua hal yang berbeda antar aplikasi
///  ditangani di luar:
///
///    Notifikasi siapa      ditentukan `NotificationRepository.role`, yang
///                          disetel sekali saat `AntarideServices` dibuat.
///
///    Tujuan saat ditekan   [onOpenAction], karena nama layar order di aplikasi
///                          penumpang dan driver memang berbeda.
///
///  Cabang di dalam layar akan tumbuh: satu `if` hari ini, dan enam bulan lagi
///  layar ini punya dua tata letak yang tidak pernah diuji bersamaan.
/// ============================================================================
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    this.onOpenAction,
    this.embedded = false,
  });

  /// Dipanggil saat satu notifikasi yang punya `action` ditekan.
  ///
  /// Kalau null, notifikasi tetap ditandai sudah dibaca tapi tidak berpindah ke
  /// mana pun. Itu perilaku yang sah — bukan setiap aplikasi punya layar tujuan
  /// untuk setiap jenis notifikasi.
  final void Function(BuildContext context, Map<String, dynamic> action)?
  onOpenAction;

  /// True kalau layar ini sudah berada di dalam `Scaffold` milik orang lain.
  ///
  /// ==========================================================================
  ///  DUA CARA LAYAR INI DIPAKAI, DAN HANYA SATU YANG PUNYA BILAH ATAS SENDIRI
  /// ==========================================================================
  ///  Di aplikasi penumpang layar ini DIDORONG sebagai route dari ikon lonceng,
  ///  jadi dia butuh `Scaffold` dan `AppBar`-nya sendiri — termasuk tombol
  ///  kembali.
  ///
  ///  Di aplikasi driver dia salah satu HALAMAN di sidebar, dan `ClayDrawerShell`
  ///  sudah menyediakan `Scaffold` beserta bilah atas berisi tombol menu. Tanpa
  ///  penanda ini, halaman notifikasi driver akan punya DUA bilah atas bertumpuk
  ///  — dan yang di bawah membawa judul yang sama dengan yang di atasnya.
  ///
  ///  Saat `embedded`, tombol "Tandai semua" juga tidak digambar di sini.
  ///  Tempatnya berpindah ke `ClayDrawerShell.actions` — lihat
  ///  [NotificationMarkAllAction].
  /// ==========================================================================
  final bool embedded;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();

    // Selalu muat ulang dari awal saat layar dibuka, walaupun controller-nya
    // sudah punya isi dari kunjungan sebelumnya.
    //
    // Alasannya: controller hidup selama aplikasi hidup, jadi isinya bisa
    // berumur berjam-jam. Menampilkan daftar lama lalu menyegarkannya diam-diam
    // membuat notifikasi baru muncul dengan cara menggeser daftar ke bawah tepat
    // saat pengguna hendak menekan sesuatu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationController>().muatUlang();
      }
    });
  }

  Future<IndicatorResult> _muatLagi() async {
    final NotificationController c = context.read<NotificationController>();

    await c.muatLagi();

    if (c.galat != null) {
      return IndicatorResult.fail;
    }

    return c.adaLagi ? IndicatorResult.success : IndicatorResult.noMore;
  }

  void _tekan(AppNotification notifikasi) {
    final NotificationController c = context.read<NotificationController>();

    // Ditandai dibaca lebih dulu, dan TIDAK di-await. Navigasi tidak boleh
    // menunggu request penandaan selesai — lihat penjelasan optimistis di
    // `NotificationController.tandaiDibaca`.
    c.tandaiDibaca(notifikasi.uuid);

    final Map<String, dynamic>? action = notifikasi.action;
    final void Function(BuildContext, Map<String, dynamic>)? buka =
        widget.onOpenAction;

    if (action != null && action.isNotEmpty && buka != null) {
      buka(context, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final NotificationController c = context.watch<NotificationController>();

    if (widget.embedded) {
      return _isi(c);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: const <Widget>[NotificationMarkAllAction()],
      ),
      body: _isi(c),
    );
  }

  Widget _isi(NotificationController c) {
    if (!c.sudahDimuat) {
      return const ClaySkeletonList(itemHeight: 92);
    }

    if (c.kosong && c.galat != null) {
      return ClayErrorState(message: c.galat!.message, onRetry: c.muatUlang);
    }

    if (c.kosong) {
      return const ClayEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Belum ada notifikasi',
        message:
            'Kabar tentang pesanan Anda — driver menerima, driver tiba, '
            'perjalanan selesai — akan muncul di sini.',
      );
    }

    return ClayRefresh(
      onRefresh: c.muatUlang,
      onLoad: _muatLagi,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: ClayTokens.space4,
          vertical: ClayTokens.space3,
        ),
        itemCount: c.items.length,
        itemBuilder: (BuildContext _, int i) {
          final AppNotification n = c.items[i];

          return _Baris(
            notifikasi: n,
            bisaDitekan:
                widget.onOpenAction != null &&
                n.action != null &&
                n.action!.isNotEmpty,
            onTap: () => _tekan(n),
          );
        },
      ),
    );
  }
}

/// Satu baris notifikasi.
class _Baris extends StatelessWidget {
  const _Baris({
    required this.notifikasi,
    required this.bisaDitekan,
    required this.onTap,
  });

  final AppNotification notifikasi;
  final bool bisaDitekan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final bool belumDibaca = !notifikasi.isRead;

    final Color warnaJudul = gelap
        ? ClayTokens.textPrimaryDark
        : ClayTokens.textPrimary;

    final Color warnaIsi = gelap
        ? ClayTokens.textSecondaryDark
        : ClayTokens.textSecondary;

    return ClayCard(
      // Yang belum dibaca TIMBUL, yang sudah dibaca RATA.
      //
      // Pembedanya kedalaman, bukan warna latar. Latar berwarna untuk yang belum
      // dibaca akan bertabrakan dengan tema gelap dan dengan warna merek — dan
      // di claymorphism, kedalaman memang bahasanya.
      depth: belumDibaca ? ClayDepth.low : ClayDepth.flat,
      onTap: bisaDitekan || belumDibaca ? onTap : null,
      margin: const EdgeInsets.only(bottom: ClayTokens.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Ikon(notifikasi.type),

          const SizedBox(width: ClayTokens.space3),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        notifikasi.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: belumDibaca
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: warnaJudul,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    if (belumDibaca) ...<Widget>[
                      const SizedBox(width: ClayTokens.space2),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: ClayTokens.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: ClayTokens.space1),

                Text(
                  notifikasi.body,
                  style: TextStyle(fontSize: 13, color: warnaIsi, height: 1.35),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: ClayTokens.space2),

                Text(
                  notifikasi.relativeTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: gelap
                        ? ClayTokens.textTertiaryDark
                        : ClayTokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ikon berdasarkan jenis notifikasi.
///
/// ============================================================================
///  JENIS YANG TIDAK DIKENALI TETAP TAMPIL
/// ============================================================================
///  Yang dikembalikan untuk jenis asing adalah ikon dan warna bawaan — bukan
///  exception, dan bukan baris yang disembunyikan.
///
///  Itu yang membuat backend bisa menambah jenis notifikasi baru tanpa menunggu
///  semua pengguna memperbarui aplikasinya. Aplikasi versi lama akan menampilkan
///  ikon umum, dan judul serta isinya — yang datang dari backend — tetap terbaca
///  utuh.
/// ============================================================================
class _Ikon extends StatelessWidget {
  const _Ikon(this.type);

  final String type;

  @override
  Widget build(BuildContext context) {
    // Nilainya dicocokkan dengan konstanta di
    // `app/Domain/Support/Models/Notification.php` di backend. Yang belum ada di
    // daftar ini — jenis baru yang ditambahkan backend setelah aplikasi ini
    // dirilis — jatuh ke cabang terakhir, bukan menjadi galat.
    final (IconData ikon, Color warna) = switch (type) {
      // Penumpang
      'order.accepted' => (Icons.check_circle_rounded, ClayTokens.primary),
      'order.driver_arrived' => (Icons.pin_drop_rounded, ClayTokens.info),
      'order.started' => (Icons.navigation_rounded, ClayTokens.info),
      'order.completed' => (Icons.flag_rounded, ClayTokens.success),
      'order.cancelled' => (Icons.cancel_rounded, ClayTokens.danger),
      'order.no_driver' => (Icons.search_off_rounded, ClayTokens.warning),

      // Driver
      'driver.order_assigned' => (Icons.assignment_rounded, ClayTokens.primary),
      'driver.order_cancelled' => (Icons.cancel_rounded, ClayTokens.danger),

      // Dompet dan pengumuman
      'wallet.credited' => (
        Icons.account_balance_wallet_rounded,
        ClayTokens.success,
      ),
      'announcement' => (Icons.campaign_rounded, ClayTokens.warning),

      _ => (Icons.notifications_rounded, ClayTokens.textSecondary),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        // Warna ikonnya sendiri, dilemahkan. Satu sumber warna untuk ikon dan
        // latarnya — jadi menambah jenis baru tidak menuntut dua warna dipilih.
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
      ),
      alignment: Alignment.center,
      child: Icon(ikon, size: 20, color: warna),
    );
  }
}

/// Tombol "Tandai semua" untuk bilah atas.
///
/// ============================================================================
///  WIDGET TERSENDIRI SUPAYA BISA DIPASANG DI BILAH ATAS MILIK ORANG LAIN
/// ============================================================================
///  Di aplikasi penumpang dia duduk di `AppBar` milik `NotificationScreen`. Di
///  aplikasi driver layar notifikasinya `embedded`, dan bilah atasnya milik
///  `ClayDrawerShell` — jadi tombolnya harus bisa dititipkan ke sana.
///
///  Yang dihindari dengan memisahkannya: dua salinan logika "hanya tampil kalau
///  ada yang belum dibaca, tampilkan snackbar kalau gagal" yang akan menyimpang.
/// ============================================================================
class NotificationMarkAllAction extends StatelessWidget {
  const NotificationMarkAllAction({super.key});

  @override
  Widget build(BuildContext context) {
    final int belumDibaca = context.select<NotificationController, int>(
      (NotificationController c) => c.unreadCount,
    );

    // Tombolnya hanya muncul kalau ADA yang belum dibaca. "Tandai semua dibaca"
    // yang selalu terlihat dan tidak melakukan apa pun terbaca sebagai tombol
    // yang rusak.
    if (belumDibaca == 0) {
      return const SizedBox.shrink();
    }

    return TextButton(
      onPressed: () => _tandai(context),
      child: const Text('Tandai semua'),
    );
  }

  static Future<void> _tandai(BuildContext context) async {
    final ScaffoldMessengerState pesan = ScaffoldMessenger.of(context);

    final bool berhasil = await context
        .read<NotificationController>()
        .tandaiSemuaDibaca();

    if (berhasil) {
      return;
    }

    // `pesan` diambil SEBELUM await. Setelah await, context ini bisa sudah tidak
    // terpasang — tombolnya sendiri menghilang begitu jumlahnya jadi nol, dan
    // membaca `ScaffoldMessenger.of(context)` dari widget yang sudah dibuang
    // melempar.
    pesan.showSnackBar(
      const SnackBar(
        content: Text('Gagal menandai. Periksa koneksi lalu coba lagi.'),
      ),
    );
  }
}
