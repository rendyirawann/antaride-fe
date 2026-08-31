import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'features/auth/welcome_screen.dart';
import 'features/home/merchant_shell.dart';

/// Akar aplikasi merchant.
class AntarideMerchantApp extends StatelessWidget {
  const AntarideMerchantApp({super.key, required this.services});

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
      ],
      child: MaterialApp(
        title: 'Antaride Merchant',
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
      SessionStage.unknown || SessionStage.loadingProfile => const _LayarBoot(),
      SessionStage.signedOut => const _PembukaMerchant(),
      SessionStage.signedIn => const MerchantShell(),
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

/// Layar tunggu selama sesi diperiksa.
///
/// ============================================================================
///  BIDANG GRADIEN PENUH, BUKAN SPINNER DI ATAS LATAR PUCAT
/// ============================================================================
///  Ini layar pertama yang dilihat merchant setiap kali membuka aplikasi.
///  Versi lama hanya denyut hijau di tengah permukaan clay — hijau `primary`
///  padahal seluruh identitas aplikasi ini amber, dan tanpa satu pun tanda
///  merek pada momen yang justru paling sering dilihat.
///
///  Sekarang seluruh layar adalah bidang [ClayGradients.hero] beraksen amber:
///  resep yang sama dengan hero `MerchantWelcomeScreen` dan layar masuk, jadi
///  boot → sambutan → masuk terbaca sebagai satu bidang warna yang sama, bukan
///  tiga layar yang kebetulan berurutan. Gradiennya SAMA di kedua mode tema —
///  isinya selalu putih.
///
///  Animasinya hanya satu [ClayEntrance] singkat. Tidak boleh lebih: layar ini
///  bisa hidup kurang dari satu detik, dan animasi yang menuntut durasi minimum
///  menahan merchant dari aplikasinya sendiri.
/// ============================================================================
class _LayarBoot extends StatelessWidget {
  const _LayarBoot();

  /// Amber merchant — aksen yang sama dengan ikon peluncur dan hero sambutan.
  static const Color _aksen = ClayTokens.warning;

  @override
  Widget build(BuildContext context) {
    // Gradiennya pekat, jadi ikon status bar dipaksa terang — HANYA selama
    // layar ini digambar; AnnotatedRegion berhenti berlaku begitu gerbang
    // sesi menggantinya.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: ClayGradients.hero(_aksen)),
          child: Stack(
            children: <Widget>[
              // Dua lingkaran samar yang sama dengan ClayHeroHeader — layar ini
              // pada dasarnya hero yang memenuhi seluruh layar.
              const Positioned(
                top: -70,
                right: -50,
                child: _Lingkaran(diameter: 220, alpha: 0.08),
              ),
              const Positioned(
                bottom: -90,
                left: -70,
                child: _Lingkaran(diameter: 240, alpha: 0.06),
              ),

              Center(
                child: ClayEntrance(
                  index: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const _MarkMerchant(),

                      const SizedBox(height: ClayTokens.space6),

                      const Text(
                        'Antaride Merchant',
                        style: TextStyle(
                          fontFamily: ClayTokens.fontFamily,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: ClayTokens.space2),

                      /*
                       * Kalimatnya tetap "Menyiapkan Antaride Merchant…" —
                       * dulu dia `message` milik ClayLoader, yang menggambarnya
                       * dengan warna teks sekunder abu. Abu di atas gradien
                       * berwarna terlihat kotor, jadi teksnya digambar di sini
                       * sebagai putih diredupkan: aturan subtitle hero yang
                       * sama di seluruh aplikasi.
                       */
                      Text(
                        'Menyiapkan Antaride Merchant…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: ClayTokens.fontFamily,
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),

                      const SizedBox(height: ClayTokens.space10),

                      // Spinner putih, bukan hijau bawaan: di atas gradien
                      // amber, hijau primary adalah warna aplikasi lain.
                      const ClayLoader(size: 38, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mark "A•" dalam tile kaca buram.
///
/// Digambar lokal, bukan diimpor: mark aslinya sengaja privat di
/// `antaride_onboarding` — mark merek bukan bagian design system, dan layar
/// lain tidak boleh menaruhnya di sembarang hero. Layar boot adalah pengecualian
/// yang sah (ini layar merek), jadi marknya digambar ulang dengan resep yang
/// sama: tile kaca putih alpha 0.16 + bingkai 0.22, huruf 'A' putih.
///
/// Titiknya HIJAU TUA, bukan amber: aturan mark Antaride memberi titik warna
/// aksen, kecuali di atas hero amber — titik amber di atas amber tidak
/// terlihat sama sekali.
class _MarkMerchant extends StatelessWidget {
  const _MarkMerchant();

  /// Hijau tua Antaride, dipakai HANYA sebagai titik mark di atas hero amber.
  static const Color _titik = Color(0xFF062E1E);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(ClayTokens.radiusLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          const Text(
            'A',
            style: TextStyle(
              fontFamily: ClayTokens.fontFamily,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3, bottom: 5),
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _titik,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lingkaran tekstur — putih transparan supaya ikut warna gradiennya.
class _Lingkaran extends StatelessWidget {
  const _Lingkaran({required this.diameter, required this.alpha});

  final double diameter;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

/// Perkenalan aplikasi merchant, lalu layar sambutan.
///
/// Halaman ketiga menyebut batasnya apa adanya. Perkenalan yang menjanjikan
/// kelola menu dan pesanan masuk — keduanya belum ada di Fase 1 — akan membuat
/// pemilik warung mencari fitur yang tidak ada, lalu menyimpulkan aplikasinya
/// rusak.
class _PembukaMerchant extends StatelessWidget {
  const _PembukaMerchant();

  @override
  Widget build(BuildContext context) {
    return const IntroGate(
      accent: ClayTokens.warning,
      pages: <IntroPage>[
        IntroPage(
          icon: Icons.storefront_rounded,
          title: 'Toko Anda di Antaride',
          body:
              'Kelola data toko yang terdaftar dan lihat statusnya kapan saja '
              'dari satu aplikasi.',
        ),
        IntroPage(
          icon: Icons.groups_rounded,
          title: 'Pelanggan di sekitar Anda',
          body:
              'Antaride mempertemukan toko Anda dengan pemesan di area layanan '
              'yang sama.',
        ),
        IntroPage(
          icon: Icons.construction_rounded,
          title: 'Menu dan pesanan menyusul',
          body:
              'Fase pertama ini baru memuat masuk dan profil toko. Pengelolaan '
              'menu dan pesanan masuk datang di pembaruan berikutnya.',
        ),
      ],
      child: MerchantWelcomeScreen(),
    );
  }
}
