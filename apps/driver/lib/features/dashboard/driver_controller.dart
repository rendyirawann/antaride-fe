import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../location/foreground_location_service.dart';
import '../location/location_background_service.dart';

/// Seluruh state kerja driver: online, tawaran, dan order berjalan.
///
/// ============================================================================
///  SATU CONTROLLER, KARENA KETIGANYA SALING MENGUNCI
/// ============================================================================
///  Ketiga hal itu tidak bisa dipisah menjadi controller sendiri-sendiri:
///
///    Driver yang punya order berjalan TIDAK BOLEH menerima tawaran baru —
///    partial unique index di database melarangnya, dan aplikasi yang tetap
///    menampilkan tawaran akan menghasilkan penolakan 409 di setiap penerimaan.
///
///    Driver yang offline tidak boleh punya tawaran tertunda di layar. Tawaran
///    yang tertinggal setelah dia offline akan ditekan, ditolak backend, dan
///    dia menyimpulkan aplikasinya rusak.
///
///  Tiga controller berarti tiga sumber kebenaran yang harus sepakat. Yang
///  terjadi kalau tidak sepakat bukan error, tapi tombol yang menolak setiap
///  tekanan.
/// ============================================================================
class DriverController extends ChangeNotifier {
  DriverController({
    required DriverRepository driver,
    LocationService? location,
    LocationBackgroundService? background,
  }) : _driver = driver,
       _location = location ?? const LocationService(),
       _background = background ?? ForegroundLocationService() {
    _background.onReport(_terimaLaporanLokasi);
  }

  final DriverRepository _driver;
  final LocationService _location;

  /// Pengirim posisi latar belakang. Foreground service di Android.
  ///
  /// ==========================================================================
  ///  DUA JALUR PENGIRIMAN, DAN HANYA SATU YANG AKTIF SEKALIGUS
  /// ==========================================================================
  ///  Android      foreground service. Posisi tetap terkirim walaupun layar mati
  ///               dan aplikasi ditutup — yang memang keadaan normal driver.
  ///
  ///  Selainnya    timer di dalam aplikasi. Bekerja selama aplikasinya terlihat,
  ///               dan berhenti begitu tidak. Itu cukup untuk pengembangan di
  ///               Chrome, dan TIDAK cukup untuk driver sungguhan.
  ///
  ///  Yang tidak boleh terjadi: keduanya jalan bersamaan. Dua pengirim untuk satu
  ///  driver berarti dua pembacaan GPS dan dua penulisan ke Redis, dan posisi yang
  ///  menang jadi bergantung pada urutan kedatangan — yang lebih lama bisa
  ///  menang. Lihat `_mulaiGps`.
  /// ==========================================================================
  final LocationBackgroundService _background;

  /// True kalau foreground service benar-benar berjalan.
  ///
  /// Bukan sama dengan `_background.supported`: platform bisa mendukungnya
  /// sementara driver menolak izin notifikasi. Yang menentukan jalur mana yang
  /// aktif adalah field ini, bukan dukungan platformnya.
  bool _serviceLatarJalan = false;

  DriverStatus? _status;
  DriverOrder? _activeOrder;
  List<DriverOffer> _offers = const <DriverOffer>[];

  ApiFailure? _failure;
  String? _locationMessage;

  bool _loading = true;
  bool _busy = false;

  Timer? _pollStatus;
  Timer? _pollOffers;
  Timer? _pingGps;
  StreamSubscription<LatLng>? _gpsListener;

  LatLng? _lastPosition;
  int _pingIntervalSeconds = 10;
  bool _disposed = false;

  /// Alamat dan tiket layanan lokasi, dari response `/driver/online`.
  ///
  /// Dikosongkan saat offline: tiket yang tertinggal setelah driver berhenti
  /// bekerja masih berlaku sampai 12 jam, dan ping yang terkirim setelah dia
  /// offline membuat posisinya tetap tercatat — jadi dia bisa mendapat tawaran
  /// untuk order yang tidak dia inginkan.
  String? _locationUrl;
  String? _locationTicket;

  /// Pengirim ping untuk jalur DALAM APLIKASI saja.
  ///
  /// Saat foreground service jalan, pinger ini tidak dipakai sama sekali — yang
  /// mengirim adalah pinger di dalam isolate service.
  final LocationPinger _pinger = LocationPinger();

