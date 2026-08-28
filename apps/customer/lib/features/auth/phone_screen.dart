import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'otp_screen.dart';

/// Layar pertama: masukkan nomor HP.
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ClayTokens.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: ClayTokens.space10),

              ClaySurface(
                depth: ClayDepth.high,
                radius: ClayTokens.radiusLarge,
                padding: const EdgeInsets.all(ClayTokens.space5),
                width: 84,
                child: const Icon(
                  Icons.two_wheeler_rounded,
                  size: 40,
                  color: ClayTokens.primary,
                ),
              ),

              const SizedBox(height: ClayTokens.space8),

              Text(
                'Masuk atau daftar',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: gelap
                      ? ClayTokens.textPrimaryDark
                      : ClayTokens.textPrimary,
                ),
              ),

              const SizedBox(height: ClayTokens.space2),

              Text(
                // Menyebutkan bahwa satu alur menangani keduanya. Tanpa ini,
                // pengguna baru akan mencari tombol "daftar" yang tidak ada,
                // lalu menyimpulkan dia harus punya akun lebih dulu.
                'Kami kirim kode ke nomor Anda. Nomor baru langsung dibuatkan '
                'akun.',
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

              ClayInput(
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

              const SizedBox(height: ClayTokens.space6),

              ClayButton(
                label: 'Kirim kode',
                icon: Icons.arrow_forward_rounded,
                isLoading: sibuk,
                onPressed: sibuk ? null : _lanjut,
              ),

              const SizedBox(height: ClayTokens.space6),

              Text(
                'Dengan melanjutkan, Anda menyetujui Syarat Layanan dan '
                'Kebijakan Privasi Antaride.',
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
          ),
        ),
      ),
    );
  }
}
