/// Profil pengguna yang sedang masuk.
///
/// Bentuknya mengikuti `UserResource` di backend. Yang sengaja TIDAK ada di
/// sana dan karenanya tidak ada di sini: id auto-increment, dan siapa yang
/// mereferalkan pengguna ini.
class AuthUser {
  const AuthUser({
    required this.uuid,
    required this.name,
    required this.phone,
    required this.status,
    required this.referralCode,
    required this.phoneVerified,
    required this.profileComplete,
    this.email,
    this.photoUrl,
    this.gender,
    this.birthDate,
    this.joinedAt,
  });

  final String uuid;
  final String name;

  /// Nomor sendiri, dalam bentuk lokal yang enak dibaca (`0812...`).
  ///
  /// Backend yang memformatnya. Aplikasi tidak menormalkan nomor sama sekali —
  /// kecuali saat MENGIRIM, dan di situ pun backend yang menjadi penentunya.
  final String phone;

  final String? email;
  final String? photoUrl;
  final String? gender;
  final String? birthDate;

  /// `active`, `suspended`, atau `banned`.
  final String status;

  final String referralCode;
  final bool phoneVerified;

  /// Apakah profilnya masih perlu dilengkapi.
  ///
  /// Datang dari backend, TIDAK disimpulkan di sini.
  ///
  /// Backend menyimpulkannya dari email yang masih kosong dan nama yang masih
  /// berbentuk "Pengguna 7890". Kalau aplikasi menyimpulkannya sendiri, orang
  /// yang benar-benar menamai dirinya seperti itu akan terus diminta melengkapi
  /// profil yang sudah lengkap.
  final bool profileComplete;

  final DateTime? joinedAt;

  bool get isActive => status == 'active';

  /// Akun yang diblokir atau ditangguhkan.
  ///
  /// Layar menampilkan alasannya dan jalan menghubungi bantuan, bukan sekadar
  /// menolak. Orang yang akunnya ditangguhkan tanpa penjelasan akan mengira
  /// aplikasinya rusak dan memasang ulang — yang tidak menyelesaikan apa pun.
  bool get isBlocked => status == 'suspended' || status == 'banned';

  /// Inisial untuk avatar, dipakai saat [photoUrl] kosong.
  String get initials {
    final List<String> bagian = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();

    if (bagian.isEmpty) {
      return '?';
    }

    if (bagian.length == 1) {
      return bagian.first.substring(0, 1).toUpperCase();
    }

    return (bagian.first.substring(0, 1) + bagian.last.substring(0, 1))
        .toUpperCase();
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    uuid: json['uuid'] as String,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String?,
    photoUrl: json['photo_url'] as String?,
    gender: json['gender'] as String?,
    birthDate: json['birth_date'] as String?,
    status: json['status'] as String? ?? 'active',
    referralCode: json['referral_code'] as String? ?? '',
    phoneVerified: json['phone_verified'] as bool? ?? false,
    profileComplete: json['profile_complete'] as bool? ?? false,
    joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '')?.toLocal(),
  );
}

/// Hasil permintaan kode OTP.
///
/// ============================================================================
///  BENTUKNYA SAMA UNTUK NOMOR TERDAFTAR DAN BELUM
/// ============================================================================
///  Backend sengaja tidak membedakan keduanya: kalau berbeda, siapa pun bisa
///  menguji nomor mana yang punya akun Antaride hanya dengan membaca response.
///
///  Konsekuensinya bagi aplikasi: layar "masukkan kode" TIDAK bisa menulis
///  "Selamat datang kembali" di tahap ini. Apakah pengguna baru atau bukan
///  baru diketahui setelah kodenya diverifikasi, lewat [AuthSession.isNewUser].
/// ============================================================================
class OtpChallenge {
  const OtpChallenge({
    required this.phoneMasked,
    required this.purpose,
    required this.expiresAt,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
    this.debugCode,
  });

  /// Nomor tersamarkan, misalnya `0812****7890`.
  ///
  /// Backend sengaja tidak mengirim nomor penuh: aplikasi sudah tahu nomor yang
  /// dia kirim, dan nomor penuh di layar hanya menambah yang bisa dibaca orang
  /// di sekitar.
  final String phoneMasked;

  final String purpose;
  final DateTime expiresAt;
  final int expiresInSeconds;

  /// Berapa detik sebelum tombol "kirim ulang" boleh ditekan.
  ///
  /// Ditegakkan backend per NOMOR, bukan per perangkat. Hitungan mundur di
  /// aplikasi hanya cermin dari itu — menekan lebih cepat tetap ditolak, dan
  /// tanpa hitungan mundur pengguna akan menekan berulang lalu menyimpulkan
  /// tombolnya tidak berfungsi.
  final int resendAfterSeconds;

  /// Kode OTP, HANYA ada di lingkungan non-produksi.
  ///
  /// Backend mengirimnya saat gateway SMS belum aktif supaya pengembangan tidak
  /// terhenti. Di produksi field-nya tidak dikirim sama sekali, jadi bukan
  /// kebocoran yang menunggu terjadi — tapi aplikasi tetap TIDAK boleh
  /// menampilkannya di build rilis.
  final String? debugCode;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
    phoneMasked: json['phone_masked'] as String? ?? '',
    purpose: json['purpose'] as String? ?? 'login',
    expiresAt:
        DateTime.tryParse(json['expires_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    expiresInSeconds: (json['expires_in_seconds'] as num?)?.toInt() ?? 0,
    resendAfterSeconds: (json['resend_after_seconds'] as num?)?.toInt() ?? 60,
    debugCode: json['debug_code'] as String?,
  );
}

/// Sesi hasil verifikasi OTP.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    required this.isNewUser,
  });

  /// Token Sanctum. Kredensial penuh — disimpan lewat `TokenStore`, tidak
  /// pernah di SharedPreferences dan tidak pernah masuk log.
  final String token;

  final AuthUser user;

  /// Apakah akunnya baru dibuat oleh verifikasi ini.
  ///
  /// Menentukan tujuan navigasi: pengguna baru diarahkan ke pelengkapan profil,
  /// yang lama langsung ke beranda.
  final bool isNewUser;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: json['token'] as String,
    isNewUser: json['is_new_user'] as bool? ?? false,
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}
