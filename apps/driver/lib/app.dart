import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_notifications/antaride_notifications.dart';
import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'features/auth/welcome_screen.dart';
import 'features/dashboard/driver_home_screen.dart';

/// Akar aplikasi driver.
///
/// ============================================================================
///  APLIKASI YANG SAMA STRUKTURNYA, TAPI BUKAN LAYAR YANG SAMA
/// ============================================================================
///  Gerbang sesi, tema, dan lapisan API-nya persis sama dengan aplikasi
///  penumpang — semuanya dari paket bersama.
///
///  Yang berbeda dan sengaja tidak dibagi: layarnya. Driver memakai aplikasi ini
///  SAMBIL BERKENDARA, dan itu mengubah hampir setiap keputusan tampilan —
///  tombol lebih besar, teks lebih sedikit, dan tidak ada layar yang menuntut
///  membaca lebih dari beberapa detik.
/// ============================================================================
class AntarideDriverApp extends StatelessWidget {
  const AntarideDriverApp({super.key, required this.services});

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
        ChangeNotifierProvider<SessionController>.value(
          value: services.session,
        ),

        /*
         * Notifikasi in-app driver.
         *
         * `services.notifications` di aplikasi ini membaca sebagai DRIVER —
         * disetel di `main.dart` lewat `notificationRole`. Satu orang bisa punya
         * akun penumpang dan driver yang sama, jadi peran itu yang menentukan
         * notifikasi siapa yang tampil, bukan akunnya.
         *
         * Yang TIDAK lewat sini: tawaran order. Tawaran hanya berlaku 15 detik,
         * dan notifikasi yang baru terbaca saat aplikasi dibuka akan selalu sudah
         * kadaluarsa. Tawaran tetap dijemput `DriverController` lewat penarikan
         * berkala.
         */
        ChangeNotifierProvider<NotificationController>(
          create: (_) => NotificationController(services.notifications),
        ),
      ],
      child: MaterialApp(
        title: 'Antaride Driver',
        debugShowCheckedModeBanner: false,
        theme: ClayTheme.light(),
        darkTheme: ClayTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _Gerbang(),
      ),
    );
  }
}

class _Gerbang extends StatelessWidget {
  const _Gerbang();

  @override
  Widget build(BuildContext context) {
    final SessionStage tahap = context.select<SessionController, SessionStage>(
      (SessionController s) => s.stage,
    );

    final Widget layar = switch (tahap) {
      SessionStage.unknown || SessionStage.loadingProfile => const _Splash(),
      SessionStage.signedOut => const _PembukaDriver(),
      // `NotificationSync` menjaga angka lencana notifikasi tetap mutakhir saat
      // aplikasi kembali ke depan. Ditempatkan DI DALAM gerbang, bukan di
      // atasnya — alasannya di docblock `NotificationSync`.
      SessionStage.signedIn => const NotificationSync(
        child: DriverHomeScreen(),
      ),
    };

    /*
     * Pergantian tahap MEMUDAR, tidak melompat. Alasan lengkapnya sama dengan
     * gerbang aplikasi penumpang: pergantian seketika dari bidang gradien penuh
     * ke permukaan clay pucat terbaca sebagai kedipan, bukan perpindahan.
     */
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(key: ValueKey<SessionStage>(tahap), child: layar),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ClaySurface(
              depth: ClayDepth.high,
              radius: ClayTokens.radiusLarge,
              padding: EdgeInsets.all(ClayTokens.space6),
              child: Icon(
                Icons.two_wheeler_rounded,
                size: 48,
                color: ClayTokens.primary,
              ),
            ),
            SizedBox(height: ClayTokens.space5),
            Text(
              'Antaride Driver',
              style: TextStyle(
                fontFamily: ClayTokens.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: ClayTokens.space8),
            ClayLoader(size: 38),
          ],
        ),
      ),
    );
  }
}

/// Perkenalan aplikasi driver, lalu layar sambutan.
///
/// Kalimatnya berbeda dari aplikasi penumpang dengan sengaja: yang membuka ini
/// calon mitra pengemudi, dan yang perlu dia tahu lebih dulu adalah bagaimana
/// order sampai kepadanya dan bagaimana penghasilannya dihitung.
class _PembukaDriver extends StatelessWidget {
  const _PembukaDriver();

  @override
  Widget build(BuildContext context) {
    return const IntroGate(
      accent: ClayTokens.primaryDark,
      pages: <IntroPage>[
        IntroPage(
          icon: Icons.notifications_active_rounded,
          title: 'Order datang sendiri',
          body:
              'Nyalakan status bekerja, dan tawaran masuk dengan jarak serta '
              'perkiraan penghasilannya. Anda yang memutuskan menerima.',
        ),
        IntroPage(
          icon: Icons.route_rounded,
          title: 'Dipandu sampai selesai',
          body:
              'Peta penjemputan, kode verifikasi penumpang, sampai penyelesaian '
              'order — semuanya dari satu layar.',
        ),
        IntroPage(
          icon: Icons.savings_rounded,
          title: 'Penghasilan langsung tercatat',
          body:
              'Setiap order masuk ke dompet Anda begitu perjalanannya selesai. '
              'Tidak ada perhitungan yang menunggu akhir hari.',
        ),
      ],
      child: DriverWelcomeScreen(),
    );
  }
}
