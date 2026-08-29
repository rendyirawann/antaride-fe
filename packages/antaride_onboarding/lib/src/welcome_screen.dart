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
///  Untuk aplikasi driver dan merchant bedanya lebih tajam lagi: keduanya
///  menuntut pendaftaran yang tidak selesai dalam satu layar — dokumen untuk
///  driver, data toko untuk merchant. Menembakkannya langsung ke kolom nomor HP
///  membuat orang yang baru mengunduh mengira dia bisa langsung bekerja.
///
///  Layar ini menjawab tiga hal sebelum meminta apa pun: aplikasi apa ini,
///  untuk siapa, dan apa yang bisa dilakukan.
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
  /// layar pembuka — dan daftar panjang membuat tombolnya terdorong ke bawah
  /// layar pada HP kecil.
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints batas) {
            return SingleChildScrollView(
              /*
               * Bisa digulir, dan tingginya dipaksa minimal setinggi layar.
               *
               * Keduanya perlu bersamaan: tanpa gulir, layar ini meluap di HP
               * pendek — dan yang terpotong justru tombolnya. Tanpa tinggi
               * minimum, `Spacer` tidak punya ruang untuk mendorong tombol ke
               * bawah di HP tinggi, dan seluruh isinya menumpuk di atas.
               */
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: batas.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(ClayTokens.space6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: ClayTokens.space8),

                        _Logo(aksen: aksen),

                        const SizedBox(height: ClayTokens.space6),

                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: gelap
                                ? ClayTokens.textPrimaryDark
                                : ClayTokens.textPrimary,
                          ),
                        ),

                        const SizedBox(height: ClayTokens.space2),

                        Text(
                          tagline,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            height: 1.5,
                            color: gelap
                                ? ClayTokens.textSecondaryDark
                                : ClayTokens.textSecondary,
                          ),
                        ),

                        const SizedBox(height: ClayTokens.space8),

                        for (final WelcomePoint p in points) ...<Widget>[
                          _Poin(poin: p, aksen: aksen),
                          const SizedBox(height: ClayTokens.space4),
                        ],

                        // Mendorong tombol ke bawah di layar tinggi, dan
                        // menyusut jadi nol di layar pendek.
                        const Spacer(),

                        const SizedBox(height: ClayTokens.space6),

                        /*
                         * DAFTAR di atas MASUK, dan itu bukan kebiasaan umum.
                         *
                         * Yang membuka layar ini kebanyakan pengguna baru —
                         * yang lama sudah punya sesi tersimpan dan tidak pernah
                         * sampai ke sini. Menaruh tindakan yang paling mungkin
                         * dipilih di posisi paling menonjol.
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

                        const SizedBox(height: ClayTokens.space4),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
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

class _Poin extends StatelessWidget {
  const _Poin({required this.poin, required this.aksen});

  final WelcomePoint poin;
  final Color aksen;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClaySurface(
          depth: ClayDepth.low,
          radius: ClayTokens.radiusSmall,
          padding: const EdgeInsets.all(ClayTokens.space3),
          child: Icon(poin.icon, size: 20, color: aksen),
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
    );
  }
}

/// Logo: huruf A yang sama dengan ikon aplikasinya.
///
/// Digambar, bukan memuat berkas gambar. Ikon peluncur hidup di `mipmap/` yang
/// tidak bisa dibaca Flutter sebagai aset, dan menyalin PNG-nya ke `assets/`
/// berarti dua salinan yang harus sepakat — yang menyimpang saat marknya diubah.
class _Logo extends StatelessWidget {
  const _Logo({required this.aksen});

  final Color aksen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: aksen,
        borderRadius: BorderRadius.circular(ClayTokens.radiusLarge),
      ),
      alignment: Alignment.center,
      child: const Text(
        'A',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 40,
          fontWeight: FontWeight.w800,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}
