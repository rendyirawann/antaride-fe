import 'package:antaride_core/antaride_core.dart';

import 'order.dart' show FareLine;

/// Estimasi harga.
///
/// ============================================================================
///  QUOTE PUNYA MASA BERLAKU, DAN ITU BUKAN DETAIL TEKNIS
/// ============================================================================
///  Backend menyimpan quote di Redis dengan TTL terbatas. Aplikasi mengirim
///  `quote_id` saat memesan, dan backend membaca harganya dari sana — harga
///  TIDAK pernah dikirim client. Itu sebabnya tidak ada setter apa pun di kelas
///  ini: nominal di sini semata untuk ditampilkan.
///
///  Yang harus ditangani layar: quote bisa kadaluarsa SAAT penumpang masih
///  menatap layar konfirmasi. Kalau itu terjadi dan aplikasi tetap mengirim
///  `quote_id` lama, backend menolaknya — dan penolakan itu muncul tepat saat
///  penumpang menekan tombol pesan, momen paling buruk untuk menampilkan galat.
///
///  [secondsUntilExpiry] dan [isExpired] ada supaya layar bisa mendahuluinya:
///  menampilkan hitungan mundur, dan meminta quote baru sebelum yang lama habis.
/// ============================================================================
class Quote {
  const Quote({
    required this.id,
    required this.expiresAt,
    required this.services,
    required this.distanceM,
    required this.durationS,
    this.zoneName,
    this.polyline,
    this.promos = const <QuotePromo>[],
  });

  final String id;
  final DateTime expiresAt;

  /// Pilihan layanan beserta harganya, sudah terurut dari backend.
  ///
  /// Urutannya TIDAK diurutkan ulang di aplikasi: backend mengurutkannya sesuai
  /// katalog, dan tiga aplikasi yang mengurutkan sendiri akan menampilkan
  /// urutan berbeda untuk data yang sama.
  final List<QuoteService> services;

  final int distanceM;
  final int durationS;
  final String? zoneName;
  final String? polyline;

  final List<QuotePromo> promos;

  double get distanceKm => distanceM / 1000;

  int get durationMinutes => (durationS / 60).ceil();

  int get secondsUntilExpiry {
    final int sisa = expiresAt.difference(DateTime.now()).inSeconds;

    return sisa < 0 ? 0 : sisa;
  }

  bool get isExpired => secondsUntilExpiry <= 0;

  /// Hampir kadaluarsa.
  ///
  /// Ambangnya 30 detik: cukup untuk penumpang menyelesaikan pemesanan setelah
  /// peringatannya muncul, dan tidak terlalu dini sehingga peringatannya menyala
  /// hampir sepanjang waktu dan berhenti dibaca.
  bool get isExpiringSoon => secondsUntilExpiry > 0 && secondsUntilExpiry <= 30;

  QuoteService? serviceFor(String code) {
    for (final QuoteService s in services) {
      if (s.code == code) {
        return s;
      }
    }

    return null;
  }

  /// Nominal potongan untuk satu kombinasi promo dan layanan.
  ///
  /// Dibaca dari quote, BUKAN dihitung. Backend mengirim nominalnya per promo
  /// per layanan justru karena satu quote bisa menawarkan beberapa promo
  /// sekaligus, dan besarnya berbeda untuk tiap layanan.
  ///
  /// Mengembalikan null kalau promonya tidak berlaku untuk layanan itu — dan
  /// layar memperlakukan null sebagai "tidak ada potongan", bukan nol rupiah.
  int? discountFor({required String promoCode, required String serviceCode}) {
    final String dicari = promoCode.toUpperCase();

    for (final QuotePromo p in promos) {
      if (p.code.toUpperCase() == dicari) {
        return p.discounts[serviceCode];
      }
    }

    return null;
  }

