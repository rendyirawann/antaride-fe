import 'dart:typed_data';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Galat tanpa amplop `error` harus tetap menyebut status HTTP-nya.
///
/// ============================================================================
///  KENAPA BERKAS INI ADA
/// ============================================================================
///  Layar dasbor driver pernah menampilkan "Terjadi gangguan. Coba lagi." dan
///  penelusurannya berhenti di situ: endpoint-nya diperiksa dari luar dan
///  sehat 200 di tujuh puluh permintaan berurutan, jadi tidak ada cara
///  mengetahui apakah perangkat itu menerima 500, 429, atau 502.
///
///  Penyebab hilangnya keterangan: backend Antaride selalu membalas
///  `{"success":false,"error":{...}}`, tapi tidak semua yang menjawab
///  permintaan itu adalah backend Antaride. Laravel menjawab 429 dan 500 dengan
///  `{"message":...}` TANPA amplop `error`, dan Nginx bisa menjawab 502.
///  Ketiganya dulu jatuh ke satu pesan bawaan yang sama.
///
///  Yang dijaga berkas ini: kejadian berikutnya bisa dibaca dari layarnya.
/// ============================================================================
void main() {
  late _AdapterPalsu adapter;

  setUp(() => adapter = _AdapterPalsu());

  ApiClient buat() {
    return ApiClient(
      tokenStore: TokenStore(),
      baseUrl: 'https://contoh.test/api/v1',
      dio: Dio()..httpClientAdapter = adapter,
    );
  }

  Future<ApiFailure> gagalkan(
    int status,
    String badan, {
    String tipe = Headers.jsonContentType,
  }) async {
    adapter.status = status;
    adapter.badan = badan;
    adapter.tipe = tipe;

    final Result<Map<String, dynamic>> hasil = await buat().get(
      '/driver/status',
    );

    final ApiFailure? f = hasil.failureOrNull;

    expect(f, isNotNull, reason: 'Response $status seharusnya gagal.');

    return f!;
  }

  group('Badan galat TANPA amplop error', () {
    test(
      '429 Laravel menyebut batas permintaan, bukan "terjadi gangguan"',
      () async {
        // Bentuk asli jawaban Laravel untuk throttle.
        final ApiFailure f = await gagalkan(
          429,
          '{"message":"Too Many Attempts."}',
        );

        /*
         * `message` di PUNCAK badan sengaja TIDAK dipakai.
         *
         * Laravel mengirim "Too Many Attempts." — benar, tapi bahasa Inggris
         * dan menyebut istilah teknis yang tidak berarti bagi penumpang. Yang
         * ditampilkan pesan kami sendiri; yang penting kodenya tetap dikenali
         * sebagai batas laju, bukan sebagai "gangguan" yang tidak jelas.
         */
        expect(f.code, 'RATE_LIMITED');
        expect(f.statusCode, 429);
        expect(f.message, contains('Terlalu banyak permintaan'));
      },
    );

    test('429 tanpa pesan apa pun tetap menyebut batas permintaan', () async {
      final ApiFailure f = await gagalkan(429, '{"success":false}');

      expect(f.code, 'RATE_LIMITED');
      expect(f.message, contains('Terlalu banyak permintaan'));
    });

    test('500 menyebut status HTTP-nya', () async {
      final ApiFailure f = await gagalkan(500, '{"success":false}');

      expect(f.code, 'SERVER_ERROR');

      // Angka di pesannya yang membuat kejadian berikutnya bisa didiagnosis
      // dari sebuah screenshot.
      expect(f.message, contains('500'));
      expect(f.message, contains('Server sedang bermasalah'));
    });

    test('502 dari Nginx juga menyebut statusnya', () async {
      final ApiFailure f = await gagalkan(502, '{"success":false}');

      expect(f.code, 'SERVER_ERROR');
      expect(f.message, contains('502'));
    });

    test(
      '403 menyebut bahwa server MENOLAK, bukan bahwa ada gangguan',
      () async {
        // Bedanya penting: "gangguan" mengarahkan orang memeriksa jaringannya,
        // padahal jaringannya baik-baik saja dan permintaannya memang ditolak.
        final ApiFailure f = await gagalkan(403, '{"success":false}');

        expect(f.message, contains('403'));
        expect(f.message, contains('ditolak server'));
      },
    );
  });

  group('Amplop error yang lengkap tetap diutamakan', () {
    test('pesan dari backend dipakai apa adanya', () async {
      final ApiFailure f = await gagalkan(
        403,
        '{"success":false,"error":{"code":"FORBIDDEN",'
        '"message":"Akun Anda bukan akun driver."}}',
      );

      /*
       * Ini yang TIDAK boleh rusak oleh perubahan di atas.
       *
       * Pesan backend jauh lebih berguna daripada apa pun yang bisa disimpulkan
       * dari status HTTP: "Akun Anda bukan akun driver" memberi tahu penyebab
       * DAN jalan keluarnya, sementara "ditolak server (HTTP 403)" hanya
       * memberi tahu bahwa sesuatu ditolak.
       */
      expect(f.code, 'FORBIDDEN');
      expect(f.message, 'Akun Anda bukan akun driver.');
    });
  });

  test('badan HTML tetap terbaca sebagai response yang rusak', () async {
    /*
     * Portal WiFi hotel dan halaman galat web server: keduanya mengirim
     * `text/html` dengan status 200. Sudah ditangani sebelum perubahan di atas,
     * dan diuji supaya tetap begitu.
     *
     * Tipe isinya HARUS text/html, bukan application/json. Dengan tipe JSON,
     * Dio gagal mem-parse HTML-nya lebih dulu dan kegagalannya sampai di sini
     * sebagai galat jaringan — bukan sebagai response yang rusak. Itu kasus
     * yang berbeda dan jauh lebih jarang; yang umum adalah proxy yang jujur
     * menyebut isinya HTML.
     */
    final ApiFailure f = await gagalkan(
      200,
      '<html><body>Gateway</body></html>',
      tipe: 'text/html',
    );

    expect(f.code, 'MALFORMED_RESPONSE');
  });
}

// -----------------------------------------------------------------------------

class _AdapterPalsu implements HttpClientAdapter {
  int status = 200;
  String badan = '{"success":true,"data":{}}';
  String tipe = Headers.jsonContentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      badan,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[tipe],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
