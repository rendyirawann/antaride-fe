import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:antaride_notifications/antaride_notifications.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'rating_sheet.dart';
import 'tracking_controller.dart';

/// Layar pelacakan satu order.
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key, required this.orderUuid});

  final String orderUuid;

  @override
  Widget build(BuildContext context) {
    final AntarideServices services = context.read<AntarideServices>();

    return ChangeNotifierProvider<TrackingController>(
      create: (BuildContext _) =>
          TrackingController(orders: services.orders, orderUuid: orderUuid)
            ..start(),
      child: const _Isi(),
    );
  }
}

class _Isi extends StatefulWidget {
  const _Isi();

  @override
  State<_Isi> createState() => _IsiState();
}

class _IsiState extends State<_Isi> {
  /// Form penilaian sudah pernah ditawarkan di layar ini.
  ///
  /// ==========================================================================
  ///  DITAWARKAN SEKALI, LALU MENUNGGU DIPANGGIL
  /// ==========================================================================
  ///  Form penilaian dibuka otomatis begitu order selesai — di situlah penumpang
  ///  paling mungkin menilai, karena perjalanannya baru saja terjadi.
  ///
  ///  Tapi HANYA sekali. Penumpang yang menutupnya sudah memutuskan; membukanya
  ///  lagi setiap penarikan berkala — dan penarikannya beberapa detik sekali —
  ///  akan membuat layar tidak bisa dipakai sama sekali.
  ///
  ///  Setelah ditutup, jalannya lewat kartu "Nilai perjalanan" di badan halaman.
  ///  Itu tetap ada selama `canRate` masih true, termasuk kalau order dibuka
  ///  lagi dari riwayat berhari-hari kemudian.
  /// ==========================================================================
  bool _sudahMenawarkan = false;

  /// Status order pada penarikan sebelumnya.
  ///
  /// ==========================================================================
  ///  DIPAKAI MENYEGARKAN LENCANA NOTIFIKASI, BUKAN MENGGAMBAR LAYAR
  /// ==========================================================================
  ///  Backend membuat notifikasi pada setiap transisi status — driver menerima,
  ///  driver tiba, perjalanan selesai. Push notification ditunda, jadi tidak ada
  ///  yang memberi tahu aplikasi bahwa notifikasi itu sudah ada.
  ///
  ///  Yang tersisa: aplikasi harus MENANYAKANNYA. Dan momen paling tepat untuk
  ///  menanyakannya adalah tepat ketika status yang dilihat layar ini berubah —
  ///  karena di situlah backend baru saja membuat notifikasinya.
  ///
  ///  Alternatifnya timer berkala khusus untuk lencana, yang berarti request
  ///  tambahan yang hampir selalu mengembalikan angka yang sama. Layar ini sudah
  ///  menarik status order secara berkala; ini hanya memanfaatkan penarikan yang
  ///  memang sudah terjadi.
  ///
  ///  Null berarti belum ada status yang pernah diamati. Penarikan PERTAMA tidak
  ///  dianggap perubahan — kalau dianggap, setiap kali layar dibuka akan ada satu
  ///  request lencana yang tidak dipicu peristiwa apa pun.
  /// ==========================================================================
  String? _statusTerakhir;

