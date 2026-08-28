import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../dashboard/driver_controller.dart';

/// Order yang sedang dikerjakan driver.
///
/// ============================================================================
///  SATU TOMBOL BESAR, DAN ISINYA DITENTUKAN BACKEND
/// ============================================================================
///  Tombol aksi di bawah dibangun dari `DriverOrder.allowedTransitions` — daftar
///  status berikutnya yang dikirim backend.
///
///  Aplikasi TIDAK punya salinan aturan transisinya. Kalau punya, akan ada versi
///  aplikasi yang menampilkan tombol yang selalu ditolak — dan bagi driver yang
///  sedang di jalan itu terlihat sebagai aplikasi rusak, bukan sebagai aturan
///  yang berubah di server.
/// ============================================================================
class ActiveOrderScreen extends StatelessWidget {
  const ActiveOrderScreen({super.key, this.embedded = false});

  /// True kalau layar ini menjadi HALAMAN di dalam sidebar, bukan route yang
  /// di-push.
  ///
  /// Bedanya hanya bilah atas: sidebar sudah menyediakannya beserta tombol
  /// hamburger, dan dua bilah atas bertumpuk akan memakan sepertiga layar.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final DriverController driver = context.watch<DriverController>();
    final DriverOrder? order = driver.activeOrder;

