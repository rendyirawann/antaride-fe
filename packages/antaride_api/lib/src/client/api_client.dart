import 'dart:async';

import 'dart:typed_data';

import 'package:antaride_core/antaride_core.dart';
import 'package:dio/dio.dart';

import 'token_store.dart';

/// Client HTTP untuk API Antaride.
///
/// ============================================================================
///  SATU BENTUK RESPONSE, DIURAI DI SATU TEMPAT
/// ============================================================================
///  Seluruh API membalas dalam bentuk yang sama:
///
///      { "success": true,  "data": {...}, "meta": {...} }
///      { "success": false, "error": { "code", "message", "details" } }
///
///  Penguraiannya ada DI SINI, bukan di setiap pemanggil. Kalau tidak, setiap
///  repository akan menulis ulang `response.data['data']` dan penanganan
///  galatnya sendiri — dan satu di antaranya akan lupa memeriksa `success`,
///  lalu memperlakukan galat sebagai data.
/// ============================================================================
///
/// ============================================================================
///  IDEMPOTENCY-KEY DIBUAT DI SINI, BUKAN DI LAYAR
/// ============================================================================
///  Setiap endpoint yang memindahkan uang menuntut header `Idempotency-Key`.
///  Kunci itu dibuat SEKALI per operasi dan DIPAKAI ULANG saat mencoba lagi —
///  itu seluruh gunanya.
///
///  Kalau layar yang membuatnya, akan ada layar yang membuat kunci baru setiap
///  kali menekan tombol. Konsekuensinya: penumpang yang menekan "Pesan" dua kali
///  mendapat DUA order, karena backend melihat dua kunci berbeda dan menganggap
///  keduanya permintaan yang berbeda.
///
///  `postIdempotent` di bawah yang mengelolanya, dan layar hanya perlu memanggil
///  operasi itu.
/// ============================================================================
class ApiClient {
  ApiClient({
    required TokenStore tokenStore,
    String? baseUrl,
    Dio? dio,
    this.onUnauthenticated,
  }) : _tokenStore = tokenStore,
       _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: AppConfig.timeoutSeconds),
      receiveTimeout: const Duration(seconds: AppConfig.timeoutSeconds),
      sendTimeout: const Duration(seconds: AppConfig.timeoutSeconds),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },

      /*
       * Dio TIDAK melempar exception untuk status apa pun.
       *
       * Seluruh penanganan galat lewat satu jalur di `_kirim`, dan itu yang
       * membuat setiap galat — 4xx, 5xx, timeout, jaringan mati — keluar dalam
       * bentuk ApiFailure yang sama.
       *
       * Kalau Dio melempar untuk 4xx dan mengembalikan untuk 2xx, akan ada dua
       * jalur yang harus sepakat, dan yang kedua akan tertinggal.
       */
      validateStatus: (int? _) => true,
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final String? token = _tokenStore.token;

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStore _tokenStore;

  /// Dipanggil saat API membalas 401.
  ///
  /// Aplikasi memakai ini untuk mengeluarkan pengguna dan kembali ke layar
  /// masuk. Ditangani di satu tempat karena kalau setiap layar menanganinya
  /// sendiri, akan ada layar yang membiarkan pengguna terjebak di halaman yang
  /// setiap request-nya gagal.
  final void Function()? onUnauthenticated;

  // ---------------------------------------------------------------------------
  //  Operasi dasar
  // ---------------------------------------------------------------------------

  Future<Result<Map<String, dynamic>>> get(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _kirim(() => _dio.get<dynamic>(path, queryParameters: query));
  }

  Future<Result<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _kirim(() => _dio.post<dynamic>(path, data: body));
  }

  Future<Result<Map<String, dynamic>>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _kirim(() => _dio.patch<dynamic>(path, data: body));
  }

  Future<Result<Map<String, dynamic>>> delete(String path) {
    return _kirim(() => _dio.delete<dynamic>(path));
  }

  /// POST multipart untuk mengunggah satu berkas.
  ///
  /// ==========================================================================
  ///  TIMEOUT-NYA SENDIRI, DAN JAUH LEBIH PANJANG
  /// ==========================================================================
  ///  Timeout bawaan client ini 20 detik — dipilih supaya request yang
  ///  menggantung tidak terbaca sebagai aplikasi yang mati.
  ///
  ///  Untuk unggahan itu terlalu pendek. Foto 300 KB di jaringan 3G yang buruk
  ///  butuh lebih dari 20 detik, dan yang terjadi kalau timeout-nya dibiarkan:
  ///  unggahan yang SEBENARNYA berhasil dibatalkan sepihak oleh aplikasi, dan
  ///  driver mengunggahnya lagi. Beberapa kali.
  ///
  ///  Yang dipanjangkan hanya `send` dan `receive` — bukan `connect`. Koneksi
  ///  yang tidak terbentuk dalam 20 detik memang tidak akan terbentuk, dan
  ///  menunggunya lebih lama tidak membeli apa pun.
  /// ==========================================================================
  ///
  /// ==========================================================================
  ///  BYTES, BUKAN JALUR BERKAS
  /// ==========================================================================
  ///  `MultipartFile.fromBytes`, bukan `fromFile`. Dua alasannya:
  ///
  ///    * Di web tidak ada jalur berkas sama sekali — yang ada blob di memori.
  ///      `fromFile` membuat seluruh alur unggah tidak bisa dicoba di Chrome,
  ///      tempat aplikasi ini dikembangkan sehari-hari.
  ///
  ///    * Berkas sementara dari kamera bisa DIHAPUS sistem sebelum unggahannya
  ///      selesai. Android membersihkan direktori cache tanpa pemberitahuan saat
  ///      penyimpanan menipis, dan yang terlihat adalah unggahan yang gagal
  ///      dengan galat "berkas tidak ditemukan" untuk foto yang baru diambil.
  /// ==========================================================================
  Future<Result<Map<String, dynamic>>> upload(
    String path, {
    required String field,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    Map<String, dynamic> fields = const <String, dynamic>{},
    void Function(int terkirim, int total)? onProgress,
  }) {
    return _kirim(() {
      final FormData form = FormData.fromMap(<String, dynamic>{
        ...fields,
        field: MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: mimeType == null ? null : DioMediaType.parse(mimeType),
        ),
      });

      return _dio.post<dynamic>(
        path,
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),

        /*
         * Kemajuan unggahan dilaporkan ke pemanggil.
         *
         * Bukan hiasan: unggahan foto di jaringan buruk bisa memakan setengah
         * menit, dan layar tanpa indikator kemajuan selama itu terbaca sebagai
         * aplikasi yang menggantung. Driver akan menutupnya dan mengulang dari
         * awal — tepat hal yang paling merugikan.
         */
        onSendProgress: onProgress,
      );
    });
  }

  /// POST yang membawa Idempotency-Key.
  ///
  /// [idempotencyKey] harus DIBUAT SEKALI per operasi dan dipakai ulang saat
  /// mencoba lagi. Lihat penjelasan di docblock kelas.
  Future<Result<Map<String, dynamic>>> postIdempotent(
    String path, {
    required String idempotencyKey,
    Map<String, dynamic>? body,
  }) {
    return _kirim(
      () => _dio.post<dynamic>(
        path,
        data: body,
        options: Options(
          headers: <String, String>{'Idempotency-Key': idempotencyKey},
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Future<Result<Map<String, dynamic>>> _kirim(
    Future<Response<dynamic>> Function() panggil,
  ) async {
    try {
      final Response<dynamic> response = await panggil();

      return _urai(response);
    } on DioException catch (e) {
      return Err<Map<String, dynamic>>(_dariDioException(e));
    } catch (_) {
      /*
       * Exception apa pun yang tidak dikenali TIDAK boleh keluar dari lapisan
       * ini.
       *
       * Kalau keluar, dia akan sampai ke widget dan menghasilkan layar merah —
       * dan layar merah kepada penumpang yang sedang memesan adalah bentuk
       * kegagalan yang paling buruk dari semuanya: dia tidak menjelaskan apa
       * pun dan tidak memberi jalan keluar.
       */
      return Err<Map<String, dynamic>>(ApiFailure.unknown());
    }
  }

  Result<Map<String, dynamic>> _urai(Response<dynamic> response) {
    final dynamic badan = response.data;

    if (badan is! Map<String, dynamic>) {
      /*
       * Response yang bukan JSON hampir selalu berarti ada yang menyisipkan
       * halaman HTML di tengah jalan: portal WiFi hotel, proxy kantor, atau
       * halaman error web server.
       *
       * Yang PENTING di sini: 200 dengan badan HTML tidak boleh diperlakukan
       * sebagai berhasil. Tanpa pemeriksaan ini, aplikasi akan mencoba membaca
       * `data` dari string HTML dan gagal jauh di dalam kode parsing — dengan
       * pesan galat yang tidak menunjuk ke penyebab sebenarnya.
       */
      return Err<Map<String, dynamic>>(ApiFailure.malformed());
    }

    final bool sukses = badan['success'] == true;

    if (sukses) {
      final dynamic data = badan['data'];

      return Ok<Map<String, dynamic>>(<String, dynamic>{
        'data': data,

        // `meta` dibawa apa adanya, termasuk cursor pagination. Layar yang
        // tidak membutuhkannya cukup mengabaikannya.
        if (badan['meta'] != null) 'meta': badan['meta'],
      });
    }

    final Map<String, dynamic> galat =
        (badan['error'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final ApiFailure kegagalan = ApiFailure(
      code: galat['code'] as String? ?? 'UNKNOWN',
      message: galat['message'] as String? ?? 'Terjadi gangguan. Coba lagi.',
      statusCode: response.statusCode,
      details:
          (galat['details'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );

    if (kegagalan.isUnauthenticated) {
      onUnauthenticated?.call();
    }

    return Err<Map<String, dynamic>>(kegagalan);
  }

  ApiFailure _dariDioException(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiFailure.timeout(),

      DioExceptionType.connectionError => ApiFailure.network(),

      // `badResponse` seharusnya tidak pernah terjadi karena validateStatus
      // menerima semua status. Kalau sampai terjadi, response-nya tetap diurai
      // supaya pesan dari backend tidak hilang.
      DioExceptionType.badResponse =>
        e.response == null
            ? ApiFailure.unknown()
            : (_urai(e.response!).failureOrNull ?? ApiFailure.unknown()),

      DioExceptionType.cancel => const ApiFailure(
        code: 'CANCELLED',
        message: 'Permintaan dibatalkan.',
      ),

      _ => ApiFailure.network(),
    };
  }
}
