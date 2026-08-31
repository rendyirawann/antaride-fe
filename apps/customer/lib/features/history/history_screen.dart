import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../order/tracking_screen.dart';

/// Riwayat pesanan, dengan cursor pagination.
///
/// ============================================================================
///  CURSOR, BUKAN NOMOR HALAMAN — DAN ITU MENGUBAH TAMPILANNYA
/// ============================================================================
///  Backend memakai cursor pagination karena riwayat order tumbuh terus, dan
///  `OFFSET 5000` memaksa database memindai lima ribu baris hanya untuk
///  dibuang.
///
///  Konsekuensinya bagi layar ini: TIDAK ADA "halaman 7", dan tidak ada jumlah
///  total. Yang ada hanya "muat lebih banyak" — dan untuk riwayat yang dibaca
///  dengan menggulir, itu memang yang dibutuhkan. Yang tidak boleh dilakukan:
///  menampilkan penomoran halaman palsu di atas API yang tidak bisa
///  menyediakannya.
/// ============================================================================
///
/// ============================================================================
///  BAHASA V2 DI LAYAR INI: KARTU, BUKAN HERO
/// ============================================================================
///  Halaman ini hidup DI BAWAH AppBar milik shell tab, jadi hero gradien yang
///  menembus status bar tidak mungkin di sini. Identitas v2 masuk lewat kartu:
///  tiap order diberi [ClayIconChip] bergradien aksen sesuai jenis layanannya,
///  sehingga daftar yang tadinya monoton abu punya titik fokus per baris.
///
///  Animasi masuk dipasang SEKALI di level layar ([ClayEntrance] membungkus
///  seluruh daftar), bukan per kartu: item `ListView.builder` di-dispose saat
///  keluar viewport, dan entrance per kartu akan diputar ulang setiap digulir
///  balik — persis rasa "gelisah" yang dilarang docblock ClayEntrance.
/// ============================================================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<Order> _orders = <Order>[];

  String? _cursor;
  bool _adaLagi = true;
  bool _memuat = false;
  bool _pertamaSelesai = false;
  ApiFailure? _galat;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  /// Muat halaman berikutnya, untuk `ClayRefresh.onLoad`.
  ///
  /// Ambang pemicunya, penjagaan pemicu ganda, dan tampilan footer ditangani
  /// `ClayRefresh` — lihat docblock-nya. Yang tersisa di sini hanya memberi tahu
  /// apakah masih ada halaman lagi.
  Future<IndicatorResult> _muatLagi() async {
    await _muat();

    if (_galat != null) {
      return IndicatorResult.fail;
    }

    return _adaLagi ? IndicatorResult.success : IndicatorResult.noMore;
  }

  Future<void> _muat({bool ulangDariAwal = false}) async {
    if (_memuat) {
      return;
    }

    if (!ulangDariAwal && !_adaLagi && _pertamaSelesai) {
      return;
    }

    setState(() {
      _memuat = true;
      _galat = null;
    });

    final AntarideServices services = context.read<AntarideServices>();

    final Result<OrderPage> hasil = await services.orders.history(
      cursor: ulangDariAwal ? null : _cursor,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _memuat = false;
      _pertamaSelesai = true;

      switch (hasil) {
        case Ok<OrderPage>(value: final OrderPage halaman):
          if (ulangDariAwal) {
            _orders.clear();
          }

          _orders.addAll(halaman.orders);
          _cursor = halaman.nextCursor;
          _adaLagi = halaman.hasMore && halaman.nextCursor != null;

        case Err<OrderPage>(failure: final ApiFailure f):
          _galat = f;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_pertamaSelesai && _memuat) {
      // Skeleton berbentuk kartu, bukan spinner: tingginya sama dengan kartu
      // sebenarnya, jadi daftarnya tidak melompat saat datanya datang.
      // Kartu v2 (chip 42 + dua baris teks + baris status) tetap jatuh di
      // kisaran tinggi yang sama, jadi angka 116 masih benar.
      return const Scaffold(body: ClaySkeletonList(itemHeight: 116));
    }

    if (_orders.isEmpty && _galat != null) {
      return Scaffold(
        body: ClayErrorState(
          message: _galat!.message,
          onRetry: () => _muat(ulangDariAwal: true),
        ),
      );
    }

    if (_orders.isEmpty) {
      return const Scaffold(
        body: ClayEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Belum ada pesanan',
          message:
              'Pesanan Anda akan muncul di sini setelah perjalanan '
              'pertama. Mulai dari tab Beranda.',
        ),
      );
    }

    return Scaffold(
      body: ClayEntrance(
        index: 0,
        child: ClayRefresh(
          onRefresh: () => _muat(ulangDariAwal: true),
          onLoad: _muatLagi,
          child: ListView.builder(
            // Ruang tambahan di akhir guliran supaya kartu terakhir tidak
            // berhenti di belakang bilah navigasi Android — lihat ClayInsets.
            padding: EdgeInsets.fromLTRB(
              ClayTokens.space5,
              ClayTokens.space5,
              ClayTokens.space5,
              ClayTokens.space5 + context.ruangBawah,
            ),
            itemCount: _orders.length,
            itemBuilder: (BuildContext context, int i) =>
                _KartuOrder(order: _orders[i]),
          ),
        ),
      ),
    );
  }
}