  /// Hitungan ping yang dibaca LAYAR, dari jalur mana pun yang aktif.
  ///
  /// ==========================================================================
  ///  SATU SUMBER UNTUK PERINGATAN, DUA SUMBER PENGISI
  /// ==========================================================================
  ///  Kedua field ini diisi salah satu dari dua tempat:
  ///
  ///    Jalur aplikasi   dari `_pinger` setelah setiap pengiriman.
  ///    Jalur service    dari laporan isolate lewat `_terimaLaporanLokasi`.
  ///
  ///  `locationWarning` membaca HANYA field ini, tidak pernah `_pinger`
  ///  langsung. Kalau dia membaca `_pinger`, peringatan di layar akan selalu
  ///  menyatakan "belum pernah terkirim" pada jalur service — karena `_pinger`
  ///  di isolate layar memang tidak pernah dipakai di jalur itu.
  ///
  ///  Dan peringatan yang menyala terus-menerus persis sama buruknya dengan
  ///  peringatan yang tidak pernah menyala: keduanya berhenti dibaca.
  /// ==========================================================================
  int _pingSukses = 0;
  int _pingGagalBerurutan = 0;

  /// Berapa ping berurutan yang gagal sebelum peringatan ditampilkan.
  ///
  /// Tiga, bukan satu: satu ping yang gagal terjadi setiap kali driver melewati
  /// area tanpa sinyal, dan peringatan yang menyala di setiap perempatan
  /// berhenti dibaca. Tiga berturut-turut pada interval 10 detik berarti sudah
  /// setengah menit posisinya tidak terkirim.
  static const int _ambangPeringatanPing = 3;

  // ---------------------------------------------------------------------------

  DriverStatus? get status => _status;

  DriverOrder? get activeOrder => _activeOrder;

  /// Tawaran yang masih hidup.
  ///
  /// Yang sudah habis masa berlakunya DISARING DI SINI, bukan dibiarkan tampil
  /// sampai penarikan berikutnya. Tawaran kadaluarsa yang masih di layar akan
  /// ditekan driver dan ditolak backend — dan penolakan itu terbaca sebagai
  /// aplikasi yang lambat, bukan sebagai tawaran yang memang sudah pindah.
  List<DriverOffer> get offers =>
      _offers.where((DriverOffer o) => !o.isExpired).toList();

  ApiFailure? get failure => _failure;

  /// Pesan soal izin atau layanan lokasi, kalau ada masalah.
  String? get locationMessage => _locationMessage;

  bool get isLoading => _loading;

  bool get isBusy => _busy;

  bool get isOnline => _status?.isOnline ?? false;

  bool get hasActiveOrder => _activeOrder != null;

  LatLng? get lastPosition => _lastPosition;

  /// Boleh menerima tawaran baru.
  ///
  /// False saat sudah ada order berjalan — lihat docblock kelas.
  bool get canTakeOffers => isOnline && !hasActiveOrder;

  /// Peringatan kalau posisi driver tidak terkirim, atau null kalau normal.
  ///
  /// ==========================================================================
  ///  INI SATU-SATUNYA KEGAGALAN PING YANG SAMPAI KE LAYAR
  /// ==========================================================================
  ///  Ping tunggal yang gagal tidak dilaporkan — itu terjadi setiap kali driver
  ///  melewati area tanpa sinyal, dan tidak ada yang perlu dia lakukan.
  ///
  ///  Tapi posisi yang TIDAK PERNAH terkirim berarti driver tidak akan pernah
  ///  muncul sebagai kandidat matching. Dia online, motornya di tempat, dan
  ///  tidak ada order yang masuk — tanpa satu pun galat di layar. Itu kegagalan
  ///  yang paling membingungkan di seluruh aplikasi driver, dan satu-satunya
  ///  cara dia bisa menghubungkannya adalah kalau kita memberitahunya.
  ///
  ///  Pesannya dibedakan: "belum pernah berhasil" biasanya konfigurasi atau izin
  ///  lokasi, "sempat berhasil lalu terputus" biasanya jaringan.
  /// ==========================================================================
  String? get locationWarning {
    if (!isOnline || _pingGagalBerurutan < _ambangPeringatanPing) {
      return null;
    }

    if (_pingSukses == 0) {
      return 'Posisi Anda belum pernah terkirim. Anda tidak akan menerima '
          'tawaran sampai ini berhasil — periksa izin lokasi dan koneksi.';
    }

    return 'Posisi Anda tidak terkirim beberapa saat terakhir. Tawaran bisa '
        'terlewat sampai koneksi pulih.';
  }

