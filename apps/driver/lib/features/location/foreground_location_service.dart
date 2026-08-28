import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'location_background_service.dart';

/// Kunci penyimpanan yang dibagi antara isolate layar dan isolate service.
///
/// ============================================================================
///  HANYA int, double, String, DAN bool YANG BISA DISIMPAN
/// ============================================================================
///  `FlutterForegroundTask.saveData` menyimpan lewat SharedPreferences dan
///  MENGABAIKAN tipe lain — dia mengembalikan false, bukan melempar.
///
///  Karena itu daftar layanan disimpan sebagai satu String yang dipisah koma,
///  bukan `List<String>`. Menyimpannya sebagai list akan gagal tanpa suara, dan
///  gejalanya muncul jauh di ujung: layanan lokasi menerima ping tanpa daftar
///  layanan, jadi driver tercatat tersedia untuk SELURUH layanan di tiketnya —
///  termasuk yang sudah dia matikan sendiri.
/// ============================================================================
class _Kunci {
  static const String url = 'antaride.location.url';
  static const String ticket = 'antaride.location.ticket';
  static const String services = 'antaride.location.services';
}

/// Foreground service Android untuk pengiriman posisi driver.
///
/// ============================================================================
///  PING PINDAH SEPENUHNYA KE ISOLATE SERVICE, TIDAK DIBAGI DUA
/// ============================================================================
///  Yang menggoda: biarkan timer di aplikasi tetap mengirim saat aplikasi
///  terlihat, dan service hanya mengambil alih saat aplikasi di latar belakang.
///
///  Yang terjadi kalau begitu: dua pengirim untuk satu driver, keduanya membaca
///  GPS sendiri, dan keduanya menulis ke Redis. Posisi yang menang jadi
///  bergantung pada urutan kedatangan — dan yang lebih lama bisa menang. Selain
///  itu GPS terbaca dua kali sesering yang perlu, yang dibayar baterai driver.
///
///  Jadi begitu service jalan, `DriverController` membatalkan timer-nya. Satu
///  pengirim, satu sumber posisi.
/// ============================================================================
///
/// ============================================================================
///  TIKET DISIMPAN DI SharedPreferences, DAN ITU DISENGAJA
/// ============================================================================
///  Isolate service tidak punya akses ke `AntarideServices` maupun ke
///  `TokenStore`. Satu-satunya jalan menitipkan alamat dan tiket kepadanya
///  adalah penyimpanan bersama.
///
///  Yang dititipkan sengaja BUKAN token Sanctum, melainkan tiket lokasi: haknya
///  hanya "catat posisi driver ini", masa berlakunya terbatas, dan dia tidak
///  bisa dipakai membaca data penumpang, memindahkan saldo, atau apa pun yang
///  lain. Kalau isi SharedPreferences terbaca aplikasi lain di perangkat yang
///  sudah di-root, yang bocor adalah kemampuan memalsukan posisi satu driver —
///  bukan seluruh akunnya.
///
///  Dibuang di [stop]. Tiket yang tertinggal setelah driver offline akan dipakai
///  service yang di-restart sistem, dan driver akan tercatat tersedia padahal
///  dia sudah pulang.
/// ============================================================================
class ForegroundLocationService extends LocationBackgroundService {
  ForegroundLocationService();

  LocationReportCallback? _laporan;
  bool _siap = false;

  /// Hanya Android.
  ///
  /// iOS punya background location, tapi bentuknya berbeda sama sekali — tidak
  /// ada foreground service, yang ada `UIBackgroundModes` beserta batasan
  /// waktunya sendiri. Menyamakan keduanya di satu implementasi berarti dua
  /// perilaku yang tidak pernah diuji bersamaan; iOS ditangani terpisah nanti.
  ///
  /// Web selalu false: method channel-nya tidak ada, dan pemanggilannya melempar
  /// `MissingPluginException` — sementara aplikasi driver dijalankan di Chrome
  /// untuk pengembangan sehari-hari.
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
    if (!supported) {
      return false;
    }

