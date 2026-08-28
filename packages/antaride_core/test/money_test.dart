import 'package:antaride_core/antaride_core.dart';
import 'package:test/test.dart';

/// ============================================================================
///  YANG DIUJI DI SINI SEBAGIAN BESAR ADALAH APA YANG *TIDAK* ADA
/// ============================================================================
///  `Money` sengaja tidak punya `plus`, `minus`, atau `percentage`. Aplikasi
///  mobile TIDAK PERNAH menghitung uang — seluruh perhitungan ada di backend,
///  dan mobile hanya menampilkannya.
///
///  Menambahkan aritmetika akan membuka jalan bagi layar yang menjumlahkan
///  sendiri lalu menampilkan total yang berbeda dari yang ditagih backend.
///  Selisih satu rupiah antara yang dilihat penumpang dan yang dipotong dari
///  saldonya adalah keluhan yang sepenuhnya sah dan sangat sulit dijelaskan.
///
///  Test di bawah menyatakan batas itu, supaya siapa pun yang ingin
///  menambahkannya nanti melihat alasannya lebih dulu.
/// ============================================================================
void main() {
  group('Money.fromJson', () {
    test('membaca tiga field dari bentuk API', () {
      final Money uang = Money.fromJson(<String, dynamic>{
        'amount': 25000,
        'currency': 'IDR',
        'formatted': 'Rp 25.000',
      });

      expect(uang.amount, 25000);
      expect(uang.currency, 'IDR');
      expect(uang.formatted, 'Rp 25.000');
    });

    /// Nominal negatif ikut terbaca apa adanya.
    ///
    /// Yang menghasilkannya: penyesuaian batas tarif dan saldo driver yang minus
    /// karena komisi order tunai. Keduanya nyata, dan keduanya harus tampil
    /// dengan tanda yang benar — yang datang dari backend, bukan disusun di sini.
    test('nominal negatif dan formatnya ikut terbaca', () {
      final Money uang = Money.fromJson(<String, dynamic>{
        'amount': -5600,
        'formatted': '-Rp 5.600',
      });

      expect(uang.amount, -5600);
      expect(uang.isNegative, isTrue);
      expect(uang.formatted, '-Rp 5.600');
    });

    /// Field yang hilang tidak melempar.
    ///
    /// Response yang bentuknya berubah tidak boleh menjatuhkan layar. Yang
    /// terjadi adalah "Rp 0" — yang salah, tapi terbaca sebagai nilai, bukan
    /// sebagai aplikasi yang mati di tengah pemesanan.
    test('field yang hilang jatuh ke nilai bawaan, tidak melempar', () {
      final Money uang = Money.fromJson(const <String, dynamic>{});

      expect(uang.amount, 0);
      expect(uang.formatted, 'Rp 0');
      expect(uang.currency, 'IDR');
    });

    test('nominal desimal dari JSON dibulatkan ke integer', () {
      // Rupiah tidak punya sen. Kalau backend mengirim 25000.0 karena serialisasi
      // JSON, yang dipakai tetap integer — bukan double yang menyelinap ke
      // perbandingan dan menghasilkan hasil yang tidak terduga.
      final Money uang = Money.fromJson(<String, dynamic>{'amount': 25000.0});

      expect(uang.amount, 25000);
      expect(uang.amount, isA<int>());
    });
  });

  group('Money.zero', () {
    /// `formatted` diisi "Rp 0", bukan string kosong.
    ///
    /// Layar yang menampilkan string kosong terlihat seperti gagal memuat,
    /// sementara "Rp 0" terbaca sebagai nilai yang memang nol.
    test('punya format yang bisa ditampilkan', () {
      expect(Money.zero.amount, 0);
      expect(Money.zero.formatted, 'Rp 0');
      expect(Money.zero.isZero, isTrue);
    });
  });

  group('Perbandingan', () {
    test('isZero, isPositive, isNegative', () {
      const Money nol = Money(amount: 0, formatted: 'Rp 0');
      const Money positif = Money(amount: 100, formatted: 'Rp 100');
      const Money negatif = Money(amount: -100, formatted: '-Rp 100');

      expect(nol.isZero, isTrue);
      expect(nol.isPositive, isFalse);
      expect(nol.isNegative, isFalse);

      expect(positif.isPositive, isTrue);
      expect(negatif.isNegative, isTrue);
    });

    test('isAtLeast memakai batas inklusif', () {
      const Money uang = Money(amount: 20000, formatted: 'Rp 20.000');

      expect(
        uang.isAtLeast(20000),
        isTrue,
        reason: 'Tepat di batas harus lolos.',
      );
      expect(uang.isAtLeast(19999), isTrue);
      expect(uang.isAtLeast(20001), isFalse);
    });

    test('isMoreThan membandingkan nominal', () {
      const Money besar = Money(amount: 30000, formatted: 'Rp 30.000');
      const Money kecil = Money(amount: 20000, formatted: 'Rp 20.000');

      expect(besar.isMoreThan(kecil), isTrue);
      expect(kecil.isMoreThan(besar), isFalse);
      expect(besar.isMoreThan(besar), isFalse);
    });

    /// Kesetaraan memakai nominal DAN mata uang, bukan `formatted`.
    ///
    /// `formatted` dibuat backend dan bisa berubah begitu ada yang memperbaiki
    /// tata bahasanya. Dua nominal yang sama dengan format berbeda tetap uang
    /// yang sama.
    test('kesetaraan mengabaikan formatted', () {
      const Money a = Money(amount: 25000, formatted: 'Rp 25.000');
      const Money b = Money(amount: 25000, formatted: 'Rp25.000');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('mata uang berbeda tidak setara walaupun nominalnya sama', () {
      const Money rupiah = Money(amount: 100, formatted: 'Rp 100');
      const Money lain = Money(
        amount: 100,
        formatted: '\$100',
        currency: 'USD',
      );

      expect(rupiah, isNot(equals(lain)));
    });
  });

  group('Batas yang disengaja', () {
    /// ========================================================================
    ///  TIDAK ADA ARITMETIKA, DAN ITU BUKAN KELUPAAN
    /// ========================================================================
    ///  Test ini tidak memanggil apa pun — dia menyatakan sebuah keputusan.
    ///
    ///  Kalau nanti ada yang menambahkan `plus`/`minus`/`percentage` ke `Money`,
    ///  test ini tidak akan gagal secara otomatis. Yang dilakukannya adalah
    ///  memastikan orang yang membuka berkas ini membaca alasannya lebih dulu —
    ///  dan kalau keputusannya memang diubah, dia menghapus test ini dengan
    ///  sadar, bukan tanpa menyadarinya.
    /// ========================================================================
    test('Money hanya membandingkan, tidak menghitung', () {
      const Money uang = Money(amount: 25000, formatted: 'Rp 25.000');

      // Yang tersedia hanya perbandingan dan pembacaan.
      expect(uang.amount, isA<int>());
      expect(uang.formatted, isA<String>());
      expect(uang.isPositive, isA<bool>());

      // toString mengembalikan bentuk yang sudah diformat backend, jadi
      // interpolasi string di layar tidak pernah menampilkan angka mentah.
      expect(uang.toString(), 'Rp 25.000');
    });
  });
}