class _KartuOrder extends StatelessWidget {
  const _KartuOrder({required this.order});

  final Order order;

  /// Ikon per kode layanan.
  ///
  /// KENAPA disalin, bukan diimpor: pemetaan aslinya privat di
  /// `home_screen.dart` (`_KisiLayanan._ikon`) dan `antaride_ui` belum punya
  /// pemetaan layanan→ikon bersama. Duplikasi enam baris ini kandidat untuk
  /// diangkat ke satu tempat — kalau beranda menambah layanan baru, tambahkan
  /// juga di sini, atau kartunya jatuh ke ikon struk generik (bukan galat).
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

    return ClayCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => TrackingScreen(orderUuid: order.uuid),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Satu-satunya bidang beraksen pekat di kartu — penanda jenis
              // layanan sekaligus identitas v2 di daftar yang serba pucat.
              ClayIconChip(
                icon: _ikon[order.serviceCode] ?? Icons.receipt_long_rounded,
                accent: ClayTokens.primary,
              ),

              const SizedBox(width: ClayTokens.space3),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            order.serviceName ?? order.orderNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: ClayTokens.fontFamily,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: gelap
                                  ? ClayTokens.textSecondaryDark
                                  : ClayTokens.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: ClayTokens.space2),
                        Text(
                          _tanggal(),
                          style: TextStyle(
                            fontFamily: ClayTokens.fontFamily,
                            fontSize: 11,
                            color: gelap
                                ? ClayTokens.textTertiaryDark
                                : ClayTokens.textTertiary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: ClayTokens.space1),

                    Text(
                      order.destination?.address ?? order.pickup.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: ClayTokens.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: gelap
                            ? ClayTokens.textPrimaryDark
                            : ClayTokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: ClayTokens.space3),

          Row(
            children: <Widget>[
              ClayStatusBadge(
                status: order.status,
                label: order.statusLabel,
                compact: true,
              ),
              const Spacer(),
              ClayMoney(
                formatted: order.total.formatted,
                size: ClayMoneySize.small,

                // Ongkos order yang dibatalkan dicoret — kecuali kalau ada
                // biaya pembatalan, karena angka yang dicoret di sebelah biaya
                // yang benar-benar ditagih membingungkan.
                strikethrough:
                    order.status == 'cancelled' &&
                    (order.cancellationFee?.isZero ?? true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tanggal dalam bentuk pendek Indonesia.
  ///
  /// Ditulis manual, bukan lewat `DateFormat` dengan locale. Untuk satu format
  /// pendek, menambahkan inisialisasi locale `intl` di jalur startup tidak
  /// sebanding — dan nama bulan Indonesia tidak akan berubah.
  String _tanggal() {
    final DateTime? waktu =
        order.completedAt ?? order.cancelledAt ?? order.requestedAt;

    if (waktu == null) {
      return '';
    }

    const List<String> bulan = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final String jam = waktu.hour.toString().padLeft(2, '0');
    final String menit = waktu.minute.toString().padLeft(2, '0');

    return '${waktu.day} ${bulan[waktu.month - 1]} · $jam:$menit';
  }
}