  /// True kalau posisi HANYA terkirim selama aplikasi terlihat.
  ///
  /// ==========================================================================
  ///  DRIVER HARUS TAHU INI, KARENA YANG DIA LAKUKAN BERBEDA
  /// ==========================================================================
  ///  Kalau foreground service tidak jalan — izin notifikasi ditolak, atau
  ///  platformnya tidak mendukung — posisi berhenti terkirim begitu dia mengunci
  ///  HP-nya. Dan dia TIDAK akan melihat galat: aplikasinya tetap menyatakan
  ///  online.
  ///
  ///  Perbedaannya dengan [locationWarning] penting: yang itu soal ping yang
  ///  GAGAL, yang bisa pulih sendiri saat sinyal kembali. Yang ini soal ping yang
  ///  bahkan tidak akan dicoba, dan yang menyelesaikannya adalah memberi izin
  ///  notifikasi — bukan menunggu.
  /// ==========================================================================
  bool get onlyPingsWhileOpen => isOnline && !_serviceLatarJalan;

  /// True kalau aplikasi punya tiket untuk mengirim posisi.
  ///
  /// ==========================================================================
  ///  TANPA TIKET, SELURUH JALUR PING DIAM TANPA SATU PUN GALAT
  /// ==========================================================================
  ///  Ping GPS tidak pergi ke Laravel — dia ke layanan lokasi, dan layanan itu
  ///  hanya menerima permintaan bertiket. Tanpa tiket, `_kirimPosisi` keluar
  ///  SEBELUM memanggil pinger.
  ///
  ///  Akibatnya `consecutiveFailures` tetap nol, jadi [locationWarning] juga
  ///  tidak pernah menyala. Driver online sepanjang jam sibuk, tidak ada satu pun
  ///  tawaran, dan tidak ada apa pun di layar yang bisa dia hubungkan dengan
  ///  penyebabnya.
  ///
  ///  Itu bug yang pernah terjadi di sini — `_hentikanGps` membuang tiket yang
  ///  baru diterima, karena `_mulaiGps` memanggilnya lebih dulu. Getter ini yang
  ///  membuat keadaannya bisa diperiksa test, dan bisa ditampilkan ke driver
  ///  alih-alih dibiarkan senyap.
  /// ==========================================================================
  bool get hasLocationTicket => _locationUrl != null && _locationTicket != null;

  // ---------------------------------------------------------------------------

  Future<void> start() async {
    // `refresh()` LEBIH DULU, dan urutan ini penting: tiket lokasi untuk driver
    // yang sudah online datang dari `GET /driver/status`. Memulai GPS sebelum
    // status ditarik berarti memulainya tanpa tiket — dan jalur ping akan diam
    // sampai driver menekan offline lalu online.
    await refresh();

    _jadwalkanStatus();
    _jadwalkanTawaran();

    if (isOnline) {
      await _mulaiGps();
    }
  }

  @override
  void dispose() {
    _disposed = true;

    _pollStatus?.cancel();
    _pollOffers?.cancel();
    _pingGps?.cancel();
    _gpsListener?.cancel();

    super.dispose();
  }

  /// Tarik status dan order berjalan.
  Future<void> refresh() async {
    final List<Object?> hasil = await Future.wait<Object?>(<Future<Object?>>[
      _driver.status(),
      _driver.activeOrder(),
    ]);

    if (_disposed) {
      return;
    }

    final Result<DriverStatus> status = hasil[0]! as Result<DriverStatus>;
    final Result<DriverOrder?> aktif = hasil[1]! as Result<DriverOrder?>;

    _loading = false;

    switch (status) {
      case Ok<DriverStatus>(value: final DriverStatus s):
        _status = s;
        _failure = null;

        /*
         * ==============================================================
         *  TIKET DARI `status` DIPAKAI KALAU BELUM ADA
         * ==============================================================
         *  Aplikasi driver ditutup Android secara rutin — kehabisan memori, atau
         *  driver menutupnya sendiri di antara order. Saat dibuka lagi, sesinya
         *  masih terbuka, jadi `goOnline` TIDAK dipanggil: yang jalan hanya
         *  `start()` lalu `refresh()`.
         *
         *  Tanpa baris ini, proses baru itu tidak punya tiket dan tidak punya
         *  cara mendapatkannya. Tidak ada satu pun posisi yang terkirim, TTL 60
         *  detik di Redis habis, dan driver keluar dari indeks ketersediaan —
         *  sementara layarnya menyatakan dia online.
         *
         *  Yang TIDAK dilakukan: menimpa tiket yang sudah ada. Tiket dari
         *  `goOnline` lebih baru, dan menimpanya dengan tiket dari penarikan
         *  status berkala berarti tiketnya diganti setiap dua puluh detik —
         *  yang membuat foreground service di-restart terus-menerus.
         * ==============================================================
         */
        if (_locationTicket == null && s.hasLocationTicket) {
          _locationUrl = s.locationUrl;
          _locationTicket = s.locationTicket;
        }

      case Err<DriverStatus>(failure: final ApiFailure f):
        // Status lama dipertahankan. Driver yang sedang mengantar melewati area
        // tanpa sinyal secara teratur, dan mengosongkan layar setiap kali satu
        // request gagal berarti dasbor berkedip sepanjang perjalanan.
        _failure = f;
    }

    _activeOrder = aktif.valueOrNull ?? _activeOrder;

    /*
     * Order yang sudah tidak berjalan DIBUANG dari state.
     *
     * `activeOrder()` mengembalikan null kalau tidak ada order berjalan, dan
     * `valueOrNull` juga null saat request-nya GAGAL. Keduanya tidak bisa
     * dibedakan dari nilainya, jadi yang membedakan adalah keberhasilannya:
     * hanya response sukses yang boleh menghapus order dari layar.
     */
    if (aktif.isOk && aktif.valueOrNull == null) {
      _activeOrder = null;
    }

    notifyListeners();
  }

