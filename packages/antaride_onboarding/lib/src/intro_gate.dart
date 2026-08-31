import 'package:flutter/material.dart';

import 'intro_screen.dart';
import 'intro_store.dart';

/// Menampilkan perkenalan dulu, lalu layar sambutan.
///
/// ============================================================================
///  KENAPA GERBANG TERSENDIRI, BUKAN CABANG DI GERBANG SESI
/// ============================================================================
///  Gerbang sesi di akar aplikasi menjawab satu pertanyaan: siapa yang sedang
///  memakai aplikasi ini. Perkenalan menjawab pertanyaan yang berbeda — apakah
///  perangkat INI sudah pernah melihatnya — dan jawabannya datang dari
///  penyimpanan lokal, bukan dari sesi.
///
///  Menggabungkan keduanya berarti gerbang sesi harus menunggu pembacaan disk
///  sebelum bisa menampilkan apa pun, termasuk untuk pengguna yang sudah masuk
///  dan tidak akan pernah melihat perkenalan.
/// ============================================================================
///
/// ============================================================================
///  TIDAK ADA LAYAR TUNGGU SELAMA PEMBACAAN
/// ============================================================================
///  Membaca satu boolean dari SharedPreferences memakan beberapa milidetik.
///  Menampilkan spinner untuk itu menghasilkan kedipan yang lebih terasa
///  daripada penantiannya sendiri.
///
///  Karena itu selama belum terjawab, yang digambar adalah [child] — layar
///  sambutan. Untuk pemasangan baru, perkenalan menggantikannya satu frame
///  kemudian, dan pergantian itu memudar lewat AnimatedSwitcher di bawah.
/// ============================================================================
class IntroGate extends StatefulWidget {
  const IntroGate({
    super.key,
    required this.pages,
    required this.child,
    this.accent,
    this.store = const IntroStore(),
  });

  final List<IntroPage> pages;

  /// Layar yang tampil setelah perkenalan selesai — biasanya layar sambutan.
  final Widget child;

  final Color? accent;

  /// Bisa diganti di test.
  final IntroStore store;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  /// Null berarti belum terjawab.
  bool? _sudah;

  @override
  void initState() {
    super.initState();

    _periksa();
  }

  Future<void> _periksa() async {
    final bool hasil = await widget.store.sudah();

    if (!mounted) {
      return;
    }

    setState(() => _sudah = hasil);
  }

  Future<void> _selesai() async {
    // Ditandai SEBELUM berpindah, bukan sesudah: kalau aplikasi ditutup persis
    // di antara keduanya, perkenalan yang sudah dilihat akan muncul lagi.
    await widget.store.tandai();

    if (!mounted) {
      return;
    }

    setState(() => _sudah = true);
  }

  @override
  Widget build(BuildContext context) {
    final bool tampilkanIntro = _sudah == false;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: tampilkanIntro
          ? IntroScreen(
              key: const ValueKey<String>('intro'),
              pages: widget.pages,
              accent: widget.accent,
              onSelesai: _selesai,
            )
          : KeyedSubtree(
              key: const ValueKey<String>('sambutan'),
              child: widget.child,
            ),
    );
  }
}
