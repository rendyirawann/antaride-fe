import 'package:antaride_core/antaride_core.dart';

import '../client/api_client.dart';
import '../models/demo_account.dart';
import '../client/token_store.dart';
import '../models/user.dart';

/// Autentikasi lewat OTP SMS.
///
/// ============================================================================
///  DUA LANGKAH, BUKAN EMPAT
/// ============================================================================
///  Tidak ada `register` dan `login` terpisah — hanya [requestOtp] lalu
///  [verifyOtp]. Nomor yang belum terdaftar mendapat akun baru di langkah kedua,
///  dan itu ditandai lewat `AuthSession.isNewUser`.
///
///  Alasannya keamanan, bukan kesederhanaan: kalau login dan registrasi
///  dipisah, perbedaan response-nya sudah cukup untuk menguji nomor mana yang
///  punya akun Antaride. Dengan satu alur, response [requestOtp] identik untuk
///  keduanya.
///
///  Konsekuensinya bagi layar: layar "masukkan kode" TIDAK bisa menyapa
///  pengguna dengan namanya. Nama baru diketahui setelah kodenya benar.
/// ============================================================================
class AuthRepository {
  const AuthRepository({
    required ApiClient client,
    required TokenStore tokenStore,
  }) : _client = client,
       _tokenStore = tokenStore;

  final ApiClient _client;
  final TokenStore _tokenStore;

