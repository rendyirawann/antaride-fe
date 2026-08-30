import 'package:flutter/material.dart';

/// Animasi masuk bergiliran: fade + naik 18 px, sekali saat layar dibuka.
///
/// ============================================================================
///  GILIRAN LEWAT [index], BUKAN LEWAT SATU CONTROLLER BERSAMA
/// ============================================================================
///  Alternatifnya: satu AnimationController di layar, tiap elemen mengambil
///  `Interval`-nya. Itu berarti tiap layar mengelola controller + mixin +
///  dispose sendiri — kode upacara yang sama disalin ke puluhan layar, dan
///  yang disalin akan menyimpang (durasi beda, kurva beda, lupa dispose).
///
///  Di sini tiap elemen cukup menyebut urutannya: `ClayEntrance(index: 2, …)`.
///  Jedanya dimasukkan KE DALAM durasi controller sebagai `Interval`, bukan
///  lewat `Future.delayed` — dua alasan:
///
///    - Tidak ada timer yang hidup di luar controller, jadi widget yang
///      di-dispose sebelum gilirannya tiba (pengguna langsung pindah layar)
///      tidak meninggalkan callback yang menyentuh State mati.
///    - Animasinya utuh di mata `pumpAndSettle` test — timer lepas bisa
///      terlewat oleh pompa frame dan menyisakan elemen setengah muncul.
/// ============================================================================
///
/// ============================================================================
///  SEKALI SAJA, DAN KENAPA ITU PENTING
/// ============================================================================
///  Controller maju sekali di initState dan tidak pernah diulang. Animasi
///  masuk yang diputar ulang tiap rebuild (setState, kembali dari layar lain)
///  membuat aplikasi terasa gelisah — yang pertama kali terasa menyambut,
///  yang kedua kali terasa menghalangi.
/// ============================================================================
class ClayEntrance extends StatefulWidget {
  const ClayEntrance({super.key, required this.index, required this.child});

  /// Urutan giliran. 0 masuk langsung; tiap tingkat menambah jeda 70 ms.
  final int index;

  final Widget child;

  @override
  State<ClayEntrance> createState() => _ClayEntranceState();
}

class _ClayEntranceState extends State<ClayEntrance>
    with SingleTickerProviderStateMixin {
  /// Jeda antar giliran. 70 ms cukup untuk terbaca sebagai urutan, dan lima
  /// elemen tetap selesai di bawah ~750 ms — di atas itu layarnya terasa
  /// menunggu dirinya sendiri.
  static const int _jedaPerIndexMs = 70;

  /// Durasi gerak satu elemen (setelah jedanya lewat).
  static const int _gerakMs = 420;

  late final AnimationController _masuk;
  late final CurvedAnimation _kurva;

  @override
  void initState() {
    super.initState();

    final int jedaMs = _jedaPerIndexMs * widget.index;
    final int totalMs = jedaMs + _gerakMs;

    _masuk = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    // Jeda = bagian datar di awal kurva. Selama Interval belum mulai,
    // nilainya 0: elemen tak terlihat dan berada 18 px di bawah tempatnya.
    _kurva = CurvedAnimation(
      parent: _masuk,
      curve: Interval(jedaMs / totalMs, 1, curve: Curves.easeOutCubic),
    );

    _masuk.forward();
  }

  @override
  void dispose() {
    _kurva.dispose();
    _masuk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _kurva,
      child: AnimatedBuilder(
        animation: _kurva,
        builder: (BuildContext _, Widget? anak) => Transform.translate(
          offset: Offset(0, 18 * (1 - _kurva.value)),
          child: anak,
        ),
        child: widget.child,
      ),
    );
  }
}
