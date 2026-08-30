import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';

import '../theme/clay_tokens.dart';

/// Satu butir menu di sidebar.
class ClayDrawerItem {
  const ClayDrawerItem({required this.label, required this.icon, this.badge});

  final String label;
  final IconData icon;

  /// Angka kecil di kanan label, misalnya jumlah tawaran menunggu.
  ///
  /// Null berarti tidak ada lencana. Nol JUGA tidak ditampilkan — lencana "0"
  /// menarik perhatian ke tempat yang tidak ada apa-apanya.
  final int? badge;
}

/// Kerangka aplikasi dengan sidebar geser beranimasi.
///
/// ============================================================================
///  KENAPA ZOOM DRAWER, BUKAN Drawer BAWAAN ATAU BOTTOM NAV
/// ============================================================================
///  `Drawer` bawaan Material menggeser panel di ATAS halaman dan menggelapkan
///  sisanya. Halaman utamanya tidak bergerak, jadi selama drawer terbuka tidak
///  ada isyarat bahwa halaman itu masih ada di belakang — dan yang dirasakan
///  adalah pindah layar, bukan membuka menu.
///
///  `flutter_zoom_drawer` menggeser, MENGECILKAN, dan MEMIRINGKAN halaman
///  utamanya, dengan dua lapis bayangan di belakangnya. Halaman itu tetap
///  terlihat sebagai kartu yang bisa dikembalikan — dan menyentuhnya di mana
///  saja menutup menunya.
///
///  Kenapa itu cocok di sini secara khusus: seluruh aplikasi memakai bahasa
///  claymorphism, yang seluruhnya tentang benda yang punya ketebalan dan
///  bayangan. Halaman yang miring dengan bayangan berlapis adalah gerakan yang
///  persis sama, dalam skala satu layar.
/// ============================================================================
///
/// ============================================================================
///  YANG MENGGANTI BOTTOM NAV, BUKAN MENAMBAHINYA
/// ============================================================================
///  Bottom nav dan sidebar yang ada bersamaan menghasilkan dua tempat berbeda
///  untuk pindah halaman, dan dua tempat itu akan menyimpang — satu memuat
///  halaman yang tidak ada di yang lain.
///
///  Satu daftar menu, satu tempat. Halaman yang dituju ditentukan [selectedIndex]
///  dan digambar [pageBuilder].
/// ============================================================================
class ClayDrawerShell extends StatefulWidget {
  const ClayDrawerShell({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.pageBuilder,
    required this.title,
    this.subtitle,
    this.avatarLabel,
    this.footerLabel,
    this.onFooterTap,
    this.actions = const <Widget>[],
    this.fullBleedPages = const <int>{},
  });

  final List<ClayDrawerItem> items;
  final int selectedIndex;
  final void Function(int) onSelect;

  /// Indeks halaman yang menggambar kepala halamannya SENDIRI.
  ///
  /// ==========================================================================
  ///  UNTUK HALAMAN BER-HERO GRADIEN
  /// ==========================================================================
  ///  Bahasa v2 membuka halaman dengan bidang gradien yang menembus status bar.
  ///  AppBar bawaan shell menghalanginya dua kali: dia mengambil status bar,
  ///  dan dia menaruh bilah datar di atas hero — dua kepala halaman bertumpuk.
  ///
  ///  Indeks yang terdaftar di sini dirender TANPA AppBar shell. Hamburger
  ///  menjadi tanggung jawab halamannya — ambil lewat [ClayDrawerScope]:
  ///
  ///      ClayDrawerScope.of(context)?.toggle()
  ///
  ///  Halamannya juga harus menyediakan Scaffold-nya sendiri.
  /// ==========================================================================
  final Set<int> fullBleedPages;

  /// Membangun halaman untuk indeks terpilih.
  final Widget Function(BuildContext, int) pageBuilder;

  /// Nama pengguna di kepala sidebar.
  final String title;

  final String? subtitle;

  /// Inisial untuk avatar bulat.
  final String? avatarLabel;

  /// Tombol di dasar sidebar, biasanya "Keluar".
  final String? footerLabel;
  final VoidCallback? onFooterTap;

  /// Tombol tambahan di kanan bilah atas halaman.
  final List<Widget> actions;

  @override
  State<ClayDrawerShell> createState() => _ClayDrawerShellState();
}

class _ClayDrawerShellState extends State<ClayDrawerShell> {
  final ZoomDrawerController _drawer = ZoomDrawerController();

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final double lebar = MediaQuery.sizeOf(context).width;

