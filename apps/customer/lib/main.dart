import 'package:antaride_auth/antaride_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';

/// Titik masuk aplikasi penumpang.
///
/// ============================================================================
///  DEPENDENCY DIBANGUN DI SINI, SEBELUM runApp
/// ============================================================================
///  `AntarideServices.build()` dipanggil sekali, dan hasilnya disalurkan ke
///  widget tree lewat provider. Tidak ada singleton global, dan tidak ada
///  `late` yang diisi belakangan.
///
///  `bootstrap()` sesi TIDAK di-await di sini, dan itu disengaja: dia membaca
///  secure storage dan memanggil API, dan menunggunya berarti layar putih
///  selama satu sampai dua detik pada setiap pembukaan aplikasi. Yang
///  dilakukan sebagai gantinya: aplikasi tampil dengan splash, dan
///  `SessionStage.unknown` yang menahannya sampai jawabannya datang.
/// ============================================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AntarideServices services = AntarideServices.build(
    platform: _platform,
    appVersion: appVersion,
  );

  // Tidak di-await. Lihat penjelasan di docblock.
  services.session.bootstrap();

  runApp(AntarideCustomerApp(services: services));
}

/// Versi aplikasi yang dilaporkan ke backend.
///
/// Ditulis manual, bukan dibaca dari `package_info_plus`. Untuk satu nilai yang
/// berubah setiap rilis, satu dependency dengan platform channel di jalur
/// startup tidak sebanding — dan angkanya sudah ada di `pubspec.yaml` yang
/// dibaca manusia di sebelahnya.
const String appVersion = '1.0.0';

/// Platform yang dilaporkan ke backend saat verifikasi OTP.
///
/// Menentukan lewat kanal apa notifikasi dikirim. `web` dipisahkan karena
/// notifikasi push web memakai jalur yang sama sekali berbeda dari FCM mobile.
String get _platform {
  if (kIsWeb) {
    return 'web';
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'other',
  };
}
