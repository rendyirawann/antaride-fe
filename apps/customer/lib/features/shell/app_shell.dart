import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

/// Kerangka utama setelah masuk: sidebar geser dengan empat halaman.
///
/// ============================================================================
///  SIDEBAR ZOOM DRAWER, BUKAN BOTTOM NAV
/// ============================================================================
///  Alasan tampilannya ada di docblock `ClayDrawerShell`. Yang perlu disebut di
///  sini adalah akibatnya bagi state layar:
///
///  `IndexedStack` di bawah menjaga keempat halaman tetap HIDUP saat berpindah.
///  Yang dijaganya bukan sekadar posisi gulir:
///
///    Beranda    titik jemput yang sudah dipilih dan posisi petanya. Pengguna
///               yang membuka Dompet untuk memeriksa saldo lalu kembali TIDAK
///               boleh mendapati pilihan titiknya hilang.
///    Riwayat    halaman-halaman yang sudah ditarik lewat cursor. Membangun
///               ulang berarti menariknya lagi dari halaman pertama — dan
///               dengan cursor pagination, tidak ada cara melompat kembali ke
///               posisi yang sudah dibaca.
///
///  Biayanya: keempat halaman tetap di memori. Untuk empat layar itu wajar, dan
///  jauh lebih murah daripada request yang diulang setiap perpindahan.
/// ============================================================================
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  /// Tab yang PERNAH dibuka.
  ///
  /// ==========================================================================
  ///  HALAMAN DIBANGUN SAAT PERTAMA DIBUKA, BUKAN SEMUANYA DI AWAL
  /// ==========================================================================
  ///  `IndexedStack` membangun SELURUH anaknya, tidak hanya yang terlihat — itu
  ///  memang cara dia menjaga state. Tanpa penyaringan ini, membuka aplikasi
  ///  menjalankan `initState` keempat halaman sekaligus, dan bersamanya lima
  ///  request serentak: katalog layanan, order berjalan, saldo dompet, mutasi
  ///  dompet, dan riwayat pesanan.
  ///
  ///  Empat dari lima itu untuk halaman yang belum dilihat pengguna, dan mungkin
  ///  tidak akan dia buka sama sekali dalam sesi itu. Di jaringan seluler yang
  ///  buruk — yang justru keadaan normal di sini — kelimanya berebut bandwidth,
  ///  dan yang tertunda adalah beranda: satu-satunya halaman yang benar-benar
  ///  sedang ditunggu.
  ///
  ///  Setelah dibuka sekali, halamannya TETAP hidup di dalam stack. Jadi yang
  ///  hilang hanya pemuatan di awal, bukan penjagaan state-nya.
  /// ==========================================================================
  final Set<int> _pernahDibuka = <int>{0};

  static const List<ClayDrawerItem> _menu = <ClayDrawerItem>[
    ClayDrawerItem(label: 'Beranda', icon: Icons.home_rounded),
    ClayDrawerItem(label: 'Riwayat Pesanan', icon: Icons.receipt_long_rounded),
    ClayDrawerItem(label: 'Dompet', icon: Icons.account_balance_wallet_rounded),
    ClayDrawerItem(label: 'Profil', icon: Icons.person_rounded),
  ];

  /// Halaman untuk satu indeks menu.
  ///
  /// Urutannya HARUS cocok dengan `_menu`. Keduanya tidak bisa disatukan begitu
  /// saja: `_menu` adalah `const` supaya tidak dibangun ulang setiap frame,
  /// sementara halaman-halamannya bukan const semua.
  Widget _halaman(int index) => switch (index) {
    1 => const HistoryScreen(),
    2 => const WalletScreen(),
    3 => const ProfileScreen(),
    _ => const HomeScreen(),
  };

  Future<void> _keluar() async {
    /*
     * Dialognya wadah clay, alurnya tetap bool.
     *
     * AlertDialog Material adalah satu-satunya elemen mentah di alur utama —
     * kotak datar tanpa kedalaman di antara permukaan clay. Yang diganti hanya
     * WADAHNYA: kontraknya tetap `showDialog<bool>` yang mengembalikan
     * true/false lewat pop, karena kode di bawah (dan pola dialog konfirmasi
     * di seluruh aplikasi) bergantung pada bentuk itu.
     */
    final bool? yakin = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => const _DialogKeluar(),
    );

    if (yakin != true || !mounted) {
      return;
    }

    // Tidak ada navigasi setelah ini. Gerbang di akar aplikasi mengamati
    // `SessionStage`, dan begitu tahapnya `signedOut` seluruh tumpukan diganti
    // layar masuk.
    await context.read<SessionController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final AuthUser? user = context.select<SessionController, AuthUser?>(
      (SessionController s) => s.user,
    );

    return ClayDrawerShell(
      items: _menu,
      selectedIndex: _tab,
      onSelect: (int i) => setState(() {
        _tab = i;
        _pernahDibuka.add(i);
      }),

      /*
       * Beranda (indeks 0) menggambar kepala halamannya sendiri: hero gradien
       * yang menembus status bar, dengan hamburger di dalam hero lewat
       * ClayDrawerScope. AppBar shell di atasnya berarti dua kepala halaman
       * bertumpuk. Halaman lain (riwayat, dompet, profil) TETAP memakai AppBar
       * shell — jangan tambahkan indeksnya ke sini tanpa memberi halaman itu
       * hero + Scaffold miliknya sendiri.
       */
      fullBleedPages: const <int>{0},

      title: user?.name ?? 'Pengguna Antaride',
      subtitle: user?.phone,
      avatarLabel: user?.initials,

      footerLabel: 'Keluar',
      onFooterTap: _keluar,

      /*
       * Halaman yang belum pernah dibuka diganti kotak kosong.
       *
       * Posisinya di dalam stack TETAP — indeks 0 selalu beranda, 1 selalu
       * riwayat, dan seterusnya. Itu yang membuat state halaman yang sudah
       * dibuka tetap terjaga saat halaman lain menyusul dibangun: Flutter
       * mencocokkan elemen berdasarkan posisi dan tipe, jadi anak yang tidak
       * berubah tidak dibuat ulang.
       */
      pageBuilder: (BuildContext context, int index) => IndexedStack(
        index: index,
        children: <Widget>[
          for (int i = 0; i < _menu.length; i++)
            if (_pernahDibuka.contains(i))
              _halaman(i)
            else
              const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Dialog konfirmasi keluar dalam wadah clay.
///
/// ============================================================================
///  HIERARKI BAHAYANYA DARI CHIP GRADIEN MERAH, BUKAN DARI WARNA TEKS SAJA
/// ============================================================================
///  Versi lama menandai aksi berbahaya hanya lewat warna teks tombol "Keluar".
///  Di sini bahayanya terbaca tiga lapis: chip ikon bergradien danger di
///  puncak, tombol "Keluar" varian danger, dan "Batal" sebagai varian sekunder
///  yang lebih tenang. Teks judul, kalimat konsekuensi, dan label kedua tombol
///  TIDAK berubah satu kata pun — hanya wadahnya.
///
///  Kedua tombol dibungkus `Expanded` — syarat aturan keras: [ClayButton] di
///  dalam `Row` harus `expanded: false` KECUALI dibungkus `Expanded`.
/// ============================================================================
class _DialogKeluar extends StatelessWidget {
  const _DialogKeluar();

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      // Wadahnya ClaySurface, jadi Material milik Dialog dibuat tak terlihat —
      // dua permukaan bertumpuk menghasilkan bayangan ganda.
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: ClayTokens.space6),
      child: ClaySurface(
        depth: ClayDepth.high,
        radius: ClayTokens.radiusLarge,
        padding: const EdgeInsets.all(ClayTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ClayIconChip(
              icon: Icons.logout_rounded,
              accent: ClayTokens.danger,
              size: 48,
            ),

            const SizedBox(height: ClayTokens.space4),

            Text(
              'Keluar?',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: gelap
                    ? ClayTokens.textPrimaryDark
                    : ClayTokens.textPrimary,
              ),
            ),

            const SizedBox(height: ClayTokens.space2),

            Text(
              'Anda perlu memasukkan kode OTP lagi untuk masuk.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                height: 1.5,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
              ),
            ),

            const SizedBox(height: ClayTokens.space6),

            Row(
              children: <Widget>[
                Expanded(
                  child: ClayButton(
                    label: 'Batal',
                    variant: ClayButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: ClayTokens.space3),
                Expanded(
                  child: ClayButton(
                    label: 'Keluar',
                    variant: ClayButtonVariant.danger,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
