import '../client/api_client.dart';
import '../models/server_config.dart';
import '../models/place.dart';

/// Konfigurasi aplikasi dan pencarian alamat.
///
/// ============================================================================
///  TIDAK SATU PUN METODE DI SINI MENGEMBALIKAN `Result`
/// ============================================================================
///  Pola repository lain di paket ini mengembalikan `Result` supaya pemanggil
///  memutuskan cara menampilkan galat. Di sini SENGAJA tidak, karena tidak ada
///  satu pun pemanggilnya yang punya cara masuk akal untuk menampilkan galat:
///
///    - `config()` dipanggil saat aplikasi mulai. Galat di sana hanya berarti
///      peta memakai titik tengah bawaan sampai panggilan berikutnya berhasil.
///    - `search()` dipanggil pada setiap ketikan. Pesan merah yang muncul dan
///      hilang mengikuti ketikan lebih mengganggu daripada daftar kosong.
///    - `reverse()` mengisi kolom alamat sebagai kemudahan. Gagal berarti
///      penggunanya mengetik sendiri, seperti sebelum fitur ini ada.
///
///  Tipe yang memaksa menangani galat, di tempat yang tidak punya cara
///  menanganinya, hanya menghasilkan `.valueOrNull` di setiap pemanggilan —
///  yaitu perilaku ini, dengan langkah tambahan.
/// ============================================================================
class PlaceRepository {
  const PlaceRepository(this._client);

  final ApiClient _client;

  /// Konfigurasi server. Gagal berarti memakai [ServerConfig.bawaan].
  Future<ServerConfig> config() async {
    final hasil = await _client.get('/config');

    return hasil.when(
      ok: (Map<String, dynamic> badan) {
        final Map<String, dynamic> data =
            (badan['data'] as Map<String, dynamic>?) ?? const {};

        return ServerConfig.fromJson(data);
      },
      err: (_) => ServerConfig.bawaan,
    );
  }

  /// Cari alamat. Daftar kosong untuk kata kunci pendek maupun kegagalan.
  ///
  /// [dekat] hanya mengurutkan hasil, bukan menyaringnya — penyaringan area
  /// dilakukan server lewat viewbox geocoder.
  Future<List<Place>> search(String kueri, {double? lat, double? lng}) async {
    final String q = kueri.trim();

    // Dijaga DI SINI juga, bukan hanya di server: setiap ketikan pertama dari
    // setiap pengguna akan memanggil jaringan tanpa satu pun hasil berguna.
    if (q.length < 3) {
      return const <Place>[];
    }

    final hasil = await _client.get(
      '/places/search',
      query: <String, dynamic>{'q': q, 'lat': ?lat, 'lng': ?lng},
    );

    return hasil.when(
      ok: (Map<String, dynamic> badan) {
        final Map<String, dynamic> data =
            (badan['data'] as Map<String, dynamic>?) ?? const {};

        final List<dynamic> daftar =
            (data['places'] as List<dynamic>?) ?? const <dynamic>[];

        return daftar
            .map((dynamic e) => Place.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      err: (_) => const <Place>[],
    );
  }

  /// Alamat untuk satu koordinat. Null kalau tidak ada atau gagal.
  ///
  /// Null BUKAN keadaan galat: titik di tengah sawah memang tidak punya alamat,
  /// dan layar menanganinya dengan membiarkan kolomnya kosong untuk diisi
  /// sendiri.
  Future<Place?> reverse(double lat, double lng) async {
    final hasil = await _client.get(
      '/places/reverse',
      query: <String, dynamic>{'lat': lat, 'lng': lng},
    );

    return hasil.when(
      ok: (Map<String, dynamic> badan) {
        final Map<String, dynamic> data =
            (badan['data'] as Map<String, dynamic>?) ?? const {};

        final Map<String, dynamic>? tempat =
            data['place'] as Map<String, dynamic>?;

        return tempat == null ? null : Place.fromJson(tempat);
      },
      err: (_) => null,
    );
  }
}
