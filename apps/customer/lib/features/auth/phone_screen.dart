import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'otp_screen.dart';

/// Layar masuk: masukkan nomor HP yang terdaftar.
///
/// Pendaftaran hidup di layarnya sendiri (`DaftarScreen`) — pendaftaran punya
/// kolom yang masuk tidak punya (nama), dan alasan selengkapnya ada di docblock
/// layar itu. Keduanya bertemu lagi di `OtpScreen` yang sama.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final TextEditingController _nomor = TextEditingController();

  String? _galatKolom;

  @override
  void dispose() {
    _nomor.dispose();
    super.dispose();
  }

  Future<void> _lanjut() async {
    final String mentah = _nomor.text;

    if (!PhoneDisplay.looksComplete(mentah)) {
      setState(() {
        _galatKolom = 'Nomor HP belum lengkap.';
      });

      return;
    }

    setState(() {
      _galatKolom = null;
    });

    final SessionController sesi = context.read<SessionController>();

    // Dibersihkan dari spasi pengelompokan, TIDAK dinormalkan. Backend yang
    // mengubah `08...` menjadi `62...` — lihat PhoneDisplay.
    final String phone = PhoneDisplay.clean(mentah);

    final bool berhasil = await sesi.requestOtp(phone);

    if (!mounted) {
      return;
    }

    if (!berhasil) {
      final ApiFailure? galat = sesi.lastFailure;

      /*
       * Galat validasi ditampilkan DI KOLOM, bukan sebagai snackbar.
       *
       * "Nomor HP tidak valid" yang muncul di bawah lalu hilang sendiri tidak
       * memberi tahu apa yang harus diperbaiki, dan pengguna yang tidak
       * membacanya cukup cepat akan menekan tombolnya lagi dengan nomor yang
       * sama.
       */
      if (galat != null && galat.isValidation) {
        setState(() {
          _galatKolom = galat.fieldErrors['phone'] ?? galat.message;
        });

        return;
      }

      _tampilkanGalat(galat);

      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => OtpScreen(phone: phone),
      ),
    );
  }

  void _tampilkanGalat(ApiFailure? galat) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(galat?.message ?? 'Tidak bisa mengirim kode. Coba lagi.'),
        backgroundColor: ClayTokens.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final bool sibuk = context.select<SessionController, bool>(
      (SessionController s) => s.isBusy,
    );

    return Scaffold(
      /*
       * KENAPA hero gradien, bukan AppBar transparan seperti dulu.
       *
       * Desain v2: layar form sekunder memakai `ClayHeroHeader` compact —
       * judul dan pengantar pindah ke atas bidang gradien, sehingga bagian
       * atas layar bukan lagi latar polos satu warna.
       *
       * Tombol kembali TETAP ADA — sekarang `ClayBackButton` di leading hero.
       * Layar ini dibuka dari layar sambutan; tanpa tombol kembali, orang
       * yang menekan "Masuk" padahal belum punya akun terjebak.
       *
       * Hero ikut DI DALAM scroll, bukan dipaku di luar: saat keyboard
       * terbuka di HP pendek, hero bisa ikut tergulir sehingga kolom nomor
       * dan tombolnya tetap terlihat.
       */
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const ClayEntrance(
              index: 0,
              child: ClayHeroHeader(
                accent: ClayTokens.primary,
                compact: true,
                title: 'Masuk',
                subtitle:
                    'Masukkan nomor HP yang terdaftar. Kami kirim kode '
                    'verifikasi ke nomor itu.',
                leading: ClayBackButton(),
              ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(ClayTokens.space6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ClayEntrance(
                      index: 1,
                      child: ClayInput(
                        controller: _nomor,
                        label: 'Nomor HP',
                        hint: '0812 3456 7890',
                        prefixIcon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        errorText: _galatKolom,
                        enabled: !sibuk,
                        letterSpacing: 0.5,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        onChanged: (String _) {
                          if (_galatKolom != null) {
                            setState(() {
                              _galatKolom = null;
                            });
                          }
                        },
                        onSubmitted: (String _) => _lanjut(),
                      ),
                    ),

                    const SizedBox(height: ClayTokens.space6),

                    ClayEntrance(
                      index: 2,
                      child: ClayButton(
                        label: 'Kirim kode',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: sibuk,
                        onPressed: sibuk ? null : _lanjut,
                      ),
                    ),

                    /*
                     * Daftar akun demo.
                     *
                     * Menyembunyikan dirinya sendiri kalau fiturnya dimatikan
                     * di server — lihat docblock `DemoAccountPicker`. Jadi
                     * aman dibiarkan di build produksi.
                     *
                     * SENGAJA tidak dibungkus ClayEntrance: geometrinya
                     * diukur widget-test di paket antaride_onboarding, dan
                     * widget ini dipertahankan persis apa adanya.
                     */
                    const DemoAccountPicker(role: 'customer'),

                    const SizedBox(height: ClayTokens.space6),

                    ClayEntrance(
                      index: 3,
                      child: Text(
                        'Dengan melanjutkan, Anda menyetujui Syarat Layanan '
                        'dan Kebijakan Privasi Antaride.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: ClayTokens.fontFamily,
                          fontSize: 11.5,
                          height: 1.5,
                          color: gelap
                              ? ClayTokens.textTertiaryDark
                              : ClayTokens.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