    /*
     * ======================================================================
     *  IZIN NOTIFIKASI DIMINTA DULU, DAN KEGAGALANNYA MEMBATALKAN SELURUHNYA
     * ======================================================================
     *  Android 13+ menuntut POST_NOTIFICATIONS sebagai izin runtime. Foreground
     *  service WAJIB punya notifikasi yang terlihat — jadi tanpa izin itu,
     *  service-nya tidak bisa dimulai sama sekali.
     *
     *  Yang penting: kegagalannya dikembalikan sebagai false, bukan ditelan.
     *  `DriverController` yang memutuskan apa artinya — dan yang dia lakukan
     *  adalah jatuh ke timer di dalam aplikasi lalu memberi tahu driver bahwa
     *  posisinya hanya terkirim selama aplikasi terbuka.
     *
     *  Menelannya berarti driver mengira dia bisa mengunci HP-nya.
     * ======================================================================
     */
    final NotificationPermission izin =
        await FlutterForegroundTask.checkNotificationPermission();

    if (izin != NotificationPermission.granted) {
      final NotificationPermission hasil =
          await FlutterForegroundTask.requestNotificationPermission();

      if (hasil != NotificationPermission.granted) {
        return false;
      }
    }

    _pasangPenerima();

    // Batas bawahnya 3 detik: interval yang lebih rapat ditolak layanan lokasi
    // dengan 429 dan hanya membakar baterai. Batas atasnya 55 detik karena TTL
    // posisi di Redis 60 detik — interval yang lebih lama membuat driver
    // menghilang dari indeks di antara dua ping.
    final int detik = intervalSeconds.clamp(3, 55);

    _siapkan(detik);

    final String daftarLayanan = services.join(',');

    await FlutterForegroundTask.saveData(key: _Kunci.url, value: url);
    await FlutterForegroundTask.saveData(key: _Kunci.ticket, value: ticket);
    await FlutterForegroundTask.saveData(
      key: _Kunci.services,
      value: daftarLayanan,
    );

    /*
     * ======================================================================
     *  SERVICE YANG SUDAH JALAN DIPERBARUI, TIDAK DIMULAI LAGI
     * ======================================================================
     *  `startService` melempar `ServiceAlreadyStartedException` kalau dipanggil
     *  dua kali, dan itu keadaan yang normal terjadi: driver menekan offline
     *  lalu online lagi sebelum service sebelumnya benar-benar berhenti, atau
     *  sistem sudah me-restart service sementara aplikasi masih hidup.
     *
     *  Yang diperbarui ada dua, dan keduanya harus ikut:
     *
     *    Interval    lewat `foregroundTaskOptions` di `updateService`. Backend
     *                bisa mengubah `ping_interval_seconds` antar sesi.
     *
     *    Tiket       lewat `sendDataToTask`, karena isolate yang SUDAH jalan
     *                membaca alamat dan tiket sekali saja di `onStart`. Tanpa
     *                dorongan ini, isolate lama tetap memakai tiket lama yang
     *                sudah kadaluarsa — dan setiap ping ditolak 401 sementara
     *                notifikasinya tetap menyatakan service berjalan.
     * ======================================================================
     */
    if (await FlutterForegroundTask.isRunningService) {
      final ServiceRequestResult pembaruan =
          await FlutterForegroundTask.updateService(
            foregroundTaskOptions: _opsi(detik),
            notificationTitle: _judulNotifikasi,
            notificationText: 'Menyiapkan pengiriman posisi…',
          );

      FlutterForegroundTask.sendDataToTask(<String, dynamic>{
        'url': url,
        'ticket': ticket,
        'services': daftarLayanan,
      });

      return pembaruan is ServiceRequestSuccess;
    }

