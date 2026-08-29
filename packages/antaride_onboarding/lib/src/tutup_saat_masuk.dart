import 'package:antaride_auth/antaride_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Menutup route ini begitu sesi berubah menjadi masuk.
///
/// ============================================================================
///  KENAPA INI ADA — DAN KENAPA SEBELUMNYA TIDAK DIBUTUHKAN
/// ============================================================================
///  Sebelum ada layar sambutan, layar masuk ADALAH `home:` dari MaterialApp.
///  Gerbang sesi di akar cukup mengganti widget-nya begitu `stage` berubah, dan
///  layar masuknya lenyap dengan sendirinya. Itu sebabnya layar masuk driver
///  dan merchant tidak memanggil Navigator sama sekali.
///
///  Sekarang layar masuk DIDORONG di atas gerbang. Gerbangnya tetap berganti —
///  tapi yang berganti ada DI BAWAH tumpukan route. Yang terlihat pengguna:
///  layar masuk yang tidak bergerak setelah dia berhasil masuk, dengan beranda
///  yang sudah siap tersembunyi persis di belakangnya.
///
///  Bug ini tidak terlihat di analyzer dan tidak terlihat di test widget yang
///  memasang layar masuk sendirian — hanya muncul kalau route-nya didorong.
/// ============================================================================
///
/// ============================================================================
///  KENAPA SATU PEMBUNGKUS, BUKAN POP DI TIAP JALUR MASUK
/// ============================================================================
///  Ada dua jalur yang menghasilkan sesi: verifikasi OTP dan tombol akun demo.
///  Menaruh `pop` di masing-masing berarti jalur ketiga yang ditambahkan nanti
///  akan lupa melakukannya — dan gejalanya (layar yang diam) tidak terbaca
///  sebagai "lupa memanggil pop".
///
///  Yang diawasi di sini KEADAAN sesinya, bukan kejadian yang memicunya. Jalur
///  apa pun yang membuat `stage` menjadi `signedIn` tertangani.
/// ============================================================================
class TutupSaatMasuk extends StatefulWidget {
  const TutupSaatMasuk({super.key, required this.child});

  final Widget child;

  @override
  State<TutupSaatMasuk> createState() => _TutupSaatMasukState();
}

class _TutupSaatMasukState extends State<TutupSaatMasuk> {
  SessionController? _sesi;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final SessionController sesi = context.read<SessionController>();

    if (identical(sesi, _sesi)) {
      return;
    }

    _sesi?.removeListener(_periksa);
    _sesi = sesi..addListener(_periksa);
  }

  @override
  void dispose() {
    _sesi?.removeListener(_periksa);

    super.dispose();
  }

  void _periksa() {
    if (!mounted || _sesi?.stage != SessionStage.signedIn) {
      return;
    }

    /*
     * Ditunda ke akhir frame.
     *
     * `notifyListeners` bisa terpanggil saat frame sedang dibangun — misalnya
     * dari sesuatu yang memulihkan sesi di `initState` turunan. Memanggil
     * Navigator di tengah build melempar galat framework, dan galat itu
     * muncul di layar sebagai layar merah, bukan sebagai layar yang tidak
     * menutup.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final NavigatorState nav = Navigator.of(context);

      // `popUntil`, bukan `pop`: saat ini bisa ada DUA route di atas gerbang —
      // layar nomor HP dan layar OTP di atasnya (aplikasi penumpang). Satu pop
      // hanya membuka salah satunya.
      if (nav.canPop()) {
        nav.popUntil((Route<dynamic> r) => r.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
