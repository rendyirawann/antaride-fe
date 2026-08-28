import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:antaride_notifications/antaride_notifications.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../documents/driver_documents_screen.dart';
import '../order/active_order_screen.dart';
import '../services/driver_services_screen.dart';
import 'driver_controller.dart';
import 'offer_card.dart';

/// Akar aplikasi driver setelah masuk: sidebar geser dengan tiga halaman.
///
/// ============================================================================
///  CONTROLLER DIBUAT DI SINI, DI ATAS SIDEBAR
/// ============================================================================
///  `DriverController` disediakan di atas [ClayDrawerShell], bukan di dalam
///  masing-masing halaman. Dua hal bergantung pada itu:
///
///    * Sidebar menampilkan status online dan lencana order berjalan. Kalau
///      controller-nya ada di dalam halaman, sidebar tidak bisa melihatnya.
///    * Penarikan berkala — status setiap 20 detik, tawaran setiap 5 detik —
///      terus berjalan saat driver membuka halaman Layanan. Kalau controller-nya
///      dibuat per halaman, timer-nya mati setiap perpindahan dan tawaran yang
///      masuk saat itu tidak terlihat.
/// ============================================================================
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AntarideServices services = context.read<AntarideServices>();

    return ChangeNotifierProvider<DriverController>(
      create: (BuildContext _) =>
          DriverController(driver: services.driver)..start(),
      child: const _Shell(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _halaman = 0;

  Future<void> _keluar() async {
    final DriverController driver = context.read<DriverController>();

    // Driver yang punya order berjalan TIDAK boleh keluar. Order yang
    // ditinggalkan tanpa driver adalah penumpang yang menunggu tanpa akhir, dan
    // di sisi driver partial unique index membuatnya tidak bisa menerima order
    // baru sampai yang ini ditutup.
    if (driver.hasActiveOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selesaikan dulu order yang sedang berjalan.'),
          backgroundColor: ClayTokens.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final bool? yakin = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text(
          'Anda akan otomatis offline dan perlu memasukkan kode OTP lagi untuk '
          'masuk.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: ClayTokens.danger),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (yakin != true || !mounted) {
      return;
    }

    if (driver.isOnline) {
      await driver.goOffline();
    }

    if (!mounted) {
      return;
    }

    await context.read<SessionController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final DriverController driver = context.watch<DriverController>();
    final DriverStatus? status = driver.status;

    final int notifBelumDibaca = context.select<NotificationController, int>(
      (NotificationController c) => c.unreadCount,
    );

    return ClayDrawerShell(
      selectedIndex: _halaman,
      onSelect: (int i) => setState(() => _halaman = i),

      items: <ClayDrawerItem>[
        // Lencana jumlah tawaran menunggu. Ini yang membuat tawaran tetap
        // terlihat saat driver sedang membuka halaman Layanan — tanpa lencana,
        // dia harus kembali ke dasbor untuk mengetahuinya.
        ClayDrawerItem(
          label: 'Dasbor',
          icon: Icons.dashboard_rounded,
          badge: driver.offers.length,
        ),
        ClayDrawerItem(
          label: 'Order Berjalan',
          icon: Icons.navigation_rounded,
          badge: driver.hasActiveOrder ? 1 : 0,
        ),
        const ClayDrawerItem(label: 'Layanan Saya', icon: Icons.tune_rounded),

        /*
         * Notifikasi sebagai HALAMAN di sidebar, bukan ikon lonceng di pojok.
         *
         * Aplikasi ini tidak punya header — seluruh layarnya dipakai isi, karena
         * driver membacanya sambil di jalan. Ikon lonceng 24 piksel di pojok atas
         * adalah target sentuh yang salah untuk orang yang sedang memakai helm
         * dan sarung tangan.
         *
         * Baris sidebar lebarnya penuh dan tingginya sama dengan tiga baris
         * lain — dan lencananya memakai mekanisme yang sudah dipakai untuk
         * tawaran dan order berjalan.
         */
        ClayDrawerItem(
          label: 'Notifikasi',
          icon: Icons.notifications_rounded,
          badge: notifBelumDibaca,
        ),

        /*
         * Dokumen SELALU ada di sidebar, bukan hanya saat belum lengkap.
         *
         * Yang menggoda: sembunyikan begitu semuanya disetujui, karena driver
         * yang sudah lolos tidak perlu membukanya lagi.
         *
         * Yang terjadi kalau begitu: SIM yang habis masa berlakunya membuat
         * driver ditolak online, dan halaman untuk memperbaruinya sudah hilang
         * dari menunya. Dia tidak punya cara menemukannya lagi.
         */
        const ClayDrawerItem(label: 'Dokumen Saya', icon: Icons.badge_rounded),
      ],

      title: status?.name.isNotEmpty == true ? status!.name : 'Driver Antaride',
      subtitle: status == null
          ? null
          : (status.isOnline ? 'Sedang bekerja' : 'Sedang offline'),
      avatarLabel: _inisial(status?.name),

      footerLabel: 'Keluar',
      onFooterTap: _keluar,

      // Tombol "Tandai semua" dititipkan ke bilah atas sidebar, dan HANYA saat
      // halaman notifikasi yang terbuka. Bilah atasnya satu untuk semua halaman
      // — tombol yang selalu ada di sana akan muncul juga di dasbor, tempat dia
      // tidak berarti apa-apa.
      actions: _halaman == 3
          ? const <Widget>[NotificationMarkAllAction()]
          : const <Widget>[],

      pageBuilder: (BuildContext context, int index) => switch (index) {
        1 => const ActiveOrderScreen(embedded: true),
        2 => const DriverServicesScreen(),

        // Notifikasi yang menunjuk ke sebuah order MEMINDAHKAN halaman ke
        // "Order Berjalan", bukan mendorong route baru.
        //
        // Alasannya: aplikasi driver hanya pernah punya SATU order berjalan —
        // itu invariant yang ditegakkan database lewat
        // `orders_one_active_per_driver`. Jadi tidak ada layar order per-uuid
        // yang bisa dituju; yang ada satu halaman yang selalu menampilkan order
        // yang sedang dikerjakan.
        //
        // Mendorong route baru di atas sidebar juga akan menyembunyikan
        // sakelar online dan tawaran masuk di belakang layar yang harus ditutup
        // dulu.
        4 => const DriverDocumentsScreen(embedded: true),

        3 => NotificationScreen(
          // `embedded`: bilah atasnya sudah disediakan `ClayDrawerShell`.
          // Tanpa ini halamannya punya dua bilah atas bertumpuk.
          embedded: true,
          onOpenAction: (BuildContext _, Map<String, dynamic> action) {
            if (action['screen'] == 'order') {
              setState(() => _halaman = 1);
            }
          },
        ),

        // Dasbor TIDAK dibungkus IndexedStack seperti di aplikasi penumpang.
        //
        // Isinya seluruhnya berasal dari `DriverController`, yang hidup di atas
        // sidebar dan tidak ikut dibuang saat halaman berganti. Tidak ada state
        // lokal yang perlu dijaga — jadi membangunnya ulang tidak kehilangan apa
        // pun, dan tiga halaman yang tetap di memori tidak membeli apa-apa.
        _ => const DriverDashboardPage(),
      },
    );
  }

  static String _inisial(String? nama) {
    if (nama == null || nama.trim().isEmpty) {
      return 'D';
    }

    final List<String> bagian = nama
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();

    if (bagian.length == 1) {
      return bagian.first.substring(0, 1).toUpperCase();
    }

    return (bagian.first.substring(0, 1) + bagian.last.substring(0, 1))
        .toUpperCase();
  }
}

/// Dasbor: sakelar kerja, ringkasan hari ini, dan tawaran masuk.
class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  Timer? _detik;

  @override
  void initState() {
    super.initState();

    // Menggerakkan hitungan mundur tawaran. Tanpanya, sisa waktu di kartu
    // tawaran membeku di angka saat kartunya digambar — dan driver menekan
    // terima pada tawaran yang menurut layarnya masih punya 12 detik.
    _detik = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _detik?.cancel();
    super.dispose();
  }

  Future<void> _tanganiOnline(DriverController driver) async {
    if (driver.isOnline) {
      final DriverSessionSummary? sesi = await driver.goOffline();

      if (!mounted) {
        return;
      }

      if (sesi != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selesai bekerja — ${_durasi(sesi.online)}, '
              '${sesi.ordersCompleted} order.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return;
    }

    final bool berhasil = await driver.goOnline();

    if (!mounted || berhasil) {
      return;
    }

    final String? lokasi = driver.locationMessage;

    // Masalah lokasi ditampilkan sebagai dialog dengan jalan keluar, bukan
    // snackbar. Snackbar hilang sendiri, dan pesan yang menuntut membuka
    // pengaturan sistem harus punya tombol yang membawa ke sana.
    if (lokasi != null) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialog) => AlertDialog(
          title: const Text('Lokasi belum siap'),
          content: Text(lokasi),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('Nanti'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialog).pop();
                const LocationService().openSettings();
              },
              child: const Text('Buka pengaturan'),
            ),
          ],
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(driver.failure?.message ?? 'Tidak bisa mulai bekerja.'),
        backgroundColor: ClayTokens.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _terima(DriverController driver, String uuid) async {
    final bool berhasil = await driver.accept(uuid);

    if (!mounted) {
      return;
    }

    if (!berhasil) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // Pesan dari backend dipakai apa adanya. Untuk 409 dia sudah
            // berbunyi "order sudah diambil driver lain" — dan mengganti itu
            // dengan teks generik membuang informasi yang paling berguna.
            driver.failure?.message ?? 'Order sudah diambil driver lain.',
          ),
          backgroundColor: ClayTokens.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    await _bukaOrder(driver);
  }

  Future<void> _bukaOrder(DriverController driver) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) =>
            ChangeNotifierProvider<DriverController>.value(
              value: driver,
              child: const ActiveOrderScreen(),
            ),
      ),
    );

    if (mounted) {
      await driver.refresh();
    }
  }

  static String _durasi(Duration d) {
    final int jam = d.inHours;
    final int menit = d.inMinutes % 60;

    return jam > 0 ? '$jam jam $menit menit' : '$menit menit';
  }

  @override
  Widget build(BuildContext context) {
    final DriverController driver = context.watch<DriverController>();
    final DriverStatus? status = driver.status;

    if (driver.isLoading) {
      return const Scaffold(body: ClayLoader(message: 'Memuat status kerja…'));
    }

    if (status == null) {
      return Scaffold(
        body: ClayErrorState(
          message:
              driver.failure?.message ??
              'Status driver tidak bisa dimuat. Pastikan akun ini memang akun '
                  'driver.',
          onRetry: driver.refresh,
        ),
      );
    }

    return Scaffold(
      body: ClayRefresh(
        onRefresh: () async {
          await driver.refresh();
          await driver.refreshOffers();
        },
        child: ListView(
          padding: const EdgeInsets.all(ClayTokens.space5),
          children: <Widget>[
            _SakelarOnline(
              status: status,
              busy: driver.isBusy,
              onTekan: () => _tanganiOnline(driver),
            ),

            const SizedBox(height: ClayTokens.space5),

            /*
             * Peringatan posisi tidak terkirim.
             *
             * Ditaruh PALING ATAS setelah sakelar kerja, di atas peringatan
             * saldo: driver yang posisinya tidak terkirim tidak akan mendapat
             * order sama sekali, sementara saldo yang kurang hanya menghalangi
             * order tunai.
             */
            if (driver.locationWarning != null) ...<Widget>[
              _PeringatanLokasi(pesan: driver.locationWarning!),
              const SizedBox(height: ClayTokens.space5),
            ],

            /*
             * ==============================================================
             *  "HANYA SELAMA APLIKASI TERBUKA" — PERINGATAN YANG BERBEDA
             * ==============================================================
             *  Bukan pengulangan peringatan di atas, dan tindakan yang
             *  diperlukan berbeda:
             *
             *    Peringatan di atas    ping GAGAL. Bisa pulih sendiri saat
             *                          sinyal kembali; tidak ada yang perlu
             *                          driver lakukan selain menunggu.
             *
             *    Peringatan ini        ping bahkan tidak akan DICOBA setelah
             *                          layarnya mati. Yang menyelesaikannya
             *                          memberi izin notifikasi — dan menunggu
             *                          tidak akan pernah menyelesaikannya.
             *
             *  Kalau ini tidak ditampilkan, driver akan mengunci HP-nya dan
             *  menunggu order yang tidak akan pernah datang. Aplikasinya tetap
             *  menyatakan dia online sepanjang waktu itu.
             *
             *  Warnanya PERINGATAN, bukan bahaya: posisinya memang masih
             *  terkirim, hanya selama dia menatap layar. Merah untuk keadaan
             *  yang masih setengah bekerja membuat merah berhenti berarti apa
             *  pun.
             * ==============================================================
             */
            if (driver.onlyPingsWhileOpen) ...<Widget>[
              const _PeringatanHanyaSaatTerbuka(),
              const SizedBox(height: ClayTokens.space5),
            ],

            if (!status.canTakeCashOrders) ...<Widget>[
              _PeringatanSaldo(status: status),
              const SizedBox(height: ClayTokens.space5),
            ],

            _RingkasanHariIni(status: status),

            const SizedBox(height: ClayTokens.space5),

            if (driver.hasActiveOrder) ...<Widget>[
              _PitaOrderBerjalan(
                order: driver.activeOrder!,
                onTap: () => _bukaOrder(driver),
              ),
              const SizedBox(height: ClayTokens.space5),
            ],

            if (driver.canTakeOffers) ...<Widget>[
              Row(
                children: <Widget>[
                  const Text(
                    'Tawaran masuk',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (driver.offers.isNotEmpty)
                    Text(
                      '${driver.offers.length} menunggu',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.primary,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: ClayTokens.space3),

              if (driver.offers.isEmpty)
                ClaySurface(
                  depth: ClayDepth.pressed,
                  padding: const EdgeInsets.all(ClayTokens.space6),
                  child: Column(
                    children: <Widget>[
                      // Radar berdenyut selagi menunggu tawaran. Layar yang
                      // benar-benar diam selama menunggu tidak bisa dibedakan
                      // dari aplikasi yang berhenti bekerja.
                      if (status.isOnline)
                        const ClayLoader(size: 30)
                      else
                        const Icon(
                          Icons.radar_rounded,
                          size: 28,
                          color: ClayTokens.textTertiary,
                        ),
                      const SizedBox(height: ClayTokens.space3),
                      Text(
                        status.isOnline
                            ? 'Belum ada tawaran. Tetap di area ramai untuk '
                                  'peluang lebih besar.'
                            : 'Anda sedang offline. Nyalakan untuk mulai '
                                  'menerima tawaran.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          height: 1.5,
                          color: ClayTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final DriverOffer tawaran in driver.offers)
                  OfferCard(
                    offer: tawaran,
                    busy: driver.isBusy,
                    onTerima: () => _terima(driver, tawaran.orderUuid),
                    onTolak: () => driver.reject(tawaran.orderUuid),
                  ),
            ],

            const SizedBox(height: ClayTokens.space8),
          ],
        ),
      ),
    );
  }
}

/// Sakelar online/offline — elemen terpenting di aplikasi driver.
class _SakelarOnline extends StatelessWidget {
  const _SakelarOnline({
    required this.status,
    required this.busy,
    required this.onTekan,
  });

  final DriverStatus status;
  final bool busy;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    final bool online = status.isOnline;

    return ClaySurface(
      // Timbul saat offline, TENGGELAM saat online. Isyarat clay untuk "sedang
      // aktif" — dan bedanya bisa dibaca dari sudut mata, tanpa membaca teks.
      depth: online ? ClayDepth.pressed : ClayDepth.high,
      radius: ClayTokens.radiusLarge,
      padding: const EdgeInsets.all(ClayTokens.space5),
      borderColor: online ? ClayTokens.primary : null,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: online ? ClayTokens.success : ClayTokens.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: ClayTokens.space3),
              Text(
                online ? 'Sedang bekerja' : 'Sedang offline',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: online ? ClayTokens.success : null,
                ),
              ),
              const Spacer(),
              if (online && status.sessionDuration != null)
                Text(
                  _jamMenit(status.sessionDuration!),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.textSecondary,
                  ),
                ),
            ],
          ),

          const SizedBox(height: ClayTokens.space4),

          ClayButton(
            label: online ? 'Berhenti bekerja' : 'Mulai bekerja',
            icon: online ? Icons.pause_rounded : Icons.play_arrow_rounded,
            variant: online
                ? ClayButtonVariant.secondary
                : ClayButtonVariant.primary,
            isLoading: busy,

            // Tombol paling besar di seluruh aplikasi. Ini yang ditekan paling
            // sering, dan ditekan sambil memegang helm.
            height: ClayTokens.driverPrimaryButtonHeight,
            onPressed: busy ? null : onTekan,
          ),
        ],
      ),
    );
  }

  static String _jamMenit(Duration d) {
    final String jam = d.inHours.toString().padLeft(2, '0');
    final String menit = (d.inMinutes % 60).toString().padLeft(2, '0');

    return '$jam:$menit';
  }
}

