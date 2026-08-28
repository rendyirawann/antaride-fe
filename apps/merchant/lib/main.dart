import 'package:antaride_auth/antaride_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';

/// Titik masuk aplikasi merchant.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AntarideServices services = AntarideServices.build(
    platform: _platform,
    appVersion: appVersion,
  );

  services.session.bootstrap();

  runApp(AntarideMerchantApp(services: services));
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
