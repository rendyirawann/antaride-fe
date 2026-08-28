import 'package:antaride_core/antaride_core.dart';

import '../client/api_client.dart';
import '../models/wallet.dart';

/// Dompet penumpang.
///
/// ============================================================================
///  TIDAK ADA TOPUP DI SINI, DAN ITU BUKAN KELUPAAN
/// ============================================================================
///  Fase 1 tidak punya integrasi payment gateway. Saldo masuk lewat dua jalur:
///  cashback promo, dan penambahan manual oleh admin lewat backoffice — yang di
///  sana pun menuntut persetujuan dua orang di atas nominal tertentu.
///
///  Layar dompet karena itu menampilkan saldo dan mutasi, TANPA tombol topup.
///  Tombol topup yang mengarah ke halaman "segera hadir" lebih buruk daripada
///  tidak ada tombolnya: dia mengundang penumpang mencoba, lalu tidak
///  memberikan apa pun.
/// ============================================================================
class WalletRepository {
  const WalletRepository(this._client);

  final ApiClient _client;

  Future<Result<WalletBalance>> balance() async {
    final Result<Map<String, dynamic>> hasil = await _client.get('/wallet');

    return hasil.map(
      (Map<String, dynamic> badan) =>
          WalletBalance.fromJson(badan['data'] as Map<String, dynamic>),
    );
  }

  /// Mutasi dompet, dengan cursor pagination.
  ///
  /// Mutasi internal — perpindahan antar dompet platform yang tidak berkaitan
  /// dengan pengguna — sudah disaring backend. Yang tampil di sini hanya yang
  /// benar-benar memengaruhi saldo penumpang, dan itu penting: riwayat yang
  /// memuat baris yang tidak dia kenali membuat orang mengira ada transaksi
  /// yang bukan miliknya.
  Future<Result<WalletTransactionPage>> transactions({
    String? cursor,
    int perPage = 20,
  }) async {
    final Result<Map<String, dynamic>> hasil = await _client.get(
      '/wallet/transactions',
      query: <String, dynamic>{'per_page': perPage, 'cursor': ?cursor},
    );

    return hasil.map((Map<String, dynamic> badan) {
      final List<dynamic> data =
          (badan['data'] as List<dynamic>?) ?? const <dynamic>[];

      final Map<String, dynamic> meta =
          (badan['meta'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      return WalletTransactionPage(
        transactions: data
            .map(
              (dynamic e) =>
                  WalletTransaction.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        nextCursor: meta['next_cursor'] as String?,
        hasMore: meta['has_more'] as bool? ?? false,
      );
    });
  }
}