/// Peringatan saldo di bawah minimum untuk order tunai.
class _PeringatanSaldo extends StatelessWidget {
  const _PeringatanSaldo({required this.status});

  final DriverStatus status;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.low,
      borderColor: ClayTokens.warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: ClayTokens.warning,
          ),
          const SizedBox(width: ClayTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Order tunai belum bisa diambil',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.warning,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  /*
                   * Menjelaskan SEBABNYA, bukan hanya menyatakan aturannya.
                   *
                   * Pada order tunai, driver menerima uang penuh dari penumpang
                   * dan komisi dipotong dari saldonya. Saldo nol berarti komisi
                   * tidak bisa ditagih.
                   *
                   * Driver yang tidak tahu alasannya akan menyimpulkan
                   * sistemnya menahan pendapatannya — dan itu keluhan yang jauh
                   * lebih sulit dijawab daripada satu kalimat di sini.
                   */
                  'Saldo Anda ${status.balance.formatted}. Komisi order tunai '
                  'dipotong dari saldo, jadi minimum '
                  'Rp ${_ribuan(status.cashDepositMinimum)} harus tersedia. '
                  'Order non-tunai tetap bisa diambil.',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    height: 1.5,
                    color: ClayTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _ribuan(int nilai) {
    final String digit = nilai.abs().toString();
    final StringBuffer hasil = StringBuffer();

    for (int i = 0; i < digit.length; i++) {
      if (i > 0 && (digit.length - i) % 3 == 0) {
        hasil.write('.');
      }

      hasil.write(digit[i]);
    }

    return hasil.toString();
  }
}