  /// Buka form penilaian, lalu segarkan order kalau penilaiannya masuk.
  ///
  /// Penyegarannya perlu supaya `can_rate` menjadi false dan kartunya hilang —
  /// tanpa itu, kartu penilaian tetap tampil untuk perjalanan yang sudah dinilai.
  Future<void> _nilai(Order order) async {
    final TrackingController pelacak = context.read<TrackingController>();

    final OrderRating? hasil = await RatingSheet.show(
      context: context,
      order: order,
    );

    if (!mounted || hasil == null) {
      return;
    }

    await pelacak.refreshNow();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terima kasih atas penilaian Anda.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _batalkan(BuildContext context, Order order) async {
    final AntarideServices services = context.read<AntarideServices>();
    final TrackingController pelacak = context.read<TrackingController>();

    final Result<List<CancellationReason>> hasil = await services.orders
        .cancellationReasons();

    if (!context.mounted) {
      return;
    }

    final List<CancellationReason> alasan =
        hasil.valueOrNull ?? const <CancellationReason>[];

    if (alasan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasil.failureOrNull?.message ??
                'Tidak bisa memuat pilihan alasan. Coba lagi.',
          ),
          backgroundColor: ClayTokens.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final CancellationReason? dipilih =
        await ClayBottomSheet.show<CancellationReason>(
          context: context,
          title: 'Kenapa dibatalkan?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final CancellationReason a in alasan)
                ClayCard(
                  onTap: () => Navigator.of(context).pop(a),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          a.text,
                          style: const TextStyle(
                            fontFamily: ClayTokens.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      /*
                   * Peringatan biaya ditampilkan SEBELUM ditekan, di baris
                   * alasannya sendiri.
                   *
                   * Menagih lalu menjelaskan sesudahnya adalah cara paling cepat
                   * membuat orang merasa ditipu — walaupun biayanya sah dan
                   * sudah tertulis di syarat layanan. Yang menentukan ada biaya
                   * atau tidak tetap backend; ini hanya memberitahu.
                   */
                      if (a.mayChargeFee)
                        const _LencanaKecil(
                          teks: 'Bisa kena biaya',
                          warna: ClayTokens.warning,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );

    if (dipilih == null || !context.mounted) {
      return;
    }

    final Result<Order> pembatalan = await services.orders.cancel(
      uuid: order.uuid,
      reasonCode: dipilih.code,
    );

    if (!context.mounted) {
      return;
    }

    switch (pembatalan) {
      case Ok<Order>():
        await pelacak.refreshNow();

      case Err<Order>(failure: final ApiFailure f):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(f.message),
            backgroundColor: ClayTokens.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// Segarkan lencana notifikasi kalau statusnya berubah sejak penarikan lalu.
  ///
  /// Dipanggil dari `build`, jadi permintaannya dijadwalkan post-frame — bukan
  /// dijalankan di tengah pembangunan widget. `notifyListeners` di dalam `build`
  /// melempar, dan yang melemparnya adalah controller notifikasi, bukan layar
  /// ini — sehingga jejak galatnya tidak akan menunjuk ke sini.
  void _catatPerubahanStatus(String status) {
    if (_statusTerakhir == status) {
      return;
    }

    final bool pertama = _statusTerakhir == null;

    _statusTerakhir = status;

    if (pertama) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationController>().refreshBadge();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TrackingController pelacak = context.watch<TrackingController>();
    final Order? order = pelacak.order;

    if (order != null) {
      _catatPerubahanStatus(order.status);
    }

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pesanan')),
        body: pelacak.isLoading
            ? const ClayLoader(message: 'Memuat pesanan…')
            : ClayErrorState(
                message:
                    pelacak.failure?.message ?? 'Pesanan tidak bisa dimuat.',
                onRetry: pelacak.refreshNow,
              ),
      );
    }

    /*
     * Form penilaian dibuka otomatis, sekali, begitu order selesai.
     *
     * Lewat post-frame callback: membuka bottom sheet DI DALAM `build` akan
     * memanggil `showModalBottomSheet` selagi frame-nya masih dibangun, dan
     * Flutter melemparkan assertion untuk itu.
     */
    if (order.canRate && !_sudahMenawarkan) {
      _sudahMenawarkan = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _nilai(order);
        }
      });
    }

    final List<LatLng> rute = PolylineCodec.decode(order.routePolyline);

    /*
     * ========================================================================
     *  DESAIN v2: PETA ADALAH ISINYA, BUKAN LAMPIRAN DI BAWAH APPBAR
     * ========================================================================
     *  Layar ini dibuka untuk SATU pertanyaan: di mana drivernya. Karena itu
     *  tidak ada hero gradien besar di sini — hero setinggi beranda akan
     *  memakan justru bagian layar yang menjawab pertanyaan itu.
     *
     *  Sebagai gantinya: peta menembus sampai status bar, kendalinya
     *  (kembali, nomor order, segarkan) mengambang di atasnya sebagai pil clay,
     *  dan seluruh keterangan perjalanan naik ke panel bermahkota bulat yang
     *  menumpang tepi bawah peta. Gradien dipakai hemat — hanya chip kecil dan
     *  bingkai kode jemput — supaya yang bergradien tetap berarti.
     * ========================================================================
     */
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        // Tile peta terang di KEDUA mode tema, jadi ikon status bar selalu
        // gelap di sini — mengikuti tema akan membuatnya hilang di mode gelap.
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints batas) {
            /*
             * Tinggi peta diikat ke tinggi layar, bukan angka mati.
             *
             * 44% memberi peta bidang yang cukup untuk membaca arah tanpa
             * mendorong kartu status keluar layar. Dijepit 200–340 supaya di HP
             * pendek petanya tidak menyusut jadi pita, dan di layar tinggi tidak
             * menelan panel keterangannya.
             */
            final double tinggiPeta = (batas.maxHeight * 0.44).clamp(
              200.0,
              340.0,
            );

            return Stack(
              children: <Widget>[
                /*
                 * Peta TIDAK dibungkus apa pun selain Positioned.
                 *
                 * `AntarideMap` adalah platform view: Opacity, Transform, atau
                 * ClipRRect di sekelilingnya memaksa compositor menyalinnya ke
                 * layer terpisah tiap frame — mahal, dan pada sebagian perangkat
                 * petanya berkedip hitam. Sudut membulat di bawah datang dari
                 * panel yang MENUTUPI tepi peta, bukan dari memotong petanya.
                 */
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: tinggiPeta,
                  child: AntarideMap(
                    interactive: true,
                    route: rute,
                    pins: <MapPin>[
                      MapPin(
                        position: LatLng(order.pickup.lat, order.pickup.lng),
                        icon: Icons.trip_origin_rounded,
                        color: ClayTokens.primary,
                        size: 30,
                      ),
                      if (order.destination != null)
                        MapPin(
                          position: LatLng(
                            order.destination!.lat,
                            order.destination!.lng,
                          ),
                          icon: Icons.place_rounded,
                          color: ClayTokens.danger,
                          size: 30,
                        ),
                    ],
                  ),
                ),

                // Panel menumpang 24 px di atas tepi bawah peta: itu yang
                // membuat mahkota bulatnya terbaca sebagai lapisan DI ATAS peta,
                // bukan sebagai kotak yang kebetulan bersebelahan.
                Positioned(
                  top: tinggiPeta - 24,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _Panel(
                    order: order,
                    onNilai: () => _nilai(order),
                    onBatalkan: () => _batalkan(context, order),
                  ),
                ),

                Positioned(
                  top: MediaQuery.paddingOf(context).top + ClayTokens.space2,
                  left: ClayTokens.space4,
                  right: ClayTokens.space4,
                  child: _KontrolPeta(
                    nomor: order.orderNumber,
                    tertunda: pelacak.failure != null,
                    onSegarkan: pelacak.refreshNow,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Kendali mengambang di atas peta
// ---------------------------------------------------------------------------

/// Baris kendali yang mengambang di atas peta: kembali, nomor order, segarkan.
///
/// ============================================================================
///  PIL CLAY, BUKAN ClayGlassButton
/// ============================================================================
///  Kaca buram putih menuntut latar PEKAT di belakangnya — syarat pakai yang
///  ditulis di ClayGlassButton sendiri. Di sini latarnya tile peta yang terang
///  dan berbintik: lingkaran putih-alpha di atasnya nyaris hilang, dan tombol
///  kembali yang nyaris hilang bukan sekadar jelek, itu jalan buntu.
///
///  Pil clay bermassa penuh menyelesaikan itu tanpa membuat komponen tandingan:
///  bentuknya ClaySurface yang sama dengan kartu di panel bawah.
/// ============================================================================
class _KontrolPeta extends StatelessWidget {
  const _KontrolPeta({
    required this.nomor,
    required this.tertunda,
    required this.onSegarkan,
  });

  final String nomor;
  final bool tertunda;
  final VoidCallback onSegarkan;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            _PilIkon(
              icon: Icons.arrow_back_rounded,
              label: 'Kembali',
              onTap: () => Navigator.maybePop(context),
            ),

            Expanded(
              child: Center(
                child: ClaySurface(
                  depth: ClayDepth.medium,
                  radius: ClayTokens.radiusPill,
                  margin: const EdgeInsets.symmetric(
                    horizontal: ClayTokens.space3,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClayTokens.space4,
                    vertical: ClayTokens.space3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.confirmation_number_rounded,
                        size: 15,
                        color: ClayTokens.primary,
                      ),
                      const SizedBox(width: ClayTokens.space2),
                      Flexible(
                        child: Text(
                          nomor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: ClayTokens.fontFamily,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: _teksUtama(gelap),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            _PilIkon(
              icon: Icons.refresh_rounded,
              label: 'Segarkan',
              onTap: onSegarkan,
            ),
          ],
        ),

        // Pita pembaruan tertunda. Data lama TETAP tampil di bawahnya — lihat
        // penjelasan di TrackingController.
        if (tertunda) ...<Widget>[
          const SizedBox(height: ClayTokens.space3),
          const ClaySurface(
            depth: ClayDepth.medium,
            radius: ClayTokens.radiusSmall,
            borderColor: ClayTokens.warning,
            padding: EdgeInsets.all(ClayTokens.space3),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.cloud_off_rounded,
                  size: 15,
                  color: ClayTokens.warning,
                ),
                SizedBox(width: ClayTokens.space2),
                Expanded(
                  child: Text(
                    'Pembaruan tertunda. Data yang tampil mungkin belum '
                    'yang terbaru.',
                    style: TextStyle(
                      fontFamily: ClayTokens.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: ClayTokens.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Tombol bulat clay untuk di atas peta. Area sentuhnya penuh 48 px.
class _PilIkon extends StatelessWidget {
  const _PilIkon({
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

    return Tooltip(
      message: label,
      child: ClaySurface(
        depth: ClayDepth.medium,
        radius: ClayTokens.radiusPill,
        padding: EdgeInsets.zero,
        width: ClayTokens.minTouchTarget,
        height: ClayTokens.minTouchTarget,
        onTap: onTap,
        child: Center(child: Icon(icon, size: 21, color: _teksUtama(gelap))),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Panel keterangan
// ---------------------------------------------------------------------------

/// Panel keterangan perjalanan yang menumpang tepi bawah peta.
///
/// Isinya bisa panjang (status, driver, kode, alamat, ongkos, penilaian), jadi
/// bergulir sendiri. Tombol pembatalan DIPAKU di kakinya, bukan ikut bergulir:
/// itu satu-satunya keputusan yang bisa diambil penumpang di layar ini, dan
/// keputusan tidak boleh bersembunyi di ujung gulungan.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.order,
    required this.onNilai,
    required this.onBatalkan,
  });

  final Order order;
  final VoidCallback onNilai;
  final VoidCallback onBatalkan;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final double bawah = MediaQuery.paddingOf(context).bottom;

    // Giliran animasi masuk dihitung berjalan, bukan ditulis tangan per kartu:
    // kartu driver dan kode jemput muncul bersyarat, dan indeks yang ditulis
    // tangan akan meninggalkan lubang di urutannya begitu salah satunya absen.
    int urutan = 0;
    Widget masuk(Widget anak) => ClayEntrance(index: urutan++, child: anak);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: gelap ? ClayTokens.surfaceDark : ClayTokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: gelap ? 0.5 : 0.14),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                ClayTokens.space5,
                ClayTokens.space6,
                ClayTokens.space5,
                order.canCancel ? ClayTokens.space6 : ClayTokens.space8 + bawah,
              ),
              children: <Widget>[
                masuk(_Status(order: order)),

                if (order.driver != null) ...<Widget>[
                  const SizedBox(height: ClayTokens.space5),
                  masuk(
                    _Bagian(
                      label: 'Driver Anda',
                      child: _KartuDriver(driver: order.driver!),
                    ),
                  ),
                ],

                if (order.pickupCode != null) ...<Widget>[
                  const SizedBox(height: ClayTokens.space5),
                  masuk(_KodeJemput(kode: order.pickupCode!)),
                ],

                const SizedBox(height: ClayTokens.space5),

                masuk(
                  _Bagian(
                    label: 'Rute',
                    child: _Alamat(order: order),
                  ),
                ),

                const SizedBox(height: ClayTokens.space5),

                masuk(
                  _Bagian(
                    label: 'Rincian biaya',
                    child: _Ongkos(order: order),
                  ),
                ),

                /*
                 * Kartu penilaian, untuk penumpang yang menutup formnya tadi.
                 *
                 * Tetap ada selama `can_rate` masih true — termasuk kalau order
                 * dibuka lagi dari riwayat berhari-hari kemudian. Tanpa jalan
                 * kedua ini, sekali form ditutup, penilaiannya hilang selamanya.
                 */
                if (order.canRate) ...<Widget>[
                  const SizedBox(height: ClayTokens.space5),
                  masuk(_AjakanMenilai(onTap: onNilai)),
                ],

                // Penilaian yang SUDAH diberikan tetap ditampilkan.
                //
                // Penumpang yang lupa apakah dia sudah menilai mendapat
                // jawabannya di sini — tanpa harus mencoba dan mendapat
                // penolakan.
                if (order.rating != null) ...<Widget>[
                  const SizedBox(height: ClayTokens.space5),
                  masuk(_PenilaianTersimpan(order.rating!)),
                ],
              ],
            ),
          ),

          if (order.canCancel) _BilahAksi(onBatalkan: onBatalkan),
        ],
      ),
    );
  }
}

/// Label bagian dan kartunya, dijadikan satu supaya jaraknya tidak menyimpang.
class _Bagian extends StatelessWidget {
  const _Bagian({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: ClayTokens.space1,
            bottom: ClayTokens.space3,
          ),
          child: ClaySectionLabel(label),
        ),
        child,
      ],
    );
  }
}

/// Kaki panel: satu tombol, dipaku, di atas garis pemisah tipis.
class _BilahAksi extends StatelessWidget {
  const _BilahAksi({required this.onBatalkan});

  final VoidCallback onBatalkan;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _garis(gelap))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ClayTokens.space5,
            vertical: ClayTokens.space4,
          ),
          child: ClayButton(
            label: 'Batalkan pesanan',
            variant: ClayButtonVariant.danger,
            icon: Icons.close_rounded,
            height: 52,
            onPressed: onBatalkan,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Kartu status
// ---------------------------------------------------------------------------

class _Status extends StatelessWidget {
  const _Status({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    // Warna diambil dari pemetaan bersama, bukan dipilih ulang di sini: warna
    // sebuah status harus sama persis di semua layar yang menampilkannya.
    final Color warna = ClayStatusBadge.warnaUntuk(order.status);

    final int? langkah = _langkah();

    return ClaySurface(
      depth: ClayDepth.medium,
      padding: const EdgeInsets.all(ClayTokens.space5),

      // Driver yang sudah tiba diberi border kuning. Ini satu-satunya status
      // yang menuntut penumpang bertindak SEKARANG, dan harus terlihat berbeda
      // dari yang lain sejak pandangan pertama.
      borderColor: order.isDriverWaiting ? ClayTokens.warning : null,

      // Pergantian status disilangkan, tidak dipotong: layar ini menarik ulang
      // setiap beberapa detik, dan isi yang berganti mendadak terbaca sebagai
      // kedipan. Kuncinya STATUS, bukan seluruh order — kalau seluruh order,
      // setiap penarikan berkala memicu transisi walau tidak ada yang berubah.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        child: Column(
          key: ValueKey<String>(order.status),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClayIconChip(icon: _ikon(), accent: warna, size: 46),
                const SizedBox(width: ClayTokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        // Label dari backend — satu sumber untuk tiga aplikasi.
                        order.statusLabel,
                        style: TextStyle(
                          fontFamily: ClayTokens.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.2,
                          color: _teksUtama(gelap),
                        ),
                      ),
                      const SizedBox(height: ClayTokens.space1),
                      Text(
                        _pesan(),
                        style: TextStyle(
                          fontFamily: ClayTokens.fontFamily,
                          fontSize: 12.5,
                          height: 1.45,
                          color: _teksKedua(gelap),
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.isSearching)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: ClayTokens.space3,
                      top: ClayTokens.space3,
                    ),
                    child: ClayInlineLoader(size: 14, color: warna),
                  ),
              ],
            ),

            if (langkah != null) ...<Widget>[
              const SizedBox(height: ClayTokens.space5),
              _Jejak(langkah: langkah, warna: warna),
            ],

            if (order.distanceM > 0 || order.durationS > 0) ...<Widget>[
              const SizedBox(height: ClayTokens.space5),
              _Metrik(order: order),
            ],
          ],
        ),
      ),
    );
  }

