import 'package:antaride_core/antaride_core.dart';

/// Order, dari sudut pandang penumpang.
///
/// ============================================================================
///  MODEL DITULIS TANGAN, TIDAK DI-GENERATE
/// ============================================================================
///  Backend punya spesifikasi OpenAPI lengkap, dan `swagger_parser` bisa
///  menghasilkan model Dart darinya. Itu TIDAK dipakai di sini, dan alasannya
///  bukan ketidakpercayaan pada alatnya.
///
///  Model hasil generate memetakan setiap field API satu-satu. Yang hilang di
///  situ adalah hal yang justru paling berguna: field TURUNAN yang dipakai
///  layar. `canCancel`, `isActive`, `waitingMinutes` tidak ada di API — dan
///  kalau model-nya di-generate, ketiganya berakhir tersebar di widget sebagai
///  perbandingan string status.
///
///  Yang terjadi kalau begitu: enam layar masing-masing menulis
///  `status == 'accepted' || status == 'driver_arriving' || ...` dan salah satu
///  akan lupa satu status. Bug itu tidak menghasilkan error, hanya tombol yang
///  tidak muncul di layar tertentu.
///
///  `parseFromJson` di bawah TETAP mengikuti bentuk OpenAPI persis, jadi
///  perubahan API akan gagal di satu tempat, bukan menyebar.
/// ============================================================================
class Order {
  const Order({
    required this.uuid,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.pickup,
    required this.total,
    required this.fareLines,
    required this.canCancel,
    required this.canRate,
    this.rating,
    this.destination,
    this.serviceCode,
    this.serviceName,
    this.driver,
    this.pickupCode,
    this.distanceM = 0,
    this.durationS = 0,
    this.routePolyline,
    this.requestedAt,
    this.matchedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationFee,
    this.cancelledBy,
  });

  final String uuid;
  final String orderNumber;

  /// Nilai mentah, misalnya `driver_arriving`. Dipakai untuk logika.
  final String status;

  /// Teks dari backend. Dipakai untuk ditampilkan.
  ///
  /// Tidak diterjemahkan di aplikasi: enam layar yang menerjemahkan sendiri akan
  /// menghasilkan enam teks yang sedikit berbeda untuk status yang sama.
  final String statusLabel;

  final String paymentMethod;
  final String paymentStatus;

  final OrderPlace pickup;
  final OrderPlace? destination;

  final String? serviceCode;
  final String? serviceName;

  final Money total;
  final List<FareLine> fareLines;

  final OrderDriver? driver;

  /// Kode jemput. HANYA terisi selama masih relevan — backend yang
  /// menentukannya, dan setelah perjalanan dimulai field-nya tidak dikirim.
  final String? pickupCode;

  final int distanceM;
  final int durationS;
  final String? routePolyline;

  final DateTime? requestedAt;
  final DateTime? matchedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  final Money? cancellationFee;
  final String? cancelledBy;

  /// Apakah tombol batalkan ditampilkan.
  ///
  /// Datang dari backend (`can_cancel`), TIDAK disimpulkan di sini.
  ///
  /// Aturan status mana yang bisa dibatalkan ada di `OrderStatus::isCancellable()`
  /// di backend. Menyalinnya ke aplikasi berarti ada dua daftar yang harus
  /// sepakat — dan versi aplikasi yang lama akan menampilkan tombol yang selalu
  /// ditolak, bug yang terlihat sebagai aplikasi rusak.
  final bool canCancel;

  /// Apakah penumpang boleh menilai perjalanan ini.
  ///
  /// ==========================================================================
  ///  DATANG DARI BACKEND, TIDAK DISIMPULKAN DI SINI
  /// ==========================================================================
  ///  Aturannya dua: order harus `completed`, DAN penumpang belum menilainya.
  ///
  ///  Aplikasi hanya bisa memeriksa yang pertama — dia tidak tahu apakah order
  ///  sudah dinilai dari perangkat lain atau di sesi sebelumnya. Yang terjadi
  ///  kalau disimpulkan sendiri: form penilaian muncul lagi di riwayat untuk
  ///  perjalanan yang sudah dinilai, dan pengirimannya ditolak 409.
  /// ==========================================================================
  final bool canRate;

