import 'dart:convert';
import 'dart:typed_data';

import 'package:antaride_api/antaride_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
///  BACKEND BISA BERADA DI SUBFOLDER, DAN APLIKASI TIDAK BOLEH MEMBUANGNYA
/// ============================================================================
///  Backend Antaride di-deploy di `https://domain.com/antaride/api/v1` — bukan
///  di akar domain. Aplikasi menerima alamat itu lewat
///  `--dart-define=API_BASE_URL` saat build.
///
///  Yang diuji di sini: subfolder-nya benar-benar ikut di setiap request yang
///  dikirim aplikasi.
///
///  Kalau tidak, gejalanya bukan galat yang menyebut subfolder: yang kembali
///  adalah 404 HTML dari web server, dan `ApiClient` menguraikannya sebagai
///  response yang bukan JSON — jadi yang muncul di layar adalah "Terjadi
///  gangguan. Coba lagi." pada SETIAP layar, tanpa satu pun petunjuk bahwa
///  masalahnya alamat.
/// ============================================================================
///
/// ============================================================================
///  KENAPA DIUJI DAN BUKAN DIASUMSIKAN
/// ============================================================================
///  Penggabungan `baseUrl` + `path` dilakukan Dio, bukan kode kita. Perilakunya
///  soal garis miring ganda TIDAK terdokumentasi sebagai jaminan, dan pernah
///  berubah antar versi mayor.
///
///  Berkas ini menyatakan perilaku yang kita ANDALKAN. Kalau pembaruan Dio
///  mengubahnya, yang gagal adalah test ini — bukan pemesanan di perangkat
///  pengguna.
/// ============================================================================
void main() {
  late _AdapterPencatat adapter;

  setUp(() => adapter = _AdapterPencatat());

  ApiClient buat(String baseUrl) {
    return ApiClient(
      tokenStore: TokenStore(),
      baseUrl: baseUrl,
      dio: Dio()..httpClientAdapter = adapter,
    );
  }

  group('Base URL di subfolder', () {
    /// ========================================================================
    ///  INI TEST YANG PALING PENTING DI BERKAS INI
    /// ========================================================================
    test('subfolder ikut di URL yang benar-benar diminta', () async {
      final ApiClient client = buat('https://domain.com/antaride/api/v1');

      await client.get('/driver/status');

      expect(
        adapter.terakhir,
        'https://domain.com/antaride/api/v1/driver/status',
        reason:
            'Subfolder hilang dari request. Server akan menjawab 404 HTML, dan '
            'aplikasi menampilkan "Terjadi gangguan" di SETIAP layar tanpa '
            'petunjuk bahwa masalahnya alamat.',
      );
    });

    /// Garis miring di akhir `baseUrl` TIDAK merusak apa pun.
    ///
    /// Orang yang menyiapkan build akan menuliskannya sesekali — `.../api/v1/`
    /// terasa lebih benar. Test ini menyatakan bahwa itu aman, supaya
    /// dokumentasi deploy tidak perlu mengancam soal hal yang tidak berbahaya.
    test(
      'garis miring di akhir baseUrl tidak menghasilkan slash ganda',
      () async {
        final ApiClient client = buat('https://domain.com/antaride/api/v1/');

        await client.get('/driver/status');

        expect(
          adapter.terakhir,
          isNot(contains('v1//driver')),
          reason: 'URL memuat garis miring ganda.',
        );

        expect(
          adapter.terakhir,
          'https://domain.com/antaride/api/v1/driver/status',
        );
      },
    );

    /// Query string tetap utuh di belakang subfolder.
    ///
    /// Yang dijaga: penggabungan yang benar untuk path, tapi salah begitu ada
    /// query — misalnya `?as=driver` pada notifikasi, yang menentukan
    /// notifikasi siapa yang tampil.
    test('query string tetap utuh', () async {
      final ApiClient client = buat('https://domain.com/antaride/api/v1');

      await client.get(
        '/notifications',
        query: <String, dynamic>{'as': 'driver', 'per_page': 20},
      );

      expect(adapter.terakhir, contains('/antaride/api/v1/notifications'));
      expect(adapter.terakhir, contains('as=driver'));
      expect(adapter.terakhir, contains('per_page=20'));
    });

    /// Unggahan multipart juga.
    ///
    /// Jalur unggah memakai `Options` tersendiri (timeout lebih panjang), jadi
    /// dia melewati kode yang berbeda dari `get`/`post` biasa — dan perbedaan
    /// itu yang membuatnya layak diuji terpisah.
    test('unggahan multipart memakai subfolder yang sama', () async {
      final ApiClient client = buat('https://domain.com/antaride/api/v1');

      await client.upload(
        '/driver/documents',
        field: 'file',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'ktp.jpg',
        mimeType: 'image/jpeg',
        fields: <String, dynamic>{'type': 'ktp'},
      );

      expect(
        adapter.terakhir,
        'https://domain.com/antaride/api/v1/driver/documents',
      );
    });

    /// Base URL di AKAR tetap bekerja.
    ///
    /// Ini yang menjaga pengembangan lokal: di sana backend di
    /// `http://127.0.0.1:8000/api/v1`, tanpa subfolder. Konfigurasi yang hanya
    /// benar untuk subfolder akan membuat aplikasi tidak bisa dijalankan di
    /// lokal.
    test('base URL tanpa subfolder tetap bekerja', () async {
      final ApiClient client = buat('http://127.0.0.1:8000/api/v1');

      await client.get('/driver/status');

      expect(adapter.terakhir, 'http://127.0.0.1:8000/api/v1/driver/status');
    });

    /// Path bersarang tidak kehilangan bagian mana pun.
    test('path bersarang utuh', () async {
      final ApiClient client = buat('https://domain.com/antaride/api/v1');

      await client.post('/driver/orders/abc-123/accept');

      expect(
        adapter.terakhir,
        'https://domain.com/antaride/api/v1/driver/orders/abc-123/accept',
      );
    });
  });
}

// =============================================================================

/// Adapter yang hanya mencatat URL yang diminta, lalu menjawab sukses.
class _AdapterPencatat implements HttpClientAdapter {
  String? terakhir;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // `options.uri` — URL LENGKAP hasil penggabungan Dio, bukan `options.path`
    // yang masih relatif. Yang diuji di sini justru penggabungannya.
    terakhir = options.uri.toString();

    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{},
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