  /// Ikon yang mewakili status.
  ///
  /// Isyarat kedua setelah warna: pengguna yang tidak bisa membedakan hijau dan
  /// kuning tetap melihat bahwa lambangnya berganti.
  IconData _ikon() {
    return switch (order.status) {
      'created' => Icons.receipt_long_rounded,
      'searching' => Icons.radar_rounded,
      'accepted' => Icons.how_to_reg_rounded,
      'driver_arriving' => Icons.two_wheeler_rounded,
      'driver_arrived' => Icons.pin_drop_rounded,
      'in_progress' => Icons.navigation_rounded,
      'completed' => Icons.check_circle_rounded,
      'cancelled' => Icons.cancel_rounded,
      'no_driver' => Icons.person_search_rounded,
      'expired' => Icons.timer_off_rounded,
      _ => Icons.local_taxi_rounded,
    };
  }

  /// Posisi order pada empat tahap perjalanan, atau null kalau perjalanannya
  /// tidak pernah terjadi.
  ///
  /// Null untuk pembatalan, kedaluwarsa, dan tidak-ada-driver: jejak yang
  /// mandek di tengah untuk order yang sudah mati membuat orang menunggu
  /// kelanjutan yang tidak akan datang.
  int? _langkah() {
    return switch (order.status) {
      'created' || 'searching' => 0,
      'accepted' || 'driver_arriving' || 'driver_arrived' => 1,
      'in_progress' => 2,
      'completed' => 3,
      _ => null,
    };
  }

