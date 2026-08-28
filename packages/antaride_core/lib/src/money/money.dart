/// Nilai uang dari API.
///
/// ============================================================================
///  TIGA FIELD, DAN KETIGANYA DIPAKAI
/// ============================================================================
///  API Antaride mengirim setiap nominal sebagai
///  `{amount, currency, formatted}`:
///
///    amount     integer Rupiah utuh — untuk BERHITUNG
///    formatted  "Rp 25.000" — untuk DITAMPILKAN
///    currency   selalu "IDR" di Fase 1, ada untuk nanti
///
///  Kenapa keduanya dikirim, bukan hanya salah satu:
///
///    Kalau hanya `amount`, tiga aplikasi Flutter harus sepakat soal pemisah
///    ribuan, posisi "Rp", dan letak tanda minus. Salah satu akan berbeda —
///    dan yang paling sering berbeda adalah tanda minus. "Rp -5.600" versus
///    "-Rp 5.600" tidak dianggap penting sampai ada penumpang yang
///    menganggapnya salah cetak.
///
///    Kalau hanya `formatted`, aplikasi tidak bisa membandingkan nominal atau
///    memeriksa apakah saldo cukup tanpa mengurai kembali stringnya — dan
///    mengurai "Rp 25.000" kembali menjadi 25000 adalah kode yang akan salah
///    pada nilai negatif.
/// ============================================================================
///
/// ============================================================================
///  TIDAK ADA ARITMETIKA DI KELAS INI, DAN ITU DISENGAJA
/// ============================================================================
///  Tidak ada `plus`, `minus`, atau `percentage`. Aplikasi mobile TIDAK PERNAH
///  menghitung uang — seluruh perhitungan ada di backend, dan mobile hanya
///  menampilkannya.
///
///  Menambahkan aritmetika di sini akan membuka jalan bagi layar yang
///  menjumlahkan sendiri dan menampilkan total yang berbeda dari yang ditagih
///  backend. Selisih satu rupiah antara yang dilihat penumpang dan yang dipotong
///  dari saldonya adalah keluhan yang sepenuhnya sah dan sangat sulit dijelaskan.
///
///  Yang ada hanya perbandingan — dan itu cukup untuk seluruh kebutuhan layar.
/// ============================================================================
class Money {
  const Money({
    required this.amount,
    required this.formatted,
    this.currency = 'IDR',
  });

  /// Rupiah utuh. Selalu integer; tidak ada sen di Rupiah.
  final int amount;

  /// Teks yang sudah diformat backend.
  final String formatted;

  final String currency;

  factory Money.fromJson(Map<String, dynamic> json) {
    return Money(
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      formatted: json['formatted'] as String? ?? 'Rp 0',
      currency: json['currency'] as String? ?? 'IDR',
    );
  }

  /// Nol, untuk keadaan awal sebelum data datang.
  ///
  /// `formatted` diisi "Rp 0", bukan string kosong: layar yang menampilkan
  /// string kosong terlihat seperti gagal memuat, sementara "Rp 0" terbaca
  /// sebagai nilai yang sebenarnya nol.
  static const Money zero = Money(amount: 0, formatted: 'Rp 0');

  bool get isZero => amount == 0;

  bool get isPositive => amount > 0;

  bool get isNegative => amount < 0;

  bool isAtLeast(int minimum) => amount >= minimum;

  bool isMoreThan(Money other) => amount > other.amount;

  @override
  bool operator ==(Object other) =>
      other is Money && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => formatted;
}
