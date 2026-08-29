import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';

import 'merchant_login_screen.dart';

/// Layar pembuka aplikasi merchant.
///
/// ============================================================================
///  MENYEBUTKAN BATASNYA DI DEPAN, BUKAN SETELAH MASUK
/// ============================================================================
///  API merchant belum ada di Fase 1. Aplikasi ini baru punya masuk dan profil —
///  belum ada kelola menu, belum ada pesanan masuk.
///
///  Kalau layar pembuka menjanjikan ketiganya, yang masuk akan mencari menu yang
///  tidak ada dan menyimpulkan aplikasinya rusak. Yang disebut di sini apa yang
///  BISA dia lakukan sekarang, beserta satu kalimat jujur tentang yang menyusul.
///
///  Ini pilihan yang sama dengan layar profil merchant: menyatakan keadaannya,
///  bukan memalsukan sakelar yang tidak memanggil apa pun.
/// ============================================================================
class MerchantWelcomeScreen extends StatelessWidget {
  const MerchantWelcomeScreen({super.key});

  /// Amber, sama dengan ikon aplikasi merchant.
  static const Color _aksen = ClayTokens.warning;

  @override
  Widget build(BuildContext context) {
    return WelcomeScreen(
      title: 'Antaride Merchant',
      tagline:
          'Aplikasi untuk mitra usaha Antaride. Kelola toko Anda dan terima '
          'pesanan dari pelanggan di sekitar.',

      accent: _aksen,

      points: const <WelcomePoint>[
        WelcomePoint(
          icon: Icons.storefront_rounded,
          title: 'Profil toko',
          body: 'Lihat data toko Anda yang terdaftar di Antaride.',
        ),
        WelcomePoint(
          icon: Icons.restaurant_menu_rounded,
          title: 'Menu dan pesanan',
          body:
              'Kelola menu dan terima pesanan — menyusul di pembaruan '
              'berikutnya.',
        ),
        WelcomePoint(
          icon: Icons.insights_rounded,
          title: 'Ringkasan penjualan',
          body:
              'Rekap pesanan dan pendapatan harian — menyusul bersama fitur '
              'di atas.',
        ),
      ],

      loginLabel: 'Masuk',
      registerLabel: 'Cara jadi merchant',

      footer:
          'Akun merchant dibuat tim Antaride setelah data usaha Anda '
          'diverifikasi.',

      onLogin: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => const MerchantLoginScreen(),
        ),
      ),

      onRegister: () => _jelaskanPendaftaran(context),
    );
  }

  void _jelaskanPendaftaran(BuildContext context) {
    ClayBottomSheet.show<void>(
      context: context,
      title: 'Cara jadi merchant Antaride',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Pendaftaran merchant belum bisa dilakukan sendiri dari aplikasi. '
            'Hubungi tim Antaride dengan menyiapkan:\n\n'
            '  •  KTP pemilik usaha\n'
            '  •  Foto tempat usaha\n'
            '  •  Alamat lengkap dan titik lokasi\n'
            '  •  Nomor rekening untuk pencairan\n\n'
            'Setelah akun dibuat, masuk lewat tombol Masuk dengan nomor HP '
            'yang Anda daftarkan.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              height: 1.6,
              color: Theme.of(context).brightness == Brightness.dark
                  ? ClayTokens.textSecondaryDark
                  : ClayTokens.textSecondary,
            ),
          ),

          const SizedBox(height: ClayTokens.space5),

          ClayButton(
            label: 'Mengerti',
            onPressed: () => Navigator.of(context).pop(),
            expanded: true,
          ),
        ],
      ),
    );
  }
}
