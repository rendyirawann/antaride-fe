import 'package:antaride_core/antaride_core.dart';

import 'order.dart' show OrderPlace;

/// Order dari sudut pandang DRIVER.
///
/// ============================================================================
///  KENAPA KELAS TERSENDIRI, BUKAN Order YANG SAMA
/// ============================================================================
///  Backend punya dua resource berbeda untuk satu baris order yang sama:
///  `OrderResource` untuk penumpang dan `DriverOrderResource` untuk driver.
///  Isinya sengaja berbeda, bukan kebetulan:
///
///    Penumpang melihat  rincian ongkos lengkap, profil driver, plat nomor
///    Driver melihat      pendapatannya saja, nomor HP penumpang, kode jemput,
///                        dan berapa yang harus ditagih kalau tunai
///
///  Driver TIDAK BOLEH melihat rincian ongkos penumpang — di dalamnya ada
///  komisi platform dan diskon promo, dan keduanya bukan urusannya. Driver yang
///  melihat total Rp 25.000 sementara pendapatannya Rp 20.000 akan menyimpulkan
///  ada yang dipotong tanpa penjelasan.
///
///  Satu kelas Dart untuk dua bentuk itu berarti separuh field-nya selalu null,
///  dan tidak ada cara membaca dari tipenya mana yang seharusnya terisi.
/// ============================================================================
class DriverOrder {
  const DriverOrder({
    required this.uuid,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.paymentMethod,
    required this.pickup,
    required this.earning,
    required this.allowedTransitions,
    this.destination,
    this.serviceCode,
    this.serviceName,
    this.collectFromPassenger,
    this.passenger,
    this.distanceM = 0,
    this.durationS = 0,
    this.routePolyline,
    this.matchedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.needsFareReview = false,
  });

  final String uuid;
  final String orderNumber;
  final String status;
  final String statusLabel;

  /// `cash` atau `wallet`.
  ///
  /// Hal PERTAMA yang perlu diketahui driver, dan karena itu ditampilkan paling
  /// mencolok di kartu order: tunai berarti dia harus menerima uang, wallet
  /// berarti dia TIDAK boleh menagih apa pun.
  final String paymentMethod;

  final OrderPlace pickup;
  final OrderPlace? destination;

  final String? serviceCode;
  final String? serviceName;

  /// Pendapatan driver untuk order ini. BUKAN total ongkos penumpang.
  final Money earning;

  /// Yang harus ditagih ke penumpang. Null pada order non-tunai.
  ///
  /// Null di sini berarti "jangan tagih apa pun", dan layar memperlakukannya
  /// begitu — bukan menampilkan Rp 0, yang terbaca sebagai ongkos gratis.
  final Money? collectFromPassenger;

  final DriverPassenger? passenger;

  final int distanceM;
  final int durationS;
  final String? routePolyline;

  final DateTime? matchedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  /// Status berikutnya yang boleh dituju dari status sekarang.
  ///
  /// ==========================================================================
  ///  TOMBOL DI LAYAR DIBANGUN DARI DAFTAR INI
  /// ==========================================================================
  ///  Aturan transisi ada di `OrderStateMachine` di backend. Aplikasi TIDAK
  ///  punya salinannya.
  ///
  ///  Kalau punya, akan ada versi aplikasi yang menampilkan tombol yang selalu
  ///  ditolak backend — dan bagi driver yang sedang di jalan itu terlihat
  ///  sebagai aplikasi yang rusak, bukan sebagai aturan yang berubah.
  /// ==========================================================================
  final List<String> allowedTransitions;

  /// Order yang ongkosnya ditandai untuk ditinjau, biasanya karena jarak
  /// sebenarnya jauh berbeda dari estimasi.
  final bool needsFareReview;

  bool get isCash => paymentMethod == 'cash';

  bool can(String status) => allowedTransitions.contains(status);

  bool get canArrive => can('driver_arrived');

  bool get canStart => can('in_progress');

  bool get canComplete => can('completed');

  bool get canCancel => can('cancelled');

  double get distanceKm => distanceM / 1000;

