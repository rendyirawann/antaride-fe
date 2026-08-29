import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Layar masuk yang DIDORONG di atas gerbang sesi harus menutup dirinya.
///
/// ============================================================================
///  BUG YANG DICEGAH BERKAS INI
/// ============================================================================
///  Sebelum ada layar sambutan, layar masuk adalah `home:` dari MaterialApp.
///  Gerbang di akar mengganti widget-nya saat sesi berubah, dan layar masuknya
///  lenyap sendiri — itu sebabnya layar masuk driver dan merchant memang tidak
///  memanggil Navigator sama sekali.
///
///  Menambahkan layar sambutan mengubah itu tanpa terlihat: layar masuk
///  sekarang DIDORONG di atas gerbang. Gerbangnya tetap berganti, tapi
///  pergantiannya terjadi di BAWAH tumpukan route. Yang dilihat pengguna: dia
///  menekan Masuk, akunnya benar-benar masuk, dan layarnya tidak bergerak —
///  dengan beranda yang sudah siap tersembunyi tepat di belakangnya.
///
///  Tidak ada analyzer yang menangkap ini, dan test yang memasang layar masuk
///  sendirian juga tidak: bug-nya baru ada saat route-nya didorong. Karena itu
///  test ini MENDORONG route-nya, persis seperti layar sambutan.
/// ============================================================================
void main() {
  testWidgets('route yang didorong menutup diri saat sesi menjadi masuk', (
    WidgetTester tester,
  ) async {
    final _SesiUji sesi = _SesiUji();

    await tester.pumpWidget(_Aplikasi(sesi: sesi));

    // Dari sambutan ke layar masuk — persis seperti tombol "Masuk".
    await tester.tap(find.text('KE LAYAR MASUK'));
    await tester.pumpAndSettle();

    expect(find.text('LAYAR MASUK'), findsOneWidget);
    expect(find.text('BERANDA'), findsNothing);

    // Berhasil masuk. Sumbernya tidak penting — OTP atau tombol akun demo
    // menghasilkan perubahan keadaan yang sama.
    sesi.jadikanMasuk();
    await tester.pumpAndSettle();

    expect(
      find.text('LAYAR MASUK'),
      findsNothing,
      reason:
          'Layar masuk masih menutupi layar. Pengguna sudah masuk tapi tidak '
          'melihat perubahan apa pun — dan tidak punya cara keluar dari layar '
          'ini selain tombol kembali perangkat.',
    );

    expect(find.text('BERANDA'), findsOneWidget);
  });

  /// Tanpa ini, dua route yang menumpuk hanya terbuka satu.
  ///
  /// Aplikasi penumpang memang menumpuk dua: layar nomor HP, lalu layar OTP di
  /// atasnya. Satu `pop` menyisakan layar nomor HP yang terlihat seperti
  /// aplikasi yang mundur satu langkah setelah berhasil masuk.
  testWidgets('dua route yang menumpuk ikut tertutup semua', (
    WidgetTester tester,
  ) async {
    final _SesiUji sesi = _SesiUji();

    await tester.pumpWidget(_Aplikasi(sesi: sesi));

    await tester.tap(find.text('KE LAYAR MASUK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('KE LAYAR OTP'));
    await tester.pumpAndSettle();

    expect(find.text('LAYAR OTP'), findsOneWidget);

    sesi.jadikanMasuk();
    await tester.pumpAndSettle();

    expect(find.text('LAYAR OTP'), findsNothing);
    expect(find.text('LAYAR MASUK'), findsNothing);
    expect(find.text('BERANDA'), findsOneWidget);
  });

  /// Sesi yang TIDAK berubah tidak boleh menutup apa pun.
  ///
  /// Kalau pembungkusnya menutup route pada notifikasi apa pun — misalnya saat
  /// `isBusy` berubah karena tombol ditekan — layar masuk akan tertutup persis
  /// saat pengguna menekan tombolnya.
  testWidgets('notifikasi tanpa perubahan tahap tidak menutup apa pun', (
    WidgetTester tester,
  ) async {
    final _SesiUji sesi = _SesiUji();

    await tester.pumpWidget(_Aplikasi(sesi: sesi));

    await tester.tap(find.text('KE LAYAR MASUK'));
    await tester.pumpAndSettle();

    sesi.beritahuTanpaBerubah();
    await tester.pumpAndSettle();

    expect(find.text('LAYAR MASUK'), findsOneWidget);
  });
}

// -----------------------------------------------------------------------------

/// Gerbang sesi tiruan, disusun sama dengan `app.dart` ketiga aplikasi:
/// `home:` yang berganti isi mengikuti tahap sesi.
class _Aplikasi extends StatelessWidget {
  const _Aplikasi({required this.sesi});

  final _SesiUji sesi;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SessionController>.value(
      value: sesi,
      child: MaterialApp(home: const _Gerbang()),
    );
  }
}

class _Gerbang extends StatelessWidget {
  const _Gerbang();

  @override
  Widget build(BuildContext context) {
    final SessionStage tahap = context.select<SessionController, SessionStage>(
      (SessionController s) => s.stage,
    );

    if (tahap == SessionStage.signedIn) {
      return const Scaffold(body: Center(child: Text('BERANDA')));
    }

    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) =>
                  const TutupSaatMasuk(child: _LayarMasuk()),
            ),
          ),
          child: const Text('KE LAYAR MASUK'),
        ),
      ),
    );
  }
}

class _LayarMasuk extends StatelessWidget {
  const _LayarMasuk();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('LAYAR MASUK'),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) =>
                      const Scaffold(body: Center(child: Text('LAYAR OTP'))),
                ),
              ),
              child: const Text('KE LAYAR OTP'),
            ),
          ],
        ),
      ),
    );
  }
}

/// `SessionController` sungguhan dengan tahap yang dikendalikan test.
///
/// Turunan, bukan tiruan penuh: `TutupSaatMasuk` mencari `SessionController`
/// lewat provider berdasarkan TIPE-nya, jadi kelas terpisah tidak akan
/// ditemukan.
///
/// Dependensinya dibuat tapi tidak pernah dipakai — tidak ada request yang
/// dikirim, dan `TokenStore()` tidak menyentuh penyimpanan aman sampai ada yang
/// memanggil `load`/`save`.
class _SesiUji extends SessionController {
  _SesiUji()
    : super(
        auth: AuthRepository(
          client: ApiClient(
            tokenStore: TokenStore(),
            baseUrl: 'http://127.0.0.1/api/v1',
            dio: Dio(),
          ),
          tokenStore: TokenStore(),
        ),
        tokenStore: TokenStore(),
        platform: 'test',
      );

  SessionStage _tahap = SessionStage.signedOut;

  @override
  SessionStage get stage => _tahap;

  void jadikanMasuk() {
    _tahap = SessionStage.signedIn;
    notifyListeners();
  }

  void beritahuTanpaBerubah() => notifyListeners();
}
