import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Layar sementara selama sesi diperiksa.
///
/// ============================================================================
///  KENAPA BUKAN LAYAR KOSONG ATAU SPINNER SAJA
/// ============================================================================
///  Pemeriksaan sesi membaca secure storage lalu memanggil API — biasanya di
///  bawah satu detik, tapi bisa lebih lama di jaringan yang buruk.
///
///  Layar kosong selama itu terbaca sebagai aplikasi yang gagal dibuka.
///  Spinner sendirian terbaca sebagai memuat sesuatu yang tidak jelas. Logo
///  dengan spinner terbaca sebagai aplikasi yang sedang bersiap — dan itu yang
///  memang sedang terjadi.
/// ============================================================================
///
/// ============================================================================
///  BIDANG GRADIEN PENUH, BUKAN PERMUKAAN CLAY PUCAT
/// ============================================================================
///  Ini layar merek: pengguna baru datang dari welcome screen yang seluruh
///  kepalanya gradien hijau, lalu setiap pembukaan berikutnya disambut layar
///  ini. Kalau yang ini pucat, mereknya terasa hilang justru di momen paling
///  sering dilihat. Gradiennya [ClayGradients.hero] — resep yang sama dengan
///  semua hero v2 — dan SAMA di kedua mode tema, karena isinya selalu putih.
///
///  Animasinya hanya satu [ClayEntrance] singkat untuk kolom isi. Tidak boleh
///  lebih: layar ini bisa hidup kurang dari satu detik, dan animasi yang
///  menunda atau menuntut durasi minimum akan menahan pengguna dari
///  aplikasinya sendiri.
/// ============================================================================
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Gradiennya gelap, jadi ikon status bar dipaksa terang — HANYA selama
    // layar ini digambar; AnnotatedRegion berhenti berlaku begitu layarnya
    // diganti oleh gerbang sesi.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: ClayGradients.hero(ClayTokens.primary),
          ),
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
                      const _MarkAntaride(),
                      const SizedBox(height: ClayTokens.space6),
                      const Text(
                        'Antaride',
                        style: TextStyle(
                          fontFamily: ClayTokens.fontFamily,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: ClayTokens.space2),
                      Text(
                        'Medan, dalam satu aplikasi',
                        style: TextStyle(
                          fontFamily: ClayTokens.fontFamily,
                          fontSize: 13,

                          // Putih diredupkan, bukan abu-abu — aturan subtitle
                          // hero: abu-abu di atas gradien terlihat kotor.
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                      const SizedBox(height: ClayTokens.space10),
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
/// Digambar lokal, bukan diimpor: mark aslinya (`_LogoMark`) sengaja privat di
/// `antaride_onboarding` — mark merek bukan bagian design system, dan layar
/// lain tidak boleh menaruhnya di sembarang hero. Splash adalah pengecualian
/// yang sah (ini layar merek), jadi marknya digambar ulang kecil di sini
/// dengan resep yang sama: tile kaca putih alpha 0.16 + border 0.22, huruf 'A'
/// putih, titik amber ([ClayTokens.warning]) di kaki huruf.
class _MarkAntaride extends StatefulWidget {
  const _MarkAntaride();

  @override
  State<_MarkAntaride> createState() => _MarkAntarideState();
}

class _MarkAntarideState extends State<_MarkAntaride>
    with SingleTickerProviderStateMixin {
  /*
   * ==========================================================================
   *  DENYUT PELAN, BUKAN PUTARAN
   * ==========================================================================
   *  Spinner yang berputar di bawah sudah menyatakan "sedang memuat". Mark yang
   *  ikut berputar akan menyatakan hal yang sama dua kali, dan gerakan cepat
   *  pada logo membuatnya terbaca sebagai bagian dari spinner, bukan sebagai
   *  merek.
   *
   *  Denyut 1400 ms dengan skala 3% cukup untuk membuat layar terasa HIDUP
   *  selama menunggu, tanpa menarik mata dari mereknya sendiri. Di bawah
   *  1000 ms gerakannya mulai terasa gelisah.
   *
   *  Berulang selama layar ini hidup — dan layar ini memang hidup persis
   *  selama pemeriksaan sesinya berjalan.
   * ==========================================================================
   */
  late final AnimationController _denyut = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _denyut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1,
        end: 1.03,
      ).animate(CurvedAnimation(parent: _denyut, curve: Curves.easeInOut)),
      child: _tile(),
    );
  }

  Widget _tile() {
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
                color: ClayTokens.warning,
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
