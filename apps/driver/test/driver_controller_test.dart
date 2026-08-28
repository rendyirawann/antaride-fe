import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_driver/features/dashboard/driver_controller.dart';
import 'package:antaride_driver/features/location/location_background_service.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
///  TIGA ATURAN YANG SALING MENGUNCI, DAN SEMUANYA SENYAP KALAU DILANGGAR
/// ============================================================================
///  1. Driver yang punya order berjalan TIDAK BOLEH menerima tawaran baru.
///     Partial unique index di database melarangnya, jadi setiap penerimaan
///     akan ditolak 409 — dan yang terlihat driver adalah tombol terima yang
///     rusak.
///
///  2. Tawaran yang sudah habis masa berlakunya harus DISARING. Kartu
///     kadaluarsa yang masih di layar akan ditekan dan ditolak backend.
///
///  3. Kunci idempotency penyelesaian order dibuat PER ORDER. Kunci yang
///     dipakai bersama antar order membuat penyelesaian order B memutar ulang
///     response order A — order B tidak pernah benar-benar ditutup, dan driver
///     terjebak tidak bisa menerima order berikutnya.
///
///  Ketiganya tidak menghasilkan galat kalau salah. Yang dihasilkannya adalah
///  driver yang online, motornya di tempat, dan tidak ada order yang masuk.
/// ============================================================================
void main() {
  late _AdapterDriver adapter;
  late DriverController driver;

  setUp(() {
    adapter = _AdapterDriver();

    final Dio dio = Dio()..httpClientAdapter = adapter;

    final ApiClient client = ApiClient(
      tokenStore: TokenStore(),
      baseUrl: 'http://127.0.0.1:8000/api/v1',
      dio: dio,
    );

    driver = DriverController(driver: DriverRepository(client));
  });

  tearDown(() => driver.dispose());

  group('Memuat status', () {
    test(
      'status dan ringkasan hari ini terurai dari response backend',
      () async {
        await driver.refresh();

        expect(driver.status, isNotNull);
        expect(driver.status!.name, isNotEmpty);
        expect(driver.status!.balance.formatted, startsWith('Rp'));
        expect(driver.status!.cashDepositMinimum, greaterThan(0));
      },
    );

    /// Kegagalan TIDAK menghapus status yang sudah tampil.
    ///
    /// Driver yang sedang mengantar melewati area tanpa sinyal secara teratur.
    /// Mengosongkan dasbor setiap kali satu request gagal berarti layarnya
    /// berkedip sepanjang perjalanan.
    test('status lama dipertahankan saat request gagal', () async {
      await driver.refresh();

      expect(driver.status, isNotNull);

      adapter.gagalkanSemua = true;

      await driver.refresh();

      expect(
        driver.status,
        isNotNull,
        reason:
            'Status dikosongkan saat request gagal. Dasbor driver akan berkedip '
            'setiap kali dia melewati area tanpa sinyal.',
      );

      expect(driver.failure, isNotNull, reason: 'Kegagalannya tetap dicatat.');
    });
  });

  group('Tawaran', () {
    test('tawaran terurai dari response backend', () async {
      adapter.online = true;

      await driver.refresh();
      await driver.refreshOffers();

      expect(driver.offers, isNotEmpty);

      final DriverOffer satu = driver.offers.first;

      expect(satu.orderUuid, isNotEmpty);
      expect(
        satu.earning.amount,
        greaterThan(0),
        reason:
            'Pendapatan Rp 0 berarti kunci `driver_earning` dibaca salah — dan '
            'itu angka pertama yang dibaca driver untuk memutuskan.',
      );
    });

    /// ========================================================================
    ///  TAWARAN KADALUARSA DISARING DI SISI APLIKASI
    /// ========================================================================
    ///  Backend sudah menyaringnya saat request dibuat, tapi tawaran bisa habis
    ///  di ANTARA dua penarikan — dan penarikannya setiap 5 detik sementara
    ///  masa berlaku tawaran hanya 15 detik.
    ///
    ///  Tanpa penyaringan di sini, kartu yang sudah mati tetap tampil sampai
    ///  penarikan berikutnya, dan driver menekan terima pada order yang sudah
    ///  pindah ke orang lain.
    /// ========================================================================
    test('tawaran yang sudah habis masa berlakunya tidak ditampilkan', () async {
      adapter.online = true;
      adapter.tawaranSudahKadaluarsa = true;

      await driver.refresh();
      await driver.refreshOffers();

      expect(
        driver.offers,
        isEmpty,
        reason:
            'Tawaran dengan expires_at di masa lalu masih ditampilkan. Driver '
            'akan menekan terima pada order yang sudah pindah.',
      );
    });

    /// ========================================================================
    ///  INI ATURAN YANG PALING MUDAH TERLEWAT
    /// ========================================================================
    ///  Driver yang punya order berjalan tidak boleh melihat tawaran sama
    ///  sekali. Partial unique index `orders_one_active_per_driver` di database
    ///  melarangnya punya dua order aktif, jadi setiap penerimaan akan ditolak.
    /// ========================================================================
    test('tawaran tidak diambil saat sudah ada order berjalan', () async {
      adapter.online = true;

      await driver.refresh();
      await driver.refreshOffers();

      expect(driver.offers, isNotEmpty);

      // Order berjalan muncul — misalnya karena driver menerima tawaran dari
      // notifikasi di perangkat lain, atau admin melakukan assign paksa.
      adapter.adaOrderBerjalan = true;

      await driver.refresh();

      expect(driver.hasActiveOrder, isTrue);

      expect(
        driver.canTakeOffers,
        isFalse,
        reason:
            'canTakeOffers masih true padahal ada order berjalan. Setiap '
            'penerimaan akan ditolak 409 oleh partial unique index.',
      );

      await driver.refreshOffers();

      expect(
        driver.offers,
        isEmpty,
        reason:
            'Tawaran masih tampil padahal ada order berjalan. Driver akan '
            'menekan terima dan mendapat penolakan tanpa penjelasan.',
      );
    });

    /// Order yang selesai membuat driver kembali menerima tawaran.
    ///
    /// Tanpa ini, `canTakeOffers` tetap false setelah order ditutup — dan driver
    /// berhenti mendapat order tanpa tahu sebabnya.
    test('setelah order berjalan hilang, tawaran diambil lagi', () async {
      adapter.online = true;
      adapter.adaOrderBerjalan = true;

      await driver.refresh();

      expect(driver.canTakeOffers, isFalse);

      adapter.adaOrderBerjalan = false;

      await driver.refresh();

      expect(
        driver.hasActiveOrder,
        isFalse,
        reason:
            'Order berjalan tidak dibuang dari state. `canTakeOffers` akan '
            'tetap false dan driver berhenti mendapat order selamanya.',
      );

      expect(driver.canTakeOffers, isTrue);
    });

    /// ========================================================================
    ///  RESPONSE SUKSES DENGAN `data: null` BERBEDA DARI REQUEST GAGAL
    /// ========================================================================
    ///  `activeOrder()` mengembalikan null pada KEDUANYA — tidak bisa dibedakan
    ///  dari nilainya. Yang membedakan adalah keberhasilan request-nya, dan
    ///  hanya response sukses yang boleh menghapus order dari layar.
    ///
    ///  Kalau tidak dibedakan, satu request gagal saat melewati area tanpa
    ///  sinyal akan MENGHAPUS order yang sedang dikerjakan dari layar driver —
    ///  di tengah perjalanan.
    /// ========================================================================
    test('order berjalan tidak dihapus oleh request yang gagal', () async {
      adapter.online = true;
      adapter.adaOrderBerjalan = true;

      await driver.refresh();

      expect(driver.hasActiveOrder, isTrue);

      adapter.gagalkanSemua = true;

      await driver.refresh();

      expect(
        driver.hasActiveOrder,
        isTrue,
        reason:
            'Order berjalan hilang karena request gagal. Driver di tengah '
            'perjalanan akan kehilangan layar ordernya saat melewati area tanpa '
            'sinyal.',
      );
    });

    /// Tawaran yang gagal diterima dibuang dari daftar, apa pun sebabnya.
    ///
    /// Kasus paling sering: 409 karena driver lain lebih cepat. Order itu sudah
    /// tidak ada, dan membiarkan kartunya di layar berarti driver menekan terima
    /// berulang pada order yang sudah pindah.
    test('tawaran yang gagal diterima dibuang dari daftar', () async {
      adapter.online = true;

      await driver.refresh();
      await driver.refreshOffers();

      final String uuid = driver.offers.first.orderUuid;

      adapter.gagalkanAccept = true;

      final bool berhasil = await driver.accept(uuid);

      expect(berhasil, isFalse);

      expect(
        driver.offers.where((DriverOffer o) => o.orderUuid == uuid),
        isEmpty,
        reason:
            'Tawaran yang ditolak masih di daftar. Driver akan menekan terima '
            'berulang pada order yang sudah diambil orang lain.',
      );
    });
  });

  group('Kunci idempotency penyelesaian order', () {
    /// ========================================================================
    ///  DIPAKAI ULANG UNTUK ORDER YANG SAMA
    /// ========================================================================
    ///  Endpoint `complete` MEMINDAHKAN UANG: pendapatan masuk ke dompet driver,
    ///  komisi dipotong, tahanan dana penumpang dilepas.
    ///
    ///  Kunci baru setiap percobaan berarti pembagian uangnya dijalankan dua
    ///  kali. Dan ini endpoint yang paling mungkin dicoba ulang di seluruh
    ///  aplikasi: driver menekan selesai di gang tanpa sinyal, tidak melihat
    ///  respons, lalu menekan lagi.
    /// ========================================================================
    test('percobaan yang gagal memakai kunci yang sama', () async {
      adapter.online = true;
      adapter.adaOrderBerjalan = true;

      await driver.refresh();

      expect(driver.hasActiveOrder, isTrue);

      adapter.gagalkanComplete = 2;

      await driver.complete();
      await driver.complete();
      await driver.complete();

      expect(adapter.kunciComplete, hasLength(3));

      expect(
        adapter.kunciComplete.toSet(),
        hasLength(1),
        reason:
            'Tiga kunci berbeda berarti pembagian uang dijalankan tiga kali. '
            'Kunci HARUS dipakai ulang saat mencoba lagi.\n'
            'Kunci yang terkirim: ${adapter.kunciComplete}',
      );
    });

    test('header Idempotency-Key benar-benar terkirim', () async {
      adapter.online = true;
      adapter.adaOrderBerjalan = true;

      await driver.refresh();
      await driver.complete();

      expect(adapter.kunciComplete, hasLength(1));
      expect(adapter.kunciComplete.single, hasLength(36));
    });
  });

  // ===========================================================================
  //  Pengiriman posisi di latar belakang
  // ===========================================================================
  //
  //  Yang diuji di sini BUKAN foreground service-nya — itu berjalan di isolate
  //  terpisah dan tidak bisa disentuh dari test. Yang diuji adalah KEPUTUSAN
  //  `DriverController`: kapan service dipakai, kapan dia jatuh ke timer di dalam
  //  aplikasi, dan bagaimana hitungan ping dari service sampai ke peringatan di
  //  layar.
  //
  //  Ketiganya gagal tanpa suara kalau salah, dan yang menanggungnya driver yang
  //  online sepanjang jam sibuk tanpa satu pun order masuk.
  //
  group('Pengiriman posisi latar belakang', () {
    late _ServiceLatarPalsu latar;
    late DriverController driverLatar;

    setUp(() {
      latar = _ServiceLatarPalsu();

      final Dio dio = Dio()..httpClientAdapter = adapter;

      final ApiClient client = ApiClient(
        tokenStore: TokenStore(),
        baseUrl: 'http://127.0.0.1:8000/api/v1',
        dio: dio,
      );

      driverLatar = DriverController(
        driver: DriverRepository(client),
        location: const _LokasiPalsu(),
        background: latar,
      );
    });

    tearDown(() => driverLatar.dispose());

    test('service latar dimulai dengan tiket dari goOnline', () async {
      adapter.online = true;

      expect(await driverLatar.goOnline(), isTrue);

      expect(latar.mulai, hasLength(1));

      expect(
        latar.mulai.first.ticket,
        _tiketLokasi,
        reason:
            'Tiket yang dikirim ke service bukan yang datang dari `goOnline`. '
            'Tiket yang salah ditolak layanan lokasi 401 di setiap ping, '
            'sementara notifikasinya tetap menyatakan service berjalan.',
      );

      expect(latar.mulai.first.url, _urlLokasi);

      expect(
        latar.mulai.first.intervalSeconds,
        7,
        reason:
            'Interval tidak diambil dari `ping_interval_seconds` backend. '
            'Terlalu jarang berarti driver keluar dari indeks ketersediaan di '
            'antara dua ping; terlalu sering berarti baterainya habis.',
      );
    });

    /// ========================================================================
    ///  DUA PENGIRIM UNTUK SATU DRIVER ADALAH BUG, BUKAN REDUNDANSI
    /// ========================================================================
    ///  Kalau service jalan DAN timer di aplikasi tetap hidup, keduanya membaca
    ///  GPS sendiri dan keduanya menulis posisi. Yang menang jadi bergantung
    ///  pada urutan kedatangan — dan yang lebih lama bisa menang.
    ///
    ///  Yang diperiksa: isolate layar tidak berlangganan GPS sama sekali saat
    ///  service jalan.
    /// ========================================================================
    test('isolate layar tidak membaca GPS saat service jalan', () async {
      adapter.online = true;

      await driverLatar.goOnline();

      expect(
        _LokasiPalsu.jumlahWatch,
        0,
        reason:
            'Aliran GPS di isolate layar tetap dibuka padahal service jalan. '
            'Chip GPS dibangunkan dua kali sesering yang perlu, sepanjang shift.',
      );
    });

    test('service latar dihentikan saat offline', () async {
      adapter.online = true;

      await driverLatar.goOnline();
      await driverLatar.goOffline();

      expect(latar.jumlahStop, greaterThanOrEqualTo(1));
    });

    /// Service dihentikan walaupun controller ini tidak pernah memulainya.
    ///
    /// Android me-restart foreground service sendiri kalau prosesnya pernah
    /// dimatikan. Di proses yang baru, controller tidak tahu apa pun soal service
    /// itu — dan kalau penghentiannya bergantung pada catatan lokalnya, service
    /// lama tetap hidup dan tetap mengirim posisi setelah driver offline.
    test(
      'service dihentikan walaupun tidak pernah dimulai di sesi ini',
      () async {
        await driverLatar.goOffline();

        expect(
          latar.jumlahStop,
          greaterThanOrEqualTo(1),
          reason:
              'Penghentian dilewati karena controller tidak mencatat pernah '
              'memulainya. Service dari sesi sebelumnya akan tetap mengirim '
              'posisi driver yang sudah pulang.',
        );
      },
    );

    /// ========================================================================
    ///  IZIN NOTIFIKASI DITOLAK: DRIVER HARUS DIBERI TAHU, BUKAN DIBIARKAN
    /// ========================================================================
    ///  Tanpa izin notifikasi, foreground service tidak bisa dimulai — Android
    ///  mewajibkan notifikasinya terlihat. Yang tersisa adalah timer di dalam
    ///  aplikasi, yang berhenti begitu driver mengunci HP-nya.
    ///
    ///  Driver yang tidak diberi tahu akan mengunci HP-nya dan menunggu order
    ///  yang tidak akan pernah datang.
    /// ========================================================================
    test('service yang gagal dimulai memicu pemberitahuan', () async {
      adapter.online = true;
      latar.gagalkanMulai = true;

      await driverLatar.goOnline();

      expect(
        driverLatar.onlyPingsWhileOpen,
        isTrue,
        reason:
            'Driver tidak diberi tahu bahwa posisinya hanya terkirim selama '
            'aplikasi terbuka. Dia akan mengunci HP-nya dan berhenti mendapat '
            'tawaran tanpa tahu sebabnya.',
      );
    });

    test('service yang berhasil dimulai tidak memicu pemberitahuan', () async {
      adapter.online = true;

      await driverLatar.goOnline();

      expect(driverLatar.onlyPingsWhileOpen, isFalse);
    });

    /// ========================================================================
    ///  LAPORAN DARI ISOLATE HARUS SAMPAI KE PERINGATAN DI LAYAR
    /// ========================================================================
    ///  Yang mengirim ping adalah isolate service. `locationWarning` di layar
    ///  tidak punya cara mengetahui hasilnya kecuali diberi tahu.
    ///
    ///  Kalau jalurnya tidak tersambung, peringatan "posisi tidak terkirim" tidak
    ///  akan pernah menyala — dan itu tepat peringatan yang paling perlu ada.
    /// ========================================================================
    test('laporan gagal berturut-turut menyalakan peringatan', () async {
      adapter.online = true;

      await driverLatar.goOnline();

      expect(driverLatar.locationWarning, isNull);

      // Dua kali gagal belum cukup: satu ping gagal terjadi setiap kali driver
      // melewati area tanpa sinyal, dan peringatan yang menyala di setiap
      // perempatan berhenti dibaca.
      latar.laporkan(const LocationReport(sent: 5, consecutiveFailures: 2));

      expect(driverLatar.locationWarning, isNull);

      latar.laporkan(const LocationReport(sent: 5, consecutiveFailures: 3));

      expect(
        driverLatar.locationWarning,
        isNotNull,
        reason:
            'Laporan dari isolate service tidak sampai ke `locationWarning`. '
            'Peringatan posisi tidak terkirim tidak akan pernah menyala.',
      );
    });

    /// Pesannya berbeda antara "belum pernah berhasil" dan "sempat berhasil".
    ///
    /// Yang pertama biasanya izin lokasi atau konfigurasi, yang kedua jaringan.
    /// Tindakan driver berbeda, jadi pesannya harus berbeda.
    test(
      'pesan peringatan membedakan belum pernah dari sempat berhasil',
      () async {
        adapter.online = true;

        await driverLatar.goOnline();

        latar.laporkan(const LocationReport(sent: 0, consecutiveFailures: 4));

        expect(driverLatar.locationWarning, contains('belum pernah'));

        latar.laporkan(const LocationReport(sent: 9, consecutiveFailures: 4));

        expect(driverLatar.locationWarning, isNot(contains('belum pernah')));
      },
    );

    /// Peringatan hilang setelah satu ping berhasil.
    ///
    /// Yang dijaga: peringatan yang menggantung setelah sinyal pulih. Driver akan
    /// menyimpulkan aplikasinya rusak, lalu me-restart-nya di tengah order.
    test('peringatan hilang setelah ping berhasil lagi', () async {
      adapter.online = true;

      await driverLatar.goOnline();

      latar.laporkan(const LocationReport(sent: 2, consecutiveFailures: 5));

      expect(driverLatar.locationWarning, isNotNull);

      latar.laporkan(const LocationReport(sent: 3, consecutiveFailures: 0));

      expect(driverLatar.locationWarning, isNull);
    });

    /// Posisi untuk peta datang dari laporan service.
    ///
    /// Itu yang membuat isolate layar tidak perlu membaca GPS sendiri — lihat
    /// docblock `LocationReport`.
    test('posisi di laporan memperbarui posisi terakhir', () async {
      adapter.online = true;

      await driverLatar.goOnline();

      latar.laporkan(
        const LocationReport(
          sent: 1,
          consecutiveFailures: 0,
          lat: 3.61,
          lng: 98.69,
        ),
      );

      expect(driverLatar.lastPosition?.latitude, closeTo(3.61, 0.0001));
      expect(driverLatar.lastPosition?.longitude, closeTo(98.69, 0.0001));
    });
  });

  // ===========================================================================
  //  Tiket lokasi
  // ===========================================================================
  //
  //  Dua bug nyata pernah hidup di jalur ini, dan keduanya sama sekali senyap:
  //
  //    1. `_hentikanGps` membuang tiket yang baru diterima, karena `_mulaiGps`
  //       memanggilnya lebih dulu untuk membersihkan sesi sebelumnya. Tidak ada
  //       satu pun posisi yang terkirim, selamanya.
  //
  //    2. Aplikasi yang di-restart sementara sesinya masih terbuka tidak punya
  //       tiket dan tidak punya cara mendapatkannya, karena tiket dulu hanya
  //       dikirim `POST /driver/online`.
  //
  //  Keduanya tidak menghasilkan galat. `_kirimPosisi` keluar SEBELUM memanggil
  //  pinger, jadi `consecutiveFailures` tetap nol dan `locationWarning` juga
  //  tidak pernah menyala. Yang terlihat driver: online sepanjang jam sibuk,
  //  tanpa satu pun tawaran.
  //
  group('Tiket lokasi', () {
    late DriverController driver;

    setUp(() {
      /*
       * Controller-nya sendiri, dan sengaja memakai JALUR CADANGAN.
       *
       * `didukung = false` berarti tidak ada foreground service — yang mengirim
       * posisi adalah timer di dalam aplikasi. Itu jalur yang dipakai web dan
       * iOS, dan justru jalur tempat bug tiket dulu hidup tanpa terlihat.
       *
       * `LocationService` palsu wajib: yang sungguhan memanggil Geolocator lewat
       * platform channel, dan channel itu menuntut binding Flutter yang tidak ada
       * di test non-widget.
       */
      final _ServiceLatarPalsu latar = _ServiceLatarPalsu()..didukung = false;

      final ApiClient client = ApiClient(
        tokenStore: TokenStore(),
        baseUrl: 'http://127.0.0.1:8000/api/v1',
        dio: Dio()..httpClientAdapter = adapter,
      );

      driver = DriverController(
        driver: DriverRepository(client),
        location: const _LokasiPalsu(),
        background: latar,
      );
    });

    tearDown(() => driver.dispose());

    test('tiket dari goOnline tidak hilang saat GPS dimulai', () async {
      adapter.online = true;

      expect(await driver.goOnline(), isTrue);

      expect(
        driver.hasLocationTicket,
        isTrue,
        reason:
            'Tiket hilang di antara `goOnline` dan `_mulaiGps`. '
            '`_hentikanGps` membuangnya, dan `_mulaiGps` memanggil '
            '`_hentikanGps` lebih dulu — jadi setiap sesi online kehilangan '
            'tiketnya tepat setelah menerimanya. Tidak ada satu pun posisi yang '
            'terkirim, dan tidak ada galat apa pun.',
      );
    });

    /// Aplikasi yang di-restail mengambil tiket dari `GET /driver/status`.
    ///
    /// `start()` adalah yang dijalankan saat aplikasi dibuka. Driver yang sesinya
    /// masih terbuka tidak melewati `goOnline` sama sekali.
    test('aplikasi yang dibuka ulang mengambil tiket dari status', () async {
      adapter.online = true;

      await driver.start();

      expect(driver.isOnline, isTrue);

      expect(
        driver.hasLocationTicket,
        isTrue,
        reason:
            'Aplikasi yang dibuka ulang tidak mengambil tiket dari '
            '`GET /driver/status`. Driver akan tetap terlihat online tanpa satu '
            'pun posisi terkirim, sampai dia menekan offline lalu online — dan '
            'itu memotong catatan jam kerjanya.',
      );
    });

    /// Driver yang OFFLINE tidak menyimpan tiket.
    ///
    /// Tiket untuk driver yang tidak bekerja adalah kemampuan mencatat posisinya
    /// sebagai tersedia. Ping yang terkirim setelah dia pulang membuatnya
    /// mendapat tawaran.
    test('driver offline tidak menyimpan tiket', () async {
      adapter.online = false;

      await driver.start();

      expect(driver.hasLocationTicket, isFalse);
    });

    test('tiket dibuang saat driver offline', () async {
      adapter.online = true;

      await driver.goOnline();

      expect(driver.hasLocationTicket, isTrue);

      adapter.online = false;

      await driver.goOffline();

      expect(
        driver.hasLocationTicket,
        isFalse,
        reason:
            'Tiket masih tersimpan setelah driver offline. Tiket berlaku sampai '
            '12 jam, dan ping yang terlewat akan mencatat posisinya sebagai '
            'tersedia setelah dia pulang.',
      );
    });

    /// Backend tanpa tiket di `status` tidak menjatuhkan apa pun.
    ///
    /// Yang dijaga: aplikasi baru yang dipakai dengan backend versi lama. Dia
    /// harus tetap bisa online lewat `goOnline` — bukan gagal memuat status.
    test('status tanpa tiket tidak menjatuhkan pemuatan', () async {
      adapter.online = true;
      adapter.statusMembawaTiket = false;

      await driver.start();

      expect(driver.status, isNotNull);
      expect(driver.isOnline, isTrue);
      expect(driver.hasLocationTicket, isFalse);

      // Dan `goOnline` tetap bisa memberinya tiket.
      adapter.statusMembawaTiket = true;

      await driver.goOnline();

      expect(driver.hasLocationTicket, isTrue);
    });
  });
}

