/// Peta, lokasi, dan polyline.
///
/// `LatLng` diekspor ulang dari `latlong2` supaya aplikasi tidak perlu
/// menambahkan paket itu sebagai dependency langsung — dan supaya semua
/// aplikasi memakai tipe koordinat yang SAMA. Dua tipe koordinat di satu basis
/// kode menghasilkan fungsi konversi di setiap perbatasan, dan salah satu akan
/// menukar lat dengan lng.
library;

export 'package:latlong2/latlong.dart' show LatLng;

export 'src/antaride_map.dart';
export 'src/location_service.dart';
export 'src/polyline_codec.dart';
