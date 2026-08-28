import 'package:dio/dio.dart';

/// Pengirim ping GPS ke layanan lokasi.
///
/// ============================================================================
///  DIO SENDIRI, BUKAN ApiClient
/// ============================================================================
///  `ApiClient` menempelkan token Sanctum ke setiap request lewat interceptor,
///  memakai `baseUrl` API, dan menguraikan bentuk response `{success, data}`.
///
///  Layanan lokasi tidak cocok dengan ketiganya: dia di host dan port yang
///  berbeda, memakai tiket bertanda tangan alih-alih token Sanctum, dan
///  balasannya tidak perlu diurai — yang penting hanya berhasil atau tidak.
///
///  Yang lebih penting: mengirim token Sanctum ke layanan lokasi berarti token
///  itu ada di log dan memori proses yang berbeda, untuk tidak ada gunanya. Tiket
///  lokasi haknya jauh lebih kecil, dan itu yang seharusnya berpindah.
/// ============================================================================
///
/// ============================================================================
///  KEGAGALAN PING DITELAN, DAN ITU KEPUTUSAN YANG DISENGAJA
/// ============================================================================
///  Ping yang gagal TIDAK dilaporkan ke layar dan TIDAK dicoba ulang.
///
///  Alasannya: ping berikutnya datang beberapa detik kemudian dan membawa posisi
///  yang lebih baru. Mencoba ulang ping yang gagal berarti mengirim posisi LAMA
///  bersaing dengan posisi baru — dan yang menang bisa yang lama.
///
///  Menampilkannya ke layar juga salah: driver tidak bisa berbuat apa pun soal
///  ping yang gagal, dan pita galat yang berkedip setiap kali dia melewati area
///  tanpa sinyal hanya membuat layar tidak bisa dibaca.
///
///  Yang TIDAK ditelan: keadaan "tidak pernah berhasil sama sekali". Itu
///  dilaporkan lewat [consecutiveFailures], dan dasbor menampilkannya sebagai
///  peringatan — karena driver yang posisinya tidak pernah terkirim tidak akan
///  pernah mendapat order, dan itu HARUS dia ketahui.
/// ============================================================================
class LocationPinger {
  LocationPinger({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      // Timeout pendek. Ping berikutnya datang beberapa detik kemudian; ping
      // yang menggantung 20 detik akan bertumpuk dengan yang lebih baru.
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: <String, String>{'Content-Type': 'application/json'},
      validateStatus: (int? _) => true,
    );
  }

  final Dio _dio;

  int _consecutiveFailures = 0;
  int _sent = 0;

  /// Berapa ping berurutan yang gagal.
  ///
  /// Nol setelah satu ping berhasil. Dasbor driver memakainya untuk memutuskan
  /// apakah menampilkan peringatan "posisi tidak terkirim".
  int get consecutiveFailures => _consecutiveFailures;

  /// Berapa ping yang berhasil terkirim sejak driver online.
  ///
  /// Dipakai layar diagnostik dan — lebih penting — untuk membedakan "belum
  /// pernah berhasil" dari "sempat berhasil lalu terputus". Keduanya butuh pesan
  /// yang berbeda: yang pertama biasanya konfigurasi, yang kedua jaringan.
  int get sent => _sent;

  void reset() {
    _consecutiveFailures = 0;
    _sent = 0;
  }

  /// Kirim satu posisi. Mengembalikan true kalau layanan lokasi menerimanya.
  Future<bool> send({
    required String url,
    required String ticket,
    required double lat,
    required double lng,
    double? headingDegrees,
    double? speedKmh,
    double? accuracyM,
    int? batteryPercent,
    List<String> services = const <String>[],
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        url,
        options: Options(
          headers: <String, String>{'Authorization': 'Bearer $ticket'},
        ),
        data: <String, dynamic>{
          'lat': lat,
          'lng': lng,
          'heading': ?headingDegrees,
          'speed_kmh': ?speedKmh,
          'accuracy_m': ?accuracyM,
          'battery_percent': ?batteryPercent,
          if (services.isNotEmpty) 'services': services,
        },
      );

      final int status = response.statusCode ?? 0;

      /*
       * 429 dihitung BERHASIL, bukan gagal.
       *
       * Layanan lokasi membalas 429 saat ping datang lebih rapat dari batas
       * minimumnya, dan itu berarti posisinya sudah cukup baru — bukan bahwa
       * pengirimannya bermasalah.
       *
       * Menghitungnya sebagai kegagalan akan membuat peringatan "posisi tidak
       * terkirim" menyala pada driver yang justru ping-nya paling rajin.
       */
      if (status == 200 || status == 429) {
        _consecutiveFailures = 0;

        if (status == 200) {
          _sent++;
        }

        return true;
      }

      _consecutiveFailures++;

      return false;
    } catch (_) {
      /*
       * Setiap exception ditelan — timeout, DNS gagal, socket ditutup.
       *
       * Kalau dibiarkan keluar, dia akan naik ke timer yang memanggilnya dan
       * menjadi unhandled exception di isolate — yang di Flutter menjatuhkan
       * aplikasi driver di tengah perjalanan.
       */
      _consecutiveFailures++;

      return false;
    }
  }
}
