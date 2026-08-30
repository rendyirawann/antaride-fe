import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Aksen aplikasi merchant.
///
/// Amber, sama dengan ikon peluncur, `MerchantWelcomeScreen`, dan layar masuk.
/// Ditulis SEKALI di sini lalu dipakai kedua halaman: aksen yang disalin per
/// halaman adalah aksen yang akan menyimpang, dan gradien hero yang berbeda
/// setengah nada antara dua tab terbaca sebagai aplikasi yang tidak dikerjakan
/// satu orang.
const Color _aksenMerchant = ClayTokens.warning;

/// Kerangka aplikasi merchant: sidebar dengan dua halaman.
///
/// ============================================================================
///  KEDUA HALAMAN MENGGAMBAR KEPALANYA SENDIRI
/// ============================================================================
///  Keduanya terdaftar di [ClayDrawerShell.fullBleedPages], jadi shell tidak
///  memasang AppBar untuk mereka. Alasannya: bahasa v2 membuka halaman dengan
///  bidang gradien yang MENEMBUS status bar, dan AppBar datar di atasnya
///  menghasilkan dua kepala halaman bertumpuk.
///
///  Konsekuensinya, hamburger jadi tanggung jawab halaman — diambil lewat
///  `ClayDrawerScope.of(context)?.toggle` di dalam hero masing-masing. Halaman
///  yang lupa memasangnya membuat sidebar tidak bisa dibuka sama sekali.
/// ============================================================================
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
    /*
     * Dialognya ClayConfirmDialog bersama, alurnya tetap bool.
     *
     * Bentuk ini pernah hidup sebagai kelas privat `_DialogKeluar` di berkas
     * ini DAN di shell customer — dua salinan yang identik sampai salah satunya
     * disentuh. Judul, kalimat konsekuensi, dan label kedua tombol TIDAK
     * berubah satu kata pun; yang hilang hanya salinannya.
     *
     * Kontraknya tetap bool: batal maupun tutup di luar mengembalikan false,
     * karena baris di bawah bergantung pada bentuk itu.
     */
    final bool yakin = await ClayConfirmDialog.tampilkan(
      context,
      icon: Icons.logout_rounded,
      title: 'Keluar?',
      message: 'Anda perlu memasukkan kode OTP lagi untuk masuk.',
      confirmLabel: 'Keluar',
    );

    if (!yakin || !mounted) {
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
      accent: ClayTokens.warning,
      items: _menu,
      selectedIndex: _halaman,
      onSelect: (int i) => setState(() => _halaman = i),

      /*
       * Kedua indeks full-bleed — lihat docblock kelas.
       *
       * Halaman baru yang ditambahkan ke `_menu` TIDAK otomatis boleh masuk ke
       * sini: dia harus punya hero dan Scaffold sendiri lebih dulu, kalau
       * tidak halamannya akan dimulai tepat di bawah jam dan baterai.
       */
      fullBleedPages: const <int>{0, 1},

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
///
/// ============================================================================
///  KENAPA HALAMAN JUJUR TETAP BOLEH TERLIHAT BAGUS
/// ============================================================================
///  Versi lama menaruh seluruh isinya dalam satu kartu abu bertuliskan "belum
///  aktif" — dan kartu tunggal di tengah layar kosong adalah bentuk yang sama
///  persis dengan layar GALAT. Merchant yang membukanya menyimpulkan
///  aplikasinya rusak, bukan bahwa fiturnya memang belum ada.
///
///  Bentuk v2 memisahkan dua hal itu: hero amber + kartu status menyatakan
///  halaman ini memang halaman utamanya dan sedang bekerja; daftar "Yang akan
///  hadir" memakai chip ABU (bukan amber) dengan pil "Menyusul", supaya tidak
///  ada satu pun butir yang bisa disalahbaca sebagai tombol yang bisa ditekan
///  hari ini. Amber disimpan untuk yang nyata — kalau semua bergradien aksen,
///  tidak ada yang berarti.
/// ============================================================================
class _Outlet extends StatelessWidget {
  const _Outlet();

  /// Yang belum ada, ditulis apa adanya. Ikonnya presentasi; kalimatnya sama
  /// persis dengan versi sebelumnya — janji produk, bukan dekorasi.
  static const List<(IconData, String)> _menyusul = <(IconData, String)>[
    (Icons.toggle_on_rounded, 'Buka dan tutup outlet dari HP'),
    (Icons.receipt_long_rounded, 'Terima dan tolak pesanan makanan'),
    (Icons.restaurant_menu_rounded, 'Ubah harga dan ketersediaan menu'),
    (Icons.insights_rounded, 'Ringkasan penjualan harian'),
  ];

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),

        // TANPA SafeArea di atas: hero harus menembus status bar. SafeArea di
        // sini menyisakan pita warna latar di atas gradien, yang terbaca
        // sebagai layar yang gagal dirender.
        child: ListView(
          padding: const EdgeInsets.only(bottom: ClayTokens.space8),
          children: <Widget>[
            // Hero ikut sebagai butir pertama daftar, bukan dipatok di atasnya:
            // dia bergulir pergi saat merchant menelusuri isi, dan itu
            // mengembalikan tinggi layar yang berharga di HP pendek.
            const ClayEntrance(
              index: 0,
              child: ClayHeroHeader(
                accent: _aksenMerchant,
                title: 'Outlet Saya',
                subtitle:
                    'Toko Anda terdaftar di Antaride Medan. Pengelolaannya '
                    'masih lewat tim kami.',
                leading: _TombolMenu(),
                trailing: _TileKaca(icon: Icons.storefront_rounded),
                bottom: Row(
                  children: <Widget>[
                    _PilKaca(icon: Icons.flag_rounded, label: 'Fase 1'),
                    SizedBox(width: ClayTokens.space2),
                    Flexible(
                      child: _PilKaca(
                        icon: Icons.support_agent_rounded,
                        label: 'Dikelola tim Antaride',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                ClayTokens.space5,
                ClayTokens.space5,
                ClayTokens.space5,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ClayEntrance(
                    index: 1,
                    child: ClaySurface(
                      depth: ClayDepth.high,
                      radius: ClayTokens.radiusLarge,
                      padding: const EdgeInsets.all(ClayTokens.space5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const ClayIconChip(
                                icon: Icons.storefront_rounded,
                                accent: _aksenMerchant,
                                size: 48,
                              ),
                              const SizedBox(width: ClayTokens.space4),
                              Expanded(
                                child: Text(
                                  'Pengelolaan outlet belum aktif',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    height: 1.25,
                                    color: gelap
                                        ? ClayTokens.textPrimaryDark
                                        : ClayTokens.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: ClayTokens.space4),

                          // Kalimatnya TIDAK diubah satu kata pun — hanya
                          // perataannya yang pindah dari tengah ke kiri:
                          // paragraf enam baris yang rata tengah membuat mata
                          // kehilangan awal barisnya.
                          Text(
                            'Fase 1 Antaride mencakup ojek, taksi, dan kirim '
                            'barang. Pesan makanan dan pengelolaan menu masih '
                            'dikerjakan.\n\n'
                            'Untuk sekarang, data outlet dan menu Anda '
                            'dikelola tim Antaride lewat backoffice. Hubungi '
                            'kantor Antaride Medan untuk perubahan apa pun.',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              height: 1.6,
                              color: gelap
                                  ? ClayTokens.textSecondaryDark
                                  : ClayTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: ClayTokens.space6),

                  const ClayEntrance(
                    index: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ClaySectionLabel('Yang akan hadir'),
                    ),
                  ),

                  const SizedBox(height: ClayTokens.space3),

                  for (int i = 0; i < _menyusul.length; i++)
                    ClayEntrance(
                      index: 3 + i,
                      child: _KartuMenyusul(
                        icon: _menyusul[i].$1,
                        label: _menyusul[i].$2,
                      ),
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

/// Satu butir fitur yang belum ada.
///
/// Chipnya ABU, bukan amber: bentuknya sama dengan kartu fitur yang nanti aktif
/// supaya daftarnya tidak belang, tapi warnanya menyatakan bahwa tidak ada apa
/// pun yang bisa ditekan di sini hari ini. Pil "Menyusul" mengatakannya sekali
/// lagi dengan kata — isyarat warna sendirian tidak terbaca oleh semua orang.
class _KartuMenyusul extends StatelessWidget {
  const _KartuMenyusul({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final Color redup = gelap
        ? ClayTokens.textTertiaryDark
        : ClayTokens.textTertiary;

    return ClayCard(
      depth: ClayDepth.flat,
      child: Row(
        children: <Widget>[
          ClayIconChip(icon: icon, accent: redup, size: 40),

          const SizedBox(width: ClayTokens.space4),

          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
              ),
            ),
          ),

          const SizedBox(width: ClayTokens.space3),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ClayTokens.space2,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: redup.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
            ),
            child: Text(
              'Menyusul',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: redup,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Halaman profil merchant.
///
/// ============================================================================
///  IDENTITAS DI ATAS GRADIEN, DATA DI KARTU DI BAWAHNYA
/// ============================================================================
///  Versi lama menaruh nama dan kontak dalam kartu abu di atas latar abu, dengan
///  avatar berupa lingkaran tenggelam tanpa warna — halaman identitas tanpa satu
///  momen identitas pun.
///
///  Di v2 nama pindah ke hero amber (avatar jadi tile kaca putih di atas
///  gradien, resep yang sama dengan mark logo), dan yang tinggal di bawah hanya
///  DATA: nomor, email, dan satu kartu jujur tentang cara mengubahnya. Tidak ada
///  baris yang bisa ditekan di halaman ini, jadi tidak ada chevron — chevron
///  yang tidak membuka apa-apa adalah janji palsu sekecil apa pun ukurannya.
/// ============================================================================
class _Profil extends StatelessWidget {
  const _Profil();

  @override
  Widget build(BuildContext context) {
    final SessionController sesi = context.watch<SessionController>();
    final AuthUser? user = sesi.user;

    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      /*
       * Keadaan galat TETAP punya hero compact, dan itu bukan hiasan: tanpa
       * AppBar shell, hamburger di dalam hero adalah SATU-SATUNYA jalan
       * kembali ke halaman outlet. Layar galat tanpa hero mengunci merchant di
       * halaman yang gagal dimuat.
       */
      return Scaffold(
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ClayHeroHeader(
                accent: _aksenMerchant,
                compact: true,
                title: 'Profil',
                leading: _TombolMenu(),
              ),
              Expanded(
                child: ClayErrorState(
                  message:
                      sesi.lastFailure?.message ?? 'Profil tidak bisa dimuat.',
                  onRetry: sesi.refreshProfile,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: ListView(
          padding: const EdgeInsets.only(bottom: ClayTokens.space8),
          children: <Widget>[
            ClayEntrance(
              index: 0,
              child: ClayHeroHeader(
                accent: _aksenMerchant,
                title: user.name,
                subtitle: user.email ?? user.phone,
                leading: const _TombolMenu(),
                trailing: _AvatarKaca(inisial: user.initials),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                ClayTokens.space5,
                ClayTokens.space5,
                ClayTokens.space5,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const ClayEntrance(
                    index: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ClaySectionLabel('Akun'),
                    ),
                  ),

                  const SizedBox(height: ClayTokens.space3),

                  ClayEntrance(
                    index: 2,
                    child: _BarisData(
                      icon: Icons.phone_rounded,
                      label: 'Nomor HP',
                      nilai: user.phone,
                    ),
                  ),

                  ClayEntrance(
                    index: 3,
                    child: _BarisData(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',

                      // Email boleh kosong di backend. Barisnya tetap
                      // ditampilkan — baris yang hilang membuat orang mengira
                      // datanya tidak pernah ada, bukan bahwa kolomnya kosong.
                      nilai: user.email ?? 'Belum diisi',
                      redup: user.email == null,
                    ),
                  ),

                  const SizedBox(height: ClayTokens.space5),

                  const ClayEntrance(
                    index: 4,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ClaySectionLabel('Toko'),
                    ),
                  ),

                  const SizedBox(height: ClayTokens.space3),

                  const ClayEntrance(
                    index: 5,
                    child: _KartuMenyusul(
                      icon: Icons.edit_note_rounded,
                      label:
                          'Ubah data toko dari aplikasi — sekarang lewat tim '
                          'Antaride Medan',
                    ),
                  ),

                  const SizedBox(height: ClayTokens.space8),

                  ClayEntrance(
                    index: 6,
                    child: Center(
                      child: Text(
                        'Antaride Merchant'
                        '${AppConfig.isProduction ? '' : ' · ${AppConfig.environment}'}',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          color: gelap
                              ? ClayTokens.textTertiaryDark
                              : ClayTokens.textTertiary,
                        ),
                      ),
                    ),
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

/// Satu baris data akun: chip gradien amber, label kecil, nilainya di bawahnya.
///
/// Tanpa `onTap` dan tanpa chevron — halaman profil merchant memang belum punya
/// satu pun aksi, dan baris yang TERLIHAT bisa ditekan tapi tidak melakukan
/// apa-apa lebih buruk daripada baris yang jelas hanya menampilkan.
class _BarisData extends StatelessWidget {
  const _BarisData({
    required this.icon,
    required this.label,
    required this.nilai,
    this.redup = false,
  });

  final IconData icon;
  final String label;
  final String nilai;

  /// Nilai yang belum diisi ditulis dengan warna tersier.
  final bool redup;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClayCard(
      child: Row(
        children: <Widget>[
          ClayIconChip(icon: icon, accent: _aksenMerchant, size: 40),

          const SizedBox(width: ClayTokens.space4),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: gelap
                        ? ClayTokens.textTertiaryDark
                        : ClayTokens.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nilai,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: redup
                        ? (gelap
                              ? ClayTokens.textTertiaryDark
                              : ClayTokens.textTertiary)
                        : (gelap
                              ? ClayTokens.textPrimaryDark
                              : ClayTokens.textPrimary),
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

/// Hamburger untuk DI DALAM hero halaman full-bleed.
///
/// `ClayDrawerScope` boleh null — halaman ini bisa dipasang sendirian di test
/// widget, dan tombol yang tidak melakukan apa-apa di sana lebih baik daripada
/// test yang tidak bisa memasang halamannya sama sekali.
class _TombolMenu extends StatelessWidget {
  const _TombolMenu();

  @override
  Widget build(BuildContext context) {
    return ClayGlassButton(
      icon: Icons.menu_rounded,
      semanticLabel: 'Menu',
      onPressed: ClayDrawerScope.of(context)?.toggle,
    );
  }
}

/// Tile kaca buram untuk DI DALAM hero: ikon putih di kotak putih-transparan.
///
/// Putih alpha 0.16 + bingkai 0.22 — resep yang sama dengan mark logo welcome
/// dan [ClayBackButton], dan karena warnanya putih-alpha dia ikut aksen apa pun
/// tanpa satu cabang warna. Lokal di berkas ini: `antaride_ui` belum
/// mengekspor tile kaca sebagai komponen.
class _TileKaca extends StatelessWidget {
  const _TileKaca({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}

/// Avatar inisial di atas gradien: tile kaca yang sama, isinya huruf.
class _AvatarKaca extends StatelessWidget {
  const _AvatarKaca({required this.inisial});

  final String inisial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        inisial,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Pil kaca untuk slot `bottom` hero: keterangan singkat di atas gradien.
///
/// Bukan `ClayStatusBadge`: badge itu memakai warna latar pucat yang hilang di
/// atas gradien pekat.
class _PilKaca extends StatelessWidget {
  const _PilKaca({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space3,
        vertical: ClayTokens.space2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: ClayTokens.space2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
