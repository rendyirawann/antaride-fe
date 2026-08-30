import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'order_flow_controller.dart';
import 'quote_screen.dart';

/// Pilih titik jemput dan tujuan.
///
/// ============================================================================
///  TITIKNYA DIPILIH DENGAN MENGGESER PETA, BUKAN DENGAN MENEKANNYA
/// ============================================================================
///  Pin-nya TETAP di tengah layar, dan petanya yang bergerak di belakangnya.
///
///  Alasannya bukan estetika. Menekan peta untuk menaruh pin menuntut ketepatan
///  jari di titik yang sekaligus tertutup jari itu sendiri — dan setiap koreksi
///  kecil menuntut menekan lagi. Dengan pin di tengah, jari menggeser dari mana
///  saja di layar dan pin-nya selalu terlihat.
///
///  Ini juga pola yang dipakai Gojek dan Grab, jadi pengguna di Medan sudah
///  mengenalnya — dan pola yang dikenal tidak perlu dijelaskan.
/// ============================================================================
///
/// ============================================================================
///  KENAPA TIDAK ADA HERO GRADIEN DI LAYAR INI
/// ============================================================================
///  Peta ADALAH kontennya. Hero gradien di puncak layar hanya akan memakan
///  area geser yang justru sedang dipakai memilih titik. Bahasa v2 masuk lewat
///  tepiannya: chrome mengambang di atas peta (tombol kembali + pil judul),
///  panel bawah yang membulat 36 seperti hero yang dibalik, dan penanda tahap
///  dengan chip ikon bergradien — gradien hanya pada elemen kecil.
/// ============================================================================
class RoutePickerScreen extends StatefulWidget {
  const RoutePickerScreen({super.key, required this.serviceCode});

  /// Layanan yang dipilih di beranda. Dipakai membatasi quote supaya
  /// perhitungannya lebih ringan dan response-nya lebih kecil.
  final String serviceCode;

  @override
  State<RoutePickerScreen> createState() => _RoutePickerScreenState();
}

enum _Tahap { jemput, tujuan }

class _RoutePickerScreenState extends State<RoutePickerScreen> {
  final TextEditingController _alamat = TextEditingController();
  final TextEditingController _catatan = TextEditingController();
  final LocationService _lokasi = const LocationService();

  _Tahap _tahap = _Tahap.jemput;
  LatLng _tengah = medanCenter;
  bool _mencariPosisi = true;

  @override
  void initState() {
    super.initState();

    _posisiAwal();
  }