// ---------------------------------------------------------------------------

/// Adapter Dio yang membalas dari fixture backend dan mencatat header.
class _AdapterDriver implements HttpClientAdapter {
  bool online = false;
  bool adaOrderBerjalan = false;
  bool tawaranSudahKadaluarsa = false;
  bool gagalkanSemua = false;
  bool gagalkanAccept = false;
  int gagalkanComplete = 0;

  final List<String> kunciComplete = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (gagalkanSemua) {
      return _gagal(503, 'SERVICE_UNAVAILABLE', 'Server sedang sibuk.');
    }

    final String path = options.path;

    if (path.endsWith('/driver/status')) {
      return _sukses(_statusDriver());
    }

    if (path.endsWith('/driver/online')) {
      return _sukses(<String, dynamic>{
        'session_started_at': '2026-08-28T08:00:00+07:00',

        // Tujuh, bukan sepuluh: angka yang berbeda dari bawaan
        // `GoOnlineResult.pingIntervalSeconds` (10). Kalau test memakai angka
        // yang sama dengan bawaannya, dia akan lulus walaupun nilainya tidak
        // pernah benar-benar dibaca dari response.
        'ping_interval_seconds': 7,

        'location': <String, dynamic>{
          'url': _urlLokasi,
          'ticket': _tiketLokasi,
        },
      });
    }

