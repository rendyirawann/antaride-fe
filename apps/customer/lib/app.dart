import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_notifications/antaride_notifications.dart';
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

    return switch (tahap) {
      SessionStage.unknown => const SplashScreen(),
      SessionStage.signedOut => const CustomerWelcomeScreen(),

      // `loadingProfile` memakai splash yang sama, bukan layar kosong: pengguna
      // sudah punya token, jadi menampilkan layar masuk sesaat di sini akan
      // terbaca sebagai sesi yang hilang.
      SessionStage.loadingProfile => const SplashScreen(),

      // Dibungkus `NotificationSync`: yang menjaga angka lencana tetap mutakhir
      // saat aplikasi kembali ke depan. Di dalam gerbang, bukan di atasnya —
      // alasannya di docblock `NotificationSync`.
      SessionStage.signedIn => const NotificationSync(child: AppShell()),
    };
  }
}
