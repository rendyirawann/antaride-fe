import 'dart:typed_data';

import 'package:antaride_core/antaride_core.dart';

import '../client/api_client.dart';
import '../models/driver_document.dart';
import '../models/driver_order.dart';

/// Seluruh endpoint aplikasi driver.
///
/// ============================================================================
///  DRIVER ADALAH PENGGUNA BIASA YANG PUNYA BARIS DI TABEL `drivers`
/// ============================================================================
///  Tidak ada guard terpisah dan tidak ada token terpisah. Token yang dipakai
///  di sini sama dengan yang dipakai aplikasi penumpang.
///
///  Alasannya: satu orang bisa jadi penumpang DAN driver sekaligus, dan itu
///  wajar — driver memesan ojek saat kendaraannya di bengkel. Guard terpisah
///  akan memaksanya punya dua akun dengan dua nomor HP.
///
///  Yang memeriksa apakah dia benar-benar driver adalah backend, dan
///  jawabannya 403. Layar memperlakukan 403 di sini sebagai "akun ini bukan
///  akun driver" dan mengarahkan ke pendaftaran driver, bukan ke layar masuk.
/// ============================================================================
class DriverRepository {
  const DriverRepository(this._client);

  final ApiClient _client;

  // ---------------------------------------------------------------------------
  //  Status kerja
  // ---------------------------------------------------------------------------

  /// Status kerja, saldo, order berjalan, dan ringkasan hari ini.
  ///
  /// Dipanggil setiap kali aplikasi driver dibuka. Satu panggilan, bukan empat:
  /// aplikasi driver sering dibuka di jaringan seluler yang buruk sambil
  /// berkendara, dan empat request berarti empat kesempatan gagal untuk satu
  /// layar.
  Future<Result<DriverStatus>> status() async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/driver/status',
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          DriverStatus.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Mulai bekerja.
  ///
  /// Posisi WAJIB: tanpa itu backend tidak bisa menentukan zona, dan tanpa zona
  /// driver tidak bisa didaftarkan di indeks ketersediaan — artinya dia online
  /// tapi tidak akan pernah menerima tawaran.
  ///
  /// [vehicleId] boleh dikosongkan kalau driver hanya punya satu kendaraan.
  /// Backend memakai kendaraan aktif pertamanya. Memaksanya memilih setiap kali
  /// online adalah satu langkah tambahan untuk pilihan yang cuma ada satu.
  Future<Result<GoOnlineResult>> goOnline({
    required double lat,
    required double lng,
    int? vehicleId,
    List<String>? serviceCodes,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/driver/online',
      body: <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'vehicle_id': ?vehicleId,
        if (serviceCodes != null && serviceCodes.isNotEmpty)
          'service_codes': serviceCodes,
      },
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          GoOnlineResult.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Berhenti bekerja.
  ///
  /// Mengembalikan ringkasan sesi yang baru ditutup, atau null kalau memang
  /// tidak ada sesi terbuka — dan null di situ BUKAN kegagalan. Driver yang
  /// menekan offline dua kali, atau yang sesinya sudah ditutup oleh timeout GPS,
  /// harus melihat konfirmasi bahwa dia offline, bukan galat.
  Future<Result<DriverSessionSummary?>> goOffline() async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/driver/offline',
    );

    return hasil.map((Map<String, dynamic> badan) {
      final Map<String, dynamic> data =
          (badan['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      final dynamic sesi = data['session'];

      if (sesi == null) {
        return null;
      }

      return DriverSessionSummary.fromJson(sesi as Map<String, dynamic>);
    });
  }

  /// Layanan yang boleh dan yang sedang dinyalakan driver.
  Future<Result<List<DriverService>>> services() async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/driver/services',
    );