  /// Minta kode OTP dikirim ke [phone].
  ///
  /// [phone] dikirim APA ADANYA seperti yang diketik pengguna. Backend yang
  /// menormalkannya ke bentuk `62xxxxxxxxxx`.
  ///
  /// Aplikasi TIDAK menormalkan nomor sendiri, dan itu disengaja: kalau
  /// menormalkan, aplikasi dan backend punya dua aturan yang harus sepakat soal
  /// `08`, `+62`, `62`, dan `0062`. Yang terjadi kalau tidak sepakat adalah OTP
  /// terkirim ke satu bentuk nomor lalu diverifikasi terhadap bentuk lain.
  Future<Result<OtpChallenge>> requestOtp({
    required String phone,
    String purpose = 'login',
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/auth/otp/request',
      body: <String, dynamic>{'phone': phone, 'purpose': purpose},
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          OtpChallenge.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Verifikasi kode, lalu masuk atau daftar.
  ///
  /// Token DISIMPAN di sini kalau berhasil. Layar tidak perlu — dan tidak
  /// boleh — menyimpannya sendiri: kalau setiap layar masuk menyimpan token,
  /// akan ada satu yang lupa, dan gejalanya adalah pengguna yang terlihat masuk
  /// tapi kembali ke layar masuk setelah aplikasi ditutup.
  ///
  /// [deviceId] dipakai backend untuk mengirim notifikasi ke perangkat yang
  /// benar. Dibuat sekali per instalasi dan disimpan, bukan diacak setiap masuk.
  Future<Result<AuthSession>> verifyOtp({
    required String phone,
    required String code,
    String purpose = 'login',
    String? deviceId,
    String? platform,
    String? fcmToken,
    String? appVersion,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/auth/otp/verify',
      body: <String, dynamic>{
        'phone': phone,
        'code': code,
        'purpose': purpose,
        'device_id': ?deviceId,
        'platform': ?platform,
        'fcm_token': ?fcmToken,
        'app_version': ?appVersion,
      },
    );

    if (hasil case Err<Map<String, dynamic>>(failure: final ApiFailure f)) {
      return Err<AuthSession>(f);
    }

    final AuthSession sesi = AuthSession.fromJson(
      (hasil as Ok<Map<String, dynamic>>).value['data'] as Map<String, dynamic>,
    );

    await _tokenStore.save(token: sesi.token, userUuid: sesi.user.uuid);

    return Ok<AuthSession>(sesi);
  }

  /// Keluar dari perangkat ini saja.
  ///
  /// ==========================================================================
  ///  TOKEN LOKAL DIHAPUS WALAUPUN PANGGILANNYA GAGAL
  /// ==========================================================================
  ///  Kalau jaringan mati saat pengguna menekan keluar, backend tidak menerima
  ///  apa pun — tapi pengguna TETAP harus keluar. Yang alternatifnya: aplikasi
  ///  menolak logout karena tidak ada sinyal, dan orang yang mau menyerahkan
  ///  HP-nya ke orang lain tidak bisa melakukannya.
  ///
  ///  Token yang tertinggal di sisi backend akan kadaluarsa sendiri, dan
  ///  `logout-all` dari perangkat lain tetap bisa mencabutnya.
  /// ==========================================================================
  // ---------------------------------------------------------------------------
  //  Akun demo
  // ---------------------------------------------------------------------------

  /// Daftar akun demo untuk satu aplikasi.
  ///
  /// ==========================================================================
  ///  KEGAGALANNYA TIDAK PERNAH SAMPAI KE LAYAR
  /// ==========================================================================
  ///  Dipanggil di layar masuk, sebelum pengguna melakukan apa pun. Kalau
  ///  request-nya gagal — server lama, jaringan putus, fiturnya dimatikan —
  ///  yang benar adalah menyembunyikan bagian akun demo, bukan menampilkan
  ///  pesan merah di layar pertama yang dia lihat.
  ///
  ///  Karena itu kembaliannya `DemoAccountList`, bukan `Result`: tidak ada
  ///  keadaan gagal yang perlu ditangani pemanggil. Yang ada hanya "ada
  ///  daftarnya" atau "tidak ada".
  /// ==========================================================================
  Future<DemoAccountList> demoAccounts({required String role}) async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/auth/demo/accounts',
      query: <String, dynamic>{'role': role},
    );

    return hasil.when(
      ok: (Map<String, dynamic> badan) => DemoAccountList.fromJson(
        (badan['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      err: (ApiFailure _) => DemoAccountList.mati,
    );
  }

  /// Masuk sebagai akun demo, tanpa OTP.
  ///
  /// Berbeda dari [demoAccounts], INI mengembalikan `Result`: pengguna sudah
  /// menekan tombol dan sedang menunggu, jadi kegagalannya harus terlihat.
  Future<Result<AuthSession>> demoLogin({
    required String uuid,
    String? deviceId,
    String? platform,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/auth/demo/login',
      body: <String, dynamic>{
        'uuid': uuid,
        'device_id': ?deviceId,
        'platform': ?platform,
      },
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          AuthSession.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  Future<Result<void>> logout() async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/auth/logout',
    );

    await _tokenStore.clear();

    return hasil.map((Map<String, dynamic> _) {});
  }

  /// Keluar dari SEMUA perangkat.
  ///
  /// Ini yang dipakai saat HP hilang. Berbeda dari [logout] karena dampaknya
  /// jauh berbeda, dan pengguna harus memilihnya secara sadar — layar menanyakan
  /// konfirmasi sebelum memanggilnya.
  Future<Result<void>> logoutAll() async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/auth/logout-all',
    );

    await _tokenStore.clear();

    return hasil.map((Map<String, dynamic> _) {});
  }

  /// Profil pengguna yang sedang masuk.
  Future<Result<AuthUser>> me() async {
    final Result<Map<String, dynamic>> hasil = await _client.get('/me');

    return hasil.map(
      (Map<String, dynamic> badan) =>
          AuthUser.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Perbarui profil.
  ///
  /// Hanya field yang dikirim yang diubah. Field yang null TIDAK dikirim sama
  /// sekali, bukan dikirim sebagai null — backend memakai `PATCH`, dan null
  /// yang terkirim akan MENGOSONGKAN field itu. Layar edit profil yang mengirim
  /// seluruh form akan menghapus email pengguna hanya karena kolomnya tidak
  /// ditampilkan di layar itu.
  Future<Result<AuthUser>> updateProfile({
    String? name,
    String? email,
    String? gender,
    String? birthDate,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.patch(
      '/me',
      body: <String, dynamic>{
        'name': ?name,
        'email': ?email,
        'gender': ?gender,
        'birth_date': ?birthDate,
      },
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          AuthUser.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Ajukan penghapusan akun.
  ///
  /// Tidak langsung menghapus: ada masa tenggang, dan masuk kembali sebelum
  /// tenggangnya habis membatalkan pengajuannya lewat [cancelDeletion].
  ///
  /// Lama tenggangnya datang dari backend, dan layar menampilkan angka dari
  /// response — bukan angka yang ditulis di aplikasi. Kebijakan itu bisa
  /// berubah, dan aplikasi yang menuliskannya sendiri akan menjanjikan tenggang
  /// yang salah.
  Future<Result<AccountDeletion>> requestDeletion() async {
    final Result<Map<String, dynamic>> hasil = await _client.delete('/me');

    return hasil.map(
      (Map<String, dynamic> badan) =>
          AccountDeletion.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  Future<Result<void>> cancelDeletion() async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/me/restore',
    );

    return hasil.map((Map<String, dynamic> _) {});
  }
}

/// Hasil pengajuan penghapusan akun.
class AccountDeletion {
  const AccountDeletion({
    required this.requestedAt,
    required this.scheduledFor,
    required this.graceDays,
    required this.message,
  });

  final DateTime requestedAt;
  final DateTime scheduledFor;
  final int graceDays;

  /// Kalimat siap tampil dari backend, sudah memuat jumlah harinya.
  final String message;

  factory AccountDeletion.fromJson(Map<String, dynamic> json) =>
      AccountDeletion(
        requestedAt:
            DateTime.tryParse(
              json['deletion_requested_at'] as String? ?? '',
            )?.toLocal() ??
            DateTime.now(),
        scheduledFor:
            DateTime.tryParse(
              json['scheduled_for'] as String? ?? '',
            )?.toLocal() ??
            DateTime.now(),
        graceDays: (json['grace_days'] as num?)?.toInt() ?? 30,
        message: json['message'] as String? ?? '',
      );
}
