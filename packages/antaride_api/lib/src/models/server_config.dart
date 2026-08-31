/// Konfigurasi yang dibaca aplikasi dari server saat mulai.
///
/// Dinamai `ServerConfig`, bukan `AppConfig`: `AppConfig` sudah dipakai
/// `antaride_core` untuk konfigurasi WAKTU BUILD (alamat API, token peta).
/// Dua nama yang sama di dua paket yang sering diimpor bersama menghasilkan
/// galat ambigu di berkas yang memakai keduanya — dan nama ini juga lebih
/// tepat: isinya memang datang dari server, bukan dari build.
///
/// ============================================================================
///  AREA LAYANAN DATANG DARI SERVER, BUKAN DITULIS DI APLIKASI
/// ============================================================================
///  Area berubah lebih cepat daripada aplikasi bisa diperbarui. Saat cakupan
///  digeser — misalnya OSRM di server dipersempit ke sekitar Lubuk Pakam —
///  aplikasi yang menyimpan koordinatnya sendiri akan tetap membuka peta di
///  kota lama.
///
///  Yang dilihat pengguna saat itu bukan pesan galat, melainkan peta yang
///  membuka kota yang salah lalu menolak menghitung ongkos tanpa alasan yang
///  bisa dia mengerti. Memperbaikinya menuntut membangun ulang dan membagikan
///  ulang APK ke semua orang.
/// ============================================================================
class ServerConfig {
  const ServerConfig({
    required this.areaLat,
    required this.areaLng,
    required this.areaRadiusKm,
    required this.areaZoom,
    required this.areaLabel,
    required this.placesEnabled,
  });

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> area =
        (json['area'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return ServerConfig(
      areaLat: (area['lat'] as num?)?.toDouble() ?? _bawaan.areaLat,
      areaLng: (area['lng'] as num?)?.toDouble() ?? _bawaan.areaLng,
      areaRadiusKm:
          (area['radius_km'] as num?)?.toDouble() ?? _bawaan.areaRadiusKm,
      areaZoom: (area['zoom'] as num?)?.toDouble() ?? _bawaan.areaZoom,
      areaLabel: (area['label'] as String?) ?? _bawaan.areaLabel,
      placesEnabled: (json['places_enabled'] as bool?) ?? false,
    );
  }

  final double areaLat;
  final double areaLng;

  /// Radius area layanan. Dipakai memutuskan seberapa jauh peta boleh dibawa
  /// sebelum aplikasi memperingatkan bahwa titiknya di luar jangkauan.
  final double areaRadiusKm;

  final double areaZoom;

  /// Nama area, dipakai di pesan "tidak ditemukan di ...".
  final String areaLabel;

  /// Server punya geocoder yang bekerja.
  ///
  /// Kalau false, kolom pencarian alamat DISEMBUNYIKAN — bukan ditampilkan
  /// lalu tidak pernah menemukan apa pun. Kolom yang selalu kosong terbaca
  /// sebagai aplikasi rusak, bukan sebagai fitur yang belum dinyalakan.
  final bool placesEnabled;

  /// Nilai yang dipakai sebelum server menjawab, dan kalau server tidak bisa
  /// dihubungi sama sekali.
  ///
  /// ==========================================================================
  ///  KENAPA ADA BAWAAN, PADAHAL SERVER YANG BERWENANG
  /// ==========================================================================
  ///  Peta harus menggambar sesuatu pada frame pertama, sebelum request apa pun
  ///  selesai. Tanpa bawaan, pilihannya cuma dua dan keduanya buruk: layar
  ///  kosong selama menunggu jaringan, atau peta di koordinat (0, 0) — Teluk
  ///  Guinea, yang membuat orang menyimpulkan aplikasinya rusak.
  ///
  ///  Nilainya titik tengah antara Medan dan Lubuk Pakam, sama dengan bawaan di
  ///  server. Keduanya memang tergandakan, dan itu ditanggung: yang satu ini
  ///  hanya dipakai beberapa ratus milidetik pertama, lalu ditimpa jawaban
  ///  server.
  /// ==========================================================================
  static const ServerConfig bawaan = _bawaan;

  static const ServerConfig _bawaan = ServerConfig(
    areaLat: 3.5697,
    areaLng: 98.7748,
    areaRadiusKm: 35,
    areaZoom: 12,
    areaLabel: 'Medan dan Lubuk Pakam',

    // Mati sampai server bilang sebaliknya — kolom pencarian yang muncul lalu
    // tidak pernah menemukan apa pun lebih buruk daripada kolom yang tidak ada.
    placesEnabled: false,
  );
}