    return hasil.map((Map<String, dynamic> badan) {
      final List<dynamic> data =
          (badan['data'] as List<dynamic>?) ?? const <dynamic>[];

      return data
          .map((dynamic e) => DriverService.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Nyalakan atau matikan satu layanan.
  ///
  /// Mematikan layanan langsung mencabut driver dari indeks ketersediaan untuk
  /// layanan itu — jadi efeknya seketika, bukan setelah sesi berikutnya. Itu
  /// yang diharapkan driver saat dia mematikan "pesan makanan" karena boks
  /// makanannya tertinggal di rumah.
  Future<Result<void>> toggleService({
    required String code,
    required bool enabled,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.patch(
      '/driver/services/$code',
      body: <String, dynamic>{'enabled': enabled},
    );

    return hasil.map((Map<String, dynamic> _) {});
  }

  // ---------------------------------------------------------------------------
  //  Tawaran
  // ---------------------------------------------------------------------------

  /// Tawaran yang belum dijawab dan belum habis masa berlakunya.
  ///
  /// ==========================================================================
  ///  INI JARING PENGAMAN, BUKAN JALUR UTAMA
  /// ==========================================================================
  ///  Tawaran seharusnya sampai lewat push notification dan Centrifugo. Endpoint
  ///  ini ada untuk keadaan yang pasti terjadi: aplikasi baru dibuka kembali
  ///  setelah dimatikan paksa, atau koneksi realtime-nya putus tanpa disadari.
  ///
  ///  Memanggilnya sebagai polling ketat — setiap dua detik — akan bekerja, dan
  ///  itulah masalahnya: gejala koneksi realtime yang rusak jadi tidak terlihat
  ///  sampai tagihan servernya naik. Panggil saat aplikasi kembali ke depan dan
  ///  saat koneksi realtime tersambung ulang.
  /// ==========================================================================
  Future<Result<List<DriverOffer>>> offers() async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/driver/orders/offers',
    );

    return hasil.map((Map<String, dynamic> badan) {
      final List<dynamic> data =
          (badan['data'] as List<dynamic>?) ?? const <dynamic>[];

      return data
          .map((dynamic e) => DriverOffer.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Terima tawaran.
  ///
  /// ==========================================================================
  ///  TIDAK IDEMPOTENT, DAN ITU DISENGAJA DI BACKEND
  /// ==========================================================================
  ///  Endpoint ini TIDAK memakai Idempotency-Key. Kalau memakainya, driver yang
  ///  menekan dua kali dan kalah balapan di percobaan pertama akan mendapat
  ///  putaran ulang response sukses milik percobaan yang tidak pernah berhasil.
  ///
  ///  Yang benar adalah 409 — dan layar memperlakukannya sebagai "order sudah
  ///  diambil driver lain", lalu menutup kartu tawarannya. Bukan sebagai galat
  ///  jaringan yang perlu dicoba ulang.
  ///
  ///  Yang menjaga dari eksekusi ganda adalah tiga lapis di backend: lock Redis,
  ///  SELECT FOR UPDATE, dan partial unique index yang melarang satu driver
  ///  punya dua order aktif.
  /// ==========================================================================
  Future<Result<DriverOrder>> accept(String orderUuid) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/driver/orders/$orderUuid/accept',
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          DriverOrder.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Tolak tawaran.
  ///
  /// Mengembalikan false kalau tawarannya sudah tidak `pending` — sudah habis,
  /// atau sudah diambil driver lain. Bukan kegagalan: hasilnya sama, kartunya
  /// ditutup.
  ///
  /// Menolak lebih baik daripada mendiamkan sampai habis, dan bukan hanya bagi
  /// penumpang: tawaran yang didiamkan menurunkan rasio penerimaan driver sama
  /// seperti yang ditolak, tapi menahan order lebih lama sebelum ditawarkan ke
  /// orang lain.
  Future<Result<bool>> reject(String orderUuid) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/driver/orders/$orderUuid/reject',
    );

    return hasil.map((Map<String, dynamic> badan) {
      final Map<String, dynamic> data =
          (badan['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      return data['rejected'] as bool? ?? false;
    });
  }

  // ---------------------------------------------------------------------------
  //  Order berjalan
  // ---------------------------------------------------------------------------

  /// Order yang sedang dikerjakan, atau null.
  Future<Result<DriverOrder?>> activeOrder() async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/driver/orders/active',
    );

    return hasil.map((Map<String, dynamic> badan) {
      final dynamic data = badan['data'];

      if (data == null) {
        return null;
      }

      return DriverOrder.fromJson(data as Map<String, dynamic>);
    });
  }

  /// Pindahkan order ke status berikutnya.
  ///
  /// [status] hanya boleh `driver_arriving` atau `driver_arrived`. Memulai
  /// perjalanan dan menyelesaikan order punya method sendiri — [startTrip] dan
  /// [complete] — karena keduanya membawa efek samping yang jauh lebih besar:
  /// pemeriksaan kode jemput, dan pembagian uang.
  ///
  /// Nilai yang boleh dikirim ada di `DriverOrder.allowedTransitions`, dan layar
  /// membangun tombolnya dari daftar itu.
  Future<Result<DriverOrder>> transition({
    required String orderUuid,
    required String status,
    required double lat,
    required double lng,
    double? accuracyM,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.patch(
      '/driver/orders/$orderUuid/status',
      body: <String, dynamic>{
        'status': status,
        'lat': lat,
        'lng': lng,
        'accuracy_m': ?accuracyM,
      },
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          DriverOrder.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Mulai perjalanan, dengan kode jemput dari penumpang.
  ///
  /// ==========================================================================
  ///  KODE JEMPUT ADALAH SATU-SATUNYA PEMERIKSAAN BAHWA ORANGNYA BENAR
  /// ==========================================================================
  ///  Driver meminta penumpang MENYEBUTKAN kodenya, lalu mengetiknya. Kode yang
  ///  salah membuat backend menolak dengan 422, dan layar menampilkannya sebagai
  ///  "kode tidak cocok, minta penumpang menyebutkan lagi" — bukan sebagai galat
  ///  sistem.
  ///
  ///  Yang TIDAK boleh dilakukan aplikasi driver: menampilkan kode yang benar di
  ///  layar driver "untuk memudahkan". Itu menghapus seluruh gunanya.
  /// ==========================================================================
  Future<Result<DriverOrder>> startTrip({
    required String orderUuid,
    required String pickupCode,
    double? lat,
    double? lng,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/driver/orders/$orderUuid/start',
      body: <String, dynamic>{
        'pickup_code': pickupCode,
        'lat': ?lat,
        'lng': ?lng,
      },
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          DriverOrder.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Selesaikan order.
  ///
  /// ==========================================================================
  ///  [idempotencyKey] HARUS DIPAKAI ULANG SAAT MENCOBA LAGI
  /// ==========================================================================
  ///  Endpoint ini MEMINDAHKAN UANG: pendapatan masuk ke dompet driver, komisi
  ///  dipotong, dan tahanan dana penumpang dilepas.
  ///
  ///  Pemanggil membuat kuncinya SEKALI — saat driver menekan "selesai" — dan
  ///  memakai kunci yang sama untuk setiap percobaan berikutnya. Kunci baru
  ///  setiap percobaan berarti backend melihat dua permintaan berbeda, dan
  ///  pembagian uangnya dijalankan dua kali.
  ///
  ///  Ini endpoint yang paling mungkin dicoba ulang di seluruh aplikasi driver:
  ///  driver menekan selesai di gang sempit tanpa sinyal, tidak melihat respons,
  ///  lalu menekan lagi.
  /// ==========================================================================
  ///
  /// [actualPolyline] adalah jejak GPS perjalanan. Opsional, karena bisa hilang
  /// kalau aplikasi dimatikan paksa di tengah jalan — dan menolak penyelesaian
  /// karena itu akan MENJEBAK driver: dia tidak bisa menutup order ini, dan
  /// tidak bisa menerima order berikutnya.
  Future<Result<DriverOrder>> complete({
    required String orderUuid,
    required String idempotencyKey,
    required double lat,
    required double lng,
    String? actualPolyline,
    int? actualDistanceM,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.postIdempotent(
      '/driver/orders/$orderUuid/complete',
      idempotencyKey: idempotencyKey,
      body: <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'actual_polyline': ?actualPolyline,
        'actual_distance_m': ?actualDistanceM,
      },
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          DriverOrder.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Batalkan order yang sudah diterima.
  ///
  /// [note] WAJIB dan minimal 5 karakter — berbeda dari pembatalan oleh
  /// penumpang, di mana catatan opsional.
  ///
  /// Alasannya: pembatalan oleh driver merugikan penumpang yang sudah menunggu,
  /// dan sebagian alasan menurunkan skor driver. Angka yang menurunkan skor
  /// seseorang harus disertai keterangan yang bisa dia bantah, bukan hanya kode.
  /// Alasan pembatalan yang boleh dipilih DRIVER.
  ///
  /// ==========================================================================
  ///  BUKAN DAFTAR YANG SAMA DENGAN MILIK PENUMPANG
  /// ==========================================================================
  ///  Tabel `cancellation_reasons` di backend disaring per `actor_type`, dan
  ///  penyaringan itu ditegakkan validasi: driver yang mengirim kode milik
  ///  penumpang ditolak 422.
  ///
  ///  Itu sebabnya ada method tersendiri di sini, dan bukan memakai
  ///  `OrderRepository.cancellationReasons()` — yang mengembalikan alasan
  ///  penumpang. Memakai yang salah menghasilkan tombol batalkan yang SELALU
  ///  ditolak, dengan galat yang tidak menjelaskan apa pun kepada driver.
  ///
  ///  Aplikasi juga TIDAK menyimpan salinan daftarnya. Admin bisa menambah atau
  ///  menonaktifkan alasan kapan saja, dan salinan di aplikasi akan menyimpang
  ///  tanpa ada yang menyadarinya sampai ada driver yang gagal membatalkan.
  /// ==========================================================================
  // ---------------------------------------------------------------------------
  //  Dokumen KYC
  // ---------------------------------------------------------------------------

  /// Keadaan dokumen driver, beserta jenis yang masih kurang.
  Future<Result<DriverDocumentState>> documents() async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/driver/documents',
    );

    return hasil.map(
      (Map<String, dynamic> badan) => DriverDocumentState.fromJson(
        (badan['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
    );
  }

  /// Unggah atau ganti satu dokumen.
  ///
  /// ==========================================================================
  ///  TIDAK MEMAKAI Idempotency-Key, DAN ITU BUKAN KELALAIAN
  /// ==========================================================================
  ///  Kunci idempotency ada untuk operasi yang MEMINDAHKAN UANG — di situ
  ///  request yang terkirim dua kali karena koneksi buruk berarti dua
  ///  pembayaran.
  ///
  ///  Unggahan dokumen tidak begitu. Jenis dokumennya unik per driver
  ///  (`unique(driver_id, type)`), jadi unggahan yang terkirim dua kali
  ///  menghasilkan baris yang SAMA — bukan dua dokumen. Yang berubah hanya
  ///  berkasnya, dan berkas kedua memang yang dimaksud driver.
  ///
  ///  Memaksakan kunci di sini justru merugikan: response yang diputar ulang dari
  ///  kunci lama akan menyatakan berhasil untuk berkas yang TIDAK terkirim, pada
  ///  percobaan kedua yang sebenarnya membawa foto yang berbeda.
  /// ==========================================================================
  ///
  /// [onProgress] menerima (terkirim, total) dalam byte. Layar wajib
  /// menampilkannya: unggahan foto di jaringan buruk bisa memakan setengah menit,
  /// dan layar tanpa indikator selama itu terbaca sebagai aplikasi yang
  /// menggantung — driver akan menutupnya dan mengulang dari awal.
  Future<Result<DriverDocument>> uploadDocument({
    required String type,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    DateTime? expiresAt,
    String? number,
    void Function(int terkirim, int total)? onProgress,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.upload(
      '/driver/documents',
      field: 'file',
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      fields: <String, dynamic>{
        'type': type,

        /*
         * Tanggal dikirim sebagai `YYYY-MM-DD`, bukan ISO 8601 penuh.
         *
         * Kolomnya bertipe DATE dan memuat tanggal kadaluarsa dokumen apa
         * adanya — bukan sebuah momen. Mengirim `2027-03-01T00:00:00+07:00` ke
         * kolom DATE membuat tanggalnya bergeser satu hari di sebagian zona,
         * dan pergeseran satu hari pada masa berlaku SIM adalah selisih antara
         * driver yang sah dan yang tidak.
         */
        if (expiresAt != null)
          'expires_at': expiresAt.toIso8601String().substring(0, 10),

        if (number != null && number.isNotEmpty) 'number': number,
      },
      onProgress: onProgress,
    );

    return hasil.map(
      (Map<String, dynamic> badan) => DriverDocument.fromJson(
        (badan['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<Result<List<DriverCancellationReason>>> cancellationReasons() async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/driver/orders/cancellation-reasons',
    );

    return hasil.map((Map<String, dynamic> badan) {
      final List<dynamic> data =
          (badan['data'] as List<dynamic>?) ?? const <dynamic>[];

      return data
          .map(
            (dynamic e) =>
                DriverCancellationReason.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    });
  }

  Future<Result<DriverOrder>> cancel({
    required String orderUuid,
    required String reasonCode,
    required String note,
    double? lat,
    double? lng,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/driver/orders/$orderUuid/cancel',
      body: <String, dynamic>{
        'reason_code': reasonCode,
        'note': note,
        'lat': ?lat,
        'lng': ?lng,
      },
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          DriverOrder.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }
}

/// Hasil [DriverRepository.goOnline].
class GoOnlineResult {
  const GoOnlineResult({
    required this.startedAt,
    required this.pingIntervalSeconds,
    this.locationUrl,
    this.locationTicket,
  });

  final DateTime startedAt;

  /// Seberapa sering aplikasi harus mengirim posisi, dalam detik.
  ///
  /// ==========================================================================
  ///  ANGKANYA DARI BACKEND, DAN HARUS DIPATUHI
  /// ==========================================================================
  ///  Backend memakai interval berbeda untuk driver menganggur dan driver yang
  ///  sedang mengantar — yang menganggur lebih jarang, karena posisinya hanya
  ///  dipakai untuk pencocokan.
  ///
  ///  Aplikasi yang menuliskan angkanya sendiri akan salah dalam dua arah, dan
  ///  keduanya buruk: terlalu jarang berarti driver tidak dianggap tersedia dan
  ///  berhenti mendapat tawaran tanpa tahu sebabnya; terlalu sering berarti
  ///  baterai HP-nya habis di tengah hari kerja.
  /// ==========================================================================
  final int pingIntervalSeconds;

  Duration get pingInterval => Duration(seconds: pingIntervalSeconds);

  /// Alamat lengkap endpoint ping di layanan lokasi.
  ///
  /// ==========================================================================
  ///  DATANG DARI BACKEND, TIDAK DITULIS DI APLIKASI
  /// ==========================================================================
  ///  Layanan lokasi berjalan terpisah dari Laravel — proses Go tersendiri, port
  ///  tersendiri, dan bisa pindah host tanpa API-nya berubah.
  ///
  ///  Aplikasi yang menuliskan alamatnya sendiri akan berhenti mengirim ping
  ///  begitu layanan itu dipindahkan, dan gejalanya bukan galat: driver terlihat
  ///  online di layarnya sendiri dan tidak pernah mendapat satu pun tawaran.
  ///
  ///  Null berarti layanan lokasinya belum dikonfigurasi di backend. Aplikasi
  ///  tetap jalan — driver tetap bisa menerima order yang ditawarkan lewat jalur
  ///  lain — tapi posisinya tidak terkirim.
  /// ==========================================================================
  final String? locationUrl;

  /// Tiket bertanda tangan untuk layanan lokasi.
  ///
  /// ==========================================================================
  ///  BUKAN TOKEN SANCTUM, DAN HAKNYA JAUH LEBIH KECIL
  /// ==========================================================================
  ///  Tiket ini HANYA bisa dipakai mengirim posisi driver ini. Dia tidak bisa
  ///  menerima order, membaca data penumpang, atau menyentuh uang — semua itu
  ///  tetap lewat token Sanctum.
  ///
  ///  Pemisahan itu yang membuatnya aman dikirim ke layanan yang berbeda: kalau
  ///  layanan lokasi dikompromikan, yang bisa dilakukan penyerang hanya
  ///  memalsukan posisi — bukan mengambil alih akun.
  ///
  ///  Masa berlakunya 12 jam, cukup untuk satu shift kerja penuh.
  /// ==========================================================================
  final String? locationTicket;

  bool get canSendLocation =>
      locationUrl != null &&
      locationUrl!.isNotEmpty &&
      locationTicket != null &&
      locationTicket!.isNotEmpty;

  factory GoOnlineResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> lokasi =
        (json['location'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return GoOnlineResult(
      startedAt:
          DateTime.tryParse(
            json['session_started_at'] as String? ?? '',
          )?.toLocal() ??
          DateTime.now(),
      pingIntervalSeconds:
          (json['ping_interval_seconds'] as num?)?.toInt() ?? 10,
      locationUrl: lokasi['url'] as String?,
      locationTicket: lokasi['ticket'] as String?,
    );
  }
}

/// Satu alasan pembatalan yang boleh dipilih driver.
class DriverCancellationReason {
  const DriverCancellationReason({
    required this.code,
    required this.text,
    required this.lowersScore,
    this.mayChargeFee = false,
  });

  final String code;
  final String text;

  /// Apakah memilih alasan ini MENURUNKAN skor pembatalan driver.
  ///
  /// ==========================================================================
  ///  DIBERITAHUKAN, TIDAK DISEMBUNYIKAN
  /// ==========================================================================
  ///  Skor pembatalan ikut menentukan prioritas driver di mesin pencocokan.
  ///
  ///  Menyembunyikan penanda ini berarti driver memilih alasan yang paling
  ///  menggambarkan keadaannya, lalu mendapati order yang masuk berkurang tanpa
  ///  tahu sebabnya — dan itu keluhan yang tidak bisa dijawab, karena dari
  ///  sudut pandangnya sistemnya memang menghukum tanpa memberi tahu.
  ///
  ///  Layar menampilkannya sebagai keterangan kecil di baris alasannya, bukan
  ///  sebagai peringatan yang menakut-nakuti.
  /// ==========================================================================
  final bool lowersScore;

  /// Selalu false di Fase 1 — driver tidak dikenai biaya pembatalan.
  ///
  /// Tetap dibaca dari backend karena kebijakannya bisa berubah tanpa rilis
  /// aplikasi baru.
  final bool mayChargeFee;

  factory DriverCancellationReason.fromJson(Map<String, dynamic> json) =>
      DriverCancellationReason(
        code: json['code'] as String,
        text: json['text'] as String? ?? '',
        lowersScore: json['lowers_score'] as bool? ?? false,
        mayChargeFee: json['may_charge_fee'] as bool? ?? false,
      );
}