    if (path.endsWith('/driver/offline')) {
      return _sukses(<String, dynamic>{'session': null});
    }

    if (path.endsWith('/driver/orders/active')) {
      return _sukses(
        adaOrderBerjalan ? _fixture('driver_active_order.json') : null,
      );
    }

    if (path.endsWith('/driver/orders/offers')) {
      return _sukses(_tawaran());
    }

    if (path.contains('/accept')) {
      if (gagalkanAccept) {
        // 409 — yang benar-benar dikirim backend saat driver lain lebih cepat.
        return _gagal(
          409,
          'ORDER_ALREADY_TAKEN',
          'Order sudah diambil driver lain.',
        );
      }

      return _sukses(_fixture('driver_active_order.json'));
    }

    if (path.contains('/complete')) {
      kunciComplete.add((options.headers['Idempotency-Key'] ?? '').toString());

      if (gagalkanComplete > 0) {
        gagalkanComplete--;

        return _gagal(503, 'SERVICE_UNAVAILABLE', 'Server sedang sibuk.');
      }

      return _sukses(_fixture('driver_active_order.json'));
    }

    return _gagal(404, 'NOT_FOUND', 'Endpoint tidak dikenali: $path');
  }

  /// Apakah response `status` ikut membawa tiket lokasi.
  ///
  /// Backend mengirimnya untuk driver yang sesinya masih terbuka — itu satu-satunya
  /// jalan aplikasi yang baru di-restart bisa melanjutkan pengiriman posisi tanpa
  /// menutup sesi driver. Dibuat bisa dimatikan supaya perilaku aplikasi terhadap
  /// backend versi lama juga bisa diuji.
  bool statusMembawaTiket = true;

  /// Status driver, dengan `online` mengikuti keadaan test.
  ///
  /// Fixture-nya diambil dari backend dan hanya satu field yang ditimpa —
  /// bentuknya tetap yang sungguhan.
  Map<String, dynamic> _statusDriver() {
    final Map<String, dynamic> status =
        _fixture('driver_status.json') as Map<String, dynamic>;

    status['online'] = online;

    // Tiket lokasi hanya ada saat sesinya terbuka — sama seperti backend.
    // Tiket untuk driver yang tidak bekerja berarti posisinya bisa tercatat
    // tersedia setelah dia pulang.
    status['location'] = online && statusMembawaTiket
        ? <String, dynamic>{'url': _urlLokasi, 'ticket': _tiketLokasi}
        : null;

    return status;
  }

  /// Tawaran, dengan masa berlaku disegarkan atau sengaja dibuat lampau.
  ///
  /// ==========================================================================
  ///  FIXTURE MEMASOK BENTUKNYA, TEST MEMASOK KESEGARANNYA
  /// ==========================================================================
  ///  `expires_at` di fixture adalah cap waktu saat fixture itu dihasilkan.
  ///  Masa berlaku tawaran hanya 15 detik, jadi memakainya apa adanya membuat
  ///  test ini lulus tepat setelah fixture dibuat dan gagal setelah itu.
  ///
  ///  Test yang hasilnya bergantung pada JAM lebih buruk daripada tidak ada
  ///  test: dia akan gagal di CI beberapa hari kemudian, dengan pesan yang
  ///  menunjuk ke penyaringan tawaran padahal penyebabnya masa berlaku fixture.
  /// ==========================================================================
  List<dynamic> _tawaran() {
    final List<dynamic> daftar =
        _fixture('driver_offers.json') as List<dynamic>;

    final DateTime kapan = tawaranSudahKadaluarsa
        ? DateTime.now().subtract(const Duration(seconds: 30))
        : DateTime.now().add(const Duration(seconds: 15));

    for (final dynamic satu in daftar) {
      (satu as Map<String, dynamic>)['expires_at'] = kapan
          .toUtc()
          .toIso8601String();
    }

    return daftar;
  }

  ResponseBody _sukses(Object? data, {int status = 200}) {
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'success': true, 'data': data}),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  ResponseBody _gagal(int status, String code, String message) {
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'success': false,
        'error': <String, dynamic>{'code': code, 'message': message},
      }),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Fixture dihasilkan backend — lihat `ContractFixtureTest` di `antaride-be`.
