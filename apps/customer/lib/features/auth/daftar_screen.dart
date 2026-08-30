import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'otp_screen.dart';

/// Halaman daftar: nama lengkap + nomor HP.
///
/// ============================================================================
///  KENAPA SEKARANG LAYAR TERSENDIRI, PADAHAL DULU DISATUKAN DENGAN MASUK
/// ============================================================================
///  Secara teknis OTP memang tidak membedakan masuk dan daftar — backend yang
///  tahu nomornya sudah terdaftar atau belum. Versi pertama layar ini karena
///  itu satu layar dengan dua kalimat.
///
///  Yang membuatnya dipisah: PENDAFTARAN PUNYA DATA YANG MASUK TIDAK PUNYA.
///  Backend membuat akun baru dengan nama tiruan ("Pengguna 1234", dari empat
///  digit terakhir nomornya), dan tanpa layar ini satu-satunya cara
///  menggantinya adalah menemukan menu profil — yang tidak dicari siapa pun
///  sampai drivernya memanggil "Pengguna 1234" di telepon.
///
///  Nama diminta DI SINI, sebelum OTP, bukan sesudahnya: sesudah OTP pengguna
///  sudah masuk, dan layar tambahan antara "berhasil" dan beranda terasa
///  seperti penghalang. Nama yang diketik dibawa `OtpScreen` dan disimpan
///  setelah verifikasi berhasil.
/// ============================================================================
class DaftarScreen extends StatefulWidget {
  const DaftarScreen({super.key});

  @override
  State<DaftarScreen> createState() => _DaftarScreenState();
}

class _DaftarScreenState extends State<DaftarScreen> {
  final TextEditingController _nama = TextEditingController();
  final TextEditingController _nomor = TextEditingController();

  String? _galatNama;
  String? _galatNomor;

  @override
  void dispose() {
    _nama.dispose();
    _nomor.dispose();
    super.dispose();
  }

  Future<void> _daftar() async {
    final String nama = _nama.text.trim();
    final String mentah = _nomor.text;

    // Dua kolom divalidasi SEKALIGUS, bukan berhenti di yang pertama salah.
    // Berhenti di kolom pertama berarti pengguna memperbaiki nama, menekan
    // tombol, baru diberi tahu nomornya juga salah — dua putaran untuk satu
    // formulir dua kolom.
    setState(() {
      _galatNama = nama.length < 2 ? 'Isi nama Anda dulu.' : null;
      _galatNomor = !PhoneDisplay.looksComplete(mentah)
          ? 'Nomor HP belum lengkap.'
          : null;
    });

    if (_galatNama != null || _galatNomor != null) {
      return;
    }

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

      if (galat != null && galat.isValidation) {
        setState(() {
          _galatNomor = galat.fieldErrors['phone'] ?? galat.message;
        });

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            galat?.message ?? 'Tidak bisa mengirim kode. Coba lagi.',
          ),
          backgroundColor: ClayTokens.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => OtpScreen(phone: phone, namaBaru: nama),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ClayTokens.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: ClayTokens.space4),

              ClaySurface(
                depth: ClayDepth.high,
                radius: ClayTokens.radiusLarge,
                padding: const EdgeInsets.all(ClayTokens.space5),
                width: 84,
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 40,
                  color: ClayTokens.primary,
                ),
              ),

              const SizedBox(height: ClayTokens.space6),

              Text(
                'Buat akun baru',
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
                'Tidak perlu kata sandi — kami kirim kode verifikasi ke nomor '
                'HP Anda.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  height: 1.5,
                  color: gelap
                      ? ClayTokens.textSecondaryDark
                      : ClayTokens.textSecondary,
                ),
              ),

              const SizedBox(height: ClayTokens.space6),

              ClayInput(
                controller: _nama,
                label: 'Nama lengkap',
                hint: 'Nama yang dilihat driver',
                prefixIcon: Icons.badge_rounded,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                errorText: _galatNama,
                enabled: !sibuk,
                onChanged: (String _) {
                  if (_galatNama != null) {
                    setState(() => _galatNama = null);
                  }
                },
              ),

              const SizedBox(height: ClayTokens.space4),

              ClayInput(
                controller: _nomor,
                label: 'Nomor HP',
                hint: '0812 3456 7890',
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                errorText: _galatNomor,
                enabled: !sibuk,
                letterSpacing: 0.5,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                onChanged: (String _) {
                  if (_galatNomor != null) {
                    setState(() => _galatNomor = null);
                  }
                },
                onSubmitted: (String _) => _daftar(),
              ),

              const SizedBox(height: ClayTokens.space6),

              ClayButton(
                label: 'Daftar',
                icon: Icons.arrow_forward_rounded,
                isLoading: sibuk,
                onPressed: sibuk ? null : _daftar,
              ),

              const SizedBox(height: ClayTokens.space6),

              Text(
                'Dengan mendaftar, Anda menyetujui Syarat Layanan dan '
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
