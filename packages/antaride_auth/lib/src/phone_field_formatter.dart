/// Pembantu tampilan untuk kolom nomor HP.
///
/// ============================================================================
///  INI MURNI TAMPILAN. NORMALISASI TETAP DI BACKEND.
/// ============================================================================
///  Yang ada di sini hanya pengelompokan digit supaya nomor yang panjang bisa
///  dibaca sambil diketik: `0812 3456 7890`.
///
///  Yang TIDAK ada di sini: pengubahan `08` menjadi `62`, penghapusan `+`, atau
///  penambahan kode negara. Semuanya dikerjakan `PhoneNumber::normalize()` di
///  backend, dan aplikasi mengirim nomor APA ADANYA.
///
///  Alasannya: kalau kedua sisi menormalkan, keduanya harus sepakat soal `08`,
///  `+62`, `62`, `0062`, dan spasi. Yang terjadi kalau tidak sepakat adalah OTP
///  terkirim ke satu bentuk nomor lalu diverifikasi terhadap bentuk lain — dan
///  gejalanya "kode selalu salah", yang tidak menunjuk ke penyebabnya sama
///  sekali.
/// ============================================================================
class PhoneDisplay {
  const PhoneDisplay._();

  /// Buang segala yang bukan digit, kecuali `+` di awal.
  ///
  /// Dipakai SEBELUM mengirim, hanya untuk membersihkan spasi yang ditambahkan
  /// [group] dan yang ikut tertempel saat pengguna menyalin nomor dari
  /// WhatsApp.
  static String clean(String masukan) {
    final String dipangkas = masukan.trim();
    final bool plus = dipangkas.startsWith('+');
    final String digit = dipangkas.replaceAll(RegExp(r'[^0-9]'), '');

    return plus ? '+$digit' : digit;
  }

  /// Kelompokkan digit dalam blok 4 untuk dibaca.
  static String group(String masukan) {
    final String digit = masukan.replaceAll(RegExp(r'[^0-9]'), '');

    if (digit.isEmpty) {
      return '';
    }

    final StringBuffer hasil = StringBuffer();

    for (int i = 0; i < digit.length; i++) {
      if (i > 0 && i % 4 == 0) {
        hasil.write(' ');
      }

      hasil.write(digit[i]);
    }

    return hasil.toString();
  }

  /// Apakah nomornya MASUK AKAL untuk dikirim.
  ///
  /// Sengaja longgar: 9 sampai 15 digit. Bukan validasi operator, dan bukan
  /// pemeriksaan prefiks.
  ///
  /// Yang dijaga di sini hanya satu hal — tidak mengirim request untuk nomor
  /// yang jelas belum selesai diketik. Aturan sebenarnya ada di backend, dan
  /// aplikasi yang memeriksa prefiks operator akan menolak nomor dari operator
  /// baru yang belum ada di daftarnya.
  static bool looksComplete(String masukan) {
    final String digit = masukan.replaceAll(RegExp(r'[^0-9]'), '');

    return digit.length >= 9 && digit.length <= 15;
  }
}