  @override
  void dispose() {
    _alamat.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _posisiAwal() async {
    final LocationOutcome hasil = await _lokasi.current();

    if (!mounted) {
      return;
    }

    setState(() {
      _mencariPosisi = false;

      if (hasil is LocationReady) {
        _tengah = hasil.position;
      }

      // Kalau lokasi tidak tersedia, peta tetap terbuka di pusat Medan dan
      // pengguna menggeser sendiri. Yang TIDAK dilakukan: menolak melanjutkan.
      // Izin lokasi memudahkan, bukan mensyaratkan — dan orang yang menolaknya
      // tetap harus bisa memesan.
    });
  }

  /// Tombol kembali di chrome peta.
  ///
  /// Kembali dari tahap tujuan mengembalikan ke tahap jemput, bukan keluar
  /// dari alur. Pengguna yang ingin memperbaiki titik jemput tidak harus
  /// memulai dari beranda lagi.
  void _kembali() {
    if (_tahap == _Tahap.tujuan) {
      final OrderFlowController alur = context.read<OrderFlowController>();

      setState(() {
        _tahap = _Tahap.jemput;
        _alamat.text = alur.pickup?.address ?? '';
        _catatan.text = alur.pickup?.note ?? '';
        _tengah = alur.pickup?.position ?? _tengah;
      });

      return;
    }

    Navigator.of(context).maybePop();
  }

  Future<void> _lanjut() async {
    final OrderFlowController alur = context.read<OrderFlowController>();

    final String alamat = _alamat.text.trim();

    final ChosenPlace tempat = ChosenPlace(
      position: _tengah,
      address: alamat.isEmpty ? _alamatCadangan() : alamat,
      note: _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
    );

    if (_tahap == _Tahap.jemput) {
      alur.setPickup(tempat);

      setState(() {
        _tahap = _Tahap.tujuan;
        _alamat.clear();
        _catatan.clear();
      });

      return;
    }

    alur.setDestination(tempat);

    final Order? dibuat = await Navigator.of(context).push<Order>(
      MaterialPageRoute<Order>(
        builder: (BuildContext _) =>
            ChangeNotifierProvider<OrderFlowController>.value(
              // Controller yang SAMA diteruskan, bukan yang baru. Alur pemesanan
              // adalah satu state yang melintasi tiga layar — lihat docblock
              // OrderFlowController.
              value: alur,
              child: QuoteScreen(serviceCode: widget.serviceCode),
            ),
      ),
    );

    if (!mounted || dibuat == null) {
      return;
    }

    // Order diteruskan ke beranda sebagai hasil layar ini, dan bersamanya
    // seluruh alur pemilihan titik ikut ditutup. Beranda yang membuka layar
    // pelacakan.
    Navigator.of(context).pop(dibuat);
  }

  /// Alamat pengganti kalau pengguna tidak mengetik apa pun.
  ///
  /// Koordinat, dibulatkan lima desimal — sekitar satu meter, yang cukup untuk
  /// driver menemukannya lewat navigasi. Lebih baik daripada string kosong,
  /// yang di layar driver terbaca sebagai order tanpa alamat.
  String _alamatCadangan() {
    final String lat = _tengah.latitude.toStringAsFixed(5);
    final String lng = _tengah.longitude.toStringAsFixed(5);

    return 'Titik $lat, $lng';
  }

  @override
  Widget build(BuildContext context) {
    final bool jemput = _tahap == _Tahap.jemput;
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    // Tanpa AppBar, peta menembus status bar — chrome-nya yang turun.
    final double atasAman = MediaQuery.paddingOf(context).top;

    final OrderFlowController alur = context.watch<OrderFlowController>();

    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AntarideMap(
                  center: _tengah,
                  fitToContent: false,
                  onCenterChanged: (LatLng titik) {
                    // Hanya menyimpan, TIDAK memanggil quote. Quote diminta
                    // sekali di layar berikutnya, setelah kedua titik pasti.
                    _tengah = titik;
                  },
                  pins: <MapPin>[
                    if (!jemput && alur.pickup != null)
                      MapPin(
                        position: alur.pickup!.position,
                        icon: Icons.trip_origin_rounded,
                        color: ClayTokens.primary,
                        size: 32,
                      ),
                  ],
                ),

                // Pin tengah, TIDAK ikut bergerak. Lihat docblock kelas.
                IgnorePointer(
                  child: Padding(
                    // Digeser ke atas separuh tinggi pin supaya UJUNG BAWAHNYA
                    // yang menunjuk ke tengah layar, bukan pusatnya.
                    padding: const EdgeInsets.only(bottom: 36),
                    child: AnimatedSwitcher(
                      // Warna pin berganti bersama tahap; pergantian yang
                      // memudar+membesar sebentar memberi umpan balik bahwa
                      // tahapnya berubah — pin-nya sendiri tetap di tengah.
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (Widget anak, Animation<double> animasi) =>
                              ScaleTransition(
                                scale: animasi,
                                child: FadeTransition(
                                  opacity: animasi,
                                  child: anak,
                                ),
                              ),
                      child: Icon(
                        Icons.place_rounded,
                        key: ValueKey<bool>(jemput),
                        size: 44,
                        color: jemput ? ClayTokens.primary : ClayTokens.danger,
                        shadows: <Shadow>[
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Chrome mengambang: tombol kembali + pil judul tahap.
                // AppBar dihapus supaya petanya penuh; keduanya kartu clay
                // supaya terbaca di atas peta yang ramai.
                Positioned(
                  top: atasAman + ClayTokens.space2,
                  left: ClayTokens.space4,
                  right: ClayTokens.space4,
                  child: ClayEntrance(
                    index: 0,
                    child: Row(
                      children: <Widget>[
                        _TombolPeta(
                          icon: Icons.arrow_back_rounded,
                          label: 'Kembali',
                          onTap: _kembali,
                        ),
                        const SizedBox(width: ClayTokens.space3),
                        Flexible(
                          child: _PilJudul(
                            judul: jemput
                                ? 'Titik penjemputan'
                                : 'Titik tujuan',
                            warna: jemput
                                ? ClayTokens.primary
                                : ClayTokens.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_mencariPosisi)
                  Positioned(
                    // Turun di bawah chrome supaya tidak bertumpuk dengannya.
                    top:
                        atasAman +
                        ClayTokens.space2 +
                        ClayTokens.minTouchTarget +
                        ClayTokens.space3,
                    child: const ClaySurface(
                      depth: ClayDepth.medium,
                      radius: ClayTokens.radiusPill,
                      padding: EdgeInsets.symmetric(
                        horizontal: ClayTokens.space4,
                        vertical: ClayTokens.space2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ClayInlineLoader(size: 12, color: ClayTokens.primary),
                          SizedBox(width: ClayTokens.space3),
                          Text(
                            'Mencari posisi Anda…',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Panel bawah: lembaran membulat 36 — cermin sudut hero v2 — dengan
          // bayangan tinggi supaya terbaca melayang di atas peta, bukan
          // menempel keras seperti kotak radius 0.
          ClayEntrance(
            index: 1,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: gelap
                    ? ClayTokens.surfaceRaisedDark
                    : ClayTokens.surfaceRaised,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
                boxShadow: ClayShadows.outer(ClayDepth.high, dark: gelap),
              ),
              padding: const EdgeInsets.fromLTRB(
                ClayTokens.space5,
                ClayTokens.space5,
                ClayTokens.space5,
                ClayTokens.space5,
              ),
              child: SafeArea(
                top: false,
                child: AnimatedSize(
                  // Kolom catatan hanya ada di tahap jemput; tanpa ini tinggi
                  // panel melompat saat tahap berganti.
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _PenandaTahap(jemput: jemput),

                      const SizedBox(height: ClayTokens.space5),

                      ClayInput(
                        controller: _alamat,
                        label: jemput ? 'Alamat penjemputan' : 'Alamat tujuan',
                        hint: jemput
                            ? 'Jl. Gatot Subroto No. 12'
                            : 'Jl. Iskandar Muda No. 4',
                        prefixIcon: jemput
                            ? Icons.trip_origin_rounded
                            : Icons.place_rounded,
                        maxLength: 200,
                      ),

                      if (jemput) ...<Widget>[
                        const SizedBox(height: ClayTokens.space3),
                        ClayInput(
                          controller: _catatan,
                          label: 'Catatan untuk driver',
                          // Contoh yang diberikan sengaja spesifik. Kolom catatan
                          // dengan hint "opsional" hampir selalu dibiarkan kosong,
                          // padahal justru keterangan seperti inilah yang membuat
                          // driver menemukan titiknya tanpa menelepon.
                          hint: 'Pagar hitam, sebelah warung',
                          maxLength: 120,
                        ),
                      ],

                      const SizedBox(height: ClayTokens.space4),

                      ClayButton(
                        label: jemput ? 'Lanjut pilih tujuan' : 'Lihat harga',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _lanjut,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol bulat clay yang mengambang di atas peta.
///
/// ============================================================================
///  KENAPA BUKAN ClayBackButton
/// ============================================================================
///  ClayBackButton adalah kaca buram untuk DI DALAM hero gradien — di atas
///  peta yang terang dia nyaris tak terlihat (docblock-nya sendiri melarang).
///  Di sini yang dibutuhkan kebalikannya: permukaan clay pekat dengan bayangan,
///  supaya punya tepi yang jelas di atas peta yang warnanya tidak bisa diduga.
/// ============================================================================
class _TombolPeta extends StatelessWidget {
  const _TombolPeta({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    // Lingkaran terlihat 44 px, area sentuh 48 px (ClayTokens.minTouchTarget).
    return SizedBox(
      width: ClayTokens.minTouchTarget,
      height: ClayTokens.minTouchTarget,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: ClayTokens.primary.withValues(alpha: 0.10),
          highlightColor: ClayTokens.primary.withValues(alpha: 0.05),
          child: Semantics(
            button: true,
            label: label,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gelap
                      ? ClayTokens.surfaceRaisedDark
                      : ClayTokens.surfaceRaised,
                  boxShadow: ClayShadows.outer(ClayDepth.medium, dark: gelap),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: gelap
                      ? ClayTokens.textPrimaryDark
                      : ClayTokens.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pil judul tahap di atas peta: titik warna tahap + judulnya.
///
/// Menggantikan judul AppBar yang dihapus — pengguna tetap harus tahu sedang
/// memilih titik apa, dan warna titiknya disamakan dengan warna pin di tengah
/// peta supaya keduanya terbaca sebagai satu hal.
class _PilJudul extends StatelessWidget {
  const _PilJudul({required this.judul, required this.warna});

  final String judul;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space4,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: gelap ? ClayTokens.surfaceRaisedDark : ClayTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
        boxShadow: ClayShadows.outer(ClayDepth.medium, dark: gelap),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: warna),
          ),
          const SizedBox(width: ClayTokens.space2),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                judul,
                key: ValueKey<String>(judul),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: gelap
                      ? ClayTokens.textPrimaryDark
                      : ClayTokens.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Penanda dua tahap: Jemput → Tujuan.
///
/// ============================================================================
///  KENAPA PENANDA TAHAP, BUKAN SEKADAR JUDUL YANG BERGANTI
/// ============================================================================
///  Dua tahap dalam satu layar tanpa indikator progres membuat tahap kedua
///  terasa seperti layar yang sama yang "belum selesai". Dua chip dengan garis
///  penghubung memberi tahu ada dua langkah, sedang di langkah mana, dan bahwa
///  langkah pertama sudah beres (chip-nya berganti centang).
///
///  Chip aktif memakai gradien aksen v2 ([ClayIconChip]); warnanya disamakan
///  dengan pin di peta — hijau untuk jemput, merah untuk tujuan — supaya
///  penanda dan pin terbaca sebagai satu sistem.
/// ============================================================================
class _PenandaTahap extends StatelessWidget {
  const _PenandaTahap({required this.jemput});

  final bool jemput;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final Color labelAktif = gelap
        ? ClayTokens.textPrimaryDark
        : ClayTokens.textPrimary;
    final Color labelRedup = gelap
        ? ClayTokens.textTertiaryDark
        : ClayTokens.textTertiary;
    final Color garisRedup = gelap
        ? ClayTokens.surfaceSunkenDark
        : ClayTokens.surfaceSunken;

    return Row(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: jemput
              ? const ClayIconChip(
                  key: ValueKey<String>('jemput-aktif'),
                  icon: Icons.trip_origin_rounded,
                  accent: ClayTokens.primary,
                  size: 34,
                )
              : const ClayIconChip(
                  key: ValueKey<String>('jemput-selesai'),
                  icon: Icons.check_rounded,
                  accent: ClayTokens.primary,
                  size: 34,
                ),
        ),
        const SizedBox(width: ClayTokens.space2),
        Text(
          'Jemput',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: labelAktif,
          ),
        ),
        const SizedBox(width: ClayTokens.space3),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            height: 3,
            decoration: BoxDecoration(
              color: jemput ? garisRedup : ClayTokens.primary,
              borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
            ),
          ),
        ),
        const SizedBox(width: ClayTokens.space3),
        Text(
          'Tujuan',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: jemput ? labelRedup : labelAktif,
          ),
        ),
        const SizedBox(width: ClayTokens.space2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: jemput
              ? Container(
                  key: const ValueKey<String>('tujuan-nonaktif'),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: garisRedup,
                    borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
                  ),
                  child: Icon(Icons.place_rounded, size: 17, color: labelRedup),
                )
              : const ClayIconChip(
                  key: ValueKey<String>('tujuan-aktif'),
                  icon: Icons.place_rounded,
                  accent: ClayTokens.danger,
                  size: 34,
                ),
        ),
      ],
    );
  }
}
