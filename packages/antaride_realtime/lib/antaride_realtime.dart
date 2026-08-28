/// Koneksi realtime Antaride.
///
/// ============================================================================
///  REALTIME MEMPERCEPAT PEMBARUAN. DIA BUKAN SUMBER KEBENARAN.
/// ============================================================================
///  Setiap layar yang memakai paket ini HARUS tetap benar walaupun tidak ada
///  satu pun peristiwa yang datang. REST tetap kebenarannya; realtime hanya
///  memberitahu lebih cepat kapan harus menariknya.
///
///  Alasannya bukan kehati-hatian berlebihan: sebagian jaringan operator dan
///  hampir semua WiFi kantor memblokir koneksi WebSocket yang panjang. Aplikasi
///  yang menggantungkan seluruh pembaruannya di sini akan membeku bagi pengguna
///  itu — dan membeku tanpa galat, yang jauh lebih sulit dilaporkan.
/// ============================================================================
library;

export 'src/centrifugo_client.dart';
export 'src/realtime_client.dart';
