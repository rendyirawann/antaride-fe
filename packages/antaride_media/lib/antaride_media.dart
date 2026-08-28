/// Pengambilan foto dan penanganan izin perangkat.
///
/// ============================================================================
///  SATU PINTU MASUK: `MediaSourceSheet.show`
/// ============================================================================
///  Layar tidak memanggil `MediaPicker` langsung, dan tidak menyentuh
///  `permission_handler` maupun `image_picker` sama sekali.
///
///  Alasannya bukan kerapian. Penanganan izin punya satu cabang yang paling mudah
///  terlewat dan paling merusak: "ditolak PERMANEN". Dialog sistem tidak akan
///  muncul lagi, apa pun yang dilakukan aplikasi, dan satu-satunya jalan keluar
///  adalah pengaturan perangkat.
///
///  Layar yang memperlakukannya sebagai pembatalan biasa menghasilkan tombol yang
///  diam: pengguna menekan "ambil foto", tidak ada yang terjadi, dan dia
///  menekannya lagi — selamanya.
///
///  Lima layar yang menangani izin sendiri-sendiri akan menghasilkan lima
///  perilaku, dan setidaknya satu di antaranya akan melewatkan cabang itu.
/// ============================================================================
library;

export 'src/media_outcome.dart';
export 'src/media_picker.dart' show MediaPicker, MediaSource;
export 'src/media_source_sheet.dart';
