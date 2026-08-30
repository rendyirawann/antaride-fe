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

  /// Kunci tetap per halaman.
  ///
  /// ==========================================================================
  ///  TANPA INI, SELURUH STATE HALAMAN HILANG SETIAP MELEWATI BERANDA
  /// ==========================================================================
  ///  Beranda terdaftar di `fullBleedPages`, dan shell merender halaman
  ///  full-bleed TANPA pembungkus `Scaffold`+`AppBar` miliknya. Artinya BENTUK
  ///  pohon widget di atas `IndexedStack` ini BERUBAH setiap kali indeksnya
  ///  berpindah ke atau dari 0.
  ///
  ///  Flutter mencocokkan elemen berdasarkan posisi dan tipe. Saat pembungkus
  ///  di atasnya muncul atau hilang, seluruh subtree di bawahnya dianggap baru:
  ///  setiap `State` dibuang dan `initState` berjalan lagi.
  ///
  ///  Yang hilang bukan hal sepele. Riwayat memulai ulang paginasinya dari
  ///  halaman pertama — kursor dan semua halaman yang sudah dimuat dibuang, dan
  ///  pengguna yang sudah menggulir jauh dikembalikan ke atas. Dompet menarik
  ///  ulang saldo dan mutasinya. Ketiga halaman menembakkan lagi request yang
  ///  jawabannya sudah ada di layar sedetik lalu.
  ///
  ///  `GlobalKey` membuat elemennya DIADOPSI ULANG di posisi barunya alih-alih
  ///  dibuang. Kuncinya harus tetap seumur `State` ini — kunci yang dibuat di
  ///  dalam `build` berubah tiap frame dan justru menjamin apa yang dicegahnya.
  ///
  ///  Ditemukan lewat review setelah `fullBleedPages` ditambahkan; analyzer
  ///  maupun test tidak bisa melihatnya — keduanya kompilasi dan lolos.
  /// ==========================================================================
  final Map<int, GlobalKey> _kunci = <int, GlobalKey>{};

  /// Halaman untuk satu indeks menu.
  ///
  /// Urutannya HARUS cocok dengan `_menu`. Keduanya tidak bisa disatukan begitu
  /// saja: `_menu` adalah `const` supaya tidak dibangun ulang setiap frame,
  /// sementara halaman-halamannya bukan const semua.
  Widget _halaman(int index) {
    final GlobalKey kunci = _kunci.putIfAbsent(index, GlobalKey.new);

    return switch (index) {
      1 => HistoryScreen(key: kunci),
      2 => WalletScreen(key: kunci),
      3 => ProfileScreen(key: kunci),
      _ => HomeScreen(key: kunci),
    };
  }

  Future<void> _keluar() async {
    /*
     * Dialognya ClayConfirmDialog bersama, alurnya tetap bool.
     *
     * Bentuk ini pernah hidup sebagai kelas privat `_DialogKeluar` di berkas
     * ini DAN di shell merchant — dua salinan yang identik sampai salah satunya
     * disentuh. Judul, kalimat konsekuensi, dan label kedua tombol TIDAK
     * berubah satu kata pun; yang hilang hanya salinannya.
     *
     * Kontraknya tetap bool: batal maupun tutup di luar mengembalikan false,
     * karena kode di bawah bergantung pada bentuk itu.
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