    return ZoomDrawer(
      controller: _drawer,

      menuScreen: _Sidebar(
        items: widget.items,
        selectedIndex: widget.selectedIndex,
        title: widget.title,
        subtitle: widget.subtitle,
        avatarLabel: widget.avatarLabel,
        footerLabel: widget.footerLabel,
        onFooterTap: widget.onFooterTap,
        onSelect: (int i) {
          widget.onSelect(i);

          // Menu ditutup setelah memilih. Sidebar yang tetap terbuka setelah
          // halaman berganti membuat pengguna harus menutupnya sendiri untuk
          // melihat hasil pilihannya.
          _drawer.close?.call();
        },
      ),

      mainScreen: ClayDrawerScope(
        toggle: () => _drawer.toggle?.call(),

        // Halaman full-bleed memasang kepala halamannya sendiri (hero gradien
        // dengan hamburger dari ClayDrawerScope); selain itu shell yang
        // memasang AppBar standar.
        child: widget.fullBleedPages.contains(widget.selectedIndex)
            ? widget.pageBuilder(context, widget.selectedIndex)
            : _Halaman(
                title: widget.items[widget.selectedIndex].label,
                actions: widget.actions,
                onMenu: () => _drawer.toggle?.call(),
                child: widget.pageBuilder(context, widget.selectedIndex),
              ),
      ),

      // -----------------------------------------------------------------------
      //  Angka-angka animasi
      // -----------------------------------------------------------------------
      style: DrawerStyle.defaultStyle,

      /*
       * Kemiringan -10 derajat, bukan -12 yang jadi bawaan paketnya.
       *
       * Pada layar sempit — dan aplikasi ini dipakai di HP entry-level yang
       * banyak di Medan — kemiringan 12 derajat membuat sudut kanan atas
       * halaman terpotong keluar layar, dan judul halaman ikut terpotong
       * bersamanya.
       */
      angle: -10,

      /*
       * 68% lebar layar, dan itu dihitung bukan dipilih.
       *
       * Label menu terpanjang di aplikasi driver adalah "Keluar dari semua
       * perangkat". Di bawah 65%, label sepanjang itu terpotong; di atas 72%,
       * halaman utamanya tersisa terlalu sedikit untuk terbaca sebagai kartu
       * yang masih ada di belakang.
       */
      slideWidth: lebar * 0.68,

      // Sudut halaman utama dibulatkan sesuai radius clay terbesar, supaya
      // kartu yang miring itu terbaca sebagai permukaan clay yang sama.
      borderRadius: ClayTokens.radiusLarge,

      // Dua lapis bayangan di belakang halaman — inti dari gerakan ini. Tanpa
      // keduanya, halaman yang miring terlihat menempel di sidebar, bukan
      // mengapung di atasnya.
      showShadow: true,
      shadowLayer1Color: gelap
          ? ClayTokens.surfaceRaisedDark.withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.32),
      shadowLayer2Color: gelap
          ? ClayTokens.surfaceDark.withValues(alpha: 0.65)
          : Colors.white.withValues(alpha: 0.58),
      drawerShadowsBackgroundColor: gelap
          ? ClayTokens.surfaceDark
          : ClayTokens.surface,

      menuBackgroundColor: gelap
          ? ClayTokens.surfaceSunkenDark
          : ClayTokens.primaryDark,

      // Menyentuh halaman utama menutup menu. Ini yang membuat gerakannya
      // terasa seperti menggeser kartu kembali, dan bukan seperti dialog yang
      // butuh tombol tutup.
      mainScreenTapClose: true,

      // Pointer di halaman utama diserap selama menu terbuka. Tanpa ini,
      // tekanan yang jatuh di atas halaman yang miring akan mengaktifkan tombol
      // yang posisinya SUDAH BERGESER — dan yang tertekan bukan yang terlihat.
      mainScreenAbsorbPointer: true,

      moveMenuScreen: true,

      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 240),

      // Kurva berbeda untuk buka dan tutup. Membuka pakai `easeOutCubic` yang
      // melambat di akhir — gerakan yang terasa mendarat. Menutup pakai
      // `easeInCubic` yang mempercepat, karena menutup adalah membuang, bukan
      // menampilkan.
      openCurve: Curves.easeOutCubic,
      closeCurve: Curves.easeInCubic,

      androidCloseOnBackTap: true,
    );
  }
}

