import 'package:antaride_core/antaride_core.dart';

import '../client/api_client.dart';
import '../models/quote.dart';

/// Estimasi harga dan katalog layanan.
class QuoteRepository {
  const QuoteRepository(this._client);

  final ApiClient _client;

  /// Daftar layanan yang aktif. TANPA autentikasi.
  ///
  /// Dipakai di layar pertama sebelum pengguna masuk, supaya orang bisa melihat
  /// apa saja yang ditawarkan sebelum menyerahkan nomor HP-nya.
  Future<Result<List<ServiceTypeInfo>>> serviceTypes() async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/service-types',
    );

    return hasil.map((Map<String, dynamic> badan) {
      final List<dynamic> data =
          (badan['data'] as List<dynamic>?) ?? const <dynamic>[];

      return data
          .map(
            (dynamic e) => ServiceTypeInfo.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    });
  }

  /// Minta estimasi harga untuk satu rute.
  ///
  /// ==========================================================================
  ///  ENDPOINT INI MAHAL, DAN AKAN DIPANGGIL TERLALU SERING
  /// ==========================================================================
  ///  Setiap panggilan memanggil OSRM untuk rutenya lalu menghitung tarif untuk
  ///  SELURUH layanan yang diminta. Backend membatasi lajunya, dan batas itu
  ///  akan tercapai kalau layar memanggilnya setiap kali pin peta bergerak.
  ///
  ///  Yang benar di layar peta: debounce sampai pin berhenti — dan itu tanggung
  ///  jawab layar, bukan repository ini. Repository yang men-debounce sendiri
  ///  akan menahan panggilan yang memang harus segera, misalnya saat penumpang
  ///  menekan "cek harga".
  /// ==========================================================================
  ///
  /// [serviceCodes] boleh dikosongkan; backend akan menghitung untuk semua
  /// layanan yang cocok dengan rutenya. Membatasinya membuat response lebih
  /// kecil dan perhitungannya lebih cepat, jadi layar yang hanya menampilkan
  /// ojek sebaiknya menyebutkannya.
  Future<Result<Quote>> create({
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    List<({double lat, double lng})> stops =
        const <({double lat, double lng})>[],
    List<String> serviceCodes = const <String>[],
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.post(
      '/quotes',
      body: <String, dynamic>{
        'pickup': <String, double>{'lat': pickupLat, 'lng': pickupLng},
        'destination': <String, double>{'lat': destLat, 'lng': destLng},
        if (stops.isNotEmpty)
          'stops': stops
              .map(
                (({double lat, double lng}) s) => <String, double>{
                  'lat': s.lat,
                  'lng': s.lng,
                },
              )
              .toList(),
        if (serviceCodes.isNotEmpty) 'service_codes': serviceCodes,
      },
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          Quote.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Ambil ulang quote yang sudah ada.
  ///
  /// Dipakai saat aplikasi kembali dari latar belakang di layar konfirmasi:
  /// lebih murah daripada menghitung ulang, dan yang perlu diketahui layar hanya
  /// apakah quote-nya masih hidup.
  ///
  /// Gagal dengan galat kalau quote-nya sudah kadaluarsa — dan itu jawaban yang
  /// benar, bukan kegagalan yang perlu disembunyikan. Layar meresponsnya dengan
  /// meminta quote baru.
  Future<Result<Quote>> show(String quoteId) async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/quotes/$quoteId',
    );

    return hasil.map(
      (Map<String, dynamic> badan) =>
          Quote.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }
}