///
/// Diurai ulang setiap pemanggilan, bukan di-cache: `_statusDriver` dan
/// `_tawaran` mengubah satu field, dan map yang dibagi antar test akan membawa
/// perubahan itu ke test berikutnya.
Object _fixture(String nama) {
  final File berkas = File('../../test_fixtures/$nama');

  if (!berkas.existsSync()) {
    fail(
      'Fixture "$nama" tidak ada.\n\n'
      'Jalankan:\n'
      '  cd antaride-be && php artisan test tests/Feature/Api/ContractFixtureTest.php\n',
    );
  }

  return jsonDecode(berkas.readAsStringSync()) as Object;
}

// =============================================================================
//  Bantu untuk grup pengiriman posisi latar belakang
// =============================================================================

const String _urlLokasi = 'http://127.0.0.1:8200/v1/driver/location';
const String _tiketLokasi = 'tiket-lokasi-uji.abc123';

/// Satu pemanggilan `start` yang tercatat.
class _PermintaanMulai {
  const _PermintaanMulai({
    required this.url,
    required this.ticket,
    required this.intervalSeconds,
    required this.services,
  });

  final String url;
  final String ticket;
  final int intervalSeconds;
  final List<String> services;
}

/// Foreground service palsu.
///
/// Menyatakan diri DIDUKUNG, yang tidak mungkin terjadi dengan implementasi
/// sungguhan di test — `defaultTargetPlatform` di VM test bukan Android. Itu
/// justru alasan seam-nya ada: tanpa dia, seluruh jalur foreground service tidak
/// pernah dijalankan satu kali pun oleh test mana pun.
class _ServiceLatarPalsu extends LocationBackgroundService {
  /// Bisa dimatikan untuk menguji jalur cadangan (timer di dalam aplikasi).
  ///
  /// Itu jalur yang dipakai web dan iOS — dan jalur tempat bug tiket dulu hidup.
  bool didukung = true;

