/// Kegagalan dari API, dalam bentuk yang bisa ditindaklanjuti.
///
/// ============================================================================
///  `code` YANG DICOCOKKAN, BUKAN `message`
/// ============================================================================
///  Backend Antaride mengirim setiap galat sebagai:
///
///      { "success": false,
///        "error": { "code": "INSUFFICIENT_BALANCE",
///                   "message": "Saldo tidak cukup. Saldo Anda Rp 12.000...",
///                   "details": { "available": 12000, "shortfall": 13000 } } }
///
///  Aplikasi bereaksi berdasarkan `code`, dan MENAMPILKAN `message`.
///
///  Mencocokkan `message` adalah kesalahan yang akan diam-diam merusak aplikasi
///  lama: pesan berubah begitu ada yang memperbaiki tata bahasanya, dan aplikasi
///  yang mencocokkan teks berhenti mengenali kasus itu tanpa satu pun error.
///  Pengguna yang belum memperbarui aplikasi tidak akan pernah tahu.
///
///  `code` adalah bagian dari kontrak dan tidak pernah diubah setelah dirilis.
/// ============================================================================
class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const <String, dynamic>{},
  });

  /// Kode mesin-readable dari backend.
  final String code;

  /// Pesan yang SUDAH ditulis untuk dibaca pengguna.
  ///
  /// Backend menulisnya lengkap dengan angka dan langkah berikutnya — "Saldo
  /// Anda Rp 12.000, kurang Rp 13.000". Menggantinya dengan teks generik di
  /// aplikasi membuang seluruh usaha itu.
  final String message;

  final int? statusCode;

  /// Data tambahan, misalnya saldo saat ini pada kasus saldo tidak cukup.
  ///
  /// Ini yang membuat aplikasi bisa menampilkan tombol "Top up sekarang" dengan
  /// nominal yang tepat tanpa memanggil endpoint lain.
  final Map<String, dynamic> details;

  // ---------------------------------------------------------------------------
  //  Kegagalan yang bukan dari backend
  // ---------------------------------------------------------------------------

  /// Jaringan tidak bisa dijangkau.
  ///
  /// Dibedakan dari galat server, karena tindak lanjutnya berbeda: yang ini
  /// berarti "periksa koneksi Anda", bukan "coba lagi nanti".
  factory ApiFailure.network() => const ApiFailure(
    code: 'NETWORK_UNREACHABLE',
    message: 'Tidak ada koneksi internet. Periksa jaringan Anda.',
  );

  factory ApiFailure.timeout() => const ApiFailure(
    code: 'TIMEOUT',
    message: 'Jaringan terlalu lambat. Coba lagi.',
  );

  /// Response yang bentuknya tidak dikenali.
  ///
  /// Terjadi kalau ada proxy yang menyisipkan halaman HTML, atau kalau versi
  /// API-nya berubah. Pesannya sengaja tidak menyebut "JSON tidak valid" —
  /// itu benar tapi tidak berarti apa pun bagi pengguna.
  factory ApiFailure.malformed() => const ApiFailure(
    code: 'MALFORMED_RESPONSE',
    message: 'Ada gangguan pada server. Coba lagi sesaat.',
  );

  factory ApiFailure.unknown([String? pesan]) => ApiFailure(
    code: 'UNKNOWN',
    message: pesan ?? 'Terjadi gangguan. Coba lagi.',
  );

  // ---------------------------------------------------------------------------
  //  Kategori
  // ---------------------------------------------------------------------------

  /// Sesi tidak berlaku. Aplikasi harus mengeluarkan pengguna.
  bool get isUnauthenticated => code == 'UNAUTHENTICATED' || statusCode == 401;

  /// Kegagalan validasi. Aplikasi menampilkannya di kolom yang bersangkutan,
  /// bukan sebagai dialog.
  bool get isValidation => code == 'VALIDATION_FAILED' || statusCode == 422;

  /// Layak dicoba lagi dengan tombol.
  ///
  /// Yang TIDAK layak: galat validasi (harus diperbaiki dulu), dan konflik
  /// seperti "order sudah diambil driver lain" (mencoba lagi tidak mengubah
  /// apa pun).
  bool get isRetryable =>
      code == 'NETWORK_UNREACHABLE' ||
      code == 'TIMEOUT' ||
      code == 'MALFORMED_RESPONSE' ||
      (statusCode != null && statusCode! >= 500);

  /// Kesalahan per kolom, untuk galat validasi.
  ///
  /// Bentuknya di `details`: `{"phone": ["Nomor HP wajib diisi."]}`.
  Map<String, String> get fieldErrors {
    final Map<String, String> hasil = <String, String>{};

    for (final MapEntry<String, dynamic> entry in details.entries) {
      final dynamic nilai = entry.value;

      if (nilai is List && nilai.isNotEmpty) {
        hasil[entry.key] = nilai.first.toString();
      } else if (nilai is String) {
        hasil[entry.key] = nilai;
      }
    }

    return hasil;
  }

  @override
  String toString() => 'ApiFailure($code, $statusCode): $message';
}
