import 'package:antaride_core/antaride_core.dart';

import '../client/api_client.dart';
import '../models/app_notification.dart';

/// Notifikasi in-app.
///
/// ============================================================================
///  `as` MENENTUKAN NOTIFIKASI SIAPA YANG DIBACA
/// ============================================================================
///  Satu orang bisa jadi penumpang DAN driver dengan akun yang sama, dan itu
///  wajar — driver memesan ojek saat kendaraannya di bengkel. Keduanya punya
///  notifikasi sendiri.
///
///  Jadi yang menentukan bukan akunnya, tapi dari APLIKASI mana request-nya
///  datang. Aplikasi penumpang memakai `RecipientRole.customer`, aplikasi driver
///  memakai `RecipientRole.driver`.
///
///  Kalau backend menyimpulkannya dari "apakah akun ini punya baris di tabel
///  drivers", maka setiap driver yang memesan ojek akan melihat notifikasi
///  drivernya di aplikasi penumpang — dan tidak akan pernah melihat notifikasi
///  penumpangnya.
/// ============================================================================
class NotificationRepository {
  const NotificationRepository(
    this._client, {
    this.role = RecipientRole.customer,
  });

  final ApiClient _client;

  /// Peran yang dipakai repository ini. Ditetapkan sekali saat dibuat.
  ///
  /// Bukan parameter per method: aplikasi driver SELALU membaca sebagai driver,
  /// dan parameter per pemanggilan berarti satu layar bisa lupa mengirimnya lalu
  /// menampilkan notifikasi penumpang di aplikasi driver.
  final RecipientRole role;

  Future<Result<NotificationPage>> list({
    String? cursor,
    int perPage = 20,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      'as': role.wire,
      'per_page': perPage,
    };

    // Halaman pertama TIDAK mengirim `cursor` sama sekali, bukan mengirimnya
    // bernilai null. Cursor kosong yang terkirim dibaca backend sebagai cursor
    // yang tidak sah, dan halaman pertama akan kosong.
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }

    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/notifications',
      query: query,
    );

    // Penguraiannya ada di `NotificationPage.fromEnvelope`, bukan di sini.
    // Alasannya di docblock factory itu: supaya test kontrak bisa memanggil
    // fungsi yang SAMA dengan yang dipakai aplikasi, tanpa membangun Dio.
    return hasil.map(NotificationPage.fromEnvelope);
  }

  /// Jumlah yang belum dibaca saja.
  ///
  /// Endpoint tersendiri karena aplikasi memanggilnya jauh lebih sering daripada
  /// daftarnya: lencana di beranda diperbarui setiap kali aplikasi kembali ke
  /// depan, sementara daftarnya hanya dibuka kalau loncengnya ditekan.
  ///
  /// Response-nya satu angka, bukan dua puluh baris notifikasi.
  Future<Result<int>> unreadCount() async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/notifications/unread-count',
      query: <String, dynamic>{'as': role.wire},
    );

    return hasil.map((Map<String, dynamic> badan) {
      final Map<String, dynamic> data =
          (badan['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      return (data['unread_count'] as num?)?.toInt() ?? 0;
    });
  }

  /// Tandai satu notifikasi sudah dibaca. Mengembalikan jumlah sisa.
  Future<Result<int>> markRead(String uuid) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/notifications/$uuid/read?as=${role.wire}',
    );

    return hasil.map(_jumlahSisa);
  }

  /// Tandai semua sudah dibaca.
  Future<Result<int>> markAllRead() async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/notifications/read-all?as=${role.wire}',
    );

    return hasil.map(_jumlahSisa);
  }

  static int _jumlahSisa(Map<String, dynamic> badan) {
    final Map<String, dynamic> data =
        (badan['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return (data['unread_count'] as num?)?.toInt() ?? 0;
  }
}

/// Peran penerima notifikasi.
enum RecipientRole {
  customer('user'),
  driver('driver');

  const RecipientRole(this.wire);

  /// Nilai yang dikirim ke API.
  ///
  /// Berbeda dari nama enum-nya untuk `customer`: backend memakai `user`, karena
  /// di sana penumpang memang baris di tabel `users`. Nama Dart-nya `customer`
  /// supaya cocok dengan nama aplikasinya.
  ///
  /// Perbedaan itu ditangani DI SINI, satu tempat — bukan dengan string literal
  /// yang ditulis ulang di setiap pemanggilan.
  final String wire;
}