  factory DriverOrder.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> trip =
        (json['trip'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final Map<String, dynamic> waktu =
        (json['timestamps'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final Map<String, dynamic>? layanan =
        json['service'] as Map<String, dynamic>?;

    return DriverOrder(
      uuid: json['uuid'] as String,
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String? ?? '',

      paymentMethod: json['payment_method'] as String? ?? 'cash',

      pickup: OrderPlace.fromJson(json['pickup'] as Map<String, dynamic>),
      destination: json['destination'] == null
          ? null
          : OrderPlace.fromJson(json['destination'] as Map<String, dynamic>),

      serviceCode: layanan?['code'] as String?,
      serviceName: layanan?['name'] as String?,

      earning: json['earning'] == null
          ? Money.zero
          : Money.fromJson(json['earning'] as Map<String, dynamic>),

      collectFromPassenger: json['collect_from_passenger'] == null
          ? null
          : Money.fromJson(
              json['collect_from_passenger'] as Map<String, dynamic>,
            ),

      passenger: json['passenger'] == null
          ? null
          : DriverPassenger.fromJson(json['passenger'] as Map<String, dynamic>),

      distanceM: (trip['distance_m'] as num?)?.toInt() ?? 0,
      durationS: (trip['duration_s'] as num?)?.toInt() ?? 0,
      routePolyline: trip['route_polyline'] as String?,

      matchedAt: _waktu(waktu['matched_at']),
      arrivedAt: _waktu(waktu['arrived_at']),
      startedAt: _waktu(waktu['started_at']),
      completedAt: _waktu(waktu['completed_at']),
      cancelledAt: _waktu(waktu['cancelled_at']),

      allowedTransitions:
          ((json['allowed_transitions'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic e) => e as String)
              .toList(),

      needsFareReview: json['needs_fare_review'] as bool? ?? false,
    );
  }

  static DateTime? _waktu(dynamic nilai) {
    if (nilai is! String || nilai.isEmpty) {
      return null;
    }

    return DateTime.tryParse(nilai)?.toLocal();
  }
}

/// Penumpang, dari sudut pandang driver.
class DriverPassenger {
  const DriverPassenger({
    required this.name,
    required this.phone,
    this.photoUrl,
  });

  final String name;

  /// Nomor HP penumpang.
  ///
  /// Backend mengirimnya PENUH hanya selama order berjalan, dan tersamarkan
  /// setelah selesai. Aplikasi tidak menyimpannya, dan riwayat order tidak
  /// pernah memuat nomor penuh — driver yang menyimpan nomor penumpang dari
  /// riwayat adalah keluhan yang sudah pernah terjadi di layanan sejenis.
  final String phone;

  final String? photoUrl;

  factory DriverPassenger.fromJson(Map<String, dynamic> json) =>
      DriverPassenger(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        photoUrl: json['photo_url'] as String?,
      );
}

/// Tawaran order yang belum dijawab.
///
/// ============================================================================
///  ISINYA SENGAJA LEBIH SEDIKIT DARI DriverOrder
/// ============================================================================
///  Driver belum menerima order ini. Yang dia butuhkan untuk memutuskan hanya
///  empat hal: berapa dapatnya, seberapa jauh titik jemputnya, ke mana, dan
///  tunai atau tidak.
///
///  Nomor HP penumpang TIDAK ada di sini, dan itu bukan kelupaan: driver yang
///  belum menerima order tidak punya alasan menghubungi penumpangnya. Kalau
///  nomornya dikirim di tahap tawaran, satu driver bisa mengumpulkan nomor dari
///  tawaran yang dia tolak semuanya.
/// ============================================================================
class DriverOffer {
  const DriverOffer({
    required this.orderUuid,
    required this.serviceCode,
    required this.paymentMethod,
    required this.pickup,
    required this.earning,
    required this.expiresAt,
    required this.distanceToPickupM,
    this.destination,
    this.distanceM = 0,
    this.durationS = 0,
  });

  final String orderUuid;
  final String serviceCode;
  final String paymentMethod;

  final OrderPlace pickup;
  final OrderPlace? destination;

  final Money earning;

  /// Batas waktu menjawab.
  ///
  /// Tawaran yang lewat batas ini akan hilang sendiri, dan backend menawarkannya
  /// ke driver lain. Layar menampilkannya sebagai hitungan mundur dan menutup
  /// tawaran begitu habis — bukan membiarkan driver menekan "terima" pada
  /// tawaran yang sudah pindah, yang menghasilkan 409 tanpa penjelasan.
  final DateTime expiresAt;

  /// Jarak driver ke titik jemput, dalam meter.
  ///
  /// Ini angka yang paling menentukan apakah tawarannya diterima: order Rp
  /// 40.000 dengan jemputan 6 km sering kurang menarik dibanding Rp 20.000
  /// dengan jemputan 400 m.
  final int distanceToPickupM;

  final int distanceM;
  final int durationS;

  bool get isCash => paymentMethod == 'cash';

  int get secondsLeft {
    final int sisa = expiresAt.difference(DateTime.now()).inSeconds;

    return sisa < 0 ? 0 : sisa;
  }

  bool get isExpired => secondsLeft <= 0;

  double get pickupDistanceKm => distanceToPickupM / 1000;

  factory DriverOffer.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> trip =
        (json['trip'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return DriverOffer(
      orderUuid: json['order_uuid'] as String,
      serviceCode: json['service_code'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? 'cash',

      pickup: OrderPlace.fromJson(json['pickup'] as Map<String, dynamic>),
      destination: json['destination'] == null
          ? null
          : OrderPlace.fromJson(json['destination'] as Map<String, dynamic>),

      earning: json['driver_earning'] == null
          ? Money.zero
          : Money.fromJson(json['driver_earning'] as Map<String, dynamic>),

      /*
       * Tawaran tanpa cap waktu yang bisa diurai dianggap SUDAH habis.
       *
       * Arah yang aman kalau salah: tawarannya tidak ditampilkan. Arah
       * sebaliknya — memberinya masa berlaku default — berarti driver menatap
       * hitungan mundur untuk tawaran yang sudah pindah ke orang lain, lalu
       * menekan terima dan mendapat penolakan.
       */
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '')?.toLocal() ??
          DateTime.now().subtract(const Duration(seconds: 1)),

      distanceToPickupM: (json['distance_to_pickup_m'] as num?)?.toInt() ?? 0,
      distanceM: (trip['distance_m'] as num?)?.toInt() ?? 0,
      durationS: (trip['duration_s'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Status kerja driver: online, saldo, order berjalan, dan ringkasan hari ini.
class DriverStatus {
  const DriverStatus({
    required this.name,
    required this.accountStatus,
    required this.ratingAverage,
    required this.ratingCount,
    required this.acceptanceRate,
    required this.cancellationRate,
    required this.completedOrders,
    required this.isOnline,
    required this.balance,
    required this.canTakeCashOrders,
    required this.cashDepositMinimum,
    required this.todayOrders,
    required this.todayEarning,
    required this.todayOnlineSeconds,
    this.sessionStartedAt,
    this.activeOrderUuid,
    this.activeOrderNumber,
    this.activeOrderStatus,
    this.locationUrl,
    this.locationTicket,
  });

  final String name;

  /// `active`, `suspended`, `pending_verification`, dan seterusnya.
  final String accountStatus;

  final double ratingAverage;
  final int ratingCount;

  /// Rasio penerimaan tawaran, 0..1.
  ///
  /// Ikut menentukan prioritas driver di mesin pencocokan, jadi ditampilkan —
  /// driver yang tidak tahu angkanya tidak punya cara memperbaikinya.
  final double acceptanceRate;

  final double cancellationRate;
  final int completedOrders;

  final bool isOnline;
  final DateTime? sessionStartedAt;

  final Money balance;

  /// Apakah driver boleh menerima order TUNAI.
  ///
  /// ==========================================================================
  ///  KENAPA ORDER TUNAI MENUNTUT SALDO
  /// ==========================================================================
  ///  Pada order tunai, driver menerima uang penuh dari penumpang, dan komisi
  ///  platform dipotong dari saldonya. Kalau saldonya nol, komisi itu tidak bisa
  ///  ditagih — dan yang terjadi adalah saldo driver minus terus-menerus.
  ///
  ///  Karena itu ada batas minimum. Datang dari backend, bukan ditulis di
  ///  aplikasi: angkanya kebijakan yang bisa berubah, dan aplikasi yang punya
  ///  salinannya sendiri akan menolak order yang seharusnya boleh.
  /// ==========================================================================
  final bool canTakeCashOrders;
  final int cashDepositMinimum;

  final String? activeOrderUuid;
  final String? activeOrderNumber;
  final String? activeOrderStatus;

  /// Alamat dan tiket layanan lokasi, kalau sesinya masih terbuka.
  ///
  /// ==========================================================================
  ///  KENAPA TIKETNYA ADA DI SINI, BUKAN HANYA DI RESPONSE `online`
  /// ==========================================================================
  ///  Aplikasi driver ditutup Android secara rutin — kehabisan memori, atau
  ///  driver menutupnya sendiri di antara order. Saat dibuka lagi, yang dipanggil
  ///  hanya `GET /driver/status`; `POST /driver/online` tidak dipanggil karena
  ///  sesinya memang masih terbuka.
  ///
  ///  Kalau tiketnya hanya datang dari `online`, aplikasi yang baru dibuka itu
  ///  TIDAK punya tiket dan tidak punya cara mendapatkannya. Tidak ada satu pun
  ///  posisi yang terkirim, TTL 60 detik di Redis habis, dan driver keluar dari
  ///  indeks ketersediaan — sementara layarnya menyatakan dia online.
  ///
  ///  Satu-satunya jalan keluar tanpa ini adalah menekan offline lalu online
  ///  lagi, yang menutup sesinya dan memotong catatan jam kerjanya. Dan tidak ada
  ///  alasan bagi driver untuk menduga itu yang perlu dia lakukan.
  ///
  ///  Null saat driver offline, dan itu bukan kelalaian: tiket untuk driver yang
  ///  tidak bekerja berarti posisinya bisa tercatat tersedia setelah dia pulang.
  /// ==========================================================================
  final String? locationUrl;
  final String? locationTicket;

  /// True kalau status ini membawa tiket yang bisa dipakai mengirim posisi.
  bool get hasLocationTicket => locationUrl != null && locationTicket != null;

  final int todayOrders;
  final Money todayEarning;
  final int todayOnlineSeconds;

  bool get hasActiveOrder => activeOrderUuid != null;

  bool get isSuspended => accountStatus != 'active';

  Duration get todayOnline => Duration(seconds: todayOnlineSeconds);

  Duration? get sessionDuration => sessionStartedAt == null
      ? null
      : DateTime.now().difference(sessionStartedAt!);

  factory DriverStatus.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> driver =
        (json['driver'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final Map<String, dynamic> rating =
        (driver['rating'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final Map<String, dynamic> wallet =
        (json['wallet'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final Map<String, dynamic>? order =
        json['active_order'] as Map<String, dynamic>?;

    final Map<String, dynamic> hariIni =
        (json['today'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final Map<String, dynamic> lokasi =
        (json['location'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return DriverStatus(
      name: driver['name'] as String? ?? '',
      accountStatus: driver['status'] as String? ?? 'active',
      ratingAverage: (rating['average'] as num?)?.toDouble() ?? 5.0,
      ratingCount: (rating['count'] as num?)?.toInt() ?? 0,
      acceptanceRate: (driver['acceptance_rate'] as num?)?.toDouble() ?? 0,
      cancellationRate: (driver['cancellation_rate'] as num?)?.toDouble() ?? 0,
      completedOrders: (driver['completed_orders'] as num?)?.toInt() ?? 0,

      isOnline: json['online'] as bool? ?? false,
      sessionStartedAt: DateTime.tryParse(
        json['session_started_at'] as String? ?? '',
      )?.toLocal(),

      balance: wallet['balance'] == null
          ? Money.zero
          : Money.fromJson(wallet['balance'] as Map<String, dynamic>),

      canTakeCashOrders: wallet['can_take_cash_orders'] as bool? ?? false,
      cashDepositMinimum:
          (wallet['cash_deposit_minimum'] as num?)?.toInt() ?? 0,

      activeOrderUuid: order?['uuid'] as String?,
      activeOrderNumber: order?['order_number'] as String?,
      activeOrderStatus: order?['status'] as String?,

      locationUrl: lokasi['url'] as String?,
      locationTicket: lokasi['ticket'] as String?,

      todayOrders: (hariIni['orders_completed'] as num?)?.toInt() ?? 0,
      todayEarning: hariIni['earning'] == null
          ? Money.zero
          : Money.fromJson(hariIni['earning'] as Map<String, dynamic>),
      todayOnlineSeconds: (hariIni['online_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Satu layanan yang bisa dinyalakan driver.
class DriverService {
  const DriverService({
    required this.code,
    required this.name,
    required this.isAllowed,
    required this.isEnabled,
  });

  final String code;
  final String name;

  /// Apakah ADMIN mengizinkan driver ini mengambil layanan tersebut.
  ///
  /// Dipisahkan dari [isEnabled] karena keduanya berbeda sepenuhnya: yang ini
  /// keputusan admin — biasanya bergantung kelengkapan dokumen — dan driver
  /// tidak bisa mengubahnya. Layar menampilkan sakelar yang MATI DAN TERKUNCI,
  /// dengan keterangan, bukan menyembunyikan layanannya.
  final bool isAllowed;

  /// Apakah DRIVER menyalakannya.
  final bool isEnabled;

  bool get isActive => isAllowed && isEnabled;

  factory DriverService.fromJson(Map<String, dynamic> json) => DriverService(
    code: json['code'] as String,
    name: json['name'] as String? ?? '',
    isAllowed: json['allowed'] as bool? ?? false,
    isEnabled: json['enabled'] as bool? ?? false,
  );
}

/// Ringkasan sesi kerja yang baru ditutup.
class DriverSessionSummary {
  const DriverSessionSummary({
    required this.startedAt,
    required this.onlineSeconds,
    required this.ordersCompleted,
    this.endedAt,
  });

  final DateTime startedAt;
  final DateTime? endedAt;
  final int onlineSeconds;
  final int ordersCompleted;

  Duration get online => Duration(seconds: onlineSeconds);

  factory DriverSessionSummary.fromJson(Map<String, dynamic> json) =>
      DriverSessionSummary(
        startedAt:
            DateTime.tryParse(json['started_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        endedAt: DateTime.tryParse(
          json['ended_at'] as String? ?? '',
        )?.toLocal(),
        onlineSeconds: (json['online_seconds'] as num?)?.toInt() ?? 0,
        ordersCompleted: (json['orders_completed'] as num?)?.toInt() ?? 0,
      );
}
