import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_onboarding/antaride_onboarding.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Kartu akun demo harus benar-benar TERLIHAT — dengan tombolnya.
///
/// ============================================================================
///  BUG YANG DICEGAH BERKAS INI, DAN KENAPA TIDAK ADA YANG MENANGKAPNYA
/// ============================================================================
///  `ClayButton` bawaannya melebar penuh (`expanded: true`, width: infinity).
///  Di dalam Row kartu demo, lebar tak terhingga membuat tombol Masuk keluar
///  dari layar — tidak terlihat sama sekali — dan kolom nama di sebelahnya
///  kebagian lebar nol, sehingga namanya jatuh SATU HURUF PER BARIS.
///
///  Analyzer tidak menandainya: `expanded` punya nilai bawaan yang sah. Test
///  yang ada juga tidak: tidak satu pun pernah MERENDER kartunya dengan data.
///  Di mode debug, layout begini melempar galat — jadi cukup satu test yang
///  merendernya untuk mengubah "terlihat rusak di HP penguji" menjadi "gagal
///  di CI".
/// ============================================================================
void main() {
  Future<void> pasang(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SessionController>.value(
        value: _SesiDenganAkun(),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DemoAccountPicker(role: 'driver'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('tombol Masuk ada di layar untuk setiap akun', (
    WidgetTester tester,
  ) async {
    await pasang(tester);

    expect(find.text('Masuk'), findsNWidgets(2));

    // Bukan cuma ada di pohon widget — benar-benar DI DALAM layar. Tombol yang
    // terdorong keluar tepi kanan tetap ditemukan oleh find, tapi tidak bisa
    // ditekan siapa pun.
    final Size layar = tester.view.physicalSize / tester.view.devicePixelRatio;

    for (final Element e in find.text('Masuk').evaluate()) {
      final Rect kotak = tester.getRect(
        find.byElementPredicate((el) => el == e),
      );

      expect(
        kotak.right <= layar.width,
        isTrue,
        reason:
            'Tombol Masuk berada di luar tepi kanan layar '
            '(${kotak.right} > ${layar.width}). Pengguna melihat kartu akun '
            'tanpa tombol apa pun.',
      );
    }
  });

  testWidgets('nama akun tidak jatuh satu huruf per baris', (
    WidgetTester tester,
  ) async {
    await pasang(tester);

    final Rect nama = tester.getRect(find.text('Sutrisno (Demo)'));

    expect(
      nama.width > nama.height,
      isTrue,
      reason:
          'Nama akun lebih tinggi daripada lebarnya (${nama.size}) — hurufnya '
          'sedang jatuh satu per baris karena kolom teksnya kebagian lebar '
          'hampir nol.',
    );
  });
}

// -----------------------------------------------------------------------------

class _SesiDenganAkun extends SessionController {
  _SesiDenganAkun()
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

  @override
  Future<DemoAccountList> demoAccounts(String role) async {
    return const DemoAccountList(
      enabled: true,
      accounts: <DemoAccount>[
        DemoAccount(
          uuid: '11111111-1111-1111-1111-111111111111',
          name: 'Sutrisno (Demo)',
          phone: '0899000000002',
          role: 'driver',
          note: 'Dokumen lengkap, saldo Rp 100.000.',
        ),
        DemoAccount(
          uuid: '22222222-2222-2222-2222-222222222222',
          name: 'Budi Penumpang (Demo)',
          phone: '0899000000001',
          role: 'driver',
        ),
      ],
    );
  }
}
