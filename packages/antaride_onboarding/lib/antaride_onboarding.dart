/// Layar sambutan, pilihan masuk/daftar, dan daftar akun demo.
///
/// ============================================================================
///  ALUR PEMBUKA YANG SAMA UNTUK TIGA APLIKASI
/// ============================================================================
///  Ketiganya membuka dengan sambutan, lalu pilihan Masuk atau Daftar. Yang
///  berbeda hanya kalimat dan peran akun demonya — keduanya disuntikkan dari
///  luar, bukan dicabangkan di dalam.
///
///  Aplikasi TIDAK langsung menembak ke layar nomor HP. Layar yang meminta nomor
///  sebagai hal pertama meminta sesuatu sebelum menjelaskan apa pun — dan untuk
///  aplikasi driver, yang membukanya bahkan belum tahu bahwa pendaftarannya
///  menuntut dokumen.
/// ============================================================================
library;

export 'src/demo_account_list.dart' show DemoAccountPicker;
export 'src/welcome_screen.dart';