    final ServiceRequestResult hasil = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: <ForegroundServiceTypes>[ForegroundServiceTypes.location],
      notificationTitle: _judulNotifikasi,
      notificationText: 'Menyiapkan pengiriman posisi…',
      callback: mulaiTugasLokasiDriver,
    );

    return hasil is ServiceRequestSuccess;
  }

  @override
  Future<void> stop() async {
    if (!supported) {
      return;
    }

    // Tiket dibuang LEBIH DULU, sebelum service dihentikan.
    //
    // Kalau urutannya dibalik dan penghentiannya gagal, service tetap berjalan
    // dengan tiket yang masih sah — dan driver yang sudah offline tetap tercatat
    // tersedia.
    await FlutterForegroundTask.removeData(key: _Kunci.ticket);
    await FlutterForegroundTask.removeData(key: _Kunci.url);
    await FlutterForegroundTask.removeData(key: _Kunci.services);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ---------------------------------------------------------------------------

  void _pasangPenerima() {
    if (_penerimaTerpasang) {
      return;
    }

    _penerimaTerpasang = true;

    // Port komunikasi antar isolate. Tanpa ini, `sendDataToMain` di isolate
    // service tidak punya tujuan — dan laporannya hilang tanpa galat, sehingga
    // peringatan "posisi tidak terkirim" tidak akan pernah menyala.
    FlutterForegroundTask.initCommunicationPort();

    FlutterForegroundTask.addTaskDataCallback(_terimaLaporan);
  }

  bool _penerimaTerpasang = false;

  void _terimaLaporan(Object data) {
    if (data is! Map) {
      return;
    }

    final Object? terkirim = data['sent'];
    final Object? gagal = data['failures'];

    if (terkirim is! int || gagal is! int) {
      return;
    }

    final Object? lat = data['lat'];
    final Object? lng = data['lng'];

    _laporan?.call(
      LocationReport(
        sent: terkirim,
        consecutiveFailures: gagal,
        lat: lat is num ? lat.toDouble() : null,
        lng: lng is num ? lng.toDouble() : null,
      ),
    );
  }

  /// `FlutterForegroundTask.init` dipanggil sekali per proses.
  ///
  /// Pemanggilan kedua tidak melempar, tapi juga tidak berguna: opsi yang
  /// tersimpan hanya dibaca `startService`. Untuk service yang sudah berjalan,
  /// yang mengubah intervalnya adalah `updateService` — lihat [start].
  void _siapkan(int detik) {
    if (_siap) {
      return;
    }

    _siap = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'antaride_driver_lokasi',
        channelName: 'Pengiriman posisi',
        channelDescription:
            'Notifikasi yang tetap terlihat selama Anda bekerja. '
            'Android mewajibkannya agar posisi Anda bisa dikirim '
            'walaupun layar mati.',

        // LOW: notifikasinya harus TERLIHAT, tapi tidak boleh berbunyi atau
        // bergetar. Driver melihatnya sepanjang shift; satu bunyi per
        // pembaruan berarti bunyi setiap sepuluh detik.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,

        // Teks notifikasinya diperbarui setiap ping. `onlyAlertOnce` yang
        // menjaga pembaruan itu tidak diperlakukan sebagai notifikasi baru.
        onlyAlertOnce: true,

        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: _opsi(detik),
    );
  }

  ForegroundTaskOptions _opsi(int detik) => ForegroundTaskOptions(
    eventAction: ForegroundTaskEventAction.repeat(detik * 1000),

    // TIDAK jalan saat perangkat menyala.
    //
    // Driver belum menyatakan dia bekerja. Service yang hidup sendiri setelah
    // HP di-restart akan mencatatnya tersedia — dan tawaran yang masuk saat dia
    // masih tidur akan hangus, yang menurunkan tingkat penerimaannya.
    autoRunOnBoot: false,
    autoRunOnMyPackageReplaced: false,

    // CPU dijaga tetap bangun. Tanpa ini, ping berhenti selama Doze — yang
    // justru keadaan normal saat HP di dudukan dengan layar mati.
    allowWakeLock: true,

    /*
     * Di-restart sistem kalau prosesnya dimatikan.
     *
     * Ini yang menuntut ACCESS_BACKGROUND_LOCATION tetap dideklarasikan:
     * foreground service yang dimulai saat aplikasi TERLIHAT boleh membaca
     * lokasi tanpa izin itu, tapi service yang di-restart sistem dimulai saat
     * aplikasi TIDAK terlihat — dan tanpa izin latar belakang, pembacaan
     * lokasinya ditolak.
     *
     * Yang terjadi kalau begitu: notifikasinya tetap tampil dan menyatakan
     * service berjalan, sementara tidak ada satu pun posisi yang terkirim.
     */
    allowAutoRestart: true,
  );

  /// Judul notifikasi service.
  ///
  /// Konstanta karena dipakai di dua jalur — `startService` dan `updateService`.
  /// Judul yang berbeda di antara keduanya akan terlihat sebagai notifikasi yang
  /// berganti sendiri saat driver online-offline-online.
  static const String _judulNotifikasi = 'Antaride Driver — sedang bekerja';

  /// Id notifikasi service.
  ///
  /// Ditetapkan, bukan dibiarkan acak: id yang berubah membuat Android
  /// menampilkan notifikasi KEDUA saat service di-restart, dan yang lama
  /// menggantung sampai aplikasi dimatikan paksa.
  static const int _serviceId = 6180;
}

