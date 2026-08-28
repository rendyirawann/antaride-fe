import 'package:antaride_auth/antaride_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
///  YANG DIUJI DI SINI ADALAH APA YANG *TIDAK* DILAKUKAN
/// ============================================================================
///  `PhoneDisplay` sengaja TIDAK menormalkan nomor: tidak mengubah `08` menjadi
///  `62`, tidak menambah kode negara, tidak membuang `+`.
///
///  Seluruh normalisasi ada di `PhoneNumber::normalize()` di backend. Kalau
///  kedua sisi menormalkan, keduanya harus sepakat soal `08`, `+62`, `62`, dan
///  `0062` — dan yang terjadi kalau tidak sepakat adalah OTP terkirim ke satu
///  bentuk nomor lalu diverifikasi terhadap bentuk lain. Gejalanya "kode selalu
///  salah", yang tidak menunjuk ke penyebabnya sama sekali.
///
///  Test di bawah menyatakan aturan itu secara eksplisit, supaya siapa pun yang
///  "memperbaiki" `clean()` menjadi menormalkan akan langsung melihat kenapa
///  itu tidak boleh.
/// ============================================================================
void main() {
  group('PhoneDisplay.clean', () {
    test('membuang spasi pengelompokan', () {
      expect(PhoneDisplay.clean('0812 3456 7890'), '081234567890');
    });

    test('membuang tanda hubung dan tanda kurung dari nomor yang disalin', () {
      // Bentuk yang muncul saat nomor disalin dari WhatsApp atau kontak.
      expect(PhoneDisplay.clean('0812-3456-7890'), '081234567890');
      expect(PhoneDisplay.clean('(0812) 3456 7890'), '081234567890');
    });

    test('mempertahankan + di awal', () {
      expect(PhoneDisplay.clean('+62 812 3456 7890'), '+6281234567890');
    });

    test('TIDAK mengubah 08 menjadi 62', () {
      expect(
        PhoneDisplay.clean('081234567890'),
        '081234567890',
        reason:
            'Normalisasi ada di backend. Kalau aplikasi ikut menormalkan, '
            'keduanya harus sepakat — dan yang terjadi kalau tidak sepakat '
            'adalah OTP dikirim ke satu bentuk lalu diverifikasi terhadap '
            'bentuk lain.',
      );
    });

    test('TIDAK menambah kode negara pada nomor tanpa awalan', () {
      expect(PhoneDisplay.clean('81234567890'), '81234567890');
    });

    test('+ di tengah dibuang, bukan dipertahankan', () {
      // `+` hanya berarti sesuatu di awal. Di tengah dia sampah dari salin-tempel.
      expect(PhoneDisplay.clean('0812+3456'), '08123456');
    });

    test('masukan kosong tetap kosong', () {
      expect(PhoneDisplay.clean(''), '');
      expect(PhoneDisplay.clean('   '), '');
    });
  });

  group('PhoneDisplay.group', () {
    test('mengelompokkan digit dalam blok empat', () {
      expect(PhoneDisplay.group('081234567890'), '0812 3456 7890');
    });

    test('blok terakhir yang tidak penuh tetap tampil', () {
      expect(PhoneDisplay.group('08123'), '0812 3');
    });

    test('masukan kosong menghasilkan string kosong', () {
      expect(PhoneDisplay.group(''), '');
    });

    test('mengabaikan karakter bukan digit yang sudah ada', () {
      expect(PhoneDisplay.group('0812-3456'), '0812 3456');
    });
  });

  group('PhoneDisplay.looksComplete', () {
    /// Sengaja LONGGAR: 9–15 digit, tanpa pemeriksaan prefiks operator.
    ///
    /// Yang dijaga hanya satu hal — tidak mengirim request untuk nomor yang
    /// jelas belum selesai diketik. Aturan sebenarnya ada di backend.
    test('menerima nomor Indonesia yang wajar', () {
      expect(PhoneDisplay.looksComplete('0812 3456 7890'), isTrue);
      expect(PhoneDisplay.looksComplete('+62 812 3456 7890'), isTrue);
    });

    test('menolak nomor yang jelas belum selesai', () {
      expect(PhoneDisplay.looksComplete('0812'), isFalse);
      expect(PhoneDisplay.looksComplete(''), isFalse);
    });

    test('menolak yang terlalu panjang', () {
      expect(PhoneDisplay.looksComplete('0812345678901234567'), isFalse);
    });

    /// ========================================================================
    ///  TIDAK MEMERIKSA PREFIKS OPERATOR, DAN ITU DISENGAJA
    /// ========================================================================
    ///  Aplikasi yang memeriksa prefiks akan menolak nomor dari operator baru
    ///  atau blok nomor baru yang belum ada di daftarnya — dan pemiliknya tidak
    ///  bisa mendaftar sama sekali, tanpa cara mengetahui sebabnya.
    ///
    ///  Nomor di bawah bukan prefiks operator Indonesia mana pun, dan tetap
    ///  harus lolos: yang menolaknya nanti adalah backend atau gateway SMS,
    ///  dengan pesan yang bisa dibaca.
    /// ========================================================================
    test('tidak memeriksa prefiks operator', () {
      expect(PhoneDisplay.looksComplete('0999 1234 5678'), isTrue);
    });
  });
}
