import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:flutter/material.dart';

import 'daftar_screen.dart';
import 'phone_screen.dart';

/// Layar pembuka aplikasi penumpang.
///
/// "Masuk" dan "Daftar" menuju layar BERBEDA: masuk hanya butuh nomor, daftar
/// juga meminta nama. Alasan pemisahannya ada di docblock `DaftarScreen`.
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

      onRegister: () => _buka(context, const DaftarScreen()),
      onLogin: () => _buka(context, const PhoneScreen()),
    );
  }

  void _buka(BuildContext context, Widget layar) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => TutupSaatMasuk(child: layar),
      ),
    );
  }
}