class _RingkasanHariIni extends StatelessWidget {
  const _RingkasanHariIni({required this.status});

  final DriverStatus status;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.low,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _Angka(
                  label: 'Pendapatan hari ini',
                  nilai: status.todayEarning.formatted,
                  besar: true,
                ),
              ),
              Expanded(
                child: _Angka(
                  label: 'Order selesai',
                  nilai: '${status.todayOrders}',
                ),
              ),
            ],
          ),

          const Divider(height: ClayTokens.space6),

          Row(
            children: <Widget>[
              Expanded(
                child: _Angka(label: 'Saldo', nilai: status.balance.formatted),
              ),
              Expanded(
                child: _Angka(
                  label: 'Rating',
                  nilai: '${status.ratingAverage.toStringAsFixed(1)} ★',
                ),
              ),
              Expanded(
                child: _Angka(
                  // Rasio penerimaan DITAMPILKAN, karena ikut menentukan
                  // prioritas driver di mesin pencocokan. Driver yang tidak tahu
                  // angkanya tidak punya cara memperbaikinya — dan akan
                  // menyimpulkan order dibagikan secara sembarang.
                  label: 'Penerimaan',
                  nilai: '${(status.acceptanceRate * 100).round()}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka({required this.label, required this.nilai, this.besar = false});

  final String label;
  final String nilai;
  final bool besar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: ClayTokens.textTertiary,
          ),
        ),
        const SizedBox(height: 3),
        ClayMoney(
          formatted: nilai,
          size: besar ? ClayMoneySize.large : ClayMoneySize.small,
        ),
      ],
    );
  }
}