    if (order == null) {
      return Scaffold(
        appBar: embedded ? null : AppBar(title: const Text('Order')),
        body: const ClayEmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'Tidak ada order berjalan',
          message:
              'Order sudah selesai atau dibatalkan. Kembali ke dasbor '
              'untuk menerima tawaran berikutnya.',
        ),
      );
    }

    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: Text(order.orderNumber),
              actions: <Widget>[
                if (order.canCancel)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined),
                    tooltip: 'Batalkan order',
                    onPressed: () => _batalkan(context, driver),
                  ),
              ],
            ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 200,
            child: AntarideMap(
              route: PolylineCodec.decode(order.routePolyline),
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
                if (driver.lastPosition != null)
                  MapPin(
                    position: driver.lastPosition!,
                    icon: Icons.two_wheeler_rounded,
                    color: ClayTokens.info,
                    size: 32,
                  ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(ClayTokens.space5),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ClayStatusBadge(
                      status: order.status,
                      label: order.statusLabel,
                    ),
                    const Spacer(),
                    if (order.needsFareReview)
                      const Icon(
                        Icons.flag_rounded,
                        size: 18,
                        color: ClayTokens.warning,
                      ),
                  ],
                ),

                const SizedBox(height: ClayTokens.space4),

                _Uang(order: order),

                const SizedBox(height: ClayTokens.space4),

                _Titik(order: order),

                if (order.passenger != null) ...<Widget>[
                  const SizedBox(height: ClayTokens.space4),
                  _Penumpang(penumpang: order.passenger!),
                ],

                // Saat tertanam di sidebar tidak ada bilah atas, jadi tombol
                // batalkan ditaruh di badan halaman. Tanpa ini, order yang
                // dibuka dari sidebar tidak punya cara dibatalkan sama sekali.
                if (embedded && order.canCancel) ...<Widget>[
                  const SizedBox(height: ClayTokens.space5),
                  ClayButton(
                    label: 'Batalkan order',
                    variant: ClayButtonVariant.ghost,
                    icon: Icons.cancel_outlined,
                    onPressed: () => _batalkan(context, driver),
                  ),
                ],

                const SizedBox(height: ClayTokens.space8),
              ],
            ),
          ),

          _BilahAksi(order: order, driver: driver),
        ],
      ),
    );
  }

  Future<void> _batalkan(BuildContext context, DriverController driver) async {
    final AntarideServices services = context.read<AntarideServices>();

    /*
     * Alasan DRIVER, dari endpoint driver — bukan endpoint penumpang.
     *
     * `cancellation_reasons` disaring per `actor_type` di backend, dan validasi
     * menolak kode milik aktor lain. Memakai daftar penumpang di sini akan
     * menghasilkan tombol batalkan yang selalu ditolak 422.
     */
    final Result<List<DriverCancellationReason>> daftar = await services.driver
        .cancellationReasons();

    if (!context.mounted) {
      return;
    }

    final List<DriverCancellationReason> alasan =
        daftar.valueOrNull ?? const <DriverCancellationReason>[];

    /*
     * TIDAK ada daftar cadangan yang ditulis di aplikasi.
     *
     * Daftar cadangan terlihat seperti kehati-hatian, tapi yang dilakukannya
     * adalah menukar galat yang jelas ("tidak bisa memuat, coba lagi") dengan
     * galat yang menyesatkan: driver memilih alasan, menekan batalkan, lalu
     * ditolak 422 tanpa penjelasan — dan kodenya memang tidak ada di tabel.
     *
     * Lebih baik gagal di sini, dengan pesan yang bisa ditindaklanjuti.
     */
    if (alasan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            daftar.failureOrNull?.message ??
                'Tidak bisa memuat pilihan alasan. Periksa koneksi lalu coba '
                    'lagi.',
          ),
          backgroundColor: ClayTokens.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final TextEditingController catatan = TextEditingController();

    DriverCancellationReason? dipilih;

    final bool? kirim = await ClayBottomSheet.show<bool>(
      context: context,
      title: 'Batalkan order',
      child: StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) ubah) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final DriverCancellationReason a in alasan)
                ClayCard(
                  depth: dipilih?.code == a.code
                      ? ClayDepth.pressed
                      : ClayDepth.flat,
                  onTap: () => ubah(() => dipilih = a),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        dipilih?.code == a.code
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: dipilih?.code == a.code
                            ? ClayTokens.primary
                            : ClayTokens.textTertiary,
                      ),
                      const SizedBox(width: ClayTokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              a.text,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            // Konsekuensi skor DIBERITAHUKAN, dan bunyinya
                            // menjelaskan akibatnya — bukan hanya menyebut
                            // "skor turun", yang tidak memberi tahu apa
                            // dampaknya bagi driver.
                            if (a.lowersScore)
                              const Text(
                                'Menurunkan skor pembatalan Anda',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: ClayTokens.warning,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: ClayTokens.space3),

              ClayInput(
                controller: catatan,
                label: 'Keterangan',
                // Catatan WAJIB minimal 5 karakter untuk pembatalan driver,
                // berbeda dari pembatalan penumpang. Sebagian alasan menurunkan
                // skor driver, dan angka yang menurunkan skor seseorang harus
                // disertai keterangan yang bisa dia bantah.
                hint: 'Wajib, minimal 5 karakter',
                maxLines: 3,
                maxLength: 500,
              ),

              const SizedBox(height: ClayTokens.space4),

              ClayButton(
                label: 'Batalkan order',
                variant: ClayButtonVariant.danger,
                height: ClayTokens.driverPrimaryButtonHeight,
                onPressed: dipilih == null || catatan.text.trim().length < 5
                    ? null
                    : () => Navigator.of(ctx).pop(true),
              ),
            ],
          );
        },
      ),
    );

    final DriverCancellationReason? terpilih = dipilih;

    if (kirim != true || terpilih == null || !context.mounted) {
      catatan.dispose();

      return;
    }

    final String note = catatan.text.trim();

    catatan.dispose();

    final bool berhasil = await driver.cancelOrder(
      reasonCode: terpilih.code,
      note: note,
    );

    if (!context.mounted) {
      return;
    }

    if (!berhasil) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            driver.failure?.message ?? 'Tidak bisa membatalkan order.',
          ),
          backgroundColor: ClayTokens.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    Navigator.of(context).pop();
  }
}

class _Uang extends StatelessWidget {
  const _Uang({required this.order});

