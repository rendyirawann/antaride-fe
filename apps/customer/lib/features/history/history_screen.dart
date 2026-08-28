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
      body: ClayRefresh(
        onRefresh: () => _muat(ulangDariAwal: true),
        onLoad: _muatLagi,
        child: ListView.builder(
          padding: const EdgeInsets.all(ClayTokens.space5),
          itemCount: _orders.length,
          itemBuilder: (BuildContext context, int i) =>
              _KartuOrder(order: _orders[i]),
        ),
      ),
    );
  }
}

class _KartuOrder extends StatelessWidget {
  const _KartuOrder({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
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
            children: <Widget>[
              ClayStatusBadge(
                status: order.status,
                label: order.statusLabel,
                compact: true,
              ),
              const Spacer(),
              Text(
                _tanggal(),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  color: ClayTokens.textTertiary,
                ),
              ),
            ],
          ),

          const SizedBox(height: ClayTokens.space3),

          Text(
            order.destination?.address ?? order.pickup.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),

          const SizedBox(height: ClayTokens.space3),

          Row(
            children: <Widget>[
              Text(
                order.serviceName ?? order.orderNumber,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  color: ClayTokens.textSecondary,
                ),
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