/// Akses ke drawer dari dalam halaman.
///
/// Ada untuk halaman [ClayDrawerShell.fullBleedPages]: mereka tidak punya
/// AppBar shell, jadi hamburger-nya hidup di dalam hero milik halaman — dan
/// tombol itu butuh cara memanggil drawer tanpa menerima callback lewat
/// berlapis-lapis konstruktor.
///
/// `of` mengembalikan null di luar shell (mis. di test yang memasang
/// halamannya sendirian) — pemanggil memakai `?.` dan hamburger yang tidak
/// melakukan apa-apa lebih baik daripada test yang tidak bisa memasang
/// halamannya.
class ClayDrawerScope extends InheritedWidget {
  const ClayDrawerScope({
    super.key,
    required this.toggle,
    required super.child,
  });

  /// Membuka/menutup sidebar.
  final VoidCallback toggle;

  static ClayDrawerScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ClayDrawerScope>();
  }

  @override
  bool updateShouldNotify(ClayDrawerScope oldWidget) {
    return toggle != oldWidget.toggle;
  }
}

/// Isi sidebar.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.title,
    this.subtitle,
    this.avatarLabel,
    this.footerLabel,
    this.onFooterTap,
  });

  final List<ClayDrawerItem> items;
  final int selectedIndex;
  final void Function(int) onSelect;
  final String title;
  final String? subtitle;
  final String? avatarLabel;
  final String? footerLabel;
  final VoidCallback? onFooterTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Container(
      /*
       * Gradien, bukan warna rata.
       *
       * Sidebar adalah satu-satunya permukaan di aplikasi ini yang mengisi
       * seluruh layar dengan warna merek. Warna rata pada bidang sebesar itu
       * terlihat datar — dan datar adalah kebalikan dari seluruh bahasa clay.
       *
       * Arah gradiennya mengikuti arah cahaya global di `ClayTokens`: terang di
       * kiri atas, lebih gelap di kanan bawah. Gradien yang arahnya berbeda dari
       * bayangan komponen di atasnya akan terbaca sebagai dua sumber cahaya.
       */
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gelap
              ? <Color>[
                  ClayTokens.surfaceRaisedDark,
                  ClayTokens.surfaceSunkenDark,
                ]
              : <Color>[ClayTokens.primaryLight, ClayTokens.primaryDark],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ClayTokens.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ClayTokens.space6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          avatarLabel ?? '?',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: ClayTokens.space4),

                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),

                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: ClayTokens.space6),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    for (int i = 0; i < items.length; i++)
                      _ButirMenu(
                        item: items[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelect(i),
                      ),
                  ],
                ),
              ),

              if (footerLabel != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClayTokens.space6,
                    vertical: ClayTokens.space3,
                  ),
                  child: OutlinedButton(
                    onPressed: onFooterTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1.6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: ClayTokens.space6,
                        vertical: ClayTokens.space3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ClayTokens.radiusPill,
                        ),
                      ),
                    ),
                    child: Text(
                      footerLabel!,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButirMenu extends StatelessWidget {
  const _ButirMenu({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ClayDrawerItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: ClayTokens.space6,
          vertical: ClayTokens.space4,
        ),

        /*
         * Butir terpilih diberi latar yang LEBIH GELAP, bukan lebih terang.
         *
         * Pada sidebar berwarna merek, latar lebih terang terbaca sebagai
         * butir yang sedang disentuh — keadaan sementara. Yang lebih gelap
         * terbaca sebagai butir yang tenggelam, yaitu keadaan yang menetap, dan
         * itu isyarat yang sama dengan permukaan clay yang ditekan di seluruh
         * aplikasi.
         */
        decoration: BoxDecoration(
          color: selected
              ? Colors.black.withValues(alpha: 0.22)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? Colors.white : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              item.icon,
              size: 21,
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.78),
            ),
            const SizedBox(width: ClayTokens.space4),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),

            // Lencana hanya kalau angkanya lebih dari nol. Lihat catatan di
            // ClayDrawerItem.badge.
            if (item.badge != null && item.badge! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
                ),
                child: Text(
                  '${item.badge}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ClayTokens.primaryDark,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Halaman utama, dengan bilah atas berisi tombol menu.
class _Halaman extends StatelessWidget {
  const _Halaman({
    required this.title,
    required this.child,
    required this.onMenu,
    required this.actions,
  });

  final String title;
  final Widget child;
  final VoidCallback onMenu;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Tombol hamburger menggantikan tombol kembali. `automaticallyImplyLeading`
        // dimatikan supaya Navigator tidak menaruh tombol kembali di sini —
        // halaman ini adalah akar, dan tidak ada tempat untuk kembali.
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Menu',
          onPressed: onMenu,
        ),
        title: Text(title),
        actions: actions,
      ),
      body: child,
    );
  }
}
