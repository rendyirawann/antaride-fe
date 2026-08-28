import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';

/// Titik masuk aplikasi driver.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AntarideServices services = AntarideServices.build(
    platform: _platform,
    appVersion: appVersion,

    // Notifikasi dibaca sebagai DRIVER, bukan sebagai penumpang.
    //
    // Satu orang bisa punya keduanya dengan akun yang sama — driver memesan
    // ojek saat kendaraannya di bengkel. Tanpa baris ini, aplikasi driver
    // menampilkan notifikasi penumpangnya, dan tidak ada galat yang muncul
    // untuk menjelaskannya.
    notificationRole: RecipientRole.driver,
  );

  services.session.bootstrap();

  runApp(AntarideDriverApp(services: services));
}

const String appVersion = '1.0.0';

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
