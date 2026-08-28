import 'dart:typed_data';

/// Hasil pengambilan foto.
///
/// ============================================================================
///  TIGA HASIL, BUKAN "File? YANG BISA NULL"
/// ============================================================================
///  `Future<File?>` menyatukan tiga keadaan yang tindakannya berbeda jauh:
///
///    Dibatalkan          pengguna menutup pemilih. Layar TIDAK boleh
///                        menampilkan apa pun — dia sendiri yang membatalkan.
///
///    Izin ditolak        bisa diminta lagi. Layar menampilkan alasannya dan
///                        tombol coba lagi.
///
///    Ditolak permanen    dialog izin TIDAK AKAN MUNCUL LAGI, apa pun yang
///                        dilakukan aplikasi. Satu-satunya jalan adalah
///                        pengaturan sistem, dan layar harus menawarkan
///                        tombol yang membukanya.
///
///  Yang terjadi kalau ketiganya jadi `null`: layar memperlakukan izin yang
///  ditolak permanen sebagai pembatalan, jadi tidak menampilkan apa pun. Pengguna
///  menekan tombol kamera, tidak ada yang terjadi, dan dia menekannya lagi —
///  selamanya, karena dialognya memang tidak akan pernah muncul.
///
///  Itu bug yang paling lazim di penanganan izin, dan bentuk `File?` yang
///  membuatnya hampir tidak bisa dihindari.
/// ============================================================================
sealed class MediaOutcome {
  const MediaOutcome();
}

/// Foto berhasil diambil.
class MediaPicked extends MediaOutcome {
  const MediaPicked({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  /// Isi berkasnya.
  ///
  /// ==========================================================================
  ///  BYTES, BUKAN JALUR BERKAS
  /// ==========================================================================
  ///  `image_picker` di web tidak punya jalur berkas sama sekali — yang ada
  ///  hanya blob di memori. Memakai `File` berarti seluruh alur ini tidak bisa
  ///  dicoba di Chrome, dan Chrome adalah tempat aplikasi ini dikembangkan
  ///  sehari-hari.
  ///
  ///  Selain itu berkas sementara dari kamera bisa DIHAPUS sistem sebelum
  ///  unggahannya selesai — Android membersihkan direktori cache tanpa
  ///  pemberitahuan saat penyimpanan menipis. Bytes yang sudah dibaca tidak bisa
  ///  hilang di tengah jalan.
  /// ==========================================================================
  final Uint8List bytes;

  final String fileName;

  /// `image/jpeg` atau `image/png`.
  ///
  /// Dikirim ke backend sebagai bagian dari multipart. Backend TIDAK
  /// mempercayainya — dia mengendus tipe sebenarnya dari isi berkasnya — tapi
  /// mengirimnya benar membuat penolakan jadi lebih jelas saat memang salah.
  final String mimeType;

  int get sizeBytes => bytes.length;

  double get sizeMb => bytes.length / (1024 * 1024);
}

/// Pengguna menutup pemilih tanpa memilih apa pun.
class MediaCancelled extends MediaOutcome {
  const MediaCancelled();
}

/// Izin belum diberikan, tapi masih bisa diminta.
class MediaPermissionDenied extends MediaOutcome {
  const MediaPermissionDenied(this.message);

  final String message;
}

/// Izin ditolak permanen — dialog sistem tidak akan muncul lagi.
///
/// Layar WAJIB menawarkan tombol yang membuka pengaturan aplikasi. Tanpa itu,
/// pengguna terkunci pada tombol yang tidak melakukan apa pun.
class MediaPermissionPermanentlyDenied extends MediaOutcome {
  const MediaPermissionPermanentlyDenied(this.message);

  final String message;
}

/// Gagal karena hal lain — kamera dipakai aplikasi lain, penyimpanan penuh.
class MediaFailed extends MediaOutcome {
  const MediaFailed(this.message);

  final String message;
}
