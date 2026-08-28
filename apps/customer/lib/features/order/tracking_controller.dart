import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:flutter/foundation.dart';

/// Menjaga satu order tetap terbarui selama masih berjalan.
///
/// ============================================================================
///  PENARIKAN BERKALA ADALAH JALUR UTAMANYA, BUKAN CADANGAN
/// ============================================================================
///  Centrifugo belum terpasang, dan bahkan kalau nanti sudah, sebagian jaringan
///  operator memblokir koneksi WebSocket panjang. Layar pelacakan yang berhenti
///  diperbarui adalah bentuk kegagalan yang paling buruk di aplikasi ini:
///  penumpang menatap posisi driver yang membeku dan menyimpulkan drivernya
///  berhenti di jalan.
///
///  Jadi penarikan berkala yang jadi tulang punggungnya, dan realtime nanti
///  hanya MEMPERCEPAT — memicu penarikan lebih awal, bukan menggantikannya.
/// ============================================================================
///
/// ============================================================================
///  INTERVALNYA BERBEDA PER STATUS, DAN ITU BUKAN OPTIMASI MIKRO
/// ============================================================================
///    searching        4 detik   — penumpang menunggu jawaban dan setiap detik
///                                 terasa. Ini juga status paling singkat.
///    driver menuju    6 detik   — posisi driver bergerak, dan itu yang
///                                 ditatap.
///    dalam perjalanan 10 detik  — tidak banyak yang berubah; yang penting
///                                 hanya kapan sampai.
///    selesai          berhenti  — tidak ada lagi yang bisa berubah.
///
///  Satu interval untuk semua akan salah di kedua arah: 10 detik terasa lambat
///  saat mencari driver, dan 4 detik selama perjalanan 40 menit menghasilkan 600
///  request untuk satu order — dikalikan setiap penumpang yang sedang jalan.
/// ============================================================================
class TrackingController extends ChangeNotifier {
  TrackingController({required OrderRepository orders, required this.orderUuid})
    : _orders = orders;

  final OrderRepository _orders;
  final String orderUuid;

  Timer? _timer;
  Order? _order;
  ApiFailure? _failure;
  bool _memuat = true;
  bool _dibuang = false;

  /// Sedang ada penarikan berjalan.
  ///
  /// Menahan penarikan berikutnya supaya tidak menumpuk saat jaringannya lambat
  /// — kalau satu request butuh 8 detik dan intervalnya 4 detik, tanpa penjaga
  /// ini akan ada dua request berjalan bersamaan dan yang lebih lama selesai
  /// menimpa yang lebih baru.
  bool _sedangMenarik = false;

  Order? get order => _order;

  ApiFailure? get failure => _failure;

  bool get isLoading => _memuat;

  /// Mulai memantau.
  Future<void> start() async {
    await _tarik();
    _jadwalkan();
  }

  /// Tarik sekarang, di luar jadwal.
  ///
  /// Dipakai tombol segarkan manual dan — nanti — pemicu dari peristiwa
  /// realtime.
  Future<void> refreshNow() => _tarik();

  @override
  void dispose() {
    _dibuang = true;
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  Future<void> _tarik() async {
    if (_dibuang || _sedangMenarik) {
      return;
    }

    _sedangMenarik = true;

    final Result<Order> hasil = await _orders.show(orderUuid);

    _sedangMenarik = false;

    if (_dibuang) {
      return;
    }

    _memuat = false;

    switch (hasil) {
      case Ok<Order>(value: final Order o):
        _order = o;
        _failure = null;

      case Err<Order>(failure: final ApiFailure f):
        /*
         * Kegagalan TIDAK menghapus order yang sudah tampil.
         *
         * Penumpang di dalam kendaraan melewati area tanpa sinyal secara
         * teratur. Mengosongkan layar setiap kali satu request gagal berarti
         * layar pelacakan berkedip antara data dan galat sepanjang perjalanan.
         *
         * Yang benar: pertahankan data terakhir, dan tampilkan pita kecil bahwa
         * pembaruannya tertunda.
         */
        _failure = f;
    }

    notifyListeners();
    _jadwalkan();
  }

  void _jadwalkan() {
    _timer?.cancel();

    if (_dibuang) {
      return;
    }

    final Order? o = _order;

    // Order yang sudah selesai atau gagal tidak ditarik lagi. Tidak ada lagi
    // yang bisa berubah, dan penarikan yang terus berjalan di layar riwayat
    // adalah biaya tanpa manfaat.
    if (o != null && !o.isActive) {
      return;
    }

    _timer = Timer(_interval(o?.status), _tarik);
  }

  Duration _interval(String? status) {
    return switch (status) {
      'created' || 'searching' => const Duration(seconds: 4),
      'accepted' ||
      'driver_arriving' ||
      'driver_arrived' => const Duration(seconds: 6),
      'in_progress' => const Duration(seconds: 10),

      // Status yang belum diketahui — termasuk saat penarikan pertama gagal —
      // memakai jeda menengah. Bukan yang tercepat: kalau penyebab
      // kegagalannya server yang sedang kelebihan beban, menariknya setiap 4
      // detik memperburuk keadaan yang sedang coba dipulihkan.
      _ => const Duration(seconds: 8),
    };
  }
}
