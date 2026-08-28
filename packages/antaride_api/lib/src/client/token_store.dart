import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token Sanctum.
///
/// ============================================================================
///  KENAPA SECURE STORAGE, BUKAN SharedPreferences
/// ============================================================================
///  SharedPreferences menyimpan nilainya sebagai XML biasa di
///  `/data/data/<paket>/shared_prefs/`. Pada perangkat yang di-root — dan
///  perangkat murah di Indonesia sering di-root oleh pemiliknya sendiri —
///  file itu bisa dibaca aplikasi lain.
///
///  Token Sanctum adalah kredensial penuh: siapa pun yang memegangnya bisa
///  memesan order, menarik saldo, dan mengubah profil sebagai pengguna itu.
///
///  `flutter_secure_storage` memakai Keystore di Android dan Keychain di iOS.
///  Keduanya bukan jaminan mutlak pada perangkat yang sudah dikompromikan, tapi
///  bedanya besar: membacanya menuntut usaha yang jauh lebih besar daripada
///  membuka file XML.
/// ============================================================================
///
/// ============================================================================
///  TOKEN DI-CACHE DI MEMORI, DAN ITU BUKAN OPTIMASI PREMATUR
/// ============================================================================
///  Secure storage berbasis platform channel — setiap pembacaan adalah panggilan
///  asinkron ke kode native. Interceptor Dio memerlukannya SINKRON dan pada
///  SETIAP request.
///
///  Tanpa cache di memori, satu-satunya cara adalah membuat interceptor-nya
///  asinkron, dan itu menambah beberapa milidetik pada setiap request. Untuk
///  aplikasi driver yang mengirim ping GPS setiap empat detik, itu bertumpuk.
///
///  Cache-nya diisi sekali di `load()` saat aplikasi mulai, lalu diperbarui
///  setiap kali token berubah.
/// ============================================================================
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const String _kunciToken = 'antaride_token';
  static const String _kunciUuid = 'antaride_user_uuid';

  String? _token;
  String? _userUuid;

  /// Token yang sedang aktif. Sinkron, dibaca dari cache memori.
  String? get token => _token;

  String? get userUuid => _userUuid;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// Muat token dari penyimpanan. Dipanggil sekali saat aplikasi mulai.
  Future<void> load() async {
    try {
      _token = await _storage.read(key: _kunciToken);
      _userUuid = await _storage.read(key: _kunciUuid);
    } catch (_) {
      /*
       * Kegagalan membaca secure storage TIDAK boleh menjatuhkan aplikasi.
       *
       * Terjadi pada perangkat yang Keystore-nya rusak setelah pembaruan
       * sistem — jarang, tapi nyata, dan pemiliknya tidak punya cara
       * memperbaikinya sendiri.
       *
       * Yang benar: perlakukan sebagai belum masuk. Pengguna masuk lagi dengan
       * OTP, dan itu satu langkah yang bisa dia lakukan. Aplikasi yang gagal
       * dibuka tidak memberinya jalan apa pun.
       */
      _token = null;
      _userUuid = null;
    }
  }

  Future<void> save({required String token, String? userUuid}) async {
    _token = token;
    _userUuid = userUuid;

    try {
      await _storage.write(key: _kunciToken, value: token);

      if (userUuid != null) {
        await _storage.write(key: _kunciUuid, value: userUuid);
      }
    } catch (_) {
      /*
       * Gagal MENULIS ditelan, dan cache memori tetap diisi.
       *
       * Konsekuensinya: pengguna tetap masuk untuk sesi ini, dan harus masuk
       * lagi setelah menutup aplikasi. Itu jauh lebih baik daripada menolak
       * login sepenuhnya — dia sudah memverifikasi OTP, dan menggagalkan
       * langkah terakhir karena penyimpanan bermasalah berarti dia tidak bisa
       * memakai aplikasi sama sekali.
       */
    }
  }

  Future<void> clear() async {
    _token = null;
    _userUuid = null;

    try {
      await _storage.delete(key: _kunciToken);
      await _storage.delete(key: _kunciUuid);
    } catch (_) {
      // Cache memori sudah dikosongkan, jadi sesi ini sudah berakhir walaupun
      // penghapusan dari penyimpanan gagal.
    }
  }
}
