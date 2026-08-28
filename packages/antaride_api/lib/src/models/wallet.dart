import 'package:antaride_core/antaride_core.dart';

/// Saldo dompet.
class WalletBalance {
  const WalletBalance({
    required this.available,
    required this.held,
    required this.total,
    required this.isFrozen,
    this.frozenReason,
  });

  /// Saldo yang bisa dipakai sekarang.
  final Money available;

  /// Saldo yang sedang DITAHAN untuk order berjalan.
  ///
  /// ==========================================================================
  ///  KENAPA DITAMPILKAN TERPISAH, BUKAN DIKURANGKAN DIAM-DIAM
  /// ==========================================================================
  ///  Saat penumpang memesan dengan wallet, ongkosnya ditahan lebih dulu, bukan
  ///  langsung dipotong. Kalau order dibatalkan, tahanan itu dilepas.
  ///
  ///  Kalau layar hanya menampilkan [available], penumpang yang saldonya
  ///  Rp 50.000 dan sedang naik ojek Rp 15.000 akan melihat Rp 35.000 dan
  ///  menyimpulkan uangnya sudah terpotong padahal perjalanannya belum selesai.
  ///  Lalu kalau dia batalkan dan saldonya kembali, dia menyimpulkan sistemnya
  ///  tidak konsisten.
  ///
  ///  Menampilkan keduanya menyelesaikan keduanya sekaligus.
  /// ==========================================================================
  final Money held;

  /// [available] + [held]. Angka yang paling besar, dan bukan yang bisa dipakai.
  final Money total;

  /// Dompet yang dibekukan admin, biasanya karena investigasi penipuan.
  ///
  /// Layar menampilkan [frozenReason] dan jalan menghubungi bantuan. Menolak
  /// transaksi tanpa penjelasan membuat orang mengira aplikasinya rusak.
  final bool isFrozen;
  final String? frozenReason;

  bool get hasHeld => held.isPositive;

  bool get canPay => !isFrozen && available.isPositive;

  factory WalletBalance.fromJson(Map<String, dynamic> json) => WalletBalance(
    available: Money.fromJson(json['balance'] as Map<String, dynamic>),
    held: Money.fromJson(json['held'] as Map<String, dynamic>),
    total: Money.fromJson(json['total'] as Map<String, dynamic>),
    isFrozen: json['is_frozen'] as bool? ?? false,
    frozenReason: json['frozen_reason'] as String?,
  );
}

/// Satu baris mutasi dompet.
///
/// ============================================================================
///  MUTASI TIDAK PERNAH BERUBAH
/// ============================================================================
///  Tabel `wallet_transactions` di backend append-only, ditegakkan trigger
///  database: UPDATE dan DELETE ditolak. Koreksi dilakukan dengan baris reversal
///  baru, bukan dengan mengubah riwayat.
///
///  Konsekuensinya bagi aplikasi, dan ini yang penting: riwayat yang sudah
///  dimuat TIDAK PERNAH perlu di-refresh untuk mengoreksi baris lama. Yang bisa
///  muncul hanya baris BARU di atasnya. Itu membuat cache riwayat aman —
///  halaman yang sudah dimuat tidak akan pernah salah.
/// ============================================================================
class WalletTransaction {
  const WalletTransaction({
    required this.uuid,
    required this.type,
    required this.label,
    required this.direction,
    required this.amount,
    required this.signedAmount,
    required this.balanceAfter,
    this.description,
    this.createdAt,
  });

  final String uuid;

  /// Nilai mentah, misalnya `trip_payment`. Untuk memilih ikon.
  final String type;

  /// Teks dari backend. Untuk ditampilkan.
  final String label;

  /// `credit` (masuk) atau `debit` (keluar).
  final String direction;

  /// Nominal, selalu POSITIF. Arahnya ada di [direction].
  final Money amount;

  /// Nominal dengan tanda: positif untuk masuk, negatif untuk keluar.
  ///
  /// Dikirim backend supaya tiga aplikasi tidak masing-masing menyimpulkan
  /// tandanya dari [direction] — dan salah satu memakai perbandingan yang
  /// terbalik.
  final int signedAmount;

  /// Saldo SETELAH mutasi ini.
  ///
  /// Datang dari backend, ditulis saat mutasinya dibuat. Layar menampilkannya
  /// apa adanya dan tidak pernah menghitungnya dari saldo sekarang dikurangi
  /// mutasi — perhitungan itu akan salah begitu ada satu baris yang belum
  /// dimuat.
  final int balanceAfter;

  final String? description;
  final DateTime? createdAt;

  bool get isCredit => direction == 'credit';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        uuid: json['uuid'] as String,
        type: json['type'] as String? ?? '',
        label: json['label'] as String? ?? '',
        direction: json['direction'] as String? ?? 'debit',
        amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
        signedAmount: (json['signed_amount'] as num?)?.toInt() ?? 0,
        balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
        description: json['description'] as String?,
        createdAt: DateTime.tryParse(
          json['created_at'] as String? ?? '',
        )?.toLocal(),
      );
}

/// Satu halaman mutasi, dengan cursor untuk halaman berikutnya.
class WalletTransactionPage {
  const WalletTransactionPage({
    required this.transactions,
    required this.hasMore,
    this.nextCursor,
  });

  final List<WalletTransaction> transactions;
  final bool hasMore;
  final String? nextCursor;
}
