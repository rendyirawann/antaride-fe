import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';

import 'driver_login_screen.dart';

/// Layar pembuka aplikasi driver.
///
/// ============================================================================
///  "DAFTAR" DI SINI TIDAK MEMBUAT AKUN — DAN ITU HARUS TERLIHAT
/// ============================================================================
///  Akun driver dibuat tim Antaride setelah dokumen diverifikasi. Tidak ada
///  jalur pendaftaran mandiri, dan memang tidak boleh ada: yang menentukan
///  seorang driver boleh bekerja adalah verifikator yang memeriksa KTP, SIM, dan
///  STNK-nya.
///
///  Kalau tombolnya tetap bernama "Daftar" dan membuka layar nomor HP, yang
///  terjadi: calon driver memasukkan nomornya, menerima kode, masuk — lalu
///  mendapati aplikasi yang menolak setiap tindakan karena akunnya bukan akun
///  driver. Dia akan menyimpulkan aplikasinya rusak.
///
///  Karena itu tombolnya bernama "Cara jadi driver" dan membuka penjelasan,
///  bukan formulir. Ini satu-satunya aplikasi dari ketiganya yang alur
///  pembukanya berbeda.
/// ============================================================================
class DriverWelcomeScreen extends StatelessWidget {
  const DriverWelcomeScreen({super.key});

  /// Hijau gelap, sama dengan ikon aplikasi driver.
  static const Color _aksen = Color(0xFF057A55);

  @override
  Widget build(BuildContext context) {
    return WelcomeScreen(
      title: 'Antaride Driver',
      tagline:
          'Aplikasi untuk mitra pengemudi Antaride. Terima order, antar '
          'penumpang, dan lihat penghasilan Anda setiap hari.',

      accent: _aksen,

      points: const <WelcomePoint>[
        WelcomePoint(
          icon: Icons.notifications_active_rounded,
          title: 'Order langsung masuk',
          body:
              'Tawaran datang saat Anda online, lengkap dengan jarak dan '
              'perkiraan penghasilannya.',
        ),
        WelcomePoint(
          icon: Icons.route_rounded,
          title: 'Navigasi dan status perjalanan',
          body:
              'Peta penjemputan, kode verifikasi penumpang, sampai '
              'penyelesaian order.',
        ),
        WelcomePoint(
          icon: Icons.savings_rounded,
          title: 'Penghasilan terlihat langsung',
          body:
              'Setiap order tercatat di dompet Anda begitu perjalanannya '
              'selesai.',
        ),
      ],

      loginLabel: 'Masuk',
      registerLabel: 'Cara jadi driver',

      footer:
          'Akun driver dibuat tim Antaride setelah dokumen Anda diverifikasi. '
          'Belum bisa mendaftar sendiri dari aplikasi.',

      onLogin: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => const DriverLoginScreen(),
        ),
      ),

      onRegister: () => _jelaskanPendaftaran(context),
    );
  }

  /// Menjelaskan cara mendaftar, bukan membuka formulir.
  ///
  /// Sheet, bukan halaman baru: isinya pendek dan pembacanya akan kembali ke
  /// layar ini. Halaman penuh untuk empat kalimat membuat orang merasa dia
  /// sedang masuk ke alur yang panjang.
  void _jelaskanPendaftaran(BuildContext context) {
    ClayBottomSheet.show<void>(
      context: context,
      title: 'Cara jadi driver Antaride',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Langkah(
            nomor: 1,
            teks:
                'Siapkan KTP, SIM C yang masih berlaku, STNK kendaraan, dan '
                'foto selfie.',
          ),
          const _Langkah(
            nomor: 2,
            teks:
                'Hubungi tim Antaride untuk pendaftaran. Nomor HP yang Anda '
                'berikan akan menjadi akun Anda.',
          ),
          const _Langkah(
            nomor: 3,
            teks:
                'Setelah akun dibuat, masuk lewat tombol Masuk dan unggah '
                'dokumen Anda dari menu Dokumen Saya.',
          ),
          const _Langkah(
            nomor: 4,
            teks:
                'Tim verifikasi memeriksa dokumen Anda, biasanya dalam '
                '1×24 jam. Setelah disetujui, Anda bisa mulai bekerja.',
          ),

          const SizedBox(height: ClayTokens.space4),

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

class _Langkah extends StatelessWidget {
  const _Langkah({required this.nomor, required this.teks});

  final int nomor;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: ClayTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: ClayTokens.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$nomor',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: ClayTokens.space3),
          Expanded(
            child: Text(
              teks,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                height: 1.5,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