  Future<void> refreshOffers() async {
    // Tawaran tidak ditarik saat sudah ada order berjalan. Backend juga tidak
    // akan mengirimkannya, jadi ini request yang jawabannya sudah diketahui.
    if (!canTakeOffers) {
      if (_offers.isNotEmpty) {
        _offers = const <DriverOffer>[];
        notifyListeners();
      }

      return;
    }

    final Result<List<DriverOffer>> hasil = await _driver.offers();

    if (_disposed) {
      return;
    }

    final List<DriverOffer>? data = hasil.valueOrNull;

    if (data != null) {
      _offers = data;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  //  Online / offline
  // ---------------------------------------------------------------------------

  /// Mulai bekerja.
  ///
  /// Mengembalikan false kalau gagal — dan penyebabnya bisa dua hal berbeda:
  /// lokasi tidak tersedia ([locationMessage]) atau backend menolak
  /// ([failure]). Layar menampilkan keduanya berbeda, karena tindakan yang
  /// diperlukan berbeda: yang pertama diselesaikan di pengaturan perangkat.
  Future<bool> goOnline() async {
    if (_busy) {
      return false;
    }

    _busy = true;
    _failure = null;
    _locationMessage = null;
    notifyListeners();

    try {
      final LocationOutcome posisi = await _location.current();

      if (posisi is LocationUnavailable) {
        /*
         * Online DITOLAK kalau tidak ada posisi, dan ini satu-satunya tempat di
         * seluruh aplikasi yang menolak karena lokasi.
         *
         * Bukan kekakuan: tanpa posisi, backend tidak bisa menentukan zona, dan
         * tanpa zona driver tidak masuk indeks ketersediaan. Dia akan tampak
         * online di layarnya sendiri dan TIDAK PERNAH menerima tawaran — dan
         * kegagalan yang paling buruk adalah yang terlihat berhasil.
         */
        _locationMessage = posisi.message;

        return false;
      }

      final LatLng titik = (posisi as LocationReady).position;

      _lastPosition = titik;

      final Result<GoOnlineResult> hasil = await _driver.goOnline(
        lat: titik.latitude,
        lng: titik.longitude,
      );

      switch (hasil) {
        case Ok<GoOnlineResult>(value: final GoOnlineResult r):
          _pingIntervalSeconds = r.pingIntervalSeconds;

          _locationUrl = r.locationUrl;
          _locationTicket = r.locationTicket;

          _resetHitunganPing();

          await refresh();
          await _mulaiGps();
          await refreshOffers();

          return true;

        case Err<GoOnlineResult>(failure: final ApiFailure f):
          _failure = f;

          return false;
      }
    } finally {
      _busy = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<DriverSessionSummary?> goOffline() async {
    if (_busy) {
      return null;
    }

    _busy = true;
    notifyListeners();

    try {
      final Result<DriverSessionSummary?> hasil = await _driver.goOffline();

      await _hentikanGps();

      // Tiket dibuang DI SINI, bukan di `_hentikanGps` — lihat docblock
      // `_lupakanTiketLokasi`. Tiket berlaku sampai 12 jam, dan yang tertinggal
      // setelah driver offline membuat ping yang terlewat tetap mencatat
      // posisinya sebagai tersedia.
      _lupakanTiketLokasi();

      _offers = const <DriverOffer>[];

      await refresh();

      return hasil.valueOrNull;
    } finally {
      _busy = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Tawaran
  // ---------------------------------------------------------------------------

  Future<bool> accept(String orderUuid) async {
    if (_busy) {
      return false;
    }

    _busy = true;
    _failure = null;
    notifyListeners();

    try {
      final Result<DriverOrder> hasil = await _driver.accept(orderUuid);

      switch (hasil) {
        case Ok<DriverOrder>(value: final DriverOrder o):
          _activeOrder = o;
          _offers = const <DriverOffer>[];

          return true;

        case Err<DriverOrder>(failure: final ApiFailure f):
          _failure = f;

          /*
           * Tawaran yang gagal diterima DIBUANG dari daftar, apa pun sebabnya.
           *
           * Kasus yang paling sering: 409 karena driver lain lebih cepat. Order
           * itu sudah tidak ada, dan membiarkan kartunya di layar berarti
           * driver menekan terima berulang pada order yang sudah pindah.
           */
          _offers = _offers
              .where((DriverOffer o) => o.orderUuid != orderUuid)
              .toList();

          return false;
      }
    } finally {
      _busy = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> reject(String orderUuid) async {
    // Kartu dibuang dari layar SEKARANG, tanpa menunggu jawaban backend.
    //
    // Driver sudah memutuskan, dan menahannya sampai request selesai membuat
    // tombol terasa tidak merespons. Kalau request-nya gagal, tawarannya akan
    // habis sendiri di backend — hasilnya sama.
    _offers = _offers
        .where((DriverOffer o) => o.orderUuid != orderUuid)
        .toList();
    notifyListeners();

    await _driver.reject(orderUuid);
  }

  // ---------------------------------------------------------------------------
  //  Order berjalan
  // ---------------------------------------------------------------------------

  Future<bool> transition(String status) async {
    final DriverOrder? order = _activeOrder;

    if (order == null || _busy) {
      return false;
    }

    final LatLng titik = _lastPosition ?? medanCenter;

    return _jalankan(
      () => _driver.transition(
        orderUuid: order.uuid,
        status: status,
        lat: titik.latitude,
        lng: titik.longitude,
      ),
    );
  }

  Future<bool> startTrip(String pickupCode) async {
    final DriverOrder? order = _activeOrder;

    if (order == null || _busy) {
      return false;
    }

    final LatLng? titik = _lastPosition;

    return _jalankan(
      () => _driver.startTrip(
        orderUuid: order.uuid,
        pickupCode: pickupCode,
        lat: titik?.latitude,
        lng: titik?.longitude,
      ),
    );
  }

  /// Selesaikan order.
  ///
  /// ==========================================================================
  ///  KUNCI IDEMPOTENCY DIBUAT SEKALI PER ORDER, DISIMPAN DI MAP
  /// ==========================================================================
  ///  Endpoint ini memindahkan uang. Percobaan ulang HARUS memakai kunci yang
  ///  sama, atau pembagian uangnya dijalankan dua kali.
  ///
  ///  Disimpan per UUID order, bukan satu field: driver bisa menyelesaikan order
  ///  A, lalu order B, dan kunci yang dipakai bersama akan membuat penyelesaian
  ///  B memutar ulang response A — yang berarti order B tidak pernah benar-benar
  ///  ditutup, dan driver terjebak tidak bisa menerima order berikutnya.
  /// ==========================================================================
  final Map<String, String> _kunciSelesai = <String, String>{};

  Future<bool> complete({String? actualPolyline, int? actualDistanceM}) async {
    final DriverOrder? order = _activeOrder;

    if (order == null || _busy) {
      return false;
    }

    final LatLng titik = _lastPosition ?? medanCenter;

    _kunciSelesai[order.uuid] ??= const Uuid().v4();

    final bool berhasil = await _jalankan(
      () => _driver.complete(
        orderUuid: order.uuid,
        idempotencyKey: _kunciSelesai[order.uuid]!,
        lat: titik.latitude,
        lng: titik.longitude,
        actualPolyline: actualPolyline,
        actualDistanceM: actualDistanceM,
      ),
    );

    if (berhasil) {
      _kunciSelesai.remove(order.uuid);

      // Order selesai dibuang dari state supaya dasbor kembali menerima
      // tawaran. Tanpa ini, `canTakeOffers` tetap false dan driver berhenti
      // mendapat order tanpa tahu sebabnya.
      _activeOrder = null;

      await refresh();
      await refreshOffers();
    }

    return berhasil;
  }

  Future<bool> cancelOrder({
    required String reasonCode,
    required String note,
  }) async {
    final DriverOrder? order = _activeOrder;

    if (order == null || _busy) {
      return false;
    }

    final LatLng? titik = _lastPosition;

    final bool berhasil = await _jalankan(
      () => _driver.cancel(
        orderUuid: order.uuid,
        reasonCode: reasonCode,
        note: note,
        lat: titik?.latitude,
        lng: titik?.longitude,
      ),
    );

    if (berhasil) {
      _activeOrder = null;

      await refresh();
      await refreshOffers();
    }

    return berhasil;
  }

  void clearFailure() {
    if (_failure == null && _locationMessage == null) {
      return;
    }

    _failure = null;
    _locationMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------

  Future<bool> _jalankan(Future<Result<DriverOrder>> Function() aksi) async {
    _busy = true;
    _failure = null;
    notifyListeners();

    try {
      final Result<DriverOrder> hasil = await aksi();

      switch (hasil) {
        case Ok<DriverOrder>(value: final DriverOrder o):
          _activeOrder = o;

          return true;

        case Err<DriverOrder>(failure: final ApiFailure f):
          _failure = f;

          return false;
      }
    } finally {
      _busy = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  GPS
  // ---------------------------------------------------------------------------

  /// Mulai memantau posisi dan mengirimnya ke backend.
  ///
  /// ==========================================================================
  ///  MEMBACA GPS DAN MENGIRIM POSISI ADALAH DUA HAL TERPISAH
  /// ==========================================================================
  ///  Aliran GPS memakai filter jarak 15 meter: driver yang berhenti di lampu
  ///  merah tidak menghasilkan pembaruan sama sekali, dan itu yang menjaga
  ///  baterainya.
  ///
  ///  Pengirimannya dijadwalkan TIMER terpisah dengan `ping_interval_seconds`
  ///  dari backend. Kalau pengirimannya dipicu aliran GPS, driver yang berhenti
  ///  akan berhenti mengirim posisi sepenuhnya — dan backend akan
  ///  mengeluarkannya dari indeks ketersediaan karena dianggap hilang.
  ///
  ///  Yang terjadi kemudian: dia online, motornya di tempat, dan tidak ada
  ///  order yang masuk. Tanpa satu pun galat di layar.
  /// ==========================================================================
  Future<void> _mulaiGps() async {
    await _hentikanGps();

    if (_disposed) {
      return;
    }

    /*
     * ======================================================================
     *  FOREGROUND SERVICE DICOBA LEBIH DULU, DAN KALAU JALAN ITU SATU-SATUNYA
     * ======================================================================
     *  Kalau service berhasil dimulai, isolate-nya yang membaca GPS DAN yang
     *  mengirim ping. Isolate layar tidak melakukan keduanya:
     *
     *    * Tidak ada timer ping — dua pengirim untuk satu driver berarti posisi
     *      yang menang bergantung pada urutan kedatangan, dan yang lebih lama
     *      bisa menang.
     *
     *    * Tidak ada aliran GPS — dua pembaca berarti chip GPS dibangunkan dua
     *      kali sesering yang perlu, sepanjang shift, dan baterai driver yang
     *      membayarnya. Posisi untuk peta di dasbor datang dari laporan service.
     *
     *  `url` dan `ticket` sudah dipastikan tidak null di `goOnline`; kalau
     *  backend belum mengonfigurasi layanan lokasi keduanya null, dan jalur
     *  service dilewati — sama seperti jalur aplikasi, tidak ada yang bisa
     *  dikirim ke mana pun.
     * ======================================================================
     */
    final String? url = _locationUrl;
    final String? tiket = _locationTicket;

    if (_background.supported && url != null && tiket != null) {
      /*
       * `services` sengaja dibiarkan kosong.
       *
       * Daftar layanan aktif driver SUDAH ada di dalam tiket — backend yang
       * menaruhnya di sana saat `goOnline`. Layanan lokasi hanya bisa
       * MEMPERSEMPIT daftar itu, tidak memperluasnya.
       *
       * Mengirim daftar dari sini berarti aplikasi menyalin informasi yang sudah
       * ada di tiket, dan salinan yang tidak sinkron akan mempersempit daftarnya
       * tanpa ada yang meminta — driver berhenti mendapat tawaran untuk layanan
       * yang menurut layarnya masih aktif.
       */
      final bool jalan = await _background.start(
        url: url,
        ticket: tiket,
        intervalSeconds: _pingIntervalSeconds,
      );

      if (_disposed) {
        return;
      }

      _serviceLatarJalan = jalan;

      if (jalan) {
        return;
      }
    }

    _gpsListener = _location.watch().listen(
      (LatLng titik) {
        _lastPosition = titik;
      },
      onError: (Object _) {
        // Kegagalan aliran GPS tidak menjatuhkan apa pun. Posisi terakhir yang
        // diketahui tetap dikirim oleh timer di bawah — posisi yang agak lama
        // jauh lebih baik daripada tidak ada posisi, karena tidak ada posisi
        // berarti hilang dari indeks.
      },
    );

    _pingGps?.cancel();
    _pingGps = Timer.periodic(
      Duration(seconds: _pingIntervalSeconds),
      (Timer _) => _kirimPosisi(),
    );
  }

  Future<void> _hentikanGps() async {
    _pingGps?.cancel();
    _pingGps = null;

    await _gpsListener?.cancel();
    _gpsListener = null;

    // Service dihentikan walaupun `_serviceLatarJalan` false.
    //
    // Alasannya: service bisa masih berjalan dari sesi SEBELUMNYA — Android
    // me-restart-nya sendiri kalau prosesnya pernah dimatikan, dan
    // `_serviceLatarJalan` di proses baru dimulai dari false. Menyerahkan
    // keputusannya ke field itu berarti service lama tetap hidup dan tetap
    // mengirim posisi setelah driver offline.
    if (_background.supported) {
      await _background.stop();
    }

    _serviceLatarJalan = false;

    _resetHitunganPing();
  }

  /// Buang tiket lokasi.
  ///
  /// ==========================================================================
  ///  DIPISAH DARI `_hentikanGps`, DAN INI BUG YANG PERNAH TERJADI
  /// ==========================================================================
  ///  Sebelumnya tiketnya dibuang di dalam `_hentikanGps`. Kelihatannya rapi:
  ///  berhenti mengirim posisi, buang tiketnya.
  ///
  ///  Tapi `_mulaiGps` memanggil `_hentikanGps` LEBIH DULU — untuk membersihkan
  ///  timer dan aliran dari sesi sebelumnya. Akibatnya urutan yang sebenarnya
  ///  terjadi setiap kali driver online adalah:
  ///
  ///    1. `goOnline` menyimpan tiket yang baru diterima dari backend.
  ///    2. `_mulaiGps` memanggil `_hentikanGps`.
  ///    3. `_hentikanGps` MENGHAPUS tiket yang baru saja disimpan.
  ///    4. Timer ping menyala, membaca tiket, mendapati null, dan langsung
  ///       keluar — setiap kali, selamanya.
  ///
  ///  Tidak ada satu pun posisi yang terkirim. Dan karena `_kirimPosisi` keluar
  ///  SEBELUM memanggil pinger, `consecutiveFailures` tetap nol — jadi
  ///  `locationWarning` juga tidak pernah menyala. Driver online sepanjang jam
  ///  sibuk, tanpa satu pun tawaran, tanpa satu pun galat di layar.
  ///
  ///  Sekarang pembuangannya hanya terjadi di `goOffline`, tempat yang memang
  ///  berarti "driver berhenti bekerja".
  /// ==========================================================================
  void _lupakanTiketLokasi() {
    _locationUrl = null;
    _locationTicket = null;
  }

  /// Kirim posisi terakhir ke layanan lokasi.
  ///
  /// ==========================================================================
  ///  KE LAYANAN GO, BUKAN KE LARAVEL
  /// ==========================================================================
  ///  Ping GPS ditangani layanan lokasi Go yang terpisah — ia menulis langsung
  ///  ke Redis dengan GEOADD. Alasannya beban: seribu driver dengan ping 4 detik
  ///  adalah 250 request per detik yang isinya hanya dua angka, dan tidak ada
  ///  satu pun fitur Laravel yang dibutuhkan untuk itu.
  ///
  ///  Alamat dan tiketnya datang dari response `/driver/online`. Aplikasi tidak
  ///  pernah menuliskan alamatnya sendiri: layanan lokasi bisa pindah host tanpa
  ///  menuntut rilis aplikasi baru.
  /// ==========================================================================
  ///
  /// ==========================================================================
  ///  KEGAGALAN TIDAK DICOBA ULANG
  /// ==========================================================================
  ///  Ping berikutnya datang beberapa detik kemudian dengan posisi yang LEBIH
  ///  BARU. Mencoba ulang yang gagal berarti mengirim posisi lama bersaing
  ///  dengan yang baru — dan yang menang bisa yang lama.
  ///
  ///  Yang dilaporkan ke layar hanya keadaan "berturut-turut gagal", lewat
  ///  [locationWarning]. Driver yang posisinya tidak pernah terkirim tidak akan
  ///  pernah mendapat order, dan itu harus dia ketahui.
  /// ==========================================================================
  Future<void> _kirimPosisi() async {
    final LatLng? titik = _lastPosition;
    final String? url = _locationUrl;
    final String? tiket = _locationTicket;

    if (titik == null || !isOnline || url == null || tiket == null) {
      return;
    }

    final int gagalSebelumnya = _pingGagalBerurutan;

    await _pinger.send(
      url: url,
      ticket: tiket,
      lat: titik.latitude,
      lng: titik.longitude,
    );

    if (_disposed) {
      return;
    }

    _pingSukses = _pinger.sent;
    _pingGagalBerurutan = _pinger.consecutiveFailures;

    /*
     * `notifyListeners` HANYA saat ambang peringatannya berubah.
     *
     * Ping berjalan setiap beberapa detik. Memberi tahu listener setiap kali
     * berarti seluruh dasbor dibangun ulang setiap ping — termasuk peta dan
     * kartu tawaran — untuk perubahan yang biasanya tidak terlihat.
     */
    final bool sebelum = gagalSebelumnya >= _ambangPeringatanPing;
    final bool sekarang = _pingGagalBerurutan >= _ambangPeringatanPing;

    if (sebelum != sekarang) {
      notifyListeners();
    }
  }

  /// Laporan dari isolate foreground service.
  ///
  /// ==========================================================================
  ///  ATURAN notifyListeners YANG SAMA SEPERTI JALUR APLIKASI
  /// ==========================================================================
  ///  Laporan datang setiap interval ping — beberapa detik sekali, sepanjang
  ///  shift. Memberi tahu listener setiap kali berarti seluruh dasbor dibangun
  ///  ulang setiap ping, termasuk peta dan kartu tawaran.
  ///
  ///  Jadi hanya dua hal yang memicunya: ambang peringatan yang berbalik, dan
  ///  posisi yang benar-benar berpindah. Selebihnya angkanya diperbarui diam-diam
  ///  dan dibaca saat layar dibangun karena alasan lain.
  /// ==========================================================================
  void _terimaLaporanLokasi(LocationReport laporan) {
    if (_disposed) {
      return;
    }

    final bool sebelum = _pingGagalBerurutan >= _ambangPeringatanPing;

    _pingSukses = laporan.sent;
    _pingGagalBerurutan = laporan.consecutiveFailures;

    final bool sekarang = _pingGagalBerurutan >= _ambangPeringatanPing;

    bool perluGambarUlang = sebelum != sekarang;

    final double? lat = laporan.lat;
    final double? lng = laporan.lng;

    if (lat != null && lng != null) {
      final LatLng titik = LatLng(lat, lng);

      // Peta di dasbor mengikuti posisi ini. Perbandingannya dengan posisi lama
      // supaya driver yang berhenti — di lampu merah, menunggu penumpang — tidak
      // memicu pembangunan ulang peta setiap beberapa detik.
      if (_lastPosition?.latitude != titik.latitude ||
          _lastPosition?.longitude != titik.longitude) {
        _lastPosition = titik;
        perluGambarUlang = true;
      }
    }

    if (perluGambarUlang) {
      notifyListeners();
    }
  }

  void _resetHitunganPing() {
    _pinger.reset();
    _pingSukses = 0;
    _pingGagalBerurutan = 0;
  }

  // ---------------------------------------------------------------------------
  //  Penjadwalan
  // ---------------------------------------------------------------------------

  void _jadwalkanStatus() {
    _pollStatus?.cancel();

    if (_disposed) {
      return;
    }

    // 20 detik. Yang berubah di sini adalah saldo dan ringkasan hari ini —
    // keduanya tidak menuntut kecepatan. Yang butuh cepat adalah tawaran dan
    // order berjalan, dan keduanya punya jadwal sendiri.
    _pollStatus = Timer.periodic(const Duration(seconds: 20), (Timer _) {
      refresh();
    });
  }

  void _jadwalkanTawaran() {
    _pollOffers?.cancel();

    if (_disposed) {
      return;
    }

    /*
     * 5 detik saat menganggur.
     *
     * Ini JARING PENGAMAN, bukan jalur utama: tawaran seharusnya sampai lewat
     * push notification dan Centrifugo. Keduanya belum terpasang, jadi untuk
     * sekarang inilah satu-satunya jalur — dan 5 detik adalah kompromi antara
     * tawaran yang terlihat cukup cepat dan beban yang masih wajar.
     *
     * Begitu realtime hidup, interval ini dinaikkan ke 30 detik dan tetap ada
     * sebagai cadangan. Yang tidak boleh: menghapusnya sepenuhnya, karena
     * sebagian jaringan operator memblokir koneksi WebSocket panjang.
     */
    _pollOffers = Timer.periodic(const Duration(seconds: 5), (Timer _) {
      refreshOffers();
    });
  }
}
