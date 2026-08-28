import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identitas perangkat, dipakai backend untuk mengarahkan notifikasi.
///
/// ============================================================================
///  DIBUAT SEKALI PER INSTALASI, BUKAN SEKALI PER LOGIN
/// ============================================================================
///  Backend menyimpan satu baris per (pengguna, device_id) untuk mengirim push.
///  Kalau aplikasi mengirim UUID baru setiap kali masuk, yang tertinggal adalah
///  puluhan baris perangkat mati untuk satu HP — dan setiap notifikasi
///  dikirimkan ke semuanya.
///
///  Gejalanya bukan galat, tapi tagihan FCM yang naik dan pengiriman yang
///  melambat karena token mati harus di-timeout satu per satu.
/// ============================================================================
///
///  Disimpan di SharedPreferences, BUKAN secure storage. Ini bukan kredensial —
///  hanya penanda yang tidak berarti apa-apa tanpa token. Menaruhnya di Keystore
///  berarti satu panggilan platform channel di jalur startup untuk data yang
///  tidak rahasia.
class DeviceIdentity {
  const DeviceIdentity._();

  static const String _kunci = 'antaride_device_id';

  /// ID perangkat, dibuat pada pemanggilan pertama lalu dipakai selamanya.
  static Future<String> resolve() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final String? tersimpan = prefs.getString(_kunci);

      if (tersimpan != null && tersimpan.isNotEmpty) {
        return tersimpan;
      }

      final String baru = const Uuid().v4();

      await prefs.setString(_kunci, baru);

      return baru;
    } catch (_) {
      /*
       * Kegagalan SharedPreferences tidak boleh menggagalkan login.
       *
       * Yang hilang kalau ini terjadi: notifikasi mungkin dikirim ke baris
       * perangkat yang salah. Yang hilang kalau login digagalkan: pengguna
       * tidak bisa memakai aplikasi sama sekali. Perbandingannya tidak
       * seimbang.
       */
      return const Uuid().v4();
    }
  }
}
