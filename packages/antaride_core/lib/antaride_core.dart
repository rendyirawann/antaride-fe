/// Inti bersama tiga aplikasi Antaride: konfigurasi, penanganan galat, dan
/// tipe uang.
///
/// TIDAK ada di paket ini: widget, navigasi, dan pemanggilan HTTP. Ketiganya
/// punya paketnya sendiri. Pemisahan itu yang membuat paket ini bisa diuji
/// tanpa Flutter dan tanpa jaringan.
library;

export 'src/config/app_config.dart';
export 'src/money/money.dart';
export 'src/result/api_failure.dart';
export 'src/result/result.dart';
