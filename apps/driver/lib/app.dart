import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_notifications/antaride_notifications.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'features/auth/driver_login_screen.dart';
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

    return switch (tahap) {
      SessionStage.unknown || SessionStage.loadingProfile => const _Splash(),
      SessionStage.signedOut => const DriverLoginScreen(),
      // `NotificationSync` menjaga angka lencana notifikasi tetap mutakhir saat
      // aplikasi kembali ke depan. Ditempatkan DI DALAM gerbang, bukan di
      // atasnya — alasannya di docblock `NotificationSync`.
      SessionStage.signedIn => const NotificationSync(
        child: DriverHomeScreen(),
      ),
    };
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
                fontFamily: 'PlusJakartaSans',
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
