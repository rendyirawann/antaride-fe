import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Masuk sebagai merchant: nomor lalu kode, dalam satu layar.
///
/// Sama seperti aplikasi driver: akun merchant dibuat tim Antaride setelah
/// verifikasi usaha, jadi tidak ada pendaftaran mandiri dan tidak perlu layar
/// terpisah untuk menjelaskannya.
class MerchantLoginScreen extends StatefulWidget {
  const MerchantLoginScreen({super.key});

  @override
  State<MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<MerchantLoginScreen> {
  final TextEditingController _nomor = TextEditingController();
  final TextEditingController _kode = TextEditingController();

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
                  Icons.storefront_rounded,
                  size: 38,
                  color: ClayTokens.primary,
                ),
              ),

              const SizedBox(height: ClayTokens.space6),

              const Text(
                'Masuk sebagai merchant',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: ClayTokens.space2),

              const Text(
                'Akun merchant dibuat tim Antaride setelah usaha Anda '
                'diverifikasi. Belum terdaftar? Hubungi kantor Antaride Medan.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  height: 1.5,
                  color: ClayTokens.textSecondary,
                ),
              ),

              const SizedBox(height: ClayTokens.space6),

              ClayInput(
                controller: _nomor,
                label: 'Nomor HP terdaftar',
                hint: '0812 3456 7890',
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                enabled: !_tahapKode && !sesi.isBusy,
                letterSpacing: 0.5,
                errorText: _tahapKode ? null : _galat,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
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
              ],

              const SizedBox(height: ClayTokens.space6),

              ClayButton(
                label: _tahapKode ? 'Masuk' : 'Kirim kode',
                icon: _tahapKode
                    ? Icons.login_rounded
                    : Icons.arrow_forward_rounded,
                isLoading: sesi.isBusy,
                onPressed: sesi.isBusy
                    ? null
                    : (_tahapKode ? _verifikasi : _mintaKode),
              ),

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
