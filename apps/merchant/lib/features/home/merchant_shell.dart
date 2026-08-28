import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Kerangka aplikasi merchant: sidebar dengan dua halaman.
class MerchantShell extends StatefulWidget {
  const MerchantShell({super.key});

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  int _halaman = 0;

  static const List<ClayDrawerItem> _menu = <ClayDrawerItem>[
    ClayDrawerItem(label: 'Outlet Saya', icon: Icons.storefront_rounded),
    ClayDrawerItem(label: 'Profil', icon: Icons.person_rounded),
  ];

  Future<void> _keluar() async {
    final bool? yakin = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Anda perlu memasukkan kode OTP lagi untuk masuk.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: ClayTokens.danger),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (yakin != true || !mounted) {
      return;
    }

    await context.read<SessionController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final AuthUser? user = context.select<SessionController, AuthUser?>(
      (SessionController s) => s.user,
    );

    return ClayDrawerShell(
      items: _menu,
      selectedIndex: _halaman,
      onSelect: (int i) => setState(() => _halaman = i),

      title: user?.name ?? 'Merchant Antaride',
      subtitle: user?.phone,
      avatarLabel: user?.initials,

      footerLabel: 'Keluar',
      onFooterTap: _keluar,

      pageBuilder: (BuildContext context, int index) => switch (index) {
        1 => const _Profil(),
        _ => const _Outlet(),
      },
    );
  }
}

/// Halaman outlet.
///
/// ============================================================================
///  MENYATAKAN RUANG LINGKUPNYA, BUKAN MEMALSUKAN LAYAR
/// ============================================================================
///  API Fase 1 belum punya satu pun endpoint merchant. Tabel merchant dan menu
///  sudah ada di database, dan backoffice sudah bisa mengelolanya — tapi tidak
///  ada jalur mobile untuk membuka-menutup outlet atau menerima order makanan.
///
///  Yang dilakukan di sini: menyebutkannya secara jelas.
///
///  Alternatifnya — layar dengan sakelar "Buka/Tutup Outlet" yang tidak
///  memanggil apa pun, atau daftar order yang selalu kosong — jauh lebih buruk.
///  Merchant akan menekannya, menyimpulkan pesanannya tidak masuk, dan menelepon
///  bantuan untuk fitur yang memang belum ada.
///
///  Halaman ini diganti begitu endpoint merchant tersedia. Sampai saat itu, dia
///  jujur.
/// ============================================================================
class _Outlet extends StatelessWidget {
  const _Outlet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(ClayTokens.space5),
        children: <Widget>[
          ClaySurface(
            depth: ClayDepth.high,
            radius: ClayTokens.radiusLarge,
            padding: const EdgeInsets.all(ClayTokens.space6),
            child: Column(
              children: <Widget>[
                const Icon(
                  Icons.storefront_rounded,
                  size: 40,
                  color: ClayTokens.primary,
                ),
                const SizedBox(height: ClayTokens.space4),
                const Text(
                  'Pengelolaan outlet belum aktif',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: ClayTokens.space3),
                const Text(
                  'Fase 1 Antaride mencakup ojek, taksi, dan kirim barang. '
                  'Pesan makanan dan pengelolaan menu masih dikerjakan.\n\n'
                  'Untuk sekarang, data outlet dan menu Anda dikelola tim '
                  'Antaride lewat backoffice. Hubungi kantor Antaride Medan '
                  'untuk perubahan apa pun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    height: 1.6,
                    color: ClayTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: ClayTokens.space5),

          const _Rencana(
            judul: 'Yang akan hadir',
            butir: <String>[
              'Buka dan tutup outlet dari HP',
              'Terima dan tolak pesanan makanan',
              'Ubah harga dan ketersediaan menu',
              'Ringkasan penjualan harian',
            ],
          ),
        ],
      ),
    );
  }
}

class _Rencana extends StatelessWidget {
  const _Rencana({required this.judul, required this.butir});

  final String judul;
  final List<String> butir;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.pressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            judul,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ClayTokens.space3),
          for (final String b in butir)
            Padding(
              padding: const EdgeInsets.only(bottom: ClayTokens.space2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: ClayTokens.textTertiary,
                  ),
                  const SizedBox(width: ClayTokens.space3),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        height: 1.45,
                        color: ClayTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Profil extends StatelessWidget {
  const _Profil();

  @override
  Widget build(BuildContext context) {
    final SessionController sesi = context.watch<SessionController>();
    final AuthUser? user = sesi.user;

    if (user == null) {
      return Scaffold(
        body: ClayErrorState(
          message: sesi.lastFailure?.message ?? 'Profil tidak bisa dimuat.',
          onRetry: sesi.refreshProfile,
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(ClayTokens.space5),
        children: <Widget>[
          ClaySurface(
            depth: ClayDepth.medium,
            radius: ClayTokens.radiusLarge,
            padding: const EdgeInsets.all(ClayTokens.space5),
            child: Row(
              children: <Widget>[
                ClaySurface(
                  depth: ClayDepth.pressed,
                  radius: ClayTokens.radiusPill,
                  padding: const EdgeInsets.all(ClayTokens.space4),
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ClayTokens.primary,
                    ),
                  ),
                ),
                const SizedBox(width: ClayTokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email ?? user.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          color: ClayTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: ClayTokens.space8),

          Center(
            child: Text(
              'Antaride Merchant'
              '${AppConfig.isProduction ? '' : ' · ${AppConfig.environment}'}',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: ClayTokens.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
