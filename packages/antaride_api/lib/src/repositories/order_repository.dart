import 'package:antaride_core/antaride_core.dart';

import '../client/api_client.dart';
import '../models/order.dart';

/// Order dari sisi penumpang.
class OrderRepository {
  const OrderRepository(this._client);

  final ApiClient _client;

  /// Order yang sedang berjalan, kalau ada.
  ///
  /// Dipanggil setiap kali aplikasi dibuka. Endpoint tersendiri, bukan filter
  /// pada daftar order — response-nya kecil, dan aplikasi memerlukannya untuk
  /// memutuskan apakah langsung menampilkan layar pelacakan alih-alih beranda.
  Future<Result<Order?>> active() async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/orders/active',
    );

    return hasil.map((Map<String, dynamic> badan) {
      final dynamic data = badan['data'];

      // `null` di sini berarti TIDAK ADA order berjalan, dan itu keadaan yang
      // sah — bukan kegagalan. Layar memperlakukannya sebagai "tampilkan
      // beranda".
      if (data == null) {
        return null;
      }

      return Order.fromJson(data as Map<String, dynamic>);
    });
  }

  Future<Result<Order>> show(String uuid) async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/orders/$uuid',
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          Order.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Riwayat order dengan cursor pagination.
  ///
  /// Cursor, bukan nomor halaman. Riwayat order tumbuh terus, dan `OFFSET 5000`
  /// memaksa database memindai lima ribu baris untuk dibuang. Konsekuensinya
  /// bagi aplikasi: tidak ada "halaman 7" — dan untuk riwayat yang dibaca dengan
  /// menggulir, itu memang bukan yang dibutuhkan.
  Future<Result<OrderPage>> history({String? cursor, int perPage = 20}) async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/orders',
      query: <String, dynamic>{'per_page': perPage, 'cursor': ?cursor},
    );

    return hasil.map((Map<String, dynamic> badan) {
      final List<dynamic> data =
          (badan['data'] as List<dynamic>?) ?? <dynamic>[];
      final Map<String, dynamic> meta =
          (badan['meta'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      return OrderPage(
        orders: data
            .map((dynamic e) => Order.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: meta['next_cursor'] as String?,
        hasMore: meta['has_more'] as bool? ?? false,
      );
    });
  }

  /// Buat order dari sebuah quote.
  ///
  /// ==========================================================================
  ///  [idempotencyKey] HARUS DIPAKAI ULANG SAAT MENCOBA LAGI
  /// ==========================================================================
  ///  Pemanggil membuat kuncinya SEKALI — saat penumpang menekan "Pesan" —
  ///  dan memakai kunci yang sama untuk setiap percobaan berikutnya.
  ///
  ///  Kalau kunci baru dibuat setiap percobaan, backend melihat dua permintaan
  ///  berbeda dan membuat DUA order. Pada pembayaran wallet, dananya ditahan
  ///  dua kali.
  ///
  ///  Itu sebabnya kuncinya diminta sebagai parameter, bukan dibuat di dalam
  ///  method ini: method yang membuat kuncinya sendiri tidak punya cara memakai
  ///  ulang kunci yang sama.
  /// ==========================================================================
  Future<Result<Order>> create({
    required String idempotencyKey,
    required String quoteId,
    required String serviceCode,
    required String paymentMethod,
    required String pickupAddress,
    String? destinationAddress,
    String? pickupNote,
    String? promoCode,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.postIdempotent(
      '/orders',
      idempotencyKey: idempotencyKey,
      body: <String, dynamic>{
        'quote_id': quoteId,
        'service_code': serviceCode,
        'payment_method': paymentMethod,
        'pickup_address': pickupAddress,
        'destination_address': ?destinationAddress,
        'pickup_note': ?pickupNote,
        'promo_code': ?promoCode,
      },
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          Order.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  Future<Result<Order>> cancel({
    required String uuid,
    required String reasonCode,
    String? note,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/orders/$uuid/cancel',
      body: <String, dynamic>{'reason_code': reasonCode, 'note': ?note},
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          Order.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Nilai driver setelah perjalanan selesai.
  ///
  /// ==========================================================================
  ///  TIDAK MEMAKAI Idempotency-Key, DAN ITU DISENGAJA
  /// ==========================================================================
  ///  Penilaian tidak memindahkan uang, dan penilaian ganda sudah dicegah unique
  ///  index di database.
  ///
  ///  Yang lebih penting: percobaan kedua HARUS mendapat jawaban yang benar —
  ///  `RATING_ALREADY_SUBMITTED` — bukan putaran ulang response percobaan
  ///  pertama. Penumpang yang menekan kirim dua kali perlu tahu penilaiannya
  ///  sudah masuk, dan layar meresponsnya dengan MENUTUP form, bukan
  ///  menampilkan galat.
  /// ==========================================================================
  Future<Result<OrderRating>> rate({
    required String uuid,
    required int score,
    List<String> tags = const <String>[],
    String? comment,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/orders/$uuid/rating',
      body: <String, dynamic>{
        'score': score,
        if (tags.isNotEmpty) 'tags': tags,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          OrderRating.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Alasan pembatalan yang boleh dipilih penumpang.
  ///
  /// Diambil dari backend, bukan ditulis di aplikasi. Daftar ini ikut
  /// menentukan apakah pembatalan dikenai biaya, dan kalau aplikasi punya
  /// salinannya sendiri, satu perubahan kebijakan menuntut rilis aplikasi baru —
  /// dan pengguna yang belum memperbarui akan mengirim kode yang tidak dikenal.
  Future<Result<List<CancellationReason>>> cancellationReasons() async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/orders/cancellation-reasons',
    );

    return hasil.map((Map<String, dynamic> badan) {
      final List<dynamic> data =
          (badan['data'] as List<dynamic>?) ?? <dynamic>[];

      return data
          .map(
            (dynamic e) =>
                CancellationReason.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    });
  }
}

class OrderPage {
  const OrderPage({
    required this.orders,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Order> orders;
  final bool hasMore;
  final String? nextCursor;
}

class CancellationReason {
  const CancellationReason({
    required this.code,
    required this.text,
    required this.mayChargeFee,
  });

  final String code;
  final String text;

  /// Ditampilkan sebagai peringatan SEBELUM penumpang menekan batal.
  ///
  /// Menagihnya lalu menjelaskan sesudahnya adalah cara paling cepat membuat
  /// orang merasa ditipu — walaupun biayanya sah dan sudah ada di syarat
  /// layanan.
  final bool mayChargeFee;

  factory CancellationReason.fromJson(Map<String, dynamic> json) =>
      CancellationReason(
        code: json['code'] as String,
        text: json['text'] as String,
        mayChargeFee: json['may_charge_fee'] as bool? ?? false,
      );
}
