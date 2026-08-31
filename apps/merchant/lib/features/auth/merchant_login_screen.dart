import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Masuk sebagai merchant: nomor lalu kode, dalam satu layar.
///
/// Sama seperti aplikasi driver: akun merchant dibuat tim Antaride setelah
/// verifikasi usaha, jadi tidak ada pendaftaran mandiri dan tidak perlu layar
/// terpisah untuk menjelaskannya.
///
/// ============================================================================
///  BENTUK V2: HERO AMBER DI ATAS, SATU KARTU FORMULIR DI BAWAH
/// ============================================================================
///  Versi lama adalah formulir di atas latar satu warna — tile ikon clay,
///  judul, paragraf, lalu kolom-kolom yang mengambang tanpa wadah. Yang
///  membuatnya terbaca sebagai "aplikasi template" bukan salah satu elemennya,
///  melainkan ketiadaan bidang warna sama sekali.
///
///  Sekarang judul dan paragraf pindah ke [ClayHeroHeader] compact beraksen
///  amber — aksen yang SAMA dengan `MerchantWelcomeScreen` dan ikon peluncur
///  merchant, sehingga perpindahan sambutan → masuk tidak terasa turun kelas.
///  Ikon storefront yang dulu hijau ikut pindah ke dalam hero sebagai tile
///  kaca: hijau `primary` di aplikasi beraksen amber adalah warna merek
///  aplikasi yang salah, dan itu terbaca bahkan oleh orang yang tidak tahu
///  kenapa.
///
///  Kolom nomor dan kolom kode dikumpulkan dalam SATU kartu clay. Kolom kode
///  membesar dari dalam kartu lewat [AnimatedSize] — dulu dia muncul mendadak
///  dan mendorong tombol ke bawah tanpa peringatan, sehingga tekanan jari
///  jatuh di tempat tombol yang sudah pindah.
/// ============================================================================
class MerchantLoginScreen extends StatefulWidget {
  const MerchantLoginScreen({super.key});

  @override
  State<MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<MerchantLoginScreen> {
  final TextEditingController _nomor = TextEditingController();
  final TextEditingController _kode = TextEditingController();

  /// Aksen aplikasi merchant — amber yang sama dengan ikon peluncurnya dan
  /// hero `MerchantWelcomeScreen`. Satu warna masuk; gradiennya diturunkan
  /// [ClayGradients], bukan dipilih terpisah.
  static const Color _aksen = ClayTokens.warning;

  bool _tahapKode = false;
  String? _galat;

  @override
  void dispose() {
    _nomor.dispose();
    _kode.dispose();
    super.dispose();
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

    setState(() {
      _tahapKode = berhasil;
      _galat = berhasil
          ? null
          : (sesi.lastFailure?.message ?? 'Tidak bisa mengirim kode.');
    });
  }

  Future<void> _verifikasi() async {
    final SessionController sesi = context.read<SessionController>();

    final bool berhasil = await sesi.verifyOtp(
      phone: PhoneDisplay.clean(_nomor.text),
      code: _kode.text.trim(),
    );

    if (!mounted || berhasil) {
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
       * Hero gradien pekat menembus status bar, jadi ikon jam dan baterai
       * harus putih selama layar ini hidup — di KEDUA mode tema, karena
       * gradiennya sama di keduanya. `ClayTheme` menyetel ikon status bar
       * gelap untuk mode terang; tanpa penimpaan ini, jam dan baterai hilang
       * di atas amber.
       */
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),

        // Hero ikut DI DALAM scroll, bukan dipaku di atasnya: saat keyboard
        // terbuka di HP pendek, hero boleh tergulir pergi supaya kolom kode
        // dan tombolnya tetap terlihat.
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ClayEntrance(
                index: 0,
                child: ClayHeroHeader(
                  accent: _aksen,
                  compact: true,
                  title: 'Masuk sebagai merchant',

                  // Menyebutkan bahwa tidak ada pendaftaran mandiri. Tanpa
                  // kalimat ini, pemilik usaha yang belum terdaftar mencari
                  // tombol daftar, menekan "Kirim kode" dengan nomor yang
                  // belum ada, lalu menyimpulkan aplikasinya rusak.
                  subtitle:
                      'Akun merchant dibuat tim Antaride setelah usaha Anda '
                      'diverifikasi. Belum terdaftar? Hubungi kantor Antaride '
                      'Medan.',

                  // Tombol kembali WAJIB ada: layar ini didorong di atas layar
                  // sambutan, dan tanpanya orang yang salah menekan "Masuk"
                  // terjebak di sini.
                  leading: ClayBackButton(),

                  trailing: _TileKaca(icon: Icons.storefront_rounded),
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

                              // Nomor dikunci setelah kode dikirim — perilaku
                              // lama, dipertahankan apa adanya.
                              enabled: !_tahapKode && !sesi.isBusy,
                              letterSpacing: 0.5,
                              errorText: _tahapKode ? null : _galat,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+ ]'),
                                ),
                                LengthLimitingTextInputFormatter(20),
                              ],
                              onSubmitted: (String _) => _mintaKode(),
                            ),

