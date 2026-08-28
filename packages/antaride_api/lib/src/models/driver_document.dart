/// Satu dokumen KYC driver.
///
/// ============================================================================
///  TIDAK PERNAH MEMUAT PATH BERKASNYA
/// ============================================================================
///  Backend sengaja tidak mengirimkannya — disk KYC privat, dan path mentah tidak
///  berguna bagi aplikasi. Yang dikirim [previewUrl]: URL bertanda tangan berumur
///  lima menit.
///
///  Konsekuensinya bagi layar: URL itu KADALUARSA. Menyimpannya di state lalu
///  menampilkannya setengah jam kemudian menghasilkan gambar yang gagal dimuat,
///  dan yang terlihat driver adalah dokumennya "hilang". Layar harus memuat
///  ulang daftarnya kalau pratinjaunya perlu dibuka lagi.
/// ============================================================================
class DriverDocument {
  const DriverDocument({
    required this.uuid,
    required this.type,
    required this.label,
    required this.status,
    required this.needsExpiry,
    required this.isExpired,
    this.rejectReason,
    this.expiresAt,
    this.previewUrl,
    this.uploadedAt,
    this.reviewedAt,
  });

  final String uuid;

  /// `ktp`, `sim`, `stnk`, `skck`, `selfie`, `bank_book`, `vaccine`.
  final String type;

  /// Nama yang siap ditampilkan, dari backend.
  ///
  /// Bukan diterjemahkan di aplikasi. Jenis dokumen bisa bertambah — misalnya
  /// kalau ada peraturan daerah baru — dan aplikasi lama yang menerjemahkannya
  /// sendiri akan menampilkan `bank_book` mentah untuk jenis yang belum dia
  /// kenal.
  final String label;

  /// `pending`, `approved`, atau `rejected`.
  final String status;

  /// Alasan penolakan dari verifikator.
  ///
  /// Ini satu-satunya cara driver mengetahui apa yang salah dengan dokumennya.
  /// Tanpa menampilkannya, dia mengunggah foto yang sama berulang kali — dan
  /// setiap putaran memakan waktu verifikator juga.
  final String? rejectReason;

  final DateTime? expiresAt;

  /// Apakah jenis ini WAJIB punya tanggal berlaku.
  ///
  /// Dari backend, bukan disimpulkan aplikasi. Dipakai layar untuk memutuskan
  /// apakah kolom tanggal ditampilkan — menampilkannya untuk KTP akan membuat
  /// driver mencari tanggal yang tidak ada di kartunya.
  final bool needsExpiry;

  final bool isExpired;

  /// URL bertanda tangan berumur pendek. Lihat docblock kelas.
  final String? previewUrl;

  final DateTime? uploadedAt;
  final DateTime? reviewedAt;

  bool get isApproved => status == 'approved';

  bool get isRejected => status == 'rejected';

  bool get isPending => status == 'pending';

  /// Kalimat status yang siap ditampilkan.
  ///
  /// Dokumen yang KADALUARSA disebut kadaluarsa, walaupun statusnya `approved`.
  /// Keduanya benar sekaligus — dia pernah lolos verifikasi, dan sekarang tidak
  /// berlaku — tapi yang perlu driver ketahui adalah yang kedua: dia tidak bisa
  /// online sampai memperbaruinya.
  String get statusLabel {
    if (isApproved && isExpired) {
      return 'Kadaluarsa';
    }

    return switch (status) {
      'approved' => 'Disetujui',
      'rejected' => 'Ditolak',
      'pending' => 'Menunggu verifikasi',
      _ => status,
    };
  }

