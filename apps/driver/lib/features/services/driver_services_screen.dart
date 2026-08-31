import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Aksen aplikasi driver — hijau tua, bukan hijau penumpang.
///
/// Diambil dari token, bukan ditulis ulang sebagai `Color(0xFF057A55)` di
/// beberapa tempat: nilai yang disalin akan menyimpang dari palet begitu
/// paletnya berubah.
const Color _aksenDriver = ClayTokens.primaryDark;

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
///
/// ============================================================================
///  KEPALA HALAMAN v2: PANEL GRADIEN, BUKAN HERO YANG MENEMBUS STATUS BAR
/// ============================================================================
///  Halaman ini hidup DI DALAM `ClayDrawerShell`, yang sudah memasang bilah atas
///  beserta hamburger-nya. Hero v2 yang menembus status bar akan menghasilkan
///  dua kepala halaman bertumpuk.
///
///  Yang dipakai bentuk yang sama dengan panel dokumen dan strip status di layar
///  order berjalan: KARTU bergradien di puncak isi — bahasa v2, tempatnya di
///  bawah bilah shell. Paragraf instruksi yang dulu berdiri sendiri sebagai
///  dinding teks abu-abu pindah ke dalam panel itu, tepat di bawah angka yang
///  menjawab "berapa yang sedang menyala".
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

    // Dua angka untuk kepala halaman. Keduanya PENJUMLAHAN dari daftar yang
    // sama yang digambar di bawahnya — tidak ada keadaan baru yang disimpan,
    // jadi tidak ada yang bisa menyimpang dari kartunya.
    final int menyala = _layanan.where((DriverService s) => s.isActive).length;

    final int terkunci = _layanan
        .where((DriverService s) => !s.isAllowed)
        .length;

    // Giliran animasi masuk berjalan lintas seluruh halaman, dan dibatasi lewat
    // `_giliran` supaya daftar panjang tidak membuat kartu terakhir muncul
    // sedetik lebih lambat daripada yang pertama.
    int urutan = 0;

    return Scaffold(
      body: ClayRefresh(
        onRefresh: _muat,
        child: ListView(
          // Ruang akhir guliran menambahkan tinggi bilah navigasi Android,
          // supaya kartu terakhir tidak berhenti di belakangnya.
          padding: EdgeInsets.fromLTRB(
            ClayTokens.space5,
            ClayTokens.space4,
            ClayTokens.space5,
            ClayTokens.space8 + context.ruangBawah,
          ),
          children: <Widget>[
            ClayEntrance(
              key: const ValueKey<String>('kepala'),
              index: _giliran(urutan++),
              child: _PanelLayanan(
                menyala: menyala,
                total: _layanan.length,
                terkunci: terkunci,
              ),
            ),

            const SizedBox(height: ClayTokens.space5),

            ClayEntrance(
              key: const ValueKey<String>('label'),
              index: _giliran(urutan++),
              child: const Padding(
                padding: EdgeInsets.only(
                  left: ClayTokens.space1,
                  bottom: ClayTokens.space2,
                ),
                child: ClaySectionLabel('Pilihan layanan'),
              ),
            ),

            for (final DriverService s in _layanan)
              Padding(
                padding: const EdgeInsets.only(bottom: ClayTokens.space3),

                // Key per KODE layanan. Halaman dibangun ulang setiap kali satu
                // sakelar disentuh (`_menyimpan`, lalu `_muat`); tanpa key yang
                // mengikuti identitas datanya, kartu yang berpindah posisi
                // mengambil alih State tetangganya dan memutar ulang animasi
                // masuknya — seluruh daftar berkedip setiap kali sakelar
                // ditekan.
                child: ClayEntrance(
                  key: ValueKey<String>('layanan-${s.code}'),
                  index: _giliran(urutan++),
                  child: _KartuLayanan(
                    layanan: s,
                    menyimpan: _menyimpan,
                    onUbah: (bool nyala) => _ubah(s, nyala),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Batas giliran animasi masuk — lihat alasannya di layar dokumen: daftar
/// panjang yang masih bergerak saat sudah dibaca terasa lambat, bukan hidup.
int _giliran(int urutan) => urutan > 5 ? 5 : urutan;

/// Kepala halaman: berapa layanan yang menyala, dan aturan mainnya.
///
/// ============================================================================
///  KENAPA ANGKANYA YANG BESAR, BUKAN JUDULNYA
/// ============================================================================
///  Judul halaman sudah ada di bilah shell di atas panel ini; mengulangnya di
///  sini hanya memakan ruang. Yang TIDAK ada di mana pun sebelum ini: berapa
///  layanan yang sedang menyala. Itu satu-satunya hal yang ingin driver pastikan
///  sebelum mulai bekerja — dan sebelumnya dia harus menghitungnya sendiri dari
///  sakelar satu per satu.
///
///  Paragraf instruksinya ikut ke dalam panel. Sebagai teks abu-abu yang berdiri
///  sendiri di atas daftar, dia dilewati; di atas gradien, dia bagian dari
///  jawaban.
/// ============================================================================
class _PanelLayanan extends StatelessWidget {
  const _PanelLayanan({
    required this.menyala,
    required this.total,
    required this.terkunci,
  });

  final int menyala;
  final int total;

  /// Berapa layanan yang belum diizinkan admin. Nol berarti barisnya tidak
  /// digambar — pemberitahuan "0 layanan terkunci" adalah kabar yang tidak
  /// perlu disampaikan.
  final int terkunci;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ClayTokens.space5),
      decoration: BoxDecoration(
        gradient: ClayGradients.hero(_aksenDriver),
        borderRadius: BorderRadius.circular(ClayTokens.radiusLarge),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _aksenDriver.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _TileKaca(
                child: Icon(Icons.tune_rounded, size: 22, color: Colors.white),
              ),

              const SizedBox(width: ClayTokens.space4),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'LAYANAN SAYA',
                      style: TextStyle(
                        fontFamily: ClayTokens.fontFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '$menyala dari $total layanan menyala',
                      style: const TextStyle(
                        fontFamily: ClayTokens.fontFamily,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: ClayTokens.space4),

          Text(
            'Nyalakan hanya layanan yang siap Anda kerjakan hari ini. '
            'Mematikan satu layanan langsung berlaku — Anda tidak akan lagi '
            'menerima tawaran untuk layanan itu.',
            style: TextStyle(
              fontFamily: ClayTokens.fontFamily,
              fontSize: 12,
              height: 1.5,

              // Putih diredupkan, bukan abu-abu: abu-abu di atas gradien
              // berwarna terlihat kotor.
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),

          if (terkunci > 0) ...<Widget>[
            const SizedBox(height: ClayTokens.space4),

            // Pil kaca, bukan lencana clay: latarnya gradien, dan lencana clay
            // yang dirancang untuk permukaan pucat hilang di atasnya.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ClayTokens.space3,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$terkunci layanan masih terkunci',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: ClayTokens.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu layanan: identitasnya, keadaannya, dan sakelarnya.
class _KartuLayanan extends StatelessWidget {
  const _KartuLayanan({
    required this.layanan,
    required this.menyimpan,
    required this.onUbah,
  });

  final DriverService layanan;

  /// Ada perubahan yang sedang dikirim. Selama itu SEMUA sakelar dikunci —
  /// guard yang sama dengan `_menyimpan` di layar, diteruskan ke sini supaya
  /// keadaan terkunci itu ikut terlihat pada sakelarnya.
  final bool menyimpan;

  final void Function(bool nyala) onUbah;

  /// Ikon per kode layanan.
  ///
  /// Pemetaannya sama dengan kisi layanan di beranda penumpang — layanan yang
  /// sama harus terlihat sama di kedua aplikasi. Kode yang TIDAK dikenali
  /// memakai ikon generik dan tetap digambar: layanan baru yang ditambahkan
  /// backend tidak boleh hilang dari halaman ini hanya karena aplikasinya belum
  /// tahu ikonnya.
  static const Map<String, IconData> _ikon = <String, IconData>{
    'ride_bike': Icons.two_wheeler_rounded,
    'ride_car': Icons.local_taxi_rounded,
    'send': Icons.local_shipping_rounded,
    'food': Icons.restaurant_rounded,
    'mart': Icons.storefront_rounded,
    'shop': Icons.shopping_bag_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final bool terkunci = !layanan.isAllowed;

    final Color abu = gelap
        ? ClayTokens.textTertiaryDark
        : ClayTokens.textTertiary;

    return ClaySurface(
      // Kedalaman mengikuti keadaan seperti sebelumnya, dan sekarang ada tepi
      // beraksen untuk yang menyala: selisih kedalaman clay saja nyaris tak
      // terlihat di layar HP yang kena matahari, dan itu kondisi normal di sini.
      depth: layanan.isActive ? ClayDepth.low : ClayDepth.flat,
      borderColor: layanan.isActive ? _aksenDriver : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Chip identitas layanan. Yang menyala memakai aksen driver; yang
              // mati atau terkunci memakai abu — bentuknya TETAP sama supaya
              // daftarnya tidak belang, hanya warnanya yang mundur.
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  ClayIconChip(
                    icon: _ikon[layanan.code] ?? Icons.category_rounded,
                    accent: layanan.isActive ? _aksenDriver : abu,
                    size: 46,
                  ),

                  // Gembok kecil menempel di sudut chip: penanda yang terbaca
                  // sebelum kalimatnya dibaca, dan bertahan walaupun kartunya
                  // dilirik sekilas.
                  if (terkunci)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gelap
                              ? ClayTokens.surfaceRaisedDark
                              : ClayTokens.surfaceRaised,
                          border: Border.all(
                            color: ClayTokens.warning.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 11,
                          color: ClayTokens.warning,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: ClayTokens.space4),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      layanan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: ClayTokens.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: layanan.isAllowed
                            ? (gelap
                                  ? ClayTokens.textPrimaryDark
                                  : ClayTokens.textPrimary)
                            : abu,
                      ),
                    ),

                    const SizedBox(height: ClayTokens.space2),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: _LencanaKeadaan(
                        terkunci: terkunci,
                        menyala: layanan.isActive,
                        abu: abu,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: ClayTokens.space3),

              _Sakelar(
                nyala: layanan.isActive,
                terkunci: terkunci,
                gelap: gelap,

                // `null` mengunci sakelarnya. Sakelar yang bisa digeser lalu
                // memantul kembali terbaca sebagai bug; yang terkunci dengan
                // keterangan di sebelahnya terbaca sebagai aturan.
                onChanged: layanan.isAllowed && !menyimpan
                    ? (bool nyala) => onUbah(nyala)
                    : null,
              ),
            ],
          ),

          /*
           * Keterangan kenapa layanannya terkunci, di kartunya sendiri.
           *
           * Kalimatnya tidak diubah: dia menyebut sebabnya DAN jalan keluarnya
           * dalam satu baris. Driver yang hanya melihat sakelar mati akan
           * menyimpulkan aplikasinya rusak, lalu menelepon kantor untuk sesuatu
           * yang bisa dia selesaikan sendiri dari halaman Dokumen Saya.
           */
          if (terkunci) ...<Widget>[
            const SizedBox(height: ClayTokens.space3),
            _PanelCatatan(
              warna: ClayTokens.warning,
              ikon: Icons.info_outline_rounded,
              teks: 'Belum diizinkan — lengkapi dokumen Anda',
              gelap: gelap,
            ),
          ],
        ],
      ),
    );
  }
}

/// Lencana keadaan layanan: menyala, dimatikan, atau terkunci.
///
/// ============================================================================
///  KENAPA BUKAN ClayStatusBadge
/// ============================================================================
///  `ClayStatusBadge` menurunkan warnanya dari status ORDER; `enabled`,
///  `disabled` dan `locked` tidak ada di peta itu dan jatuh ke cabang abu-abu,
///  sehingga ketiga keadaan akan berwarna sama — padahal warnanya yang jadi
///  informasi. Menitipkan status order palsu supaya warnanya kebetulan benar
///  akan menyandera halaman ini pada peta status milik order.
///
///  Jadi bentuknya (pil, latar 12% warna, teks 11 w700) disalin, warnanya milik
///  sendiri. Yang seharusnya terjadi di paket bersama: lencana yang menerima
///  warna eksplisit, supaya salinan ini tidak lahir lagi di layar berikutnya.
/// ============================================================================
class _LencanaKeadaan extends StatelessWidget {
  const _LencanaKeadaan({
    required this.terkunci,
    required this.menyala,
    required this.abu,
  });

  final bool terkunci;
  final bool menyala;
  final Color abu;

  @override
  Widget build(BuildContext context) {
    final (String label, IconData ikon, Color warna) = terkunci
        ? ('Terkunci', Icons.lock_rounded, ClayTokens.warning)
        : menyala
        ? ('Aktif', Icons.bolt_rounded, _aksenDriver)
        : ('Dimatikan', Icons.pause_rounded, abu);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space3,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(ikon, size: 13, color: warna),
          const SizedBox(width: 6),

          // Flexible + ellipsis: lencana ini duduk di kolom yang lebarnya sisa
          // setelah chip dan sakelar. Di HP paling sempit, label yang tidak
          // boleh dipotong akan merobek kartunya.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: ClayTokens.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: warna,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sakelar layanan.
///
/// ============================================================================
///  SAKELAR MATERIAL YANG DIWARNAI, BUKAN SAKELAR BUATAN TANGAN
/// ============================================================================
///  Yang membuat sakelar bawaan terlihat asing di antara permukaan clay bukan
///  bentuknya, melainkan warnanya: biru tema Material di tengah palet hijau.
///  Menggambar sendiri sakelar berarti menulis ulang animasi, umpan balik
///  sentuh, dan — yang paling mudah terlupakan — semantik aksesibilitasnya.
///
///  Jadi yang diganti hanya warnanya (aksen driver saat menyala, permukaan
///  tenggelam saat mati) dan ikon di kepala sakelarnya. `onChanged` diteruskan
///  APA ADANYA: null-nya yang mengunci, dan itu mekanisme yang tidak boleh
///  diubah.
///
///  Ikon gembok diputuskan dari `terkunci` (= `!isAllowed`), BUKAN dari
///  `WidgetState.disabled`. Sakelar juga nonaktif sesaat saat perubahan sedang
///  dikirim, dan gembok yang berkedip di situ akan menyatakan layanan yang
///  sebenarnya boleh dipakai sebagai terlarang.
/// ============================================================================
class _Sakelar extends StatelessWidget {
  const _Sakelar({
    required this.nyala,
    required this.terkunci,
    required this.gelap,
    required this.onChanged,
  });

  final bool nyala;
  final bool terkunci;
  final bool gelap;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final Color mati = gelap
        ? ClayTokens.surfaceSunkenDark
        : ClayTokens.surfaceSunken;

    return Switch(
      value: nyala,
      onChanged: onChanged,

      thumbColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> keadaan,
      ) {
        if (keadaan.contains(WidgetState.selected)) {
          return Colors.white;
        }

        return gelap ? ClayTokens.textTertiaryDark : Colors.white;
      }),

      trackColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> keadaan,
      ) {
        if (keadaan.contains(WidgetState.selected)) {
          return _aksenDriver;
        }

        return mati;
      }),

      trackOutlineColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> keadaan,
      ) {
        if (keadaan.contains(WidgetState.selected)) {
          return Colors.transparent;
        }

        return gelap
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.10);
      }),

      thumbIcon: WidgetStateProperty.resolveWith<Icon?>((
        Set<WidgetState> keadaan,
      ) {
        if (terkunci) {
          return const Icon(Icons.lock_rounded, color: ClayTokens.warning);
        }

        if (keadaan.contains(WidgetState.selected)) {
          return const Icon(Icons.check_rounded, color: _aksenDriver);
        }

        return null;
      }),
    );
  }
}