  /// Kalimat yang menjelaskan apa yang sedang terjadi.
  ///
  /// Lencana status saja tidak cukup: "Mencari driver" tidak memberitahu apakah
  /// penumpang perlu menunggu di tempat atau boleh berjalan. Kalimat ini yang
  /// memberitahunya — dan itu ditulis di aplikasi, bukan di backend, karena
  /// yang berbeda per aplikasi adalah SIAPA yang membacanya. Driver mendapat
  /// kalimat yang lain untuk status yang sama.
  String _pesan() {
    final Duration? mencari = order.searchingFor;

    return switch (order.status) {
      'created' => 'Pesanan Anda sedang disiapkan.',
      'searching' =>
        mencari == null
            ? 'Kami sedang mencari driver terdekat.'
            : 'Mencari driver — sudah ${mencari.inSeconds} detik. Biasanya di '
                  'bawah satu menit.',
      'accepted' =>
        'Driver sudah menerima pesanan Anda dan akan segera '
            'berangkat.',
      'driver_arriving' => 'Driver sedang menuju titik penjemputan.',
      'driver_arrived' =>
        'Driver sudah tiba. Sebutkan kode jemput di bawah '
            'kepada driver.',
      'in_progress' => 'Perjalanan sedang berlangsung.',
      'completed' => 'Perjalanan selesai. Terima kasih sudah memakai Antaride.',
      'cancelled' => 'Pesanan ini dibatalkan.',
      'no_driver' =>
        'Tidak ada driver yang tersedia saat ini. Coba pesan '
            'beberapa saat lagi.',
      'expired' => 'Pesanan kedaluwarsa karena tidak ada driver yang menerima.',
      _ => order.statusLabel,
    };
  }
}

