import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
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
class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final TextEditingController _nomor = TextEditingController();
  final TextEditingController _kode = TextEditingController();

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ClayTokens.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: ClayTokens.space8),

              ClaySurface(
                depth: ClayDepth.high,
                radius: ClayTokens.radiusLarge,
                padding: const EdgeInsets.all(ClayTokens.space5),
                width: 84,
                child: const Icon(
                  Icons.badge_rounded,
                  size: 38,
                  color: ClayTokens.primary,
                ),
              ),

              const SizedBox(height: ClayTokens.space6),

              Text(
                'Masuk sebagai driver',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: gelap
                      ? ClayTokens.textPrimaryDark
                      : ClayTokens.textPrimary,
                ),
              ),

              const SizedBox(height: ClayTokens.space2),

              Text(
                // Menyebutkan bahwa tidak ada pendaftaran mandiri. Tanpa ini,
                // orang yang belum terdaftar akan mencari tombol daftar,
                // menekan "masuk" dengan nomor yang belum ada, dan menyimpulkan
                // aplikasinya rusak.
                'Akun driver dibuat oleh tim Antaride setelah dokumen Anda '
                'diverifikasi. Belum punya akun? Hubungi kantor Antaride Medan.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  height: 1.5,
                  color: gelap
                      ? ClayTokens.textSecondaryDark
                      : ClayTokens.textSecondary,
                ),
              ),

              const SizedBox(height: ClayTokens.space6),

              ClayInput(
                controller: _nomor,
                label: 'Nomor HP terdaftar',
                hint: '0812 3456 7890',
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,

                // Nomor dikunci setelah kode dikirim. Kalau tidak, driver bisa
                // mengubah nomornya lalu memverifikasi kode dengan nomor yang
                // berbeda — dan yang terjadi adalah "kode selalu salah" yang
                // tidak menunjuk ke penyebabnya.
                enabled: !_tahapKode && !sesi.isBusy,
                letterSpacing: 0.5,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                errorText: _tahapKode ? null : _galat,
                onSubmitted: (String _) => _mintaKode(),
              ),

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
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      color: ClayTokens.textTertiary,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: ClayTokens.space6),

              ClayButton(
                label: _tahapKode ? 'Mulai bekerja' : 'Kirim kode',
                icon: _tahapKode
                    ? Icons.login_rounded
                    : Icons.arrow_forward_rounded,
                isLoading: sesi.isBusy,

                // Tombol driver lebih tinggi dari bawaan. Dipakai dengan sarung
                // tangan dan sambil berdiri di dekat kendaraan; target sentuh
                // yang pas-pasan menghasilkan tekanan yang tidak terdaftar.
                height: ClayTokens.driverPrimaryButtonHeight,
                onPressed: sesi.isBusy
                    ? null
                    : (_tahapKode ? _verifikasi : _mintaKode),
              ),

              if (_tahapKode) ...<Widget>[
                const SizedBox(height: ClayTokens.space4),
                Center(
                  child: _sisaKirimUlang > 0
                      ? Text(
                          'Kirim ulang dalam $_sisaKirimUlang detik',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            color: ClayTokens.textTertiary,
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
                  child: Text(
                    'Mode pengembangan — kode: ${tantangan!.debugCode}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ClayTokens.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