  /// Penilaian yang PERNAH diberikan, kalau sudah dinilai.
  ///
  /// Terisi supaya layar riwayat bisa MENAMPILKAN bintangnya — bukan hanya
  /// menyembunyikan formnya. Penumpang yang lupa apakah dia sudah menilai
  /// mendapat jawabannya tanpa harus mencoba.
  final OrderRating? rating;

  // ---------------------------------------------------------------------------
  //  Turunan
  // ---------------------------------------------------------------------------

  /// Order yang masih berjalan.
  static const Set<String> _statusBerjalan = <String>{
    'created',
    'searching',
    'accepted',
    'driver_arriving',
    'driver_arrived',
    'in_progress',
  };

  bool get isActive => _statusBerjalan.contains(status);

  bool get isSearching => status == 'searching';

  bool get hasDriver => driver != null;

  bool get isCompleted => status == 'completed';

  bool get isFailed =>
      status == 'cancelled' || status == 'no_driver' || status == 'expired';

  /// Driver sudah tiba di titik jemput.
  ///
  /// Dipisahkan karena ini SATU-SATUNYA status yang menuntut penumpang bertindak
  /// sekarang — dan layar harus memperlakukannya berbeda: notifikasi, getaran,
  /// dan lencana kuning.
  bool get isDriverWaiting => status == 'driver_arrived';

  double get distanceKm => distanceM / 1000;

  int get durationMinutes => (durationS / 60).ceil();

  /// Berapa lama order ini sudah mencari driver.
  ///
  /// Dihitung dari `requestedAt`, dan hanya berarti selama masih `searching`.
  Duration? get searchingFor {
    if (!isSearching || requestedAt == null) {
      return null;
    }

    return DateTime.now().difference(requestedAt!);
  }

  // ---------------------------------------------------------------------------

