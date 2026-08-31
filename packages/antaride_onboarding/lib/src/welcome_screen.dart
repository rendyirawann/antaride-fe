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
///  Layar ini adalah contoh pertama bahasa desain v2, dan bagian-bagiannya
///  sudah diangkat ke `antaride_ui`: bidang gradiennya jadi [ClayHeroHeader],
///  chip ikonnya jadi [ClayIconChip], animasi masuknya jadi [ClayEntrance].
///  Yang tersisa di berkas ini hanya susunan layarnya dan mark logo — layar
///  lain WAJIB memakai komponen yang sama, bukan menyalin dari sini.
///
///  Dua bidang (gradien + clay) yang membuat layarnya tidak terasa seperti
///  formulir: formulir seluruhnya satu warna latar. Isinya juga masuk dengan
///  animasi singkat — sekali, saat layar dibuka, bukan berulang.
/// ============================================================================
class WelcomeScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final Color aksen = accent ?? ClayTokens.primary;

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
                    ClayEntrance(
                      index: 0,
                      child: ClayHeroHeader(
                        accent: aksen,
                        title: title,
                        subtitle: tagline,
                        leading: _LogoMark(aksen: aksen),
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
                          for (int i = 0; i < points.length; i++) ...<Widget>[
                            ClayEntrance(
                              index: i + 1,
                              child: _KartuPoin(poin: points[i], aksen: aksen),
                            ),
                            const SizedBox(height: ClayTokens.space3),
                          ],
                        ],
                      ),
                    ),

                    const Spacer(),

                    Padding(
                      /*
                       * ==========================================================
                       *  RUANG BAWAH IKUT BILAH NAVIGASI ANDROID
                       * ==========================================================
                       *  Layar ini SENGAJA tidak dibungkus SafeArea: hero-nya
                       *  harus menembus status bar. Tapi tepi BAWAH tetap perlu
                       *  dihormati — di HP dengan bilah navigasi tiga tombol
                       *  (kembali/home/aplikasi), tombol Daftar dan Masuk berada
                       *  PERSIS di belakangnya dan tidak bisa ditekan.
                       *
                       *  `MediaQuery.viewPaddingOf`, bukan `paddingOf`:
                       *  `paddingOf` menjadi nol ketika ada sesuatu yang sudah
                       *  mengonsumsinya (mis. SafeArea di atas), sementara
                       *  viewPadding selalu melaporkan tinggi bilah yang
                       *  sebenarnya.
                       * ==========================================================
                       */
                      padding: EdgeInsets.fromLTRB(
                        ClayTokens.space6,
                        0,
                        ClayTokens.space6,
                        ClayTokens.space5 +
                            MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      child: ClayEntrance(
                        // Giliran terakhir, setelah semua kartu poin.
                        index: points.length + 1,
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
                              label: registerLabel,
                              onPressed: onRegister,
                              expanded: true,
                            ),

                            const SizedBox(height: ClayTokens.space3),

                            ClayButton(
                              label: loginLabel,
                              onPressed: onLogin,
                              variant: ClayButtonVariant.secondary,
                              expanded: true,
                            ),

                            if (footer != null) ...<Widget>[
                              const SizedBox(height: ClayTokens.space4),
                              Text(
                                footer!,
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

/// Mark "A•" di atas hero.
///
/// Digambar, bukan memuat berkas gambar: ikon peluncur hidup di `mipmap/` yang
/// tidak bisa dibaca Flutter sebagai aset, dan menyalin PNG-nya ke `assets/`
/// berarti dua salinan yang menyimpang saat marknya diubah.
///
/// Titik amber setelah huruf mengikuti mark ikon peluncur — huruf yang sedang
/// menuju ke suatu titik. Di sini hurufnya putih di atas gradien, jadi tile-nya
/// kaca buram (putih transparan), bukan kotak pejal.
///
/// TETAP di berkas ini, bukan di `antaride_ui`: mark merek bukan bagian design
/// system — layar lain tidak boleh menaruh logo di sembarang hero.
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

    return ClaySurface(
      depth: ClayDepth.low,
      radius: ClayTokens.radiusMedium,
      padding: const EdgeInsets.all(ClayTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClayIconChip(icon: poin.icon, accent: aksen),
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
