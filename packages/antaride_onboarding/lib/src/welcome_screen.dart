import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';

/// Layar pertama yang dilihat pengguna sebelum masuk.
///
/// ============================================================================
///  KENAPA TIDAK LANGSUNG KE LAYAR NOMOR HP
/// ============================================================================
///  Aplikasi yang membuka layar "masukkan nomor HP" sebagai layar pertama
///  meminta sesuatu sebelum menjelaskan apa pun. Yang membukanya belum tahu
///  aplikasi ini untuk apa, siapa yang membuatnya, dan kenapa nomornya
///  dibutuhkan.
///
///  Layar ini menjawab tiga hal sebelum meminta apa pun: aplikasi apa ini,
///  untuk siapa, dan apa yang bisa dilakukan.
/// ============================================================================
///
/// ============================================================================
///  BENTUKNYA: HERO GRADIEN DI ATAS, ISI DI PERMUKAAN CLAY DI BAWAH
/// ============================================================================
///  Bagian atas satu bidang gradien warna aksen yang menembus status bar,
///  dengan lingkaran-lingkaran samar sebagai tekstur. Merek dan tagline hidup
///  di sana, putih di atas warna. Bagian bawah kembali ke permukaan clay biasa
///  untuk daftar fitur dan tombol.
///
///  Dua bidang ini yang membuat layarnya tidak terasa seperti formulir:
///  formulir seluruhnya satu warna latar. Isinya juga masuk dengan animasi
///  singkat — sekali, saat layar dibuka, bukan berulang.
/// ============================================================================
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.title,
    required this.tagline,
    required this.points,
    required this.onLogin,
    required this.onRegister,
    this.accent,
    this.registerLabel = 'Daftar',
    this.loginLabel = 'Masuk',
    this.footer,
  });

  final String title;
  final String tagline;

  /// Tiga hal yang bisa dilakukan aplikasi ini.
  ///
  /// TIGA, bukan lima. Yang keempat dan seterusnya tidak dibaca siapa pun di
  /// layar pembuka — dan daftar panjang mendorong tombolnya keluar layar pada
  /// HP kecil.
  final List<WelcomePoint> points;

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  /// Warna aksen aplikasi ini. Bawaannya hijau merek.
  final Color? accent;

  final String loginLabel;
  final String registerLabel;

  /// Kalimat tambahan di bawah tombol, misalnya syarat pendaftaran driver.
  final String? footer;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  /// Animasi masuk. Satu controller untuk semuanya; tiap bagian mengambil
  /// potongan kurvanya sendiri lewat `Interval` supaya masuknya bergiliran.
  late final AnimationController _masuk;

  @override
  void initState() {
    super.initState();

    _masuk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _masuk.dispose();
    super.dispose();
  }

  /// Fade + geser naik sedikit, dimulai pada [mulai] (0..1 dari durasi total).
  Widget _muncul({required double mulai, required Widget child}) {
    final CurvedAnimation kurva = CurvedAnimation(
      parent: _masuk,
      curve: Interval(mulai, 1, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: kurva,
      child: AnimatedBuilder(
        animation: kurva,
        builder: (BuildContext _, Widget? anak) => Transform.translate(
          offset: Offset(0, 18 * (1 - kurva.value)),
          child: anak,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final Color aksen = widget.accent ?? ClayTokens.primary;

    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints batas) {
          return SingleChildScrollView(
            /*
             * Bisa digulir, dan tingginya dipaksa minimal setinggi layar.
             *
             * Keduanya perlu bersamaan: tanpa gulir, layar ini meluap di HP
             * pendek — dan yang terpotong justru tombolnya. Tanpa tinggi
             * minimum, `Spacer` tidak punya ruang mendorong tombol ke bawah
             * di HP tinggi.
             */
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: batas.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _muncul(
                      mulai: 0,
                      child: _Hero(
                        aksen: aksen,
                        title: widget.title,
                        tagline: widget.tagline,
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ClayTokens.space6,
                        ClayTokens.space6,
                        ClayTokens.space6,
                        ClayTokens.space4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (
                            int i = 0;
                            i < widget.points.length;
                            i++
                          ) ...<Widget>[
                            _muncul(
                              mulai: 0.15 + i * 0.12,
                              child: _KartuPoin(
                                poin: widget.points[i],
                                aksen: aksen,
                              ),
                            ),
                            const SizedBox(height: ClayTokens.space3),
                          ],
                        ],
                      ),
                    ),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ClayTokens.space6,
                        0,
                        ClayTokens.space6,
                        ClayTokens.space5,
                      ),
                      child: _muncul(
                        mulai: 0.45,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            /*
                             * DAFTAR di atas MASUK, dan itu bukan kebiasaan
                             * umum. Yang membuka layar ini kebanyakan pengguna
                             * baru — yang lama sudah punya sesi tersimpan dan
                             * tidak pernah sampai ke sini.
                             */
                            ClayButton(
                              label: widget.registerLabel,
                              onPressed: widget.onRegister,
                              expanded: true,
                            ),

                            const SizedBox(height: ClayTokens.space3),

                            ClayButton(
                              label: widget.loginLabel,
                              onPressed: widget.onLogin,
                              variant: ClayButtonVariant.secondary,
                              expanded: true,
                            ),

                            if (widget.footer != null) ...<Widget>[
                              const SizedBox(height: ClayTokens.space4),
                              Text(
                                widget.footer!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11.5,
                                  height: 1.5,
                                  color: gelap
                                      ? ClayTokens.textTertiaryDark
                                      : ClayTokens.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Satu hal yang bisa dilakukan aplikasi.
class WelcomePoint {
  const WelcomePoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

// -----------------------------------------------------------------------------

/// Bidang gradien di atas: merek, tagline, dan tekstur lingkaran.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.aksen,
    required this.title,
    required this.tagline,
  });

  final Color aksen;
  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    // Gradien dari aksen ke versi lebih gelapnya sendiri — bukan warna kedua
    // yang dipilih terpisah, supaya SEMUA aksen (hijau, hijau tua, amber)
    // menghasilkan gradien yang serasi tanpa tabel kombinasi.
    final Color tua = Color.lerp(aksen, Colors.black, 0.32)!;

    // Menembus status bar. `padding.top` dari MediaQuery, bukan SafeArea:
    // gradiennya harus ADA di belakang jam dan baterai, isinya saja yang turun.
    final double atas = MediaQuery.paddingOf(context).top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[aksen, tua],
          ),
        ),
        child: Stack(
          children: <Widget>[
            // Lingkaran-lingkaran samar. Tekstur, bukan informasi — cukup dua,
            // dan keduanya putih transparan supaya ikut warna aksen apa pun.
            Positioned(
              top: -70,
              right: -50,
              child: _Lingkaran(diameter: 220, alpha: 0.08),
            ),
            Positioned(
              bottom: -90,
              left: -70,
              child: _Lingkaran(diameter: 240, alpha: 0.06),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                ClayTokens.space6,
                atas + ClayTokens.space8,
                ClayTokens.space6,
                ClayTokens.space8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _LogoMark(aksen: aksen),

                  const SizedBox(height: ClayTokens.space5),

                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: ClayTokens.space3),

                  Text(
                    tagline,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      height: 1.55,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

/// Mark "A•" di atas hero.
///
/// Digambar, bukan memuat berkas gambar: ikon peluncur hidup di `mipmap/` yang
/// tidak bisa dibaca Flutter sebagai aset, dan menyalin PNG-nya ke `assets/`
/// berarti dua salinan yang menyimpang saat marknya diubah.
///
/// Titik amber setelah huruf mengikuti mark ikon peluncur — huruf yang sedang
/// menuju ke suatu titik. Di sini hurufnya putih di atas gradien, jadi tile-nya
/// kaca buram (putih transparan), bukan kotak pejal.
class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.aksen});

  final Color aksen;

  @override
  Widget build(BuildContext context) {
    // Aturan yang sama dengan ikon peluncur: titiknya amber — KECUALI di
    // aplikasi merchant yang hero-nya sendiri amber, di sana titiknya hijau
    // tua. Titik amber di atas gradien amber tenggelam tanpa terlihat salah.
    final Color titik = aksen == ClayTokens.warning
        ? const Color(0xFF062E1E)
        : ClayTokens.warning;

    return Container(
      width: 64,
      height: 64,
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
              fontFamily: 'PlusJakartaSans',
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3, bottom: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: titik),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu fitur: kartu clay dengan chip ikon bergradien.
class _KartuPoin extends StatelessWidget {
  const _KartuPoin({required this.poin, required this.aksen});

  final WelcomePoint poin;
  final Color aksen;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final Color tua = Color.lerp(aksen, Colors.black, 0.28)!;

    return ClaySurface(
      depth: ClayDepth.low,
      radius: ClayTokens.radiusMedium,
      padding: const EdgeInsets.all(ClayTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[aksen, tua],
              ),
              borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
            ),
            child: Icon(poin.icon, size: 21, color: Colors.white),
          ),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  poin.title,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: gelap
                        ? ClayTokens.textPrimaryDark
                        : ClayTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  poin.body,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    height: 1.45,
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
