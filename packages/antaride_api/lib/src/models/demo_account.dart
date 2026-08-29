/// Satu akun demo yang bisa dimasuki tanpa OTP.
///
/// ============================================================================
///  ADA KARENA OTP BELUM DIKIRIM KE MANA PUN
/// ============================================================================
///  Backend hanya punya satu pengirim SMS, dan yang dilakukannya menulis kode ke
///  berkas log — bukan mengirimnya ke HP. Di produksi kode itu pun disembunyikan.
///
///  Akibatnya di server yang sudah ter-deploy: tidak ada seorang pun yang bisa
///  masuk. Bukan sulit — tidak bisa. Akun demo yang membuat aplikasinya bisa
///  diuji sebelum gateway SMS dipasang.
/// ============================================================================
///
/// ============================================================================
///  DAFTARNYA DARI BACKEND, TIDAK DITULIS DI APLIKASI
/// ============================================================================
///  Menuliskannya sebagai konstanta di sini akan bekerja sampai akunnya berubah
///  di server — lalu tombol yang ditekan penguji menembak akun yang sudah tidak
///  ada, dan yang muncul galat yang tidak menyebut penyebabnya.
///
///  Lebih penting lagi: backend yang memutuskan apakah fiturnya menyala. Daftar
///  yang tertanam di aplikasi akan tetap menampilkan tombol demo di server
///  produksi yang sudah mematikannya.
/// ============================================================================
class DemoAccount {
  const DemoAccount({
    required this.uuid,
    required this.name,
    required this.phone,
    required this.role,
    this.note,
  });

  /// Dipakai untuk masuk. Bukan nomor HP-nya.
  ///
  /// Nomor bisa berubah; uuid tidak. Dan uuid yang bocor tidak berguna kalau
  /// fitur demo dimatikan di server — sementara nomor yang bocor tetap bisa
  /// dipakai meminta OTP.
  final String uuid;

  final String name;

  /// Ditampilkan apa adanya, tidak disamarkan.
  ///
  /// Berbeda dari nomor pengguna sungguhan yang selalu disamarkan di seluruh
  /// aplikasi. Ini akun yang memang untuk dibagikan, dan penguji perlu nomornya
  /// kalau dia mau mencoba jalur OTP biasa.
  final String phone;

  /// `customer`, `driver`, atau `merchant`.
  final String role;

  /// Keterangan singkat: saldo, kelengkapan dokumen, dan sebagainya.
  ///
  /// Ada supaya penguji tahu akun mana yang dia butuhkan tanpa mencoba satu per
  /// satu. Datang dari backend, jadi kalimatnya tidak ditulis ulang di tiga
  /// aplikasi.
  final String? note;

  factory DemoAccount.fromJson(Map<String, dynamic> json) => DemoAccount(
    uuid: json['uuid'] as String,
    name: json['name'] as String? ?? 'Akun demo',
    phone: json['phone'] as String? ?? '',
    role: json['role'] as String? ?? '',
    note: json['note'] as String?,
  );
}

/// Hasil pemanggilan daftar akun demo.
///
/// ============================================================================
///  `enabled` DIBEDAKAN DARI DAFTAR KOSONG
/// ============================================================================
///  Keduanya menghasilkan daftar tanpa isi, tapi artinya berbeda:
///
///    enabled false   fiturnya dimatikan di server. Aplikasi menyembunyikan
///                    seluruh bagian akun demo — termasuk judulnya.
///
///    enabled true,   fiturnya menyala tapi belum ada akun yang di-seed.
///    daftar kosong   Aplikasi menampilkan keterangan bahwa akunnya belum
///                    disiapkan, supaya yang menyiapkannya tahu harus
///                    menjalankan seeder.
///
///  Tanpa pembeda ini, server yang lupa menjalankan seeder terlihat sama dengan
///  server yang sengaja mematikan fiturnya.
/// ============================================================================
class DemoAccountList {
  const DemoAccountList({required this.accounts, required this.enabled});

  final List<DemoAccount> accounts;
  final bool enabled;

  /// Daftar kosong yang menyatakan fiturnya mati.
  ///
  /// Dipakai saat request-nya sendiri gagal: layar masuk tidak boleh menampilkan
  /// galat hanya karena bagian tambahan yang opsional tidak bisa dimuat.
  static const DemoAccountList mati = DemoAccountList(
    accounts: <DemoAccount>[],
    enabled: false,
  );

  factory DemoAccountList.fromJson(Map<String, dynamic> json) {
    return DemoAccountList(
      accounts: ((json['accounts'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => DemoAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}
