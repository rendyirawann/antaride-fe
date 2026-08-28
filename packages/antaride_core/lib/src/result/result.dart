import 'api_failure.dart';

/// Hasil operasi yang bisa gagal.
///
/// ============================================================================
///  KENAPA Result, BUKAN try/catch DI SETIAP LAYAR
/// ============================================================================
///  Dengan exception, kegagalan tidak muncul di tanda tangan fungsi. Layar yang
///  memanggil `api.createOrder()` tidak punya cara mengetahui bahwa dia bisa
///  melempar — dan yang terjadi adalah layar yang lupa menangkapnya, lalu
///  aplikasi menampilkan layar merah kepada penumpang yang sedang memesan.
///
///  Dengan `Result<T>`, kegagalannya ADA di tipe kembaliannya. Layar tidak bisa
///  memakai nilainya tanpa terlebih dulu menangani kemungkinan gagal — bukan
///  karena disiplin, tapi karena kompiler menolaknya.
///
///  Yang tetap dilempar sebagai exception: bug pemrograman (null yang tidak
///  seharusnya null, index di luar batas). Itu bukan kegagalan yang perlu
///  ditangani layar, itu kesalahan yang harus diperbaiki.
/// ============================================================================
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.err(ApiFailure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  /// Nilai kalau berhasil, null kalau gagal.
  ///
  /// Dipakai di tempat yang memang tidak peduli kenapa gagal — misalnya
  /// pemuatan data pelengkap yang boleh tidak ada.
  T? get valueOrNull => switch (this) {
    Ok<T>(value: final T v) => v,
    Err<T>() => null,
  };

  ApiFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(failure: final ApiFailure f) => f,
  };

  /// Ubah nilainya kalau berhasil.
  Result<R> map<R>(R Function(T value) ubah) => switch (this) {
    Ok<T>(value: final T v) => Ok<R>(ubah(v)),
    Err<T>(failure: final ApiFailure f) => Err<R>(f),
  };

  /// Rantai operasi yang juga bisa gagal.
  Result<R> flatMap<R>(Result<R> Function(T value) lanjut) => switch (this) {
    Ok<T>(value: final T v) => lanjut(v),
    Err<T>(failure: final ApiFailure f) => Err<R>(f),
  };

  /// Tangani kedua kemungkinan.
  ///
  /// Ini bentuk yang dipakai di layar: keduanya WAJIB ditangani, dan kompiler
  /// yang menegakkannya.
  R when<R>({
    required R Function(T value) ok,
    required R Function(ApiFailure failure) err,
  }) => switch (this) {
    Ok<T>(value: final T v) => ok(v),
    Err<T>(failure: final ApiFailure f) => err(f),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final ApiFailure failure;

  @override
  String toString() => 'Err($failure)';
}