// =============================================================================
//  Isolate service
// =============================================================================

/// Titik masuk isolate service.
///
/// `@pragma('vm:entry-point')` WAJIB. Tanpa itu, tree-shaking build release
/// membuang fungsi ini — dia tidak dipanggil dari kode Dart mana pun, yang
/// memanggilnya adalah sisi Android lewat nama.
///
/// Gejalanya khas dan menyesatkan: service jalan normal di debug, lalu di
/// release notifikasinya muncul tapi tidak ada satu pun ping yang terkirim.
@pragma('vm:entry-point')
void mulaiTugasLokasiDriver() {
  FlutterForegroundTask.setTaskHandler(_TugasLokasiDriver());
}

/// Pengirim posisi yang berjalan di isolate service.
///
/// ============================================================================
///  MEMBACA GPS DAN MENGIRIM POSISI TETAP DUA HAL TERPISAH
/// ============================================================================
///  Aturan yang sama seperti di `DriverController`, dan alasannya sama:
///
///    * Aliran GPS memakai filter jarak 15 meter, jadi driver yang berhenti di
///      lampu merah tidak menghasilkan pembaruan sama sekali. Itu yang menjaga
///      baterainya.
///
///    * Pengirimannya dijadwalkan `onRepeatEvent` dengan interval dari backend.
///      Kalau pengirimannya dipicu aliran GPS, driver yang berhenti akan
///      BERHENTI mengirim posisi — dan TTL 60 detik di Redis akan
///      mengeluarkannya dari indeks ketersediaan.
///
///  Jadi posisi yang sedikit lama tetap dikirim. Posisi lama jauh lebih baik
///  daripada tidak ada posisi: yang pertama membuat driver tetap dapat tawaran,
///  yang kedua membuatnya hilang.
/// ============================================================================
class _TugasLokasiDriver extends TaskHandler {
  final LocationPinger _pinger = LocationPinger();

  StreamSubscription<LatLng>? _aliran;
  LatLng? _terakhir;

  String? _url;
  String? _tiket;
  List<String> _layanan = const <String>[];

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _url = await FlutterForegroundTask.getData<String>(key: _Kunci.url);
    _tiket = await FlutterForegroundTask.getData<String>(key: _Kunci.ticket);

    final String? layanan = await FlutterForegroundTask.getData<String>(
      key: _Kunci.services,
    );

    _layanan = (layanan ?? '')
        .split(',')
        .where((String s) => s.isNotEmpty)
        .toList();

    const LocationService lokasi = LocationService();