/// Panel catatan bertepi berwarna — dipakai untuk keterangan layanan terkunci.
///
/// Tepi kiri 3 px digambar sebagai KOTAK di dalam ClipRRect, bukan sebagai
/// `Border(left: …)` pada BoxDecoration: border tak seragam yang digabung dengan
/// borderRadius melanggar assert BoxDecoration, dan gejalanya pengecualian saat
/// melukis — bukan tampilan yang sedikit meleset.
class _PanelCatatan extends StatelessWidget {
  const _PanelCatatan({
    required this.warna,
    required this.ikon,
    required this.teks,
    required this.gelap,
  });

  final Color warna;
  final IconData ikon;
  final String teks;
  final bool gelap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 3, child: ColoredBox(color: warna)),
            Expanded(
              child: ColoredBox(
                color: warna.withValues(alpha: gelap ? 0.16 : 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(ClayTokens.space3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(ikon, size: 16, color: warna),
                      const SizedBox(width: ClayTokens.space2),
                      Expanded(
                        child: Text(
                          teks,
                          style: TextStyle(
                            fontFamily: ClayTokens.fontFamily,
                            fontSize: 11.5,
                            height: 1.45,
                            color: gelap
                                ? ClayTokens.textSecondaryDark
                                : ClayTokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile kaca buram untuk DI DALAM panel gradien.
///
/// Putih transparan, bukan warna pejal: tile ini ikut warna panelnya tanpa satu
/// pun cabang warna — pola yang sama dengan lingkaran tekstur di hero v2.
class _TileKaca extends StatelessWidget {
  const _TileKaca({required this.child});

  final Widget child;

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
      child: Center(child: child),
    );
  }
}
