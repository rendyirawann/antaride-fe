import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:flutter/material.dart';

import 'phone_screen.dart';

/// Layar pembuka aplikasi penumpang.
///
/// ============================================================================
///  "MASUK" DAN "DAFTAR" MENUJU LAYAR YANG SAMA, DAN ITU DISENGAJA
/// ============================================================================
///  Autentikasi di Antaride memakai OTP: yang dimasukkan pengguna nomor HP-nya,
///  dan backend yang menentukan apakah nomor itu sudah terdaftar. Tidak ada
///  kata sandi, jadi tidak ada perbedaan teknis antara masuk dan mendaftar.
///
///  Yang membedakan keduanya di sini hanya KALIMATNYA — dan itu bukan hiasan.
///  Orang yang menekan "Daftar" perlu diberi tahu bahwa dia akan menerima kode,
///  bukan diminta membuat sandi. Orang yang menekan "Masuk" tidak perlu
///  penjelasan itu.
///
///  Alternatifnya — satu tombol "Lanjutkan" — bekerja, tapi membuat orang yang
///  belum punya akun ragu apakah aplikasi ini bisa dia pakai sama sekali.
/// ============================================================================
class CustomerWelcomeScreen extends StatelessWidget {
  const CustomerWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WelcomeScreen(
      title: 'Antaride',
      tagline:
          'Ojek, mobil, dan kirim barang di Medan. Satu aplikasi, harga '
          'terlihat sebelum Anda memesan.',

      points: const <WelcomePoint>[
        WelcomePoint(
          icon: Icons.receipt_long_rounded,
          title: 'Harga pasti di depan',
          body:
              'Ongkosnya dihitung sebelum Anda menekan pesan, bukan setelah '
              'sampai tujuan.',
        ),
        WelcomePoint(
          icon: Icons.near_me_rounded,
          title: 'Pantau driver di peta',
          body: 'Lihat posisi driver bergerak dari penjemputan sampai tujuan.',
        ),
        WelcomePoint(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Tunai atau dompet',
          body: 'Bayar dengan uang tunai ke driver, atau potong saldo dompet.',
        ),
      ],

      onRegister: () => _buka(context, daftar: true),
      onLogin: () => _buka(context, daftar: false),
    );
  }

  void _buka(BuildContext context, {required bool daftar}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) =>
            TutupSaatMasuk(child: PhoneScreen(mendaftar: daftar)),
      ),
    );
  }
}