  factory DriverDocument.fromJson(Map<String, dynamic> json) => DriverDocument(
    uuid: json['uuid'] as String,
    type: json['type'] as String? ?? '',
    label: json['label'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    rejectReason: json['reject_reason'] as String?,
    expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
    needsExpiry: json['needs_expiry'] as bool? ?? false,
    isExpired: json['is_expired'] as bool? ?? false,
    previewUrl: json['preview_url'] as String?,
    uploadedAt: DateTime.tryParse(
      json['uploaded_at'] as String? ?? '',
    )?.toLocal(),
    reviewedAt: DateTime.tryParse(
      json['reviewed_at'] as String? ?? '',
    )?.toLocal(),
  );
}

/// Seluruh keadaan dokumen driver, beserta yang masih kurang.
///
/// ============================================================================
///  YANG KURANG IKUT DIKIRIM BACKEND, TIDAK DIHITUNG APLIKASI
/// ============================================================================
///  Aplikasi bisa menghitungnya sendiri: daftar wajib dikurangi yang sudah
///  disetujui. Yang membuatnya salah: daftar wajibnya ada di konfigurasi backend
///  (`antaride.kyc.required_documents`) dan bisa berubah — misalnya kalau ada
///  peraturan daerah yang menuntut dokumen tambahan.
///
///  Aplikasi yang menyimpan daftarnya sendiri akan menyatakan driver sudah
///  lengkap sementara backend menolaknya online. Dan driver tidak punya satu pun
///  petunjuk tentang dokumen apa yang sebenarnya diminta.
/// ============================================================================
class DriverDocumentState {
  const DriverDocumentState({
    required this.documents,
    required this.required,
    required this.missing,
    required this.expired,
    required this.canGoOnline,
  });

  final List<DriverDocument> documents;

  /// Jenis dokumen yang wajib untuk bisa bekerja.
  final List<String> required;

  /// Jenis wajib yang belum DISETUJUI.
  ///
  /// Yang masih `pending` tetap masuk daftar ini — dia belum bisa dipakai
  /// bekerja, dan driver yang melihatnya hilang akan menyimpulkan dia sudah bisa
  /// online.
  final List<String> missing;

  /// Jenis yang perlu DIPERBARUI karena tanggalnya sudah lewat.
  ///
  /// ==========================================================================
  ///  DIPISAH DARI [missing] KARENA TINDAKANNYA BERBEDA
  /// ==========================================================================
  ///  Yang `missing` belum pernah diunggah atau belum diperiksa — driver
  ///  menyelesaikannya dengan memfoto dokumennya.
  ///
  ///  Yang di sini pernah LOLOS verifikasi, dan sekarang perlu diperpanjang di
  ///  kantor yang menerbitkannya. Memfotonya ulang tidak menyelesaikan apa pun,
  ///  dan kalimat yang menyuruhnya mengunggah ulang akan membuatnya mencoba
  ///  berulang untuk masalah yang tidak ada di aplikasi.
  ///
  ///  Memuat jenis yang TIDAK wajib juga — SKCK kadaluarsa yang tersimpan
  ///  sebagai disetujui tetap menghalangi online, karena `GoOnline` tidak
  ///  membedakannya.
  /// ==========================================================================
  final List<String> expired;

  /// Apakah backend akan MENGIZINKAN driver online.
  ///
  /// Dihitung backend, bukan disimpulkan aplikasi dari [missing]. Yang
  /// dijaga: `GoOnline` menolak dokumen kadaluarsa juga, dan aplikasi yang
  /// menghitungnya sendiri dari daftar wajib akan menyatakan driver siap lalu
  /// tombol online-nya ditolak — tanpa satu pun petunjuk kenapa.
  final bool canGoOnline;

  /// Dokumen untuk satu jenis, atau null kalau belum diunggah.
  DriverDocument? forType(String type) {
    for (final DriverDocument d in documents) {
      if (d.type == type) {
        return d;
      }
    }

    return null;
  }

  factory DriverDocumentState.fromJson(Map<String, dynamic> json) {
    return DriverDocumentState(
      documents: ((json['documents'] as List<dynamic>?) ?? const <dynamic>[])
          .map(
            (dynamic e) => DriverDocument.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      required: ((json['required'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(),
      missing: ((json['missing'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(),
      expired: ((json['expired'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(),
      canGoOnline: json['can_go_online'] as bool? ?? false,
    );
  }
}
