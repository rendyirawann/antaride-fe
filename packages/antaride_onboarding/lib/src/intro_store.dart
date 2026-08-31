import 'package:shared_preferences/shared_preferences.dart';

/// Penanda "perkenalan sudah pernah dilihat".
///
/// ============================================================================
///  SharedPreferences, BUKAN PENYIMPANAN AMAN
/// ============================================================================
///  Token sesi disimpan di `flutter_secure_storage` karena bocornya berarti
///  akun bisa diambil alih. Penanda ini tidak: yang terburuk kalau seseorang
///  mengubahnya adalah dia melihat tiga layar perkenalan sekali lagi.
///
///  Penyimpanan aman lebih lambat dan bisa GAGAL di sebagian perangkat Android
///  yang keystore-nya bermasalah — dan gagal membaca penanda ini tidak boleh
///  menghalangi aplikasi terbuka.
/// ============================================================================
class IntroStore {
  const IntroStore();

  static const String _kunci = 'antaride_intro_selesai';

  /// Perkenalan sudah pernah diselesaikan atau dilewati.
  ///
  /// Mengembalikan `true` kalau penyimpanannya sendiri gagal dibaca —
  /// fail-open, dan itu disengaja: aplikasi yang menampilkan perkenalan setiap
  /// kali dibuka karena penyimpanannya bermasalah jauh lebih mengganggu
  /// daripada aplikasi yang melewatkannya sekali.
  Future<bool> sudah() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      return prefs.getBool(_kunci) ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Menandai perkenalan selesai. Kegagalannya diabaikan — lihat [sudah].
  Future<void> tandai() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_kunci, true);
    } catch (_) {
      // Sengaja diam: yang terjadi kalau ini gagal adalah perkenalan muncul
      // sekali lagi di pembukaan berikutnya.
    }
  }
}