                            /*
                             * Kolom kode tumbuh dari DALAM kartu.
                             *
                             * Kondisinya persis sama dengan sebelumnya
                             * (`_tahapKode`); yang ditambahkan hanya
                             * AnimatedSize di sekelilingnya, supaya tinggi
                             * kartu beranjak halus dan tombol di bawahnya
                             * bergeser mengikuti, bukan melompat.
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

                                    // Nomor tersamarkan datang dari backend,
                                    // bukan dari kolom di atas: yang dikirimi
                                    // SMS adalah nomor yang DITERIMA server.
                                    if (tantangan != null) ...<Widget>[
                                      const SizedBox(height: ClayTokens.space2),
                                      Text(
                                        'Dikirim ke ${tantangan.phoneMasked}',
                                        textAlign: TextAlign.center,
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
                        label: _tahapKode ? 'Masuk' : 'Kirim kode',
                        icon: _tahapKode
                            ? Icons.login_rounded
                            : Icons.arrow_forward_rounded,
                        isLoading: sesi.isBusy,
                        onPressed: sesi.isBusy
                            ? null
                            : (_tahapKode ? _verifikasi : _mintaKode),
                      ),
                    ),

                    /*
                     * Daftar akun demo.
                     *
                     * Menyembunyikan dirinya sendiri kalau fiturnya dimatikan
                     * di server — lihat docblock `DemoAccountPicker`. Jadi
                     * aman dibiarkan di build produksi.
                     *
                     * SENGAJA tidak dibungkus ClayEntrance dan tidak digayakan
                     * ulang: geometri serta label tombolnya diukur widget-test
                     * di paket `antaride_onboarding`, dan widget ini
                     * dipertahankan persis apa adanya.
                     */
                    const DemoAccountPicker(role: 'merchant'),

                    if (AppConfig.showDevTools &&
                        tantangan?.debugCode != null) ...<Widget>[
                      const SizedBox(height: ClayTokens.space5),

                      /*
                       * Banner kode pengembangan.
                       *
                       * Kedua penjaganya (showDevTools DAN debugCode) tetap
                       * seperti sebelumnya. Gayanya dirapikan, TIDAK dibuat
                       * lebih mencolok: ini alat pengembang, bukan bagian dari
                       * alur masuk yang dilihat merchant sungguhan.
                       */
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
                                  const ClaySectionLabel('Mode pengembangan'),
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
/// Resep yang sama dengan mark logo welcome dan [ClayBackButton] (putih alpha
/// 0.16, bingkai 0.22) — di atas gradien pekat, kaca buram terbaca sebagai
/// bagian dari bidangnya, bukan stiker yang ditempel. Warnanya putih-alpha,
/// bukan warna pejal, supaya dia ikut aksen apa pun tanpa cabang warna.
///
/// Lokal di berkas ini karena `antaride_ui` belum mengekspor tile kaca sebagai
/// komponen; kalau nanti diekspor, kelas ini diganti komponen paketnya.
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
