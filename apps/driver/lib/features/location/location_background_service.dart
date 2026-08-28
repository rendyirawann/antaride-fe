/// Pengirim posisi yang tetap bekerja saat aplikasi tidak terlihat.
///
/// ============================================================================
///  KENAPA INI PERLU ADA SAMA SEKALI
/// ============================================================================
///  Driver bekerja dengan HP di dudukan, layar mati, aplikasi di latar belakang.
///  Android menghentikan pembacaan lokasi untuk aplikasi dalam keadaan itu —
///  bukan melambatkan, tapi MENGHENTIKAN.
///
///  Akibatnya: ping berhenti, backend mengeluarkan driver dari indeks
///  ketersediaan setelah TTL 60 detik habis, dan tidak ada tawaran yang masuk.
///  Yang dilihat driver: aplikasi menyatakan dia online, motornya di tempat, dan
///  tidak ada order sepanjang jam sibuk. Tanpa satu pun galat.
///
///  Satu-satunya cara yang disetujui Android untuk terus membaca lokasi adalah
///  foreground service dengan notifikasi yang terlihat. Itu yang dibungkus di
///  sini.
/// ============================================================================
///
/// ============================================================================
///  ANTARMUKA, BUKAN LANGSUNG KE PAKETNYA — DAN ADA DUA ALASANNYA
/// ============================================================================
///  1. Foreground service hanya ada di Android. Aplikasi driver juga dijalankan
///     di Chrome untuk pengembangan sehari-hari (`melos run run:driver`), dan
///     memanggil method channel di sana melempar `MissingPluginException`.
///     Dengan antarmuka ini, platform yang tidak mendukungnya menjawab
///     [supported] false dan `DriverController` jatuh ke timer di dalam
///     aplikasi — yang cukup selama aplikasinya terlihat.
///
///  2. Task handler-nya berjalan di ISOLATE TERPISAH, dan isolate tidak bisa
///     diuji dari test biasa. Antarmuka ini yang membuat `DriverController` tetap
///     bisa diuji: test menyuntikkan implementasi palsu, dan yang diuji adalah
///     keputusannya — kapan service dimulai, kapan dihentikan, dan bagaimana
///     hitungan ping dari service sampai ke peringatan di layar.
/// ============================================================================
abstract class LocationBackgroundService {
  const LocationBackgroundService();

  /// True kalau platform ini punya foreground service.
  ///
  /// False di web, iOS, dan desktop. Pemanggil TIDAK boleh memanggil [start]
  /// kalau ini false — bukan karena akan melempar, tapi karena jawabannya
  /// sudah pasti gagal dan kegagalan itu tidak berarti apa-apa.
  bool get supported;

  /// Mulai mengirim posisi di latar belakang.
  ///
  /// [url] dan [ticket] datang dari response `/driver/status/online`. Keduanya
  /// diteruskan ke isolate service, karena isolate itu TIDAK punya akses ke
  /// `AntarideServices` maupun ke token sesi — dan memang tidak boleh punya.
  ///
  /// [services] membatasi layanan yang posisinya dicatat. Nilainya hanya bisa
  /// MEMPERSEMPIT daftar di dalam tiket; layanan lokasi menolak upaya
  /// memperluasnya.
  ///
  /// Mengembalikan false kalau service tidak bisa dimulai — izin notifikasi
  /// ditolak, atau Android menolak permintaannya. Pemanggil harus menganggap
  /// itu berarti "posisi hanya terkirim selama aplikasi terlihat", bukan
  /// "posisi terkirim".
  Future<bool> start({
    required String url,
    required String ticket,
    required int intervalSeconds,
    List<String> services = const <String>[],
  });

  /// Hentikan pengiriman dan buang notifikasinya.
  ///
  /// Aman dipanggil walaupun service-nya tidak berjalan. Itu penting: driver
  /// yang keluar dari sesi tanpa pernah online tetap melewati jalur ini, dan
  /// pengecualian di situ akan menggantung proses keluarnya.
  Future<void> stop();

  /// Dipanggil setiap kali service melaporkan hasil pengiriman.
  ///
  /// ==========================================================================
  ///  HITUNGANNYA DILAPORKAN BALIK, TIDAK DIHITUNG LAGI DI SISI LAYAR
  /// ==========================================================================
  ///  Yang benar-benar mengirim ping adalah isolate service. Layar tidak punya
  ///  cara mengetahui hasilnya kecuali diberi tahu.
  ///
  ///  Kalau layar menghitungnya sendiri — misalnya dengan timer bayangan yang
  ///  menganggap setiap interval berhasil — angkanya akan benar tepat sampai
  ///  saat pertama ada yang gagal. Dan peringatan "posisi tidak terkirim" yang
  ///  tidak pernah menyala adalah bentuk kegagalan yang paling mahal di
  ///  aplikasi ini.
  /// ==========================================================================
  void onReport(LocationReportCallback callback);
}

/// Laporan dari isolate service ke isolate layar.
typedef LocationReportCallback = void Function(LocationReport report);

/// Satu laporan pengiriman posisi dari isolate service.
///
/// ============================================================================
///  POSISINYA IKUT DILAPORKAN, DAN ITU YANG MENCEGAH GPS TERBACA DUA KALI
/// ============================================================================
///  Peta di dasbor driver menampilkan posisinya sendiri. Cara yang tampak paling
///  sederhana: isolate layar ikut berlangganan aliran GPS untuk peta itu.
///
///  Yang terjadi kalau begitu: DUA pembaca GPS untuk satu perangkat — satu di
///  isolate layar, satu di isolate service. Keduanya membangunkan chip GPS
///  sendiri, dan keduanya terus berjalan saat aplikasi di latar belakang karena
///  prosesnya memang dijaga hidup oleh foreground service.
///
///  Baterai driver yang membayarnya, sepanjang shift.
///
///  Jadi saat service berjalan, isolate layar TIDAK membaca GPS sama sekali.
///  Posisi untuk petanya datang dari laporan ini — dari pembacaan yang memang
///  sudah terjadi untuk ping.
/// ============================================================================
class LocationReport {
  const LocationReport({
    required this.sent,
    required this.consecutiveFailures,
    this.lat,
    this.lng,
  });

  /// Berapa ping yang berhasil sejak service dimulai.
  final int sent;

  /// Berapa ping berurutan yang gagal. Nol setelah satu ping berhasil.
  final int consecutiveFailures;

  /// Posisi yang dikirim pada ping ini.
  ///
  /// Null kalau service belum punya posisi sama sekali — GPS di dalam gedung
  /// bisa tidak menjawab selama beberapa menit pertama.
  final double? lat;
  final double? lng;
}

/// Implementasi untuk platform tanpa foreground service.
///
/// Dipakai di web dan iOS. Sengaja TIDAK melempar dari [start]: yang memanggil
/// sudah memeriksa [supported], dan implementasi yang melempar hanya memindahkan
/// keputusan itu ke waktu jalan.
class UnsupportedLocationBackgroundService extends LocationBackgroundService {
  const UnsupportedLocationBackgroundService();

  @override
  bool get supported => false;

  @override
  Future<bool> start({
    required String url,
    required String ticket,
    required int intervalSeconds,
    List<String> services = const <String>[],
  }) async => false;

  @override
  Future<void> stop() async {}

  @override
  void onReport(LocationReportCallback callback) {}
}