/// Empat ruas tahap perjalanan: dipesan, dijemput, perjalanan, selesai.
///
/// Lencana status menjawab "sekarang di mana"; jejak ini menjawab "berapa lagi
/// yang tersisa" — dan pertanyaan kedua itu yang membuat orang berhenti menarik
/// ulang layarnya setiap sepuluh detik.
class _Jejak extends StatelessWidget {
  const _Jejak({required this.langkah, required this.warna});

  final int langkah;
  final Color warna;

  static const List<String> _label = <String>[
    'Dipesan',
    'Dijemput',
    'Perjalanan',
    'Selesai',
  ];

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final Color mati = gelap
        ? ClayTokens.surfaceSunkenDark
        : ClayTokens.surfaceSunken;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < _label.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= langkah ? warna : mati,
                    borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: ClayTokens.space2),

        Row(
          children: <Widget>[
            for (int i = 0; i < _label.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _label[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: ClayTokens.fontFamily,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: i <= langkah ? warna : _teksKetiga(gelap),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Jarak, lama perjalanan, dan nama layanan dalam satu strip tenggelam.
class _Metrik extends StatelessWidget {
  const _Metrik({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> butir = <Widget>[
      if (order.distanceM > 0)
        _ButirMetrik(
          icon: Icons.straighten_rounded,
          teks: _jarak(order.distanceM),
        ),
      if (order.durationS > 0)
        _ButirMetrik(
          icon: Icons.schedule_rounded,
          teks: _durasi(order.durationS),
        ),
      if (order.serviceName != null)
        _ButirMetrik(icon: Icons.local_taxi_rounded, teks: order.serviceName!),
    ];

    return ClaySurface(
      depth: ClayDepth.pressed,
      radius: ClayTokens.radiusSmall,
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space4,
        vertical: ClayTokens.space3,
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < butir.length; i++) ...<Widget>[
            if (i > 0)
              Container(
                width: 1,
                height: 16,
                margin: const EdgeInsets.symmetric(
                  horizontal: ClayTokens.space3,
                ),
                color: _garis(gelap),
              ),
            Flexible(child: butir[i]),
          ],
        ],
      ),
    );
  }
}

class _ButirMetrik extends StatelessWidget {
  const _ButirMetrik({required this.icon, required this.teks});

  final IconData icon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: _teksKetiga(gelap)),
        const SizedBox(width: ClayTokens.space2),
        Flexible(
          child: Text(
            teks,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: ClayTokens.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _teksKedua(gelap),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Driver
// ---------------------------------------------------------------------------

class _KartuDriver extends StatelessWidget {
  const _KartuDriver({required this.driver});

  final OrderDriver driver;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final bool adaRincian =
        driver.vehicleDescription.isNotEmpty || driver.plateNumber != null;

    return ClaySurface(
      depth: ClayDepth.low,
      padding: const EdgeInsets.all(ClayTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const ClayIconChip(
                icon: Icons.person_rounded,
                accent: ClayTokens.primary,
                size: 48,
              ),
              const SizedBox(width: ClayTokens.space4),
              Expanded(
                child: Text(
                  driver.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: ClayTokens.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: _teksUtama(gelap),
                  ),
                ),
              ),
              const SizedBox(width: ClayTokens.space3),

              // Rating dalam pil kecil, bukan baris teks di bawah nama: angkanya
              // dibaca sekali sebagai penilaian, dan pil membuatnya terbaca
              // begitu tanpa bersaing dengan plat nomor di bawahnya.
              ClaySurface(
                depth: ClayDepth.pressed,
                radius: ClayTokens.radiusPill,
                padding: const EdgeInsets.symmetric(
                  horizontal: ClayTokens.space3,
                  vertical: ClayTokens.space1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: ClayTokens.warning,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${driver.ratingAverage.toStringAsFixed(1)} '
                      '(${driver.ratingCount})',
                      style: TextStyle(
                        fontFamily: ClayTokens.fontFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _teksKedua(gelap),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (adaRincian) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClayTokens.space4),
              child: Container(height: 1, color: _garis(gelap)),
            ),

            if (driver.vehicleDescription.isNotEmpty)
              _BarisInfo(
                label: 'Kendaraan',
                child: Text(
                  driver.vehicleDescription,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: ClayTokens.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: _teksUtama(gelap),
                  ),
                ),
              ),

            /*
             * Plat nomor ditampilkan PALING BESAR di kartu ini.
             *
             * Ini satu-satunya cara penumpang memastikan kendaraan yang berhenti
             * di depannya benar. Nama dan foto driver membantu, tapi plat nomor
             * yang menentukan — dan di antrean ojek yang ramai, itu yang dibaca
             * dari jauh. Bentuknya sengaja meniru papan nomor: bidang terang
             * berbingkai tegas, bukan sekadar teks tebal di atas kartu.
             */
            if (driver.plateNumber != null) ...<Widget>[
              if (driver.vehicleDescription.isNotEmpty)
                const SizedBox(height: ClayTokens.space3),
              _BarisInfo(
                label: 'Plat nomor',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClayTokens.space3,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: gelap ? ClayTokens.surfaceSunkenDark : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _teksUtama(gelap).withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    driver.plateNumber!,
                    style: TextStyle(
                      fontFamily: ClayTokens.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: _teksUtama(gelap),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Baris keterangan driver: label kecil di kiri, nilainya rata kanan.
class _BarisInfo extends StatelessWidget {
  const _BarisInfo({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: ClayTokens.fontFamily,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: _teksKetiga(gelap),
          ),
        ),
        const SizedBox(width: ClayTokens.space4),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: child),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Kode jemput
// ---------------------------------------------------------------------------

/// Kode verifikasi — elemen paling menonjol di panel saat driver menjemput.
///
/// ============================================================================
///  BINGKAI GRADIEN, ANGKA DIPECAH PER KARAKTER
/// ============================================================================
///  Kartu ini harus menang dari kartu lain di panel tanpa membuat seluruh panel
///  berwarna. Bingkai gradien setipis 1,5 px memberi bobot itu dengan bidang
///  berwarna yang nyaris nol — sesuai aturan layar peta: gradien hanya pada
///  elemen kecil.
///
///  Angkanya dipecah per karakter karena kode ini DIBACAKAN, bukan disalin, dan
///  deret yang dipecah lebih sulit salah baca daripada empat digit yang
///  menempel. Wrap, bukan Row: kode yang lebih panjang di HP sempit harus turun
///  baris, bukan meluber keluar kartu.
/// ============================================================================
class _KodeJemput extends StatelessWidget {
  const _KodeJemput({required this.kode});

  final String kode;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    // Hijau primary di atas bidang gelap kehilangan kontras; primaryLight yang
    // memegang perannya di mode gelap.
    final Color aksen = gelap ? ClayTokens.primaryLight : ClayTokens.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: ClayGradients.chip(ClayTokens.primary),
        borderRadius: BorderRadius.circular(ClayTokens.radiusMedium + 1.5),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: gelap
              ? ClayTokens.surfaceRaisedDark
              : ClayTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: ClayTokens.space4,
          vertical: ClayTokens.space5,
        ),
        child: Column(
          children: <Widget>[
            const ClaySectionLabel('Kode jemput'),

            const SizedBox(height: ClayTokens.space4),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: ClayTokens.space2,
              runSpacing: ClayTokens.space2,
              children: <Widget>[
                for (final String huruf in kode.split(''))
                  Container(
                    width: 46,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: aksen.withValues(alpha: gelap ? 0.20 : 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      huruf,
                      style: TextStyle(
                        fontFamily: ClayTokens.fontFamily,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: aksen,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: ClayTokens.space4),

            Text(
              // Menyebutkan bahwa kodenya DISEBUTKAN, bukan ditunjukkan. Kode
              // yang ditunjukkan bisa dibaca dari jauh oleh orang lain, dan
              // seluruh gunanya adalah memastikan orang yang naik memang yang
              // memesan.
              'Sebutkan kode ini kepada driver sebelum berangkat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: ClayTokens.fontFamily,
                fontSize: 11.5,
                height: 1.4,
                color: _teksKedua(gelap),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Rute dan ongkos
// ---------------------------------------------------------------------------

class _Alamat extends StatelessWidget {
  const _Alamat({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.low,
      padding: const EdgeInsets.all(ClayTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Baris(
            icon: Icons.trip_origin_rounded,
            warna: ClayTokens.primary,
            label: 'Penjemputan',
            teks: order.pickup.address,
            catatan: order.pickup.note,
          ),
          if (order.destination != null) ...<Widget>[
            // Penghubung antara dua chip: itu yang membuat dua alamat terbaca
            // sebagai SATU perjalanan, bukan dua baris yang kebetulan
            // bertumpuk. Lebar 15 menaruhnya tepat di bawah sumbu chip 32 px.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 15),
                  Container(width: 2, height: 20, color: _garis(gelap)),
                ],
              ),
            ),
            _Baris(
              icon: Icons.place_rounded,
              warna: ClayTokens.danger,
              label: 'Tujuan',
              teks: order.destination!.address,
            ),
          ],
        ],
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.icon,
    required this.warna,
    required this.label,
    required this.teks,
    this.catatan,
  });

  final IconData icon;
  final Color warna;
  final String label;
  final String teks;
  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClayIconChip(icon: icon, accent: warna, size: 32),
        const SizedBox(width: ClayTokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: ClayTokens.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _teksKetiga(gelap),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                teks,
                style: TextStyle(
                  fontFamily: ClayTokens.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: _teksUtama(gelap),
                ),
              ),
              if (catatan != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  catatan!,
                  style: TextStyle(
                    fontFamily: ClayTokens.fontFamily,
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                    color: _teksKedua(gelap),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Ongkos extends StatelessWidget {
  const _Ongkos({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.low,
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space4,
        vertical: ClayTokens.space3,
      ),
      child: Column(
        children: <Widget>[
          for (final FareLine baris in order.fareLines)
            ClayMoneyRow(label: baris.label, formatted: baris.formatted),

          if (order.cancellationFee != null &&
              order.cancellationFee!.isPositive)
            ClayMoneyRow(
              label: 'Biaya pembatalan',
              formatted: order.cancellationFee!.formatted,
            ),

          const Divider(height: ClayTokens.space5),

          ClayMoneyRow(
            label: 'Total',
            formatted: order.total.formatted,
            emphasized: true,
            hint: order.paymentMethod == 'cash'
                ? 'Bayar tunai ke driver'
                : 'Dipotong dari dompet',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Penilaian
// ---------------------------------------------------------------------------

/// Ajakan menilai, untuk penumpang yang menutup form penilaiannya tadi.
class _AjakanMenilai extends StatelessWidget {
  const _AjakanMenilai({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.medium,
      borderColor: ClayTokens.warning,
      padding: const EdgeInsets.all(ClayTokens.space4),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const ClayIconChip(
            icon: Icons.star_rounded,
            accent: ClayTokens.warning,
            size: 42,
          ),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Text(
              'Nilai perjalanan ini. Penilaian Anda membantu '
              'driver lain mendapat order.',
              style: TextStyle(
                fontFamily: ClayTokens.fontFamily,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: _teksUtama(gelap),
              ),
            ),
          ),
          const SizedBox(width: ClayTokens.space2),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: _teksKetiga(gelap),
          ),
        ],
      ),
    );
  }
}

/// Penilaian yang sudah diberikan, ditampilkan sebagai ringkasan.
class _PenilaianTersimpan extends StatelessWidget {
  const _PenilaianTersimpan(this.rating);

  final OrderRating rating;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.pressed,
      padding: const EdgeInsets.all(ClayTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const ClaySectionLabel('Penilaian Anda'),
              const Spacer(),
              for (int i = 1; i <= 5; i++)
                Icon(
                  i <= rating.score
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: i <= rating.score
                      ? ClayTokens.warning
                      : _teksKetiga(gelap),
                ),
            ],
          ),

          if (rating.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: ClayTokens.space3),
            Wrap(
              spacing: ClayTokens.space2,
              runSpacing: ClayTokens.space2,
              children: <Widget>[
                for (final String tag in rating.tags)
                  _LencanaKecil(teks: tag, warna: ClayTokens.primary),
              ],
            ),
          ],

          if (rating.comment != null) ...<Widget>[
            const SizedBox(height: ClayTokens.space3),
            Text(
              rating.comment!,
              style: TextStyle(
                fontFamily: ClayTokens.fontFamily,
                fontSize: 12,
                height: 1.45,
                fontStyle: FontStyle.italic,
                color: _teksKedua(gelap),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Serba-serbi
// ---------------------------------------------------------------------------

/// Lencana teks kecil berwarna.
///
/// Lokal, bukan di antaride_ui: peta layar menyarankan komponen bersama untuk
/// ini, tapi paket bersama berada di luar wilayah perombakan layar ini. Kalau
/// nanti dipakai layar kedua, inilah yang diangkat ke sana — bentuknya sudah
/// sesuai dan tidak ada yang perlu diubah selain tempatnya.
class _LencanaKecil extends StatelessWidget {
  const _LencanaKecil({required this.teks, required this.warna});

  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
      ),
      child: Text(
        teks,
        style: TextStyle(
          fontFamily: ClayTokens.fontFamily,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: warna,
        ),
      ),
    );
  }
}

Color _teksUtama(bool gelap) =>
    gelap ? ClayTokens.textPrimaryDark : ClayTokens.textPrimary;

Color _teksKedua(bool gelap) =>
    gelap ? ClayTokens.textSecondaryDark : ClayTokens.textSecondary;

Color _teksKetiga(bool gelap) =>
    gelap ? ClayTokens.textTertiaryDark : ClayTokens.textTertiary;

/// Garis pemisah setipis mungkin.
///
/// Kontrasnya diturunkan dari latar, bukan warna abu tetap: abu yang benar di
/// mode terang terlihat terlalu keras di mode gelap, dan sebaliknya.
Color _garis(bool gelap) => gelap
    ? Colors.white.withValues(alpha: 0.08)
    : Colors.black.withValues(alpha: 0.06);

/// Jarak dalam satuan yang dibaca orang, bukan meter mentah.
String _jarak(int meter) {
  if (meter >= 1000) {
    return '${(meter / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  return '$meter m';
}

/// Lama perjalanan dalam menit — dan jam kalau memang selama itu.
String _durasi(int detik) {
  final int menit = (detik / 60).round();

  if (menit < 60) {
    return '${menit < 1 ? 1 : menit} menit';
  }

  final int jam = menit ~/ 60;
  final int sisa = menit % 60;

  return sisa == 0 ? '$jam jam' : '$jam jam $sisa menit';
}