  final DriverOrder order;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.medium,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Pendapatan Anda',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                ClayMoney(
                  formatted: order.earning.formatted,
                  size: ClayMoneySize.large,
                ),
              ],
            ),
          ),

          /*
           * Yang harus ditagih HANYA muncul pada order tunai.
           *
           * Pada order non-tunai, `collect_from_passenger` dikirim null oleh
           * backend, dan di sini itu berarti kolomnya tidak ditampilkan sama
           * sekali — bukan menampilkan Rp 0.
           *
           * "Tagih Rp 0" terbaca sebagai perjalanan gratis, dan driver yang
           * membacanya sekilas tidak akan menagih pada order yang seharusnya
           * dibayar.
           */
          if (order.collectFromPassenger != null)
            ClaySurface(
              depth: ClayDepth.pressed,
              radius: ClayTokens.radiusSmall,
              padding: const EdgeInsets.all(ClayTokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  const Text(
                    'TAGIH TUNAI',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: ClayTokens.warning,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ClayMoney(
                    formatted: order.collectFromPassenger!.formatted,
                    size: ClayMoneySize.medium,
                    color: ClayTokens.warning,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Titik extends StatelessWidget {
  const _Titik({required this.order});

  final DriverOrder order;

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
            label: 'JEMPUT',
            teks: order.pickup.address,
            catatan: order.pickup.note,
          ),
          if (order.destination != null) ...<Widget>[
            const SizedBox(height: ClayTokens.space4),
            _Baris(
              icon: Icons.place_rounded,
              warna: ClayTokens.danger,
              label: 'ANTAR',
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
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: warna,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                teks,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (catatan != null) ...<Widget>[
                const SizedBox(height: 3),
                ClaySurface(
                  depth: ClayDepth.flat,
                  radius: ClayTokens.radiusSmall,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClayTokens.space3,
                    vertical: ClayTokens.space2,
                  ),
                  color: ClayTokens.warning.withValues(alpha: 0.1),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.sticky_note_2_rounded,
                        size: 13,
                        color: ClayTokens.warning,
                      ),
                      const SizedBox(width: ClayTokens.space2),
                      Expanded(
                        child: Text(
                          // Catatan penumpang ditampilkan MENONJOL, bukan
                          // sebagai teks kecil di bawah alamat. Ini biasanya
                          // satu-satunya keterangan yang membuat driver
                          // menemukan titiknya tanpa menelepon.
                          catatan!,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
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

class _Penumpang extends StatelessWidget {
  const _Penumpang({required this.penumpang});

  final DriverPassenger penumpang;

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
              size: 22,
              color: ClayTokens.primary,
            ),
          ),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  penumpang.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  penumpang.phone,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    color: ClayTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            tooltip: 'Salin nomor',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: penumpang.phone));

              if (!context.mounted) {
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nomor penumpang disalin.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Bilah aksi di bawah: satu tombol utama sesuai status.
class _BilahAksi extends StatelessWidget {
  const _BilahAksi({required this.order, required this.driver});

  final DriverOrder order;
  final DriverController driver;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.high,
      radius: 0,
      padding: const EdgeInsets.all(ClayTokens.space5),
      child: SafeArea(top: false, child: _tombol(context)),
    );
  }

  Widget _tombol(BuildContext context) {
    // Urutannya mengikuti alur perjalanan, dan yang menentukan tombol mana
    // muncul adalah `allowedTransitions` dari backend — bukan urutan di sini.
    if (order.can('driver_arriving')) {
      return ClayButton(
        label: 'Menuju penjemputan',
        icon: Icons.navigation_rounded,
        isLoading: driver.isBusy,
        height: ClayTokens.driverPrimaryButtonHeight,
        onPressed: driver.isBusy
            ? null
            : () => _transisi(context, 'driver_arriving'),
      );
    }

    if (order.canArrive) {
      return ClayButton(
        label: 'Sudah tiba di titik jemput',
        icon: Icons.where_to_vote_rounded,
        isLoading: driver.isBusy,
        height: ClayTokens.driverPrimaryButtonHeight,
        onPressed: driver.isBusy
            ? null
            : () => _transisi(context, 'driver_arrived'),
      );
    }

    if (order.canStart) {
      return ClayButton(
        label: 'Mulai perjalanan',
        icon: Icons.play_arrow_rounded,
        isLoading: driver.isBusy,
        height: ClayTokens.driverPrimaryButtonHeight,
        onPressed: driver.isBusy ? null : () => _mintaKode(context),
      );
    }

    if (order.canComplete) {
      return ClayButton(
        label: order.isCash
            ? 'Sudah terima uang — Selesaikan'
            : 'Selesaikan perjalanan',
        icon: Icons.check_circle_rounded,
        isLoading: driver.isBusy,
        height: ClayTokens.driverPrimaryButtonHeight,
        onPressed: driver.isBusy ? null : () => _selesaikan(context),
      );
    }

    return ClayButton(
      label: 'Kembali ke dasbor',
      variant: ClayButtonVariant.secondary,
      height: ClayTokens.driverPrimaryButtonHeight,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }

  Future<void> _transisi(BuildContext context, String status) async {
    final bool berhasil = await driver.transition(status);

    if (!context.mounted || berhasil) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(driver.failure?.message ?? 'Tidak bisa memperbarui.'),
        backgroundColor: ClayTokens.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Minta kode jemput dari penumpang.
  ///
  /// ==========================================================================
  ///  KODENYA DISEBUTKAN PENUMPANG, TIDAK PERNAH DITAMPILKAN DI SINI
  /// ==========================================================================
  ///  Ini satu-satunya pemeriksaan bahwa orang yang naik memang yang memesan.
  ///  Aplikasi driver tidak menerima kode yang benar dari backend, dan kalaupun
  ///  menerimanya, menampilkannya "untuk memudahkan" akan menghapus seluruh
  ///  gunanya.
  ///
  ///  Kode yang salah ditolak backend dengan 422, dan pesannya sudah berbunyi
  ///  "minta penumpang menyebutkan kodenya lagi".
  /// ==========================================================================
  Future<void> _mintaKode(BuildContext context) async {
    final TextEditingController kode = TextEditingController();

    final bool? kirim = await ClayBottomSheet.show<bool>(
      context: context,
      title: 'Kode jemput',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Minta penumpang menyebutkan 4 digit kode jemput, lalu masukkan di '
            'bawah.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              height: 1.5,
              color: ClayTokens.textSecondary,
            ),
          ),
          const SizedBox(height: ClayTokens.space4),
          ClayInput(
            controller: kode,
            hint: '••••',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            letterSpacing: 14,
            maxLength: 6,
            autofocus: true,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: ClayTokens.space4),
          ClayButton(
            label: 'Mulai perjalanan',
            icon: Icons.play_arrow_rounded,
            height: ClayTokens.driverPrimaryButtonHeight,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (kirim != true || !context.mounted) {
      kode.dispose();

      return;
    }

    final String nilai = kode.text.trim();

    kode.dispose();

    final bool berhasil = await driver.startTrip(nilai);

    if (!context.mounted || berhasil) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          driver.failure?.message ??
              'Kode jemput tidak cocok. Minta penumpang menyebutkan lagi.',
        ),
        backgroundColor: ClayTokens.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selesaikan(BuildContext context) async {
    // Konfirmasi HANYA untuk order tunai. Yang dikonfirmasi bukan
    // penyelesaiannya, tapi bahwa uangnya sudah diterima — dan setelah order
    // ditutup, driver tidak punya cara menagih lagi.
    if (order.isCash) {
      final bool? sudah = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialog) => AlertDialog(
          title: const Text('Uang sudah diterima?'),
          content: Text(
            'Pastikan Anda sudah menerima '
            '${order.collectFromPassenger?.formatted ?? ''} dari penumpang. '
            'Setelah order ditutup, tagihan tidak bisa diajukan lagi.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Belum'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Sudah, selesaikan'),
            ),
          ],
        ),
      );

      if (sudah != true || !context.mounted) {
        return;
      }
    }

    final bool berhasil = await driver.complete();

    if (!context.mounted) {
      return;
    }

    if (!berhasil) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            driver.failure?.message ?? 'Tidak bisa menyelesaikan order.',
          ),
          backgroundColor: ClayTokens.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    Navigator.of(context).pop();
  }
}
