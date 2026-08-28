import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Layanan yang boleh dan yang sedang dinyalakan driver.
///
/// ============================================================================
///  DUA HAL BERBEDA YANG SERING TERCAMPUR
/// ============================================================================
///    `allowed`   keputusan ADMIN, biasanya bergantung kelengkapan dokumen.
///                Driver tidak bisa mengubahnya.
///    `enabled`   pilihan DRIVER sendiri.
///
///  Layanan yang belum diizinkan tetap DITAMPILKAN, dengan sakelar mati dan
///  terkunci beserta keterangannya. Menyembunyikannya membuat driver menyimpulkan
///  Antaride tidak punya layanan itu — dan dia tidak akan pernah tahu bahwa yang
///  kurang hanyalah satu dokumen.
/// ============================================================================
class DriverServicesScreen extends StatefulWidget {
  const DriverServicesScreen({super.key});

  @override
  State<DriverServicesScreen> createState() => _DriverServicesScreenState();
}

class _DriverServicesScreenState extends State<DriverServicesScreen> {
  List<DriverService> _layanan = const <DriverService>[];

  bool _memuat = true;
  bool _menyimpan = false;
  ApiFailure? _galat;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() async {
    if (!mounted) {
      return;
    }

    setState(() => _memuat = true);

    final AntarideServices services = context.read<AntarideServices>();

    final Result<List<DriverService>> hasil = await services.driver.services();

    if (!mounted) {
      return;
    }

    setState(() {
      _memuat = false;
      _layanan = hasil.valueOrNull ?? _layanan;
      _galat = hasil.failureOrNull;
    });
  }

  Future<void> _ubah(DriverService layanan, bool nyala) async {
    if (_menyimpan) {
      return;
    }

    setState(() => _menyimpan = true);

    final AntarideServices services = context.read<AntarideServices>();

    final Result<void> hasil = await services.driver.toggleService(
      code: layanan.code,
      enabled: nyala,
    );

    if (!mounted) {
      return;
    }

    setState(() => _menyimpan = false);

    if (hasil.isErr) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasil.failureOrNull?.message ?? 'Tidak bisa mengubah layanan.',
          ),
          backgroundColor: ClayTokens.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    // Dimuat ulang dari backend, bukan diubah di state lokal.
    //
    // Mematikan satu layanan juga mencabut driver dari indeks ketersediaan untuk
    // layanan itu, dan bisa mengubah hal lain yang tidak terlihat dari sini.
    // Menebaknya di aplikasi berarti layar yang menampilkan keadaan yang bukan
    // keadaan sebenarnya.
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat && _layanan.isEmpty) {
      return const Scaffold(body: ClaySkeletonList(itemHeight: 76));
    }

    if (_layanan.isEmpty) {
      return Scaffold(
        body: _galat != null
            ? ClayErrorState(message: _galat!.message, onRetry: _muat)
            : const ClayEmptyState(
                icon: Icons.tune_rounded,
                title: 'Belum ada layanan',
                message:
                    'Tim Antaride belum mengizinkan layanan apa pun untuk '
                    'akun Anda. Hubungi kantor Antaride Medan.',
              ),
      );
    }

    return Scaffold(
      body: ClayRefresh(
        onRefresh: _muat,
        child: ListView(
          padding: const EdgeInsets.all(ClayTokens.space5),
          children: <Widget>[
            const Text(
              'Nyalakan hanya layanan yang siap Anda kerjakan hari ini. '
              'Mematikan satu layanan langsung berlaku — Anda tidak akan lagi '
              'menerima tawaran untuk layanan itu.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                height: 1.5,
                color: ClayTokens.textSecondary,
              ),
            ),

            const SizedBox(height: ClayTokens.space5),

            for (final DriverService s in _layanan)
              ClayCard(
                depth: s.isActive ? ClayDepth.low : ClayDepth.flat,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.name,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: s.isAllowed
                                  ? null
                                  : ClayTokens.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.isAllowed
                                ? (s.isEnabled ? 'Aktif' : 'Dimatikan')
                                : 'Belum diizinkan — lengkapi dokumen Anda',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              color: s.isAllowed
                                  ? ClayTokens.textSecondary
                                  : ClayTokens.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.isActive,

                      // `null` mengunci sakelarnya. Sakelar yang bisa digeser
                      // lalu memantul kembali terbaca sebagai bug; yang terkunci
                      // dengan keterangan di sebelahnya terbaca sebagai aturan.
                      onChanged: s.isAllowed && !_menyimpan
                          ? (bool nyala) => _ubah(s, nyala)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