  factory Order.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> fare =
        (json['fare'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final Map<String, dynamic> waktu =
        (json['timestamps'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final Map<String, dynamic> trip =
        (json['trip'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final Map<String, dynamic> pembatalan =
        (json['cancellation'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return Order(
      uuid: json['uuid'] as String,
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String? ?? '',

      paymentMethod:
          (json['payment'] as Map<String, dynamic>?)?['method'] as String? ??
          'cash',
      paymentStatus:
          (json['payment'] as Map<String, dynamic>?)?['status'] as String? ??
          'unpaid',

      pickup: OrderPlace.fromJson(json['pickup'] as Map<String, dynamic>),
      destination: json['destination'] == null
          ? null
          : OrderPlace.fromJson(json['destination'] as Map<String, dynamic>),

      serviceCode:
          (json['service'] as Map<String, dynamic>?)?['code'] as String?,
      serviceName:
          (json['service'] as Map<String, dynamic>?)?['name'] as String?,

      total: fare['total'] == null
          ? Money.zero
          : Money.fromJson(fare['total'] as Map<String, dynamic>),

      fareLines: ((fare['lines'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => FareLine.fromJson(e as Map<String, dynamic>))
          .toList(),

      driver: json['driver'] == null
          ? null
          : OrderDriver.fromJson(json['driver'] as Map<String, dynamic>),

      pickupCode: json['pickup_code'] as String?,

      distanceM: (trip['distance_m'] as num?)?.toInt() ?? 0,
      durationS: (trip['duration_s'] as num?)?.toInt() ?? 0,
      routePolyline: trip['route_polyline'] as String?,

      requestedAt: _waktu(waktu['requested_at']),
      matchedAt: _waktu(waktu['matched_at']),
      completedAt: _waktu(waktu['completed_at']),
      cancelledAt: _waktu(waktu['cancelled_at']),

      cancellationFee: pembatalan['fee'] == null
          ? null
          : Money(
              amount: (pembatalan['fee'] as num).toInt(),
              formatted: pembatalan['fee_formatted'] as String? ?? 'Rp 0',
            ),
      cancelledBy: pembatalan['by'] as String?,

      canCancel: json['can_cancel'] as bool? ?? false,

      // Default FALSE, bukan true. Kalau field-nya hilang karena perubahan API,
      // yang terjadi adalah form penilaian tidak muncul — bukan penilaian yang
      // dikirim lalu ditolak 409.
      canRate: json['can_rate'] as bool? ?? false,

      rating: json['rating'] == null
          ? null
          : OrderRating.fromJson(json['rating'] as Map<String, dynamic>),
    );
  }

  /// Urai cap waktu ISO 8601 dari backend.
  ///
  /// `toLocal()` dipanggil karena backend mengirim UTC dengan offset. Tanpa itu,
  /// "diterima 08:14" akan tampil sebagai 01:14 di HP pengguna — dan tidak ada
  /// yang akan mengira penyebabnya zona waktu.
  static DateTime? _waktu(dynamic nilai) {
    if (nilai is! String || nilai.isEmpty) {
      return null;
    }

    return DateTime.tryParse(nilai)?.toLocal();
  }
}

class OrderPlace {
  const OrderPlace({
    required this.address,
    required this.lat,
    required this.lng,
    this.note,
  });

  final String address;
  final double lat;
  final double lng;
  final String? note;

  factory OrderPlace.fromJson(Map<String, dynamic> json) => OrderPlace(
    address: json['address'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble() ?? 0,
    lng: (json['lng'] as num?)?.toDouble() ?? 0,
    note: json['note'] as String?,
  );
}

class OrderDriver {
  const OrderDriver({
    required this.name,
    required this.ratingAverage,
    required this.ratingCount,
    this.photoUrl,
    this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.plateNumber,
  });

  final String name;
  final double ratingAverage;
  final int ratingCount;
  final String? photoUrl;

  final String? vehicleType;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;

  /// Plat nomor adalah satu-satunya cara penumpang memastikan kendaraan yang
  /// berhenti di depannya benar. Ditampilkan paling besar di layar pelacakan.
  final String? plateNumber;

  String get vehicleDescription {
    final List<String> bagian = <String>[
      ?vehicleBrand,
      ?vehicleModel,
      if (vehicleColor != null) '— $vehicleColor',
    ];

    return bagian.isEmpty ? '' : bagian.join(' ');
  }

  factory OrderDriver.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rating =
        (json['rating'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final Map<String, dynamic>? kendaraan =
        json['vehicle'] as Map<String, dynamic>?;

    return OrderDriver(
      name: json['name'] as String? ?? '',
      ratingAverage: (rating['average'] as num?)?.toDouble() ?? 5.0,
      ratingCount: (rating['count'] as num?)?.toInt() ?? 0,
      photoUrl: json['photo_url'] as String?,
      vehicleType: kendaraan?['type'] as String?,
      vehicleBrand: kendaraan?['brand'] as String?,
      vehicleModel: kendaraan?['model'] as String?,
      vehicleColor: kendaraan?['color'] as String?,
      plateNumber: kendaraan?['plate_number'] as String?,
    );
  }
}

/// Satu baris rincian ongkos.
class FareLine {
  const FareLine({
    required this.label,
    required this.amount,
    required this.formatted,
  });

  final String label;
  final int amount;

  /// Sudah termasuk tandanya. Backend yang menanganinya — diskon dan penyesuaian
  /// regulasi keduanya negatif dan harus tampil dengan minus di depan.
  final String formatted;

  factory FareLine.fromJson(Map<String, dynamic> json) => FareLine(
    label: json['label'] as String? ?? '',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    formatted: json['formatted'] as String? ?? 'Rp 0',
  );
}

/// Penilaian yang diberikan penumpang untuk satu order.
class OrderRating {
  const OrderRating({
    required this.score,
    this.tags = const <String>[],
    this.comment,
    this.ratedAt,
  });

  /// 1 sampai 5.
  final int score;

  /// Alasan yang dipilih, misalnya "ramah" atau "kendaraan bersih".
  final List<String> tags;

  final String? comment;
  final DateTime? ratedAt;

  factory OrderRating.fromJson(Map<String, dynamic> json) => OrderRating(
    score: (json['score'] as num?)?.toInt() ?? 0,
    tags: ((json['tags'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => e.toString())
        .toList(),
    comment: json['comment'] as String?,
    ratedAt: DateTime.tryParse(json['rated_at'] as String? ?? '')?.toLocal(),
  );
}
