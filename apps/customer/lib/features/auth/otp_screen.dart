import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Layar kedua: masukkan kode OTP.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone, this.namaBaru});

  /// Nomor yang sudah dibersihkan, seperti yang dikirim ke backend.
  final String phone;

  /// Nama dari halaman daftar, disimpan ke profil SETELAH verifikasi berhasil.
  ///
  /// ==========================================================================
  ///  KENAPA SETELAH, BUKAN SAAT VERIFIKASI
  /// ==========================================================================
  ///  Endpoint verifikasi tidak menerima nama — dan memang tidak boleh: nomor
  ///  yang SUDAH terdaftar juga melewati endpoint yang sama, dan nama dari
  ///  formulir daftar tidak boleh menimpa nama akun lama hanya karena
  ///  pemiliknya menekan "Daftar" alih-alih "Masuk"... kecuali dia memang baru.
  ///
  ///  Backend menamai akun BARU "Pengguna 1234" (empat digit terakhir nomor).
  ///  Nama dari sini hanya dipakai menggantikan nama tiruan itu — akun lama
  ///  yang namanya sudah diisi tidak disentuh.
  /// ==========================================================================
  final String? namaBaru;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _kode = TextEditingController();

  Timer? _hitungan;
  int _sisaKirimUlang = 0;
  String? _galatKolom;

  @override
  void initState() {
    super.initState();

    _mulaiHitungan();
  }

  @override
  void dispose() {
    _hitungan?.cancel();
    _kode.dispose();
    super.dispose();
  }

  /// Hitungan mundur tombol kirim ulang.
  ///
  /// ==========================================================================
  ///  ANGKA AWALNYA DARI BACKEND, BUKAN DITULIS DI SINI
  /// ==========================================================================
  ///  Jeda kirim ulang ditegakkan backend per NOMOR — bukan per perangkat, dan
  ///  bukan per IP. Hitungan di aplikasi hanya cermin dari itu.
  ///
  ///  Kalau angkanya ditulis di aplikasi dan berbeda dari backend, ada dua arah
  ///  yang keduanya buruk: lebih pendek berarti tombolnya aktif tapi ditolak;
  ///  lebih panjang berarti pengguna menunggu lebih lama daripada perlu.
  /// ==========================================================================
  void _mulaiHitungan() {
    final OtpChallenge? tantangan = context.read<SessionController>().challenge;

    _sisaKirimUlang = tantangan?.resendAfterSeconds ?? 60;

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

  Future<void> _verifikasi() async {
    final String kode = _kode.text.trim();

    if (kode.length < 4) {
      setState(() {
        _galatKolom = 'Kode belum lengkap.';
      });

      return;
    }

    final SessionController sesi = context.read<SessionController>();

    final bool berhasil = await sesi.verifyOtp(phone: widget.phone, code: kode);

    if (!mounted) {
      return;
    }

    if (!berhasil) {
      final ApiFailure? galat = sesi.lastFailure;

      setState(() {
        _galatKolom =
            galat?.fieldErrors['code'] ??
            galat?.message ??
            'Kode salah. Coba lagi.';
      });

      // Kolomnya dikosongkan supaya pengguna tidak harus menghapus enam digit
      // sebelum mengetik ulang. Kode yang salah tidak ada gunanya dipertahankan.
      _kode.clear();

      return;
    }

    await _simpanNamaBaru(sesi);

    if (!mounted) {
      return;
    }

    /*
     * TIDAK ada navigasi ke beranda di sini.
     *
     * Gerbang di akar aplikasi mengamati `SessionStage`, dan begitu tahapnya
     * menjadi `signedIn` seluruh tumpukan navigasi diganti oleh AppShell.
     *
     * Yang dilakukan di sini hanya membuang layar ini dari tumpukan, supaya
     * tombol kembali sistem tidak membawa pengguna balik ke layar OTP yang
     * kodenya sudah terpakai.
     */
    Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
  }

  /// Simpan nama dari halaman daftar — hanya kalau akunnya memang masih
  /// bernama tiruan.
  ///
  /// Kegagalan di sini SENGAJA tidak menghalangi apa pun: pengguna sudah
  /// masuk, dan namanya bisa diganti kapan saja dari menu profil. Galat yang
  /// menahan orang di layar OTP setelah kodenya diterima jauh lebih buruk
  /// daripada nama tiruan yang bertahan sebentar.
  Future<void> _simpanNamaBaru(SessionController sesi) async {
    final String? nama = widget.namaBaru?.trim();

    if (nama == null || nama.isEmpty) {
      return;
    }

    // "Pengguna 1234" adalah nama buatan backend untuk akun baru. Akun LAMA
    // yang mendaftar ulang lewat tombol Daftar namanya bukan itu — dan nama
    // lamanya tidak boleh ditimpa formulir daftar.
    final String sekarang = sesi.user?.name ?? '';

    if (!RegExp(r'^Pengguna \d{4}$').hasMatch(sekarang)) {
      return;
    }

    await sesi.updateProfile(name: nama);
  }

  Future<void> _kirimUlang() async {
    final SessionController sesi = context.read<SessionController>();

    final bool berhasil = await sesi.requestOtp(widget.phone);

    if (!mounted) {
      return;
    }

    if (berhasil) {
      _mulaiHitungan();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode baru sudah dikirim.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sesi.lastFailure?.message ?? 'Tidak bisa mengirim ulang kode.',
        ),
        backgroundColor: ClayTokens.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final SessionController sesi = context.watch<SessionController>();
    final OtpChallenge? tantangan = sesi.challenge;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ClayTokens.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Masukkan kode',
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
                // Nomor TERSAMARKAN dari backend, bukan nomor penuh. Aplikasi
                // sudah tahu nomor yang dia kirim; nomor penuh di layar hanya
                // menambah yang bisa dibaca orang di sekitar.
                'Kami kirim ke ${tantangan?.phoneMasked ?? widget.phone}',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: gelap
                      ? ClayTokens.textSecondaryDark
                      : ClayTokens.textSecondary,
                ),
              ),

              const SizedBox(height: ClayTokens.space8),

              ClayInput(
                controller: _kode,
                label: 'Kode 6 digit',
                hint: '••••••',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                letterSpacing: 12,
                maxLength: 6,
                autofocus: true,
                errorText: _galatKolom,
                enabled: !sesi.isBusy,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (String nilai) {
                  if (_galatKolom != null) {
                    setState(() {
                      _galatKolom = null;
                    });
                  }

                  // Kirim otomatis setelah digit keenam. Menekan tombol setelah
                  // mengetik enam digit adalah langkah yang tidak menambah apa
                  // pun — dan pada keypad kecil, tombolnya sering tertutup
                  // keyboard.
                  if (nilai.length == 6 && !sesi.isBusy) {
                    _verifikasi();
                  }
                },
                onSubmitted: (String _) => _verifikasi(),
              ),

              const SizedBox(height: ClayTokens.space5),

              ClayButton(
                label: 'Verifikasi',
                isLoading: sesi.isBusy,
                onPressed: sesi.isBusy ? null : _verifikasi,
              ),

              const SizedBox(height: ClayTokens.space5),

              Center(
                child: _sisaKirimUlang > 0
                    ? Text(
                        'Kirim ulang dalam $_sisaKirimUlang detik',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: gelap
                              ? ClayTokens.textTertiaryDark
                              : ClayTokens.textTertiary,
                        ),
                      )
                    : TextButton(
                        onPressed: sesi.isBusy ? null : _kirimUlang,
                        child: const Text('Kirim ulang kode'),
                      ),
              ),

              /*
               * Kode debug HANYA di lingkungan non-produksi.
               *
               * Backend mengirimnya saat gateway SMS belum aktif supaya
               * pengembangan tidak terhenti menunggu SMS yang tidak pernah
               * datang. Dua penjaga di sini: field-nya tidak dikirim di
               * produksi, DAN `showDevTools` false di produksi. Satu penjaga
               * saja cukup — dua karena yang dipertaruhkan adalah kode masuk
               * yang tampil di layar pengguna sungguhan.
               */
              if (AppConfig.showDevTools &&
                  tantangan?.debugCode != null) ...<Widget>[
                const SizedBox(height: ClayTokens.space6),
                ClaySurface(
                  depth: ClayDepth.pressed,
                  color: gelap ? null : const Color(0xFFFEF3C7),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.construction_rounded,
                        size: 18,
                        color: ClayTokens.warning,
                      ),
                      const SizedBox(width: ClayTokens.space3),
                      Expanded(
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