  bool gagalkanMulai = false;

  final List<_PermintaanMulai> mulai = <_PermintaanMulai>[];

  int jumlahStop = 0;

  LocationReportCallback? _laporan;

  @override
  bool get supported => didukung;

  @override
  void onReport(LocationReportCallback callback) {
    _laporan = callback;
  }

  @override
  Future<bool> start({
    required String url,
    required String ticket,
    required int intervalSeconds,
    List<String> services = const <String>[],
  }) async {
    mulai.add(
      _PermintaanMulai(
        url: url,
        ticket: ticket,
        intervalSeconds: intervalSeconds,
        services: services,
      ),
    );

    return !gagalkanMulai;
  }

  @override
  Future<void> stop() async {
    jumlahStop++;
  }

  /// Meniru laporan dari isolate service.
  void laporkan(LocationReport laporan) => _laporan?.call(laporan);
}

/// Layanan lokasi palsu.
///
/// [jumlahWatch] yang dihitung STATIS, bukan per instans: yang diuji adalah
/// apakah isolate layar membuka aliran GPS sama sekali, dan controller-nya
/// membuat `LocationService`-nya sendiri kalau tidak disuntikkan.
class _LokasiPalsu extends LocationService {
  const _LokasiPalsu();

  static int jumlahWatch = 0;

  @override
  Future<LocationOutcome> current({
    Duration timeout = const Duration(seconds: 10),
  }) async => LocationReady(LatLng(3.5952, 98.6722), accuracyM: 8);

  @override
  Stream<LatLng> watch({int distanceFilterM = 15}) {
    jumlahWatch++;

    return const Stream<LatLng>.empty();
  }
}
