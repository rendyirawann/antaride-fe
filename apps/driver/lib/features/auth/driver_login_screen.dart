import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Masuk sebagai driver: nomor lalu kode, dalam SATU layar.
///
/// ============================================================================
///  SATU LAYAR, BUKAN DUA — DAN ITU BERBEDA DARI APLIKASI PENUMPANG
/// ============================================================================
///  Aplikasi penumpang memakai dua layar terpisah, karena di sana layar pertama
///  juga memuat penjelasan bahwa nomor baru langsung dibuatkan akun.
///
///  Untuk driver itu tidak berlaku: akun driver DIBUAT ADMIN setelah verifikasi
///  dokumen, dan tidak ada pendaftaran mandiri. Yang tersisa hanya dua kolom,
///  dan dua kolom tidak butuh dua layar — terutama untuk orang yang membukanya
///  sambil bersiap berangkat kerja.
/// ============================================================================
///
/// ============================================================================
///  BENTUK V2: HERO COMPACT DI ATAS, FORMULIR DALAM KARTU DI BAWAH
/// ============================================================================
///  Judul dan paragraf penjelasan hidup di [ClayHeroHeader] compact — bidang
///  gradien aksen driver yang menyambung dengan `DriverWelcomeScreen`, supaya
///  perpindahan welcome→login tidak terasa turun kelas ke formulir polos.
///  Kolom-kolomnya dikumpulkan dalam SATU kartu clay: kolom kode yang muncul
///  belakangan membesar dari DALAM kartu lewat [AnimatedSize], bukan
///  menambah kartu baru yang menggeser tombol tanpa peringatan.
/// ============================================================================
class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final TextEditingController _nomor = TextEditingController();
  final TextEditingController _kode = TextEditingController();

  /// Aksen aplikasi driver — hijau tua yang sama dengan ikon peluncurnya
  /// dan hero `DriverWelcomeScreen`.
  static const Color _aksen = Color(0xFF057A55);

  Timer? _hitungan;
  int _sisaKirimUlang = 0;
  bool _tahapKode = false;
  String? _galat;

  @override
  void dispose() {
    _hitungan?.cancel();
    _nomor.dispose();
    _kode.dispose();
    super.dispose();
  }

  void _mulaiHitungan(int detik) {
    _sisaKirimUlang = detik;

    _hitungan?.cancel();
    _hitungan = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();

        return;
      }

      setState(() {
        _sisaKirimUlang = _sisaKirimUlang > 0 ? _sisaKirimUlang - 1 : 0;
      });

      if (_sisaKirimUlang == 0) {
        t.cancel();
      }
    });
  }

  Future<void> _mintaKode() async {
    if (!PhoneDisplay.looksComplete(_nomor.text)) {
      setState(() => _galat = 'Nomor HP belum lengkap.');

      return;
    }

    final SessionController sesi = context.read<SessionController>();

    final bool berhasil = await sesi.requestOtp(
      PhoneDisplay.clean(_nomor.text),
    );

    if (!mounted) {
      return;
    }

    if (!berhasil) {
      setState(() {
        _galat = sesi.lastFailure?.message ?? 'Tidak bisa mengirim kode.';
      });

      return;
    }

    setState(() {
      _tahapKode = true;
      _galat = null;
    });

    _mulaiHitungan(sesi.challenge?.resendAfterSeconds ?? 60);
  }

  Future<void> _verifikasi() async {
    final SessionController sesi = context.read<SessionController>();

    final bool berhasil = await sesi.verifyOtp(
      phone: PhoneDisplay.clean(_nomor.text),
      code: _kode.text.trim(),
    );

    if (!mounted || berhasil) {
      // Kalau berhasil, gerbang di akar yang mengganti layarnya. Tidak ada
      // navigasi di sini.
      return;
    }

    setState(() {
      _galat = sesi.lastFailure?.message ?? 'Kode salah.';
      _kode.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final SessionController sesi = context.watch<SessionController>();
    final OtpChallenge? tantangan = sesi.challenge;

    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      /*
       * Hero gradien gelap menembus status bar, jadi ikon jam/baterai harus
       * putih selama layar ini hidup — di kedua mode tema, karena gradiennya
       * sama di kedua mode. Hanya status bar yang disentuh; bilah navigasi
       * bawah dibiarkan mengikuti tema.
       */
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ClayEntrance(
                index: 0,
                child: ClayHeroHeader(
                  accent: _aksen,
                  compact: true,
                  title: 'Masuk sebagai driver',

                  // Menyebutkan bahwa tidak ada pendaftaran mandiri. Tanpa ini,
                  // orang yang belum terdaftar akan mencari tombol daftar,
                  // menekan "masuk" dengan nomor yang belum ada, dan
                  // menyimpulkan aplikasinya rusak.
                  subtitle:
                      'Akun driver dibuat oleh tim Antaride setelah dokumen '
                      'Anda diverifikasi. Belum punya akun? Hubungi kantor '
                      'Antaride Medan.',
                  leading: const ClayBackButton(),
                  trailing: const _TileKaca(icon: Icons.badge_rounded),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  ClayTokens.space6,
                  ClayTokens.space6,
                  ClayTokens.space6,
                  ClayTokens.space6 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ClayEntrance(
                      index: 1,
                      child: ClaySurface(
                        depth: ClayDepth.medium,
                        radius: ClayTokens.radiusLarge,
                        padding: const EdgeInsets.all(ClayTokens.space5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            ClayInput(
                              controller: _nomor,
                              label: 'Nomor HP terdaftar',
                              hint: '0812 3456 7890',
                              prefixIcon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,

                              // Nomor dikunci setelah kode dikirim. Kalau
                              // tidak, driver bisa mengubah nomornya lalu
                              // memverifikasi kode dengan nomor yang berbeda —
                              // dan yang terjadi adalah "kode selalu salah"
                              // yang tidak menunjuk ke penyebabnya.
                              enabled: !_tahapKode && !sesi.isBusy,
                              letterSpacing: 0.5,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+ ]'),
                                ),
                                LengthLimitingTextInputFormatter(20),
                              ],
                              errorText: _tahapKode ? null : _galat,
                              onSubmitted: (String _) => _mintaKode(),
                            ),

                            /*
                             * Kolom kode membesar dari dalam kartu, bukan
                             * muncul mendadak: AnimatedSize membuat kartunya
                             * tumbuh halus saat _tahapKode menyala, sehingga
                             * tombol di bawahnya bergeser mengikuti — bukan
                             * melompat.
                             */
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  if (_tahapKode) ...<Widget>[
                                    const SizedBox(height: ClayTokens.space4),
                                    ClayInput(
                                      controller: _kode,
                                      label: 'Kode dari SMS',
                                      hint: '••••••',
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      letterSpacing: 12,
                                      maxLength: 6,
                                      autofocus: true,
                                      enabled: !sesi.isBusy,
                                      errorText: _galat,
                                      inputFormatters: <TextInputFormatter>[
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (String nilai) {
                                        if (nilai.length == 6 && !sesi.isBusy) {
                                          _verifikasi();
                                        }
                                      },
                                      onSubmitted: (String _) => _verifikasi(),
                                    ),

                                    if (tantangan != null) ...<Widget>[
                                      const SizedBox(height: ClayTokens.space2),
                                      Text(
                                        'Dikirim ke ${tantangan.phoneMasked}',
                                        style: TextStyle(
                                          fontFamily: ClayTokens.fontFamily,
                                          fontSize: 11.5,
                                          color: gelap
                                              ? ClayTokens.textTertiaryDark
                                              : ClayTokens.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: ClayTokens.space5),

                    ClayEntrance(
                      index: 2,
                      child: ClayButton(
                        label: _tahapKode ? 'Mulai bekerja' : 'Kirim kode',
                        icon: _tahapKode
                            ? Icons.login_rounded
                            : Icons.arrow_forward_rounded,
                        isLoading: sesi.isBusy,

                        // Tombol driver lebih tinggi dari bawaan. Dipakai
                        // dengan sarung tangan dan sambil berdiri di dekat
                        // kendaraan; target sentuh yang pas-pasan menghasilkan
                        // tekanan yang tidak terdaftar.
                        height: ClayTokens.driverPrimaryButtonHeight,
                        onPressed: sesi.isBusy
                            ? null
                            : (_tahapKode ? _verifikasi : _mintaKode),
                      ),
                    ),

                    /*
                     * Daftar akun demo.
                     *
                     * Menyembunyikan dirinya sendiri kalau fiturnya dimatikan
                     * di server — lihat docblock `DemoAccountPicker`. Jadi aman
                     * dibiarkan di build produksi. ClayEntrance di sini hanya
                     * animasi masuk, bukan kondisi baru.
                     */
                    const ClayEntrance(
                      index: 3,
                      child: DemoAccountPicker(role: 'driver'),
                    ),

                    if (_tahapKode) ...<Widget>[
                      const SizedBox(height: ClayTokens.space4),
                      Center(
                        child: _sisaKirimUlang > 0
                            // Hitung mundur dalam pill clay tenggelam: keadaan
                            // "belum bisa" yang terlihat sebagai keadaan, bukan
                            // teks polos yang seolah tombol mati.
                            ? ClaySurface(
                                depth: ClayDepth.pressed,
                                radius: ClayTokens.radiusPill,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ClayTokens.space4,
                                  vertical: ClayTokens.space2,
                                ),
                                child: Text(
                                  'Kirim ulang dalam $_sisaKirimUlang detik',
                                  style: TextStyle(
                                    fontFamily: ClayTokens.fontFamily,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: gelap
                                        ? ClayTokens.textTertiaryDark
                                        : ClayTokens.textTertiary,
                                  ),
                                ),
                              )
                            : TextButton(
                                onPressed: sesi.isBusy ? null : _mintaKode,
                                child: const Text('Kirim ulang kode'),
                              ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: sesi.isBusy
                              ? null
                              : () => setState(() {
                                  _tahapKode = false;
                                  _galat = null;
                                  _kode.clear();
                                }),
                          child: const Text('Ganti nomor'),
                        ),
                      ),
                    ],

                    if (AppConfig.showDevTools &&
                        tantangan?.debugCode != null) ...<Widget>[
                      const SizedBox(height: ClayTokens.space5),
                      ClaySurface(
                        depth: ClayDepth.pressed,
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.construction_rounded,
                              size: 18,
                              color: ClayTokens.warning,
                            ),
                            const SizedBox(width: ClayTokens.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'MODE PENGEMBANGAN',
                                    style: TextStyle(
                                      fontFamily: ClayTokens.fontFamily,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: ClayTokens.warning,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kode: ${tantangan!.debugCode}',
                                    style: TextStyle(
                                      fontFamily: ClayTokens.fontFamily,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 3,
                                      fontFeatures: const <FontFeature>[
                                        FontFeature.tabularFigures(),
                                      ],
                                      color: gelap
                                          ? ClayTokens.textPrimaryDark
                                          : ClayTokens.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile kaca buram untuk DI DALAM hero: ikon putih di kotak putih-transparan.
///
/// Bahasa yang sama dengan mark logo welcome dan [ClayBackButton] (putih
/// alpha 0.16, border 0.22) — di atas gradien pekat, kaca buram terbaca
/// sebagai bagian dari bidangnya, bukan stiker yang ditempel. Lokal di berkas
/// ini karena `antaride_ui` belum mengekspor tile kaca sebagai komponen.
class _TileKaca extends StatelessWidget {
  const _TileKaca({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}
