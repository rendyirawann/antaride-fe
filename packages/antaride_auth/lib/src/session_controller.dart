import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:flutter/foundation.dart';

import 'device_identity.dart';

/// Tahap sesi.
enum SessionStage {
  /// Belum diperiksa. Layar menampilkan splash, bukan layar masuk.
  ///
  /// Membedakan ini dari [signedOut] adalah yang mencegah kedipan layar masuk
  /// pada pengguna yang sebenarnya sudah masuk — token dibaca dari secure
  /// storage secara asinkron, dan tanpa tahap ini layar masuk sudah tergambar
  /// sebelum jawabannya datang.
  unknown,

  signedOut,

  /// Sudah punya token, tapi profil belum dimuat.
  loadingProfile,

  signedIn,
}

/// Sumber kebenaran tunggal tentang siapa yang sedang masuk.
///
/// ============================================================================
///  KENAPA ChangeNotifier, BUKAN riverpod / bloc
/// ============================================================================
///  Tiga aplikasi memakai kelas ini. Kalau dia terikat ke satu framework state
///  management, ketiganya terikat juga — dan mengganti pilihan itu nanti berarti
///  menyentuh setiap layar di tiga aplikasi sekaligus.
///
///  `ChangeNotifier` ada di dalam Flutter sendiri. `provider` di aplikasi hanya
///  MENYALURKANNYA ke widget tree; aplikasi yang ingin memakai riverpod atau
///  bloc bisa membungkus kelas ini tanpa mengubahnya.
/// ============================================================================
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthRepository auth,
    required TokenStore tokenStore,
    required String platform,
    String? appVersion,
  }) : _auth = auth,
       _tokenStore = tokenStore,
       _platform = platform,
       _appVersion = appVersion;

  final AuthRepository _auth;
  final TokenStore _tokenStore;
  final String _platform;
  final String? _appVersion;

  SessionStage _stage = SessionStage.unknown;
  AuthUser? _user;
  ApiFailure? _lastFailure;
  OtpChallenge? _challenge;
  bool _busy = false;

  SessionStage get stage => _stage;

  AuthUser? get user => _user;

  /// Tantangan OTP yang sedang berjalan, kalau ada.
  ///
  /// Layar "masukkan kode" membacanya untuk hitungan mundur dan nomor
  /// tersamarkan. Null berarti belum ada kode yang diminta — dan layar itu
  /// seharusnya tidak terbuka.
  OtpChallenge? get challenge => _challenge;

  ApiFailure? get lastFailure => _lastFailure;

  /// Sedang ada panggilan berjalan. Tombol dinonaktifkan selama true.
  bool get isBusy => _busy;

  bool get isSignedIn => _stage == SessionStage.signedIn;

  bool get isResolved => _stage != SessionStage.unknown;

  // ---------------------------------------------------------------------------

  /// Baca token tersimpan lalu muat profil. Dipanggil sekali saat aplikasi mulai.
  ///
  /// ==========================================================================
  ///  PROFIL DIMUAT DI SINI, BUKAN DIANGGAP VALID DARI ADANYA TOKEN
  /// ==========================================================================
  ///  Token yang ada di penyimpanan belum tentu masih berlaku: bisa sudah
  ///  dicabut lewat `logout-all` dari HP lain, atau akunnya ditangguhkan admin.
  ///
  ///  Memuat profil di awal adalah cara mengetahuinya SEBELUM pengguna mencoba
  ///  memesan. Alternatifnya — menganggap valid lalu gagal di request pertama —
  ///  berarti pengguna dikeluarkan tepat saat dia menekan tombol pesan.
  /// ==========================================================================
  Future<void> bootstrap() async {
    await _tokenStore.load();

    if (!_tokenStore.isAuthenticated) {
      _setStage(SessionStage.signedOut);

      return;
    }

    _setStage(SessionStage.loadingProfile);

    final Result<AuthUser> hasil = await _auth.me();

    switch (hasil) {
      case Ok<AuthUser>(value: final AuthUser u):
        _user = u;
        _setStage(SessionStage.signedIn);

      case Err<AuthUser>(failure: final ApiFailure f):
        /*
         * HANYA 401 yang mengeluarkan pengguna.
         *
         * Kalau server sedang mati atau tidak ada sinyal, token-nya belum tentu
         * salah — dan mengeluarkan pengguna karena itu berarti dia harus
         * menunggu SMS lagi hanya karena membuka aplikasi di dalam lift.
         *
         * Untuk kegagalan yang bisa dicoba lagi, tahapnya TETAP `signedIn`
         * dengan profil kosong: layar menampilkan tombol coba lagi, dan
         * token-nya tetap dipakai.
         */
        if (f.isUnauthenticated) {
          await _tokenStore.clear();
          _user = null;
          _lastFailure = null;
          _setStage(SessionStage.signedOut);

          return;
        }

        _lastFailure = f;
        _setStage(SessionStage.signedIn);
    }
  }

  /// Minta kode OTP.
  Future<bool> requestOtp(String phone, {String purpose = 'login'}) async {
    return _jalankan(() async {
      final Result<OtpChallenge> hasil = await _auth.requestOtp(
        phone: phone,
        purpose: purpose,
      );

      return hasil.when(
        ok: (OtpChallenge c) {
          _challenge = c;

          return true;
        },
        err: (ApiFailure f) {
          _lastFailure = f;

          return false;
        },
      );
    });
  }

  /// Verifikasi kode dan masuk.
  Future<bool> verifyOtp({
    required String phone,
    required String code,
    String purpose = 'login',
  }) async {
    return _jalankan(() async {
      final String deviceId = await DeviceIdentity.resolve();

      final Result<AuthSession> hasil = await _auth.verifyOtp(
        phone: phone,
        code: code,
        purpose: purpose,
        deviceId: deviceId,
        platform: _platform,
        appVersion: _appVersion,
      );

      return hasil.when(
        ok: (AuthSession s) {
          _user = s.user;
          _challenge = null;
          _stage = SessionStage.signedIn;

          return true;
        },
        err: (ApiFailure f) {
          _lastFailure = f;

          return false;
        },
      );
    });
  }

  /// Muat ulang profil, misalnya setelah diubah di layar edit.
  Future<void> refreshProfile() async {
    final Result<AuthUser> hasil = await _auth.me();

    final AuthUser? u = hasil.valueOrNull;

    if (u != null) {
      _user = u;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? email,
    String? gender,
    String? birthDate,
  }) async {
    return _jalankan(() async {
      final Result<AuthUser> hasil = await _auth.updateProfile(
        name: name,
        email: email,
        gender: gender,
        birthDate: birthDate,
      );

      return hasil.when(
        ok: (AuthUser u) {
          _user = u;

          return true;
        },
        err: (ApiFailure f) {
          _lastFailure = f;

          return false;
        },
      );
    });
  }

  Future<void> signOut({bool allDevices = false}) async {
    _busy = true;
    notifyListeners();

    if (allDevices) {
      await _auth.logoutAll();
    } else {
      await _auth.logout();
    }

    // Hasil panggilannya TIDAK diperiksa, dan itu disengaja. Token lokal sudah
    // dihapus oleh repository apa pun jawabannya — lihat penjelasan di
    // AuthRepository.logout.
    _user = null;
    _challenge = null;
    _lastFailure = null;
    _busy = false;
    _setStage(SessionStage.signedOut);
  }

  /// Dipanggil ApiClient saat backend membalas 401 di request mana pun.
  ///
  /// Ini yang menangani token yang dicabut di TENGAH pemakaian — bukan hanya
  /// saat aplikasi mulai. Ditangani di satu tempat karena kalau setiap layar
  /// menanganinya sendiri, akan ada layar yang membiarkan pengguna terjebak di
  /// halaman yang setiap request-nya gagal.
  void handleUnauthenticated() {
    if (_stage == SessionStage.signedOut) {
      return;
    }

    _tokenStore.clear();
    _user = null;
    _challenge = null;
    _setStage(SessionStage.signedOut);
  }

  void clearFailure() {
    if (_lastFailure == null) {
      return;
    }

    _lastFailure = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------

  Future<bool> _jalankan(Future<bool> Function() aksi) async {
    if (_busy) {
      // Panggilan kedua saat yang pertama masih berjalan DITOLAK, bukan
      // diantrekan. Yang memicunya: tombol yang ditekan dua kali cepat. Kalau
      // diantrekan, backend menerima dua permintaan OTP dan pengguna menerima
      // dua SMS — yang kami bayar dan yang dia baca sebagai gangguan.
      return false;
    }

    _busy = true;
    _lastFailure = null;
    notifyListeners();

    try {
      return await aksi();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _setStage(SessionStage tahap) {
    _stage = tahap;
    notifyListeners();
  }
}