class _PitaOrderBerjalan extends StatelessWidget {
  const _PitaOrderBerjalan({required this.order, required this.onTap});

  final DriverOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.medium,
      borderColor: ClayTokens.primary,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.navigation_rounded,
            color: ClayTokens.primary,
            size: 24,
          ),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClayStatusBadge(
                  status: order.status,
                  label: order.statusLabel,
                  compact: true,
                ),
                const SizedBox(height: ClayTokens.space2),
                Text(
                  order.pickup.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: ClayTokens.primary),
        ],
      ),
    );
  }
}

/// Peringatan bahwa posisi driver tidak terkirim ke layanan lokasi.
/// Pemberitahuan bahwa posisi hanya terkirim selama aplikasi terlihat.
///
/// Muncul kalau foreground service tidak berjalan — izin notifikasi ditolak,
/// atau platformnya tidak mendukungnya (web, iOS).
class _PeringatanHanyaSaatTerbuka extends StatelessWidget {
  const _PeringatanHanyaSaatTerbuka();

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.low,
      borderColor: ClayTokens.warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.phonelink_ring_rounded,
            size: 20,
            color: ClayTokens.warning,
          ),
          const SizedBox(width: ClayTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Jangan tutup aplikasi ini',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.warning,
                  ),
                ),
                const SizedBox(height: 3),

                // Kalimatnya menyebut AKIBATNYA, bukan penyebab teknisnya.
                // "Foreground service tidak aktif" tidak memberi tahu driver apa
                // yang harus dia lakukan; "Anda berhenti mendapat order" iya.
                const Text(
                  'Posisi Anda hanya terkirim selama layar menyala dan '
                  'aplikasi ini terbuka. Kalau Anda menguncinya, Anda '
                  'berhenti mendapat order.\n\n'
                  'Izinkan notifikasi Antaride Driver di pengaturan HP agar '
                  'posisi tetap terkirim dengan layar mati.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    height: 1.5,
                    color: ClayTokens.textSecondary,
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

class _PeringatanLokasi extends StatelessWidget {
  const _PeringatanLokasi({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.low,
      borderColor: ClayTokens.danger,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.location_disabled_rounded,
            size: 20,
            color: ClayTokens.danger,
          ),
          const SizedBox(width: ClayTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Posisi tidak terkirim',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.danger,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pesan,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    height: 1.5,
                    color: ClayTokens.textSecondary,
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