    /*
     * Satu pembacaan langsung untuk mengisi posisi awal.
     *
     * Tanpa ini, ping pertama baru terkirim setelah driver BERGERAK 15 meter —
     * karena aliran di bawah memakai filter jarak. Driver yang online sambil
     * menunggu di satu tempat tidak akan tercatat sama sekali selama dia diam.
     */
    final LocationOutcome awal = await lokasi.current();

    if (awal is LocationReady) {
      _terakhir = awal.position;
    }

    _aliran = lokasi.watch().listen(
      (LatLng titik) {
        _terakhir = titik;
      },
      onError: (Object _) {
        // Kegagalan aliran GPS tidak menghentikan apa pun. Posisi terakhir yang
        // diketahui tetap dikirim `onRepeatEvent`.
      },
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Tidak di-await, dan pengecualiannya tidak boleh keluar dari sini.
    //
    // `onRepeatEvent` sinkron. Future yang gagal tanpa penangkap di isolate akan
    // menjadi unhandled error — dan itu mematikan isolate service, yang berarti
    // ping berhenti sementara notifikasinya tetap tampil.
    unawaited(_kirim().catchError((Object _) {}));
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _aliran?.cancel();
    _aliran = null;
  }

  /// Isolate service diberi tiket baru tanpa perlu di-restart.
  ///
  /// Dipakai saat tiket diperbarui di tengah shift. Tanpa jalur ini,
  /// pembaruannya menuntut service dimatikan dan dinyalakan lagi — dan di antara
  /// keduanya ada jeda saat posisi driver tidak terkirim.
  @override
  void onReceiveData(Object data) {
    if (data is! Map) {
      return;
    }

    final Object? url = data['url'];
    final Object? tiket = data['ticket'];

    if (url is String && url.isNotEmpty) {
      _url = url;
    }

    if (tiket is String && tiket.isNotEmpty) {
      _tiket = tiket;
    }

    // Daftar layanan ikut, karena driver bisa mematikan salah satu layanannya
    // di tengah shift. Isolate yang tetap memakai daftar lama akan mencatatnya
    // tersedia untuk layanan yang sudah dia matikan sendiri.
    final Object? layanan = data['services'];

    if (layanan is String) {
      _layanan = layanan.split(',').where((String s) => s.isNotEmpty).toList();
    }
  }

  Future<void> _kirim() async {
    final LatLng? titik = _terakhir;
    final String? url = _url;
    final String? tiket = _tiket;

    if (titik == null || url == null || tiket == null) {
      return;
    }

    await _pinger.send(
      url: url,
      ticket: tiket,
      lat: titik.latitude,
      lng: titik.longitude,
      services: _layanan,
    );

    // Dilaporkan ke isolate layar supaya peringatan "posisi tidak terkirim"
    // punya angka untuk dibaca. Lihat `LocationBackgroundService.onReport`.
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'sent': _pinger.sent,
      'failures': _pinger.consecutiveFailures,

      // Posisinya ikut supaya peta di dasbor tidak perlu membaca GPS sendiri —
      // lihat docblock `LocationReport`.
      'lat': titik.latitude,
      'lng': titik.longitude,
    });

    /*
     * Notifikasinya menyebut keadaan sebenarnya, bukan kalimat tetap.
     *
     * "Sedang bekerja" yang tidak pernah berubah tidak memberi tahu apa pun.
     * Yang berguna bagi driver adalah jawaban atas satu pertanyaan: apakah
     * posisi saya benar-benar terkirim?
     *
     * Itu satu-satunya tempat dia bisa melihatnya tanpa membuka aplikasi — dan
     * ini justru saat aplikasinya tertutup.
     */
    await FlutterForegroundTask.updateService(
      notificationText: _pinger.consecutiveFailures == 0
          ? 'Posisi terkirim ${_jam(DateTime.now())}'
          : 'Posisi belum terkirim — periksa sinyal',
    );
  }

  static String _jam(DateTime waktu) {
    final String jam = waktu.hour.toString().padLeft(2, '0');
    final String menit = waktu.minute.toString().padLeft(2, '0');

    return '$jam:$menit';
  }
}
