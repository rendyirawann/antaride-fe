import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_notifications/antaride_notifications.dart';
import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'features/auth/welcome_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/splash_screen.dart';

/// Akar aplikasi penumpang.
class AntarideCustomerApp extends StatelessWidget {
  const AntarideCustomerApp({super.key, required this.services});

  final AntarideServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AntarideServices>.value(value: services),

        /*
         * Konfigurasi dari server: area layanan dan sakelar pencarian alamat.
         *
         * `..muat()` langsung di sini, bukan ditunggu layar mana pun: nilainya
         * dibutuhkan peta pada frame pertama, dan controller ini SELALU punya
         * nilai bawaan yang bisa dipakai sementara jawabannya datang. Tidak ada
         * keadaan "belum dimuat" yang harus ditangani pembacanya.
         */
        ChangeNotifierProvider<ServerConfigController>(
          create: (_) => ServerConfigController(services.places)..muat(),
        ),

        // Controller sesi disalurkan sebagai ChangeNotifierProvider TANPA
        // `create`, karena instansnya sudah dibuat di `AntarideServices` —
        // ApiClient memegang referensinya untuk menangani 401.
        //
        // `dispose: false`: pemiliknya adalah services, bukan provider ini.
        // Provider yang membuangnya akan menutup controller yang masih dipegang
        // ApiClient.
        ChangeNotifierProvider<SessionController>.value(
          value: services.session,
        ),

        /*
         * Controller notifikasi dipasang DI AKAR, bukan di dalam layar
         * notifikasinya.
         *
         * Yang dilayaninya ada dua: daftar notifikasi, dan lencana angka di ikon
         * lonceng di beranda. Kalau dipasang di dalam layarnya, controller-nya
         * dibuang saat layar ditutup — dan lencana di beranda kehilangan
         * angkanya setiap kali pengguna keluar dari daftar notifikasi.
         *
         * Dibuat malas (bawaan provider), dan itu penting: yang pertama
         * memintanya adalah `NotificationSync` di dalam kerangka setelah masuk.
         * Membuatnya lebih awal berarti ada permintaan jumlah notifikasi saat
         * pengguna belum masuk — dan 401 dari sana akan memaksa keluar dari sesi
         * yang belum dimulai.
         */
        ChangeNotifierProvider<NotificationController>(
          create: (_) => NotificationController(services.notifications),
        ),
      ],
      child: MaterialApp(
        title: 'Antaride',
        debugShowCheckedModeBanner: false,

        theme: ClayTheme.light(),
        darkTheme: ClayTheme.dark(),

        /*
         * Mengikuti tema sistem.
         *
         * Bukan dipaksa terang. Aplikasi ride-hailing banyak dipakai malam hari,
         * dan layar terang di dalam kendaraan gelap membutakan sesaat — yang
         * bukan hal sepele saat orangnya sedang mencocokkan plat nomor.
         */
        themeMode: ThemeMode.system,

        home: const _Gerbang(),
      ),
    );
  }
}

/// Menentukan layar mana yang tampil berdasarkan tahap sesi.
///
/// ============================================================================
///  SATU GERBANG, BUKAN PEMERIKSAAN DI SETIAP LAYAR
/// ============================================================================
///  Setiap layar yang memeriksa sendiri apakah pengguna masuk akan menghasilkan
///  satu yang lupa — dan yang lupa itu bisa dibuka lewat notifikasi atau deep
///  link tanpa sesi.
///
///  Dengan gerbang di akar, keluar dari sesi di mana pun — termasuk lewat 401
///  yang datang di tengah pemakaian — otomatis mengembalikan pengguna ke layar
///  masuk tanpa satu pun `Navigator.pop` yang harus ditulis.
/// ============================================================================
class _Gerbang extends StatelessWidget {
  const _Gerbang();

  @override
  Widget build(BuildContext context) {
    final SessionStage tahap = context.select<SessionController, SessionStage>(
      (SessionController s) => s.stage,
    );

    final Widget layar = switch (tahap) {
      SessionStage.unknown => const SplashScreen(),
      SessionStage.signedOut => const _PembukaPenumpang(),

      // `loadingProfile` memakai splash yang sama, bukan layar kosong: pengguna
      // sudah punya token, jadi menampilkan layar masuk sesaat di sini akan
      // terbaca sebagai sesi yang hilang.
      SessionStage.loadingProfile => const SplashScreen(),

      // Dibungkus `NotificationSync`: yang menjaga angka lencana tetap mutakhir
      // saat aplikasi kembali ke depan. Di dalam gerbang, bukan di atasnya —
      // alasannya di docblock `NotificationSync`.
      SessionStage.signedIn => const NotificationSync(child: AppShell()),
    };

    /*
     * ========================================================================
     *  PERGANTIAN TAHAP MEMUDAR, TIDAK MELOMPAT
     * ========================================================================
     *  Tanpa ini, splash berganti ke beranda dalam SATU frame — dan pergantian
     *  seketika dari bidang gradien hijau penuh ke permukaan clay pucat terbaca
     *  sebagai kedipan, bukan sebagai perpindahan.
     *
     *  260 ms: cukup untuk terlihat sebagai peralihan, cukup singkat untuk
     *  tidak menahan orang yang sesinya sudah siap.
     *
     *  `ValueKey` pada tahapnya, bukan pada tipe widgetnya: `unknown` dan
     *  `loadingProfile` sama-sama SplashScreen, dan tanpa kunci yang membedakan
     *  keduanya, AnimatedSwitcher akan memudarkan splash MENJADI splash saat
     *  tahapnya bergeser di antara keduanya.
     * ========================================================================
     */
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(key: ValueKey<SessionStage>(tahap), child: layar),
    );
  }
}

/// Perkenalan aplikasi, lalu layar sambutan penumpang.
///
/// Halaman perkenalannya ditulis di sini, bukan di paket bersama: isinya
/// menjelaskan LAYANAN aplikasi ini, dan tiga aplikasi menjelaskan tiga hal
/// yang berbeda. Yang dibagikan bentuk layarnya, bukan kalimatnya.
class _PembukaPenumpang extends StatelessWidget {
  const _PembukaPenumpang();

  @override
  Widget build(BuildContext context) {
    return const IntroGate(
      pages: <IntroPage>[
        IntroPage(
          icon: Icons.near_me_rounded,
          title: 'Pesan dari mana saja',
          body:
              'Tentukan titik jemput dengan menggeser peta atau mencari '
              'alamatnya. Driver terdekat yang menjemput Anda.',
        ),
        IntroPage(
          icon: Icons.receipt_long_rounded,
          title: 'Harga pasti di depan',
          body:
              'Ongkosnya dihitung sebelum Anda menekan pesan — bukan setelah '
              'sampai tujuan.',
        ),
        IntroPage(
          icon: Icons.verified_user_rounded,
          title: 'Driver terverifikasi',
          body:
              'Setiap driver Antaride diperiksa dokumennya sebelum boleh '
              'bekerja. Perjalanan Anda bisa dipantau di peta.',
        ),
      ],
      child: CustomerWelcomeScreen(),
    );
  }
}