  factory Quote.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rute =
        (json['route'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return Quote(
      id: json['quote_id'] as String,

      /*
       * Cap waktu yang tidak bisa diurai membuat quote dianggap SUDAH
       * kadaluarsa, bukan berlaku selamanya.
       *
       * Arah yang aman kalau salah: aplikasi meminta quote baru. Arah
       * sebaliknya — menganggapnya masih berlaku — berarti aplikasi memesan
       * dengan harga yang tidak bisa dipastikan masih berlaku, dan penolakan
       * backend muncul di layar konfirmasi tanpa penjelasan.
       */
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '')?.toLocal() ??
          DateTime.now().subtract(const Duration(seconds: 1)),

      services: ((json['services'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => QuoteService.fromJson(e as Map<String, dynamic>))
          .toList(),

      distanceM: (rute['distance_m'] as num?)?.toInt() ?? 0,
      durationS: (rute['duration_s'] as num?)?.toInt() ?? 0,
      polyline: rute['polyline'] as String?,
      zoneName: json['zone'] as String?,

      promos: ((json['promos'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => QuotePromo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Satu pilihan layanan di dalam quote.
class QuoteService {
  const QuoteService({
    required this.code,
    required this.name,
    required this.total,
    required this.isOrderable,
    this.surgeMultiplier = '1.00',
    this.surgeActive = false,
    this.surgeExplanation,
    this.pickupEtaMinutes,
    this.availableDrivers = 0,
    this.tripDurationMinutes = 0,
    this.fareLines = const <FareLine>[],
  });

  final String code;
  final String name;

  final Money total;

  /// Apakah layanan ini bisa dipesan sekarang.
  ///
  /// Datang dari backend (`orderable`). Yang membuatnya false: tidak ada driver
  /// tersedia di sekitar, atau kill switch layanan itu sedang dimatikan.
  ///
  /// Layar menampilkannya sebagai pilihan REDUP dengan keterangan, bukan
  /// menyembunyikannya. Pilihan yang hilang membuat penumpang menyimpulkan
  /// layanannya tidak ada di Medan — dan kesimpulan itu tidak bisa dibatalkan
  /// oleh apa pun yang muncul di layar setelahnya.
  final bool isOrderable;

  final String surgeMultiplier;
  final bool surgeActive;

  /// Kalimat siap tampil dari backend, misalnya "Sedang jam sibuk".
  ///
  /// Null kalau tidak ada surge. Alasan teknis pemicunya tidak dikirim ke
  /// aplikasi, dan itu memang bukan yang dibutuhkan penumpang.
  final String? surgeExplanation;

  /// Perkiraan berapa menit driver sampai ke titik jemput.
  ///
  /// Angka ini lebih menentukan keputusan penumpang daripada harganya, jadi
  /// layar menampilkannya sejajar dengan harga, bukan di bawahnya.
  final int? pickupEtaMinutes;

  final int availableDrivers;
  final int tripDurationMinutes;

  /// Rincian ongkos siap tampil. Baris bernilai nol sudah dibuang backend.
  final List<FareLine> fareLines;

  /// Apakah sedang ada tarif jam sibuk.
  ///
  /// Ditampilkan sebagai lencana. Surge yang tidak diberitahukan adalah penyebab
  /// keluhan harga yang paling sering muncul: penumpang membandingkan dengan
  /// ongkos kemarin lalu menyimpulkan tarifnya dinaikkan diam-diam.
  bool get hasSurge => surgeActive || surgeMultiplier != '1.00';

  bool get hasNoDriver => availableDrivers == 0;

  factory QuoteService.fromJson(Map<String, dynamic> json) {
    /*
     * `fare` DI QUOTE BENTUKNYA BERBEDA dari `fare` di order.
     *
     * Quote mengirimnya rata — `total_fare` integer dan `total_formatted`
     * string — karena breakdown-nya masih berupa hasil perhitungan, belum baris
     * di tabel orders.
     *
     * Order mengirimnya bersarang: `total` sebagai objek Money utuh.
     *
     * Perbedaan itu ditangani DI SINI dan di `Order.fromJson`, masing-masing
     * sekali. Menyeragamkannya di lapisan lain berarti setiap layar harus
     * menebak bentuk mana yang datang.
     */
    final Map<String, dynamic> fare =
        (json['fare'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final Map<String, dynamic> surge =
        (json['surge'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return QuoteService(
      code: json['service_code'] as String? ?? '',
      name: json['service_name'] as String? ?? '',

      total: Money(
        amount: (fare['total_fare'] as num?)?.toInt() ?? 0,
        formatted: fare['total_formatted'] as String? ?? 'Rp 0',
      ),

      // Default-nya FALSE, bukan true. Kalau field-nya hilang karena perubahan
      // API, yang terjadi adalah tombol pesan mati — bukan pesanan yang dikirim
      // ke layanan yang sedang dimatikan lalu ditolak backend.
      isOrderable: json['orderable'] as bool? ?? false,

      surgeMultiplier: surge['multiplier'] as String? ?? '1.00',
      surgeActive: surge['active'] as bool? ?? false,
      surgeExplanation: surge['explanation'] as String?,

      pickupEtaMinutes: (json['pickup_eta_minutes'] as num?)?.toInt(),
      availableDrivers: (json['available_drivers'] as num?)?.toInt() ?? 0,
      tripDurationMinutes:
          (json['trip_duration_minutes'] as num?)?.toInt() ?? 0,

      fareLines: ((fare['lines'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => FareLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Promo yang berlaku untuk quote ini.
class QuotePromo {
  const QuotePromo({
    required this.code,
    required this.title,
    required this.discounts,
  });

  final String code;
  final String title;

  /// Nominal potongan per kode layanan.
  ///
  /// Layanan yang tidak ada di map ini TIDAK mendapat potongan dari promo ini.
  final Map<String, int> discounts;

  factory QuotePromo.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mentah =
        (json['discounts'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return QuotePromo(
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      discounts: mentah.map(
        (String k, dynamic v) =>
            MapEntry<String, int>(k, (v as num?)?.toInt() ?? 0),
      ),
    );
  }
}

/// Satu layanan di katalog, tanpa harga.
///
/// Dipakai di layar pertama SEBELUM pengguna masuk — endpoint `/service-types`
/// memang tanpa autentikasi. Harga baru muncul setelah ada titik jemput dan
/// tujuan, dan itu datang sebagai [QuoteService].
class ServiceTypeInfo {
  const ServiceTypeInfo({
    required this.code,
    required this.name,
    required this.vehicleClass,
    this.description,
    this.iconUrl,
    this.requiresMerchant = false,
    this.supportsMultiStop = false,
    this.maxStops = 1,
  });

  final String code;
  final String name;
  final String vehicleClass;
  final String? description;
  final String? iconUrl;

  /// Layanan yang menuntut merchant, misalnya pesan makanan.
  ///
  /// Layar tidak boleh meminta quote untuk layanan ini dari peta biasa —
  /// alurnya lewat pemilihan merchant lebih dulu.
  final bool requiresMerchant;

  final bool supportsMultiStop;
  final int maxStops;

  factory ServiceTypeInfo.fromJson(Map<String, dynamic> json) =>
      ServiceTypeInfo(
        code: json['code'] as String,
        name: json['name'] as String? ?? '',
        vehicleClass: json['vehicle_class'] as String? ?? 'motorcycle',
        description: json['description'] as String?,
        iconUrl: json['icon_url'] as String?,
        requiresMerchant: json['requires_merchant'] as bool? ?? false,
        supportsMultiStop: json['supports_multi_stop'] as bool? ?? false,
        maxStops: (json['max_stops'] as num?)?.toInt() ?? 1,
      );
}
