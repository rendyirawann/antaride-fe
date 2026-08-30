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

/// Aksen aplikasi driver — dipakai untuk SEMUA gradien di layar ini.
///
/// Diberi nama sendiri, bukan dipanggil `ClayTokens.primaryDark` di tempat
/// pemakaian: di berkas yang penuh cabang `gelap ? xDark : x`, nama
/// "primaryDark" terbaca sebagai "hijau untuk mode gelap" — padahal ini warna
/// merek aplikasi driver di KEDUA mode.
const Color _aksen = ClayTokens.primaryDark;

/// Aksen saat driver offline: batu tulis netral, bukan abu-abu pucat.
///
/// ============================================================================
///  SELURUH BIDANG YANG BERGANTI WARNA, BUKAN TITIK 10 PIKSEL
/// ============================================================================
///  Online/offline adalah satu-satunya keadaan yang salah membacanya berakibat
///  langsung: driver yang mengira dirinya online akan menunggu order yang tidak
///  akan pernah datang. Versi lama menyampaikannya lewat titik 10 px dan warna
///  teks — dua isyarat yang menuntut layar ditatap dari dekat.
///
///  Di sini yang berganti adalah SELURUH bidang puncak layar: hijau merek saat
///  bekerja, batu tulis saat tidak. Terbaca dari jarak lengan, di bawah
///  matahari, tanpa membaca satu kata pun.
///
///  Tetap satu warna yang di-lerp ke hitam oleh `ClayGradients.hero`, jadi
///  aturan gradien desain v2 tidak dilanggar — yang berubah hanya warna yang
///  masuk.
/// ============================================================================
const Color _aksenIstirahat = Color(0xFF404A5C);

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

      /*
       * Dasbor menggambar kepala halamannya SENDIRI.
       *
       * Halaman 0 memasang hero gradien yang menembus status bar — dan bilah
       * atas bawaan shell menghalanginya dua kali: dia mengambil status bar,
       * lalu menaruh bilah datar di atas hero. Mendaftarkannya di sini yang
       * membuat gradien status kerja jadi hal pertama yang terlihat saat
       * aplikasi dibuka.
       *
       * Konsekuensinya: hamburger jadi tanggung jawab dasbor, diambil lewat
       * `ClayDrawerScope`. Halaman lain tetap memakai bilah atas shell.
       */
      fullBleedPages: const <int>{0},

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

    /*
     * Keadaan memuat dan galat PUN memakai hero, dan itu bukan hiasan.
     *
     * Dasbor terdaftar di `fullBleedPages`, jadi tidak ada bilah atas shell di
     * layar ini. Scaffold telanjang di dua keadaan itu berarti tidak ada
     * hamburger sama sekali — driver yang statusnya gagal dimuat terkurung di
     * layar galat, tanpa jalan ke Dokumen Saya maupun Keluar.
     */
    if (driver.isLoading) {
      return const _KerangkaDasbor(
        subtitle: 'Menyiapkan status kerja Anda…',
        isi: ClayLoader(message: 'Memuat status kerja…'),
      );
    }

    if (status == null) {
      return _KerangkaDasbor(
        subtitle: 'Status kerja belum bisa ditampilkan.',
        isi: ClayErrorState(
          message:
              driver.failure?.message ??
              'Status driver tidak bisa dimuat. Pastikan akun ini memang akun '
                  'driver.',
          onRetry: driver.refresh,
        ),
      );
    }

    return Scaffold(
      /*
       * TANPA SafeArea di atas, dan itu wajib.
       *
       * Hero gradien adalah kepala halaman ini dan harus MENEMBUS status bar.
       * SafeArea akan menyisakan pita warna latar di atas gradien, yang
       * terbaca sebagai layar yang belum selesai dimuat.
       */
      body: ClayRefresh(
        onRefresh: () async {
          await driver.refresh();
          await driver.refreshOffers();
        },

        // Padding horizontal dipasang per bagian, BUKAN di ListView: hero harus
        // menyentuh kedua tepi layar.
        child: ListView(
          padding: const EdgeInsets.only(bottom: ClayTokens.space8),
          children: <Widget>[
            /*
             * ==============================================================
             *  KUNCI PADA SETIAP ClayEntrance, DAN KENAPA WAJIB DI LAYAR INI
             * ==============================================================
             *  Dasbor dibangun ulang SETIAP DETIK oleh `_detik`, dan daftar
             *  anaknya berubah panjang tiap kali peringatan muncul atau
             *  hilang. Tanpa kunci, Flutter mencocokkan elemen berdasarkan
             *  posisi: satu peringatan yang muncul menggeser semua yang di
             *  bawahnya, dan bagian paling bawah dibangun sebagai elemen BARU
             *  lalu memutar animasi masuknya lagi di tengah sesi.
             *
             *  Dengan kunci tetap, tiap bagian membawa State-nya sendiri —
             *  yang sudah muncul tetap diam, dan hanya bagian yang benar-benar
             *  baru yang beranimasi.
             * ==============================================================
             */
            ClayEntrance(
              key: const ValueKey<String>('hero'),
              index: 0,
              child: _HeroKerja(
                status: status,
                busy: driver.isBusy,
                onTekan: () => _tanganiOnline(driver),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                ClayTokens.space5,
                ClayTokens.space5,
                ClayTokens.space5,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  /*
                   * Peringatan posisi tidak terkirim.
                   *
                   * Ditaruh PALING ATAS setelah sakelar kerja, di atas
                   * peringatan saldo: driver yang posisinya tidak terkirim
                   * tidak akan mendapat order sama sekali, sementara saldo yang
                   * kurang hanya menghalangi order tunai.
                   */
                  if (driver.locationWarning != null) ...<Widget>[
                    ClayEntrance(
                      key: const ValueKey<String>('lokasi'),
                      index: 1,
                      child: _Peringatan(
                        ikon: Icons.location_disabled_rounded,
                        warna: ClayTokens.danger,
                        judul: 'Posisi tidak terkirim',
                        isi: driver.locationWarning!,
                      ),
                    ),
                    const SizedBox(height: ClayTokens.space4),
                  ],

                  /*
                   * ==========================================================
                   *  "HANYA SELAMA APLIKASI TERBUKA" — PERINGATAN YANG BERBEDA
                   * ==========================================================
                   *  Bukan pengulangan peringatan di atas, dan tindakan yang
                   *  diperlukan berbeda:
                   *
                   *    Peringatan di atas    ping GAGAL. Bisa pulih sendiri
                   *                          saat sinyal kembali; tidak ada
                   *                          yang perlu driver lakukan selain
                   *                          menunggu.
                   *
                   *    Peringatan ini        ping bahkan tidak akan DICOBA
                   *                          setelah layarnya mati. Yang
                   *                          menyelesaikannya memberi izin
                   *                          notifikasi — dan menunggu tidak
                   *                          akan pernah menyelesaikannya.
                   *
                   *  Kalau ini tidak ditampilkan, driver akan mengunci HP-nya
                   *  dan menunggu order yang tidak akan pernah datang.
                   *  Aplikasinya tetap menyatakan dia online sepanjang waktu
                   *  itu.
                   *
                   *  Warnanya PERINGATAN, bukan bahaya: posisinya memang masih
                   *  terkirim, hanya selama dia menatap layar. Merah untuk
                   *  keadaan yang masih setengah bekerja membuat merah berhenti
                   *  berarti apa pun.
                   * ==========================================================
                   */
                  if (driver.onlyPingsWhileOpen) ...<Widget>[
                    const ClayEntrance(
                      key: ValueKey<String>('hanya-terbuka'),
                      index: 1,
                      child: _Peringatan(
                        ikon: Icons.phonelink_ring_rounded,
                        warna: ClayTokens.warning,
                        judul: 'Jangan tutup aplikasi ini',

                        // Kalimatnya menyebut AKIBATNYA, bukan penyebab
                        // teknisnya. "Foreground service tidak aktif" tidak
                        // memberi tahu driver apa yang harus dia lakukan;
                        // "Anda berhenti mendapat order" iya.
                        isi:
                            'Posisi Anda hanya terkirim selama layar menyala '
                            'dan aplikasi ini terbuka. Kalau Anda menguncinya, '
                            'Anda berhenti mendapat order.\n\n'
                            'Izinkan notifikasi Antaride Driver di pengaturan '
                            'HP agar posisi tetap terkirim dengan layar mati.',
                      ),
                    ),
                    const SizedBox(height: ClayTokens.space4),
                  ],

                  if (!status.canTakeCashOrders) ...<Widget>[
                    ClayEntrance(
                      key: const ValueKey<String>('saldo'),
                      index: 1,
                      child: _Peringatan(
                        ikon: Icons.account_balance_wallet_rounded,
                        warna: ClayTokens.warning,
                        judul: 'Order tunai belum bisa diambil',

                        /*
                         * Menjelaskan SEBABNYA, bukan hanya menyatakan
                         * aturannya.
                         *
                         * Pada order tunai, driver menerima uang penuh dari
                         * penumpang dan komisi dipotong dari saldonya. Saldo
                         * nol berarti komisi tidak bisa ditagih.
                         *
                         * Driver yang tidak tahu alasannya akan menyimpulkan
                         * sistemnya menahan pendapatannya — dan itu keluhan
                         * yang jauh lebih sulit dijawab daripada satu kalimat
                         * di sini.
                         */
                        isi:
                            'Saldo Anda ${status.balance.formatted}. Komisi '
                            'order tunai dipotong dari saldo, jadi minimum '
                            'Rp ${_ribuan(status.cashDepositMinimum)} harus '
                            'tersedia. Order non-tunai tetap bisa diambil.',
                      ),
                    ),
                    const SizedBox(height: ClayTokens.space4),
                  ],

                  ClayEntrance(
                    key: const ValueKey<String>('ringkasan'),
                    index: 2,
                    child: _RingkasanHariIni(status: status),
                  ),

                  const SizedBox(height: ClayTokens.space5),

                  if (driver.hasActiveOrder) ...<Widget>[
                    ClayEntrance(
                      key: const ValueKey<String>('order-berjalan'),
                      index: 3,
                      child: _PitaOrderBerjalan(
                        order: driver.activeOrder!,
                        onTap: () => _bukaOrder(driver),
                      ),
                    ),
                    const SizedBox(height: ClayTokens.space5),
                  ],

                  if (driver.canTakeOffers) ...<Widget>[
                    ClayEntrance(
                      key: const ValueKey<String>('judul-tawaran'),
                      index: 4,
                      child: Row(
                        children: <Widget>[
                          const ClaySectionLabel('Tawaran masuk'),
                          const Spacer(),
                          if (driver.offers.isNotEmpty)
                            _PilHitung(jumlah: driver.offers.length),
                        ],
                      ),
                    ),

                    const SizedBox(height: ClayTokens.space3),

                    if (driver.offers.isEmpty)
                      ClayEntrance(
                        key: const ValueKey<String>('tawaran-kosong'),
                        index: 5,
                        child: _MenungguTawaran(online: status.isOnline),
                      )
                    else
                      /*
                       * ======================================================
                       *  KARTU TAWARAN SENGAJA TANPA ANIMASI MASUK
                       * ======================================================
                       *  `OfferCard` stateless dan digerakkan rebuild `_detik`
                       *  setiap satu detik. Animasi masuk apa pun di sini —
                       *  ClayEntrance, scale, fade — berisiko berkedip tiap
                       *  detik begitu daftar tawarannya berubah panjang dan
                       *  elemennya bergeser posisi.
                       *
                       *  Kartu yang berkedip di bawah jempol yang sedang
                       *  bergerak ke tombol "Terima" jauh lebih mahal daripada
                       *  animasi masuk yang tidak ada. Yang menarik perhatian
                       *  ke tawaran baru adalah bidang gradien di kepala
                       *  kartunya, bukan gerakan.
                       * ======================================================
                       */
                      for (final DriverOffer tawaran in driver.offers)
                        OfferCard(
                          offer: tawaran,
                          busy: driver.isBusy,
                          onTerima: () => _terima(driver, tawaran.orderUuid),
                          onTolak: () => driver.reject(tawaran.orderUuid),
                        ),
                  ],
                ],
              ),
            ),
          ],
        ),
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

/// Kerangka dasbor untuk keadaan memuat dan galat.
///
/// Hero compact-nya membawa satu hal yang tidak boleh hilang: hamburger —
/// lihat alasannya di tempat pemakaian.
class _KerangkaDasbor extends StatelessWidget {
  const _KerangkaDasbor({required this.subtitle, required this.isi});

  final String subtitle;
  final Widget isi;

  @override
  Widget build(BuildContext context) {
    return ClayHeroScaffold(
      header: ClayHeroHeader(
        accent: _aksen,
        compact: true,
        title: 'Dasbor',
        subtitle: subtitle,
        leading: ClayGlassButton(
          icon: Icons.menu_rounded,
          semanticLabel: 'Menu',
          onPressed: ClayDrawerScope.of(context)?.toggle,
        ),
      ),
      body: isi,
    );
  }
}

/// Kepala dasbor: bidang gradien status kerja dengan sakelar besar di dalamnya.
///
/// ============================================================================
///  SAKELAR ADA DI DALAM HERO, BUKAN DI KARTU DI BAWAHNYA
/// ============================================================================
///  Warna hero MENYATAKAN status, dan tombol di dalamnya MENGUBAH status itu.
///  Menaruh keduanya dalam satu bidang membuat hubungan sebab-akibatnya
///  terbaca tanpa dijelaskan: yang ditekan mengubah warna yang mengelilinginya.
///
///  Kartu terpisah di bawah hero akan mengulang informasi yang sudah dinyatakan
///  warna hero — dan pengulangan itu memakan tinggi layar yang di aplikasi ini
///  milik tawaran masuk.
/// ============================================================================
class _HeroKerja extends StatelessWidget {
  const _HeroKerja({
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
    final Duration? sesi = status.sessionDuration;

    return ClayHeroHeader(
      accent: online ? _aksen : _aksenIstirahat,
      title: online ? 'Sedang bekerja' : 'Sedang offline',
      subtitle: online
          ? 'Tawaran dikirim ke posisi Anda selama sakelar ini menyala.'
          : 'Nyalakan sakelar di bawah untuk mulai menerima tawaran.',

      // Hamburger. `ClayDrawerScope` boleh null — dasbor bisa dipasang
      // sendirian di test widget, dan tombol yang tidak melakukan apa-apa di
      // sana lebih baik daripada test yang tidak bisa memasang layarnya.
      leading: ClayGlassButton(
        icon: Icons.menu_rounded,
        semanticLabel: 'Menu',
        onPressed: ClayDrawerScope.of(context)?.toggle,
      ),

      // Lama sesi hanya berarti selama sesinya berjalan. Pil "00:00" di layar
      // offline adalah angka yang menuntut ditafsirkan tanpa memberi apa-apa.
      trailing: online && sesi != null
          ? _PilKaca(ikon: Icons.timer_outlined, teks: _jamMenit(sesi))
          : null,

      bottom: _SakelarKerja(online: online, busy: busy, onTekan: onTekan),
    );
  }

  static String _jamMenit(Duration d) {
    final String jam = d.inHours.toString().padLeft(2, '0');
    final String menit = (d.inMinutes % 60).toString().padLeft(2, '0');

    return '$jam:$menit';
  }
}

/// Sakelar online/offline — elemen terpenting di seluruh aplikasi driver.
///
/// ============================================================================
///  KENAPA BUKAN ClayButton
/// ============================================================================
///  Semua varian `ClayButton` dirancang untuk latar clay yang pucat: `primary`
///  hijau pejal hilang di atas gradien hijau, `secondary` memakai warna
///  permukaan yang di mode gelap justru lebih gelap daripada heronya, dan
///  `ghost` transparan. Tombol ini duduk DI ATAS gradien — persoalan yang sama
///  yang melahirkan `ClayGlassButton`, hanya dalam bentuk slab selebar layar
///  yang belum ada di paket bersama.
///
///  Karena itu bentuknya lokal di berkas ini, dengan aturan yang sama seperti
///  ClayGlassButton: warnanya putih-alpha, jadi ikut aksen apa pun dan tidak
///  punya satu pun cabang mode gelap.
///
///  Tingginya tetap [ClayTokens.driverPrimaryButtonHeight] — target sentuh
///  untuk tangan bersarung tangan, dan itu keputusan produk, bukan gaya.
/// ============================================================================
class _SakelarKerja extends StatelessWidget {
  const _SakelarKerja({
    required this.online,
    required this.busy,
    required this.onTekan,
  });

  final bool online;
  final bool busy;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    /*
     * Putih PEJAL saat offline, kaca buram saat online — dan itu terbalik dari
     * dugaan pertama.
     *
     * Saat offline, "Mulai bekerja" adalah satu-satunya hal yang perlu
     * dilakukan di layar ini: slab putih di atas bidang batu tulis jadi benda
     * paling terang di layar. Saat online, pekerjaannya sudah berjalan dan
     * tombol itu MENGHENTIKAN sesi — bobot visualnya sengaja diturunkan jadi
     * kaca, supaya jempol tidak menemukannya secara tidak sengaja.
     */
    final Color latar = online
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white;

    final Color teks = online ? Colors.white : _aksen;

    final BorderRadius bentuk = BorderRadius.circular(ClayTokens.radiusMedium);

    return Semantics(
      button: true,
      label: online ? 'Berhenti bekerja' : 'Mulai bekerja',
      child: Material(
        color: Colors.transparent,
        borderRadius: bentuk,
        child: InkWell(
          onTap: busy ? null : onTekan,
          borderRadius: bentuk,

          // Riak diturunkan dari warna teksnya: riak gelap bawaan Material di
          // atas gradien aksen terlihat seperti noda.
          splashColor: teks.withValues(alpha: 0.12),
          highlightColor: teks.withValues(alpha: 0.06),

          child: Ink(
            height: ClayTokens.driverPrimaryButtonHeight,
            decoration: BoxDecoration(
              color: latar,
              borderRadius: bentuk,
              border: online
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 1.5,
                    )
                  : null,

              // Bayangan hanya pada slab putih: dia yang mengangkatnya dari
              // gradien. Kaca buram justru harus terlihat MENEMPEL pada
              // bidangnya.
              boxShadow: online
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Center(
              child: busy
                  ? ClayInlineLoader(size: 18, color: teks)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          online
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 22,
                          color: teks,
                        ),
                        const SizedBox(width: ClayTokens.space2),
                        Text(
                          online ? 'Berhenti bekerja' : 'Mulai bekerja',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: 1.0,
                            color: teks,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pil kaca buram untuk DI DALAM hero: satu angka pendek yang menemani judul.
class _PilKaca extends StatelessWidget {
  const _PilKaca({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space3,
        vertical: ClayTokens.space2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(ikon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            teks,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.0,
              color: Colors.white,

              // Angka berlebar tetap: jam sesi berubah tiap menit, dan tanpa
              // ini pilnya melebar-menyempit sendiri di sudut layar.
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan hari ini: pendapatan sebagai angka utama, sisanya tiga statistik.
///
/// ============================================================================
///  SATU ANGKA BESAR, TIGA ANGKA KECIL
/// ============================================================================
///  Versi lama menampilkan lima angka dengan bobot yang hampir sama, dan
///  hasilnya tidak ada yang terbaca lebih dulu. Pendapatan hari ini adalah
///  alasan driver membuka layar ini di antara order — dia mendapat chip
///  gradien, ukuran uang `large`, dan seluruh baris pertama. Saldo, rating, dan
///  penerimaan adalah angka yang diperiksa sesekali, bukan tiap kali.
/// ============================================================================
class _RingkasanHariIni extends StatelessWidget {
  const _RingkasanHariIni({required this.status});

  final DriverStatus status;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.low,
      radius: ClayTokens.radiusLarge,
      padding: const EdgeInsets.all(ClayTokens.space5),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const ClayIconChip(
                icon: Icons.payments_rounded,
                accent: _aksen,
                size: 46,
              ),
              const SizedBox(width: ClayTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Pendapatan hari ini',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: gelap
                            ? ClayTokens.textTertiaryDark
                            : ClayTokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ClayMoney(
                        formatted: status.todayEarning.formatted,
                        size: ClayMoneySize.large,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ClayTokens.space3),
              _PilAngka(teks: '${status.todayOrders} order'),
            ],
          ),

          const Divider(height: ClayTokens.space6),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _StatKecil(
                  ikon: Icons.account_balance_wallet_rounded,
                  label: 'Saldo',
                  nilai: ClayMoney(
                    formatted: status.balance.formatted,
                    size: ClayMoneySize.small,
                  ),
                ),
              ),
              Expanded(
                child: _StatKecil(
                  ikon: Icons.star_rounded,
                  label: 'Rating',
                  nilai: _Nilai('${status.ratingAverage.toStringAsFixed(1)} ★'),
                ),
              ),
              Expanded(
                child: _StatKecil(
                  ikon: Icons.percent_rounded,

                  // Rasio penerimaan DITAMPILKAN, karena ikut menentukan
                  // prioritas driver di mesin pencocokan. Driver yang tidak
                  // tahu angkanya tidak punya cara memperbaikinya — dan akan
                  // menyimpulkan order dibagikan secara sembarang.
                  label: 'Penerimaan',
                  nilai: _Nilai('${(status.acceptanceRate * 100).round()}%'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Satu statistik kecil: chip gradien, angkanya, lalu labelnya.
class _StatKecil extends StatelessWidget {
  const _StatKecil({
    required this.ikon,
    required this.label,
    required this.nilai,
  });

  final IconData ikon;
  final String label;
  final Widget nilai;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: <Widget>[
        ClayIconChip(icon: ikon, accent: _aksen, size: 34),
        const SizedBox(height: ClayTokens.space2),

        // Saldo bisa sepanjang "Rp 1.250.000" di kolom selebar sepertiga layar.
        // Diperkecil, bukan dipotong: angka uang yang ter-ellipsis lebih buruk
        // daripada angka uang yang kecil.
        FittedBox(fit: BoxFit.scaleDown, child: nilai),

        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: gelap
                ? ClayTokens.textTertiaryDark
                : ClayTokens.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Angka statistik non-uang. Bobotnya disamakan dengan `ClayMoney.small` supaya
/// baris statistiknya tidak terlihat belang.
class _Nilai extends StatelessWidget {
  const _Nilai(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Text(
      teks,
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: gelap ? ClayTokens.textPrimaryDark : ClayTokens.textPrimary,
      ),
    );
  }
}

/// Pil angka beraksen di ujung kanan baris pendapatan.
class _PilAngka extends StatelessWidget {
  const _PilAngka({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space3,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _aksen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
      ),
      child: Text(
        teks,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.0,
          color: _aksen,
        ),
      ),
    );
  }
}

/// Pil hitungan tawaran menunggu, di seberang label bagian.
class _PilHitung extends StatelessWidget {
  const _PilHitung({required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space3,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        gradient: ClayGradients.chip(_aksen),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
      ),
      child: Text(
        '$jumlah menunggu',
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          height: 1.0,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Keadaan kosong daftar tawaran.
class _MenungguTawaran extends StatelessWidget {
  const _MenungguTawaran({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.pressed,
      radius: ClayTokens.radiusLarge,
      padding: const EdgeInsets.all(ClayTokens.space6),
      child: Column(
        children: <Widget>[
          if (online)
            /*
             * Radar berdenyut selagi menunggu tawaran. Layar yang benar-benar
             * diam selama menunggu tidak bisa dibedakan dari aplikasi yang
             * berhenti bekerja.
             *
             * Cincin aksen di sekelilingnya memberi denyut itu tempat: tanpa
             * cincin, tiga titik memantul di tengah kartu kosong terbaca
             * sebagai layar yang macet sedang memuat, bukan sebagai radar yang
             * menyala.
             */
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _aksen.withValues(alpha: 0.12),
              ),
              child: const Center(child: ClayLoader(size: 28, color: _aksen)),
            )
          else
            const ClayIconChip(
              icon: Icons.radar_rounded,
              accent: ClayTokens.textTertiary,
              size: 48,
            ),

          const SizedBox(height: ClayTokens.space4),

          Text(
            online
                ? 'Belum ada tawaran. Tetap di area ramai untuk peluang lebih '
                      'besar.'
                : 'Anda sedang offline. Nyalakan untuk mulai menerima tawaran.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              height: 1.5,
              color: gelap
                  ? ClayTokens.textSecondaryDark
                  : ClayTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pita order berjalan — satu-satunya kartu bergradien di bawah hero.
///
/// Order yang sedang dikerjakan adalah hal paling mendesak di layar ini. Versi
/// lama hanya kartu clay ber-border, jadi bobotnya sama dengan kartu ringkasan
/// di atasnya. Gradien tetap dipakai hemat justru supaya berarti: kalau semua
/// kartu bergradien, tidak ada yang menonjol.
class _PitaOrderBerjalan extends StatelessWidget {
  const _PitaOrderBerjalan({required this.order, required this.onTap});

  final DriverOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius bentuk = BorderRadius.circular(ClayTokens.radiusMedium);

    return Material(
      color: Colors.transparent,
      borderRadius: bentuk,
      child: InkWell(
        onTap: onTap,
        borderRadius: bentuk,
        splashColor: Colors.white.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            gradient: ClayGradients.hero(_aksen),
            borderRadius: bentuk,
          ),
          padding: const EdgeInsets.all(ClayTokens.space4),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: ClayTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Label status dari backend di atas kaca buram —
                    // `ClayStatusBadge` memakai latar pucat yang hilang di atas
                    // gradien.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ClayTokens.space2,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(
                          ClayTokens.radiusPill,
                        ),
                      ),
                      child: Text(
                        order.statusLabel,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          height: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: ClayTokens.space2),
                    Text(
                      order.pickup.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner peringatan dasbor: chip gradien + judul berwarna + penjelasannya.
///
/// ============================================================================
///  SATU BENTUK UNTUK KETIGA PERINGATAN
/// ============================================================================
///  Dulu tiga kelas terpisah dengan susunan yang sama, disalin tiga kali — dan
///  yang terjadi pada susunan yang disalin adalah dia menyimpang. Yang
///  membedakan bahaya dari peringatan sekarang bukan lagi border 1,5 px tapi
///  chip gradien 40 px: merah untuk posisi yang tidak terkirim, amber untuk
///  keadaan yang masih setengah bekerja.
///
///  Bentuknya sengaja LOKAL di berkas ini, bukan di `antaride_ui`: pola yang
///  sama muncul di lima layar driver lain, dan menyatukannya adalah satu
///  perubahan paket bersama tersendiri — bukan efek samping perombakan dasbor.
/// ============================================================================
class _Peringatan extends StatelessWidget {
  const _Peringatan({
    required this.ikon,
    required this.warna,
    required this.judul,
    required this.isi,
  });

  final IconData ikon;
  final Color warna;
  final String judul;
  final String isi;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.low,
      radius: ClayTokens.radiusLarge,
      padding: const EdgeInsets.all(ClayTokens.space4),
      borderColor: warna,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClayIconChip(icon: ikon, accent: warna, size: 40),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  judul,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: warna,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isi,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    height: 1.5,
                    color: gelap
                        ? ClayTokens.textSecondaryDark
                        : ClayTokens.textSecondary,
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
