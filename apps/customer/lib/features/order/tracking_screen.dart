import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:antaride_notifications/antaride_notifications.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
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
                            fontFamily: 'PlusJakartaSans',
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ClayTokens.warning.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Bisa kena biaya',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ClayTokens.warning,
                            ),
                          ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: pelacak.refreshNow,
            tooltip: 'Segarkan',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Pita pembaruan tertunda. Data lama TETAP tampil di bawahnya — lihat
          // penjelasan di TrackingController.
          if (pelacak.failure != null)
            Container(
              width: double.infinity,
              color: ClayTokens.warning.withValues(alpha: 0.14),
              padding: const EdgeInsets.symmetric(
                horizontal: ClayTokens.space4,
                vertical: ClayTokens.space2,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 15,
                    color: ClayTokens.warning,
                  ),
                  const SizedBox(width: ClayTokens.space2),
                  const Expanded(
                    child: Text(
                      'Pembaruan tertunda. Data yang tampil mungkin belum '
                      'yang terbaru.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(
            height: 230,
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

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(ClayTokens.space5),
              children: <Widget>[
                _Status(order: order),

                if (order.driver != null) ...<Widget>[
                  const SizedBox(height: ClayTokens.space4),
                  _KartuDriver(driver: order.driver!),
                ],

                if (order.pickupCode != null) ...<Widget>[
                  const SizedBox(height: ClayTokens.space4),
                  _KodeJemput(kode: order.pickupCode!),
                ],

                const SizedBox(height: ClayTokens.space4),

                _Alamat(order: order),

                const SizedBox(height: ClayTokens.space4),

                _Ongkos(order: order),

                const SizedBox(height: ClayTokens.space6),

                /*
                 * Kartu penilaian, untuk penumpang yang menutup formnya tadi.
                 *
                 * Tetap ada selama `can_rate` masih true — termasuk kalau order
                 * dibuka lagi dari riwayat berhari-hari kemudian. Tanpa jalan
                 * kedua ini, sekali form ditutup, penilaiannya hilang selamanya.
                 */
                if (order.canRate)
                  ClaySurface(
                    depth: ClayDepth.medium,
                    borderColor: ClayTokens.warning,
                    onTap: () => _nilai(order),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.star_rounded,
                          color: ClayTokens.warning,
                          size: 26,
                        ),
                        const SizedBox(width: ClayTokens.space4),
                        const Expanded(
                          child: Text(
                            'Nilai perjalanan ini. Penilaian Anda membantu '
                            'driver lain mendapat order.',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),

                // Penilaian yang SUDAH diberikan tetap ditampilkan.
                //
                // Penumpang yang lupa apakah dia sudah menilai mendapat
                // jawabannya di sini — tanpa harus mencoba dan mendapat
                // penolakan.
                if (order.rating != null) _PenilaianTersimpan(order.rating!),

                if (order.canCancel)
                  ClayButton(
                    label: 'Batalkan pesanan',
                    variant: ClayButtonVariant.danger,
                    icon: Icons.close_rounded,
                    onPressed: () => _batalkan(context, order),
                  ),

                const SizedBox(height: ClayTokens.space6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.medium,

      // Driver yang sudah tiba diberi border kuning. Ini satu-satunya status
      // yang menuntut penumpang bertindak SEKARANG, dan harus terlihat berbeda
      // dari yang lain sejak pandangan pertama.
      borderColor: order.isDriverWaiting ? ClayTokens.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClayStatusBadge(status: order.status, label: order.statusLabel),
              const Spacer(),
              if (order.isSearching)
                const ClayInlineLoader(size: 14, color: ClayTokens.primary),
            ],
          ),

          const SizedBox(height: ClayTokens.space3),

          Text(
            _pesan(),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              height: 1.5,
              color: ClayTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
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

class _KartuDriver extends StatelessWidget {
  const _KartuDriver({required this.driver});

  final OrderDriver driver;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.low,
      child: Row(
        children: <Widget>[
          ClaySurface(
            depth: ClayDepth.pressed,
            radius: ClayTokens.radiusPill,
            padding: const EdgeInsets.all(ClayTokens.space3),
            child: const Icon(
              Icons.person_rounded,
              size: 26,
              color: ClayTokens.primary,
            ),
          ),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  driver.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
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
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: ClayTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (driver.vehicleDescription.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    driver.vehicleDescription,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      color: ClayTokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          /*
           * Plat nomor ditampilkan PALING BESAR di kartu ini.
           *
           * Ini satu-satunya cara penumpang memastikan kendaraan yang berhenti
           * di depannya benar. Nama dan foto driver membantu, tapi plat nomor
           * yang menentukan — dan di antrean ojek yang ramai, itu yang dibaca
           * dari jauh.
           */
          if (driver.plateNumber != null)
            ClaySurface(
              depth: ClayDepth.pressed,
              radius: ClayTokens.radiusSmall,
              padding: const EdgeInsets.symmetric(
                horizontal: ClayTokens.space3,
                vertical: ClayTokens.space2,
              ),
              child: Text(
                driver.plateNumber!,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KodeJemput extends StatelessWidget {
  const _KodeJemput({required this.kode});

  final String kode;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.medium,
      borderColor: ClayTokens.primary,
      child: Column(
        children: <Widget>[
          const Text(
            'KODE JEMPUT',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: ClayTokens.textSecondary,
            ),
          ),
          const SizedBox(height: ClayTokens.space2),
          Text(
            kode,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: ClayTokens.primary,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: ClayTokens.space2),
          const Text(
            // Menyebutkan bahwa kodenya DISEBUTKAN, bukan ditunjukkan. Kode
            // yang ditunjukkan bisa dibaca dari jauh oleh orang lain, dan
            // seluruh gunanya adalah memastikan orang yang naik memang yang
            // memesan.
            'Sebutkan kode ini kepada driver sebelum berangkat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              color: ClayTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Alamat extends StatelessWidget {
  const _Alamat({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.pressed,
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
            const SizedBox(height: ClayTokens.space4),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: warna),
        ),
        const SizedBox(width: ClayTokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: ClayTokens.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                teks,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (catatan != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  catatan!,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: ClayTokens.textSecondary,
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

/// Penilaian yang sudah diberikan, ditampilkan sebagai ringkasan.
class _PenilaianTersimpan extends StatelessWidget {
  const _PenilaianTersimpan(this.rating);

  final OrderRating rating;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.pressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'Penilaian Anda',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: ClayTokens.textTertiary,
                ),
              ),
              const Spacer(),
              for (int i = 1; i <= 5; i++)
                Icon(
                  i <= rating.score
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: i <= rating.score
                      ? ClayTokens.warning
                      : ClayTokens.textTertiary,
                ),
            ],
          ),

          if (rating.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: ClayTokens.space2),
            Text(
              rating.tags.join(' · '),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                color: ClayTokens.textSecondary,
              ),
            ),
          ],

          if (rating.comment != null) ...<Widget>[
            const SizedBox(height: ClayTokens.space2),
            Text(
              rating.comment!,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
