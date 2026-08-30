import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hero header, overlap, dan animasi masuk.
///
/// ============================================================================
///  APA YANG DIJAGA BERKAS INI
/// ============================================================================
///  Tiga hal yang tidak tertangkap analyzer dan gampang pecah diam-diam:
///
///    1. Hero di HP sempit (320) — judul panjang harus MEMBUNGKUS, bukan
///       meluap. Overflow horizontal hanya muncul saat dirender, dan HP 320
///       masih nyata di pasar aplikasi ini.
///    2. Overlap ClayHeroScaffold benar-benar MENUMPANG tepi bawah hero.
///       Implementasinya trik layout (Align heightFactor 0.5) yang mudah
///       "diperbaiki" orang menjadi Transform — yang terlihat sama sekilas
///       tapi meninggalkan lubang layout. Test ini membandingkan Rect.
///    3. ClayEntrance berakhir TERLIHAT PENUH. Animasi yang berhenti di
///       opacity 0.97 tidak terlihat di emulator dan terlihat di perangkat.
/// ============================================================================
void main() {
  /// HP sempit: 320 logical piksel. dpr dipaksa 1 supaya angka fisik = logis.
  Future<void> pasang(
    WidgetTester tester, {
    required Brightness kecerahan,
    required Widget child,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: kecerahan == Brightness.dark
            ? ClayTheme.dark()
            : ClayTheme.light(),
        home: child,
      ),
    );
  }

  /// Hero dengan SEMUA slot terisi — susunan terlebar yang mungkin.
  Widget heroLengkap({required bool compact}) {
    return ClayHeroHeader(
      accent: ClayTokens.primary,
      title: 'Selamat datang kembali di Antaride',
      subtitle: 'Perjalanan, makanan, dan kiriman dalam satu aplikasi.',
      leading: const ClayBackButton(),
      trailing: const Icon(Icons.notifications_none, color: Colors.white),
      bottom: Row(
        children: <Widget>[
          const ClayIconChip(icon: Icons.wallet, accent: ClayTokens.primary),
          const SizedBox(width: ClayTokens.space3),
          const Expanded(
            child: Text(
              'Saldo Rp1.250.000 siap dipakai',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      compact: compact,
    );
  }

  for (final Brightness kecerahan in <Brightness>[
    Brightness.light,
    Brightness.dark,
  ]) {
    testWidgets('hero di lebar 320 tidak meluap ($kecerahan)', (
      WidgetTester tester,
    ) async {
      await pasang(
        tester,
        kecerahan: kecerahan,
        child: Scaffold(
          // Scroll supaya yang diuji hanya luapan HORIZONTAL — dua hero
          // bertumpuk boleh lebih tinggi dari layar uji.
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                heroLengkap(compact: false),
                heroLengkap(compact: true),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Hero meluap di lebar 320. Judul atau slot bottom-nya tidak '
            'membungkus — dan HP selebar ini masih dipakai pengguna nyata.',
      );
      expect(find.byType(ClayHeroHeader), findsNWidgets(2));
    });
  }

  testWidgets('overlap ClayHeroScaffold menindih tepi bawah hero', (
    WidgetTester tester,
  ) async {
    const Key kunciOverlap = Key('kartu-overlap');

    await pasang(
      tester,
      kecerahan: Brightness.light,
      child: const ClayHeroScaffold(
        header: ClayHeroHeader(accent: ClayTokens.primary, title: 'Dompet'),
        overlap: ClaySurface(
          key: kunciOverlap,
          child: SizedBox(height: 80, width: double.infinity),
        ),
        body: SizedBox.expand(),
      ),
    );

    final Rect hero = tester.getRect(find.byType(ClayHeroHeader));
    final Rect kartu = tester.getRect(find.byKey(kunciOverlap));

    // Menumpang = tepi bawah hero membelah kartunya: atasnya di ATAS garis
    // itu, bawahnya di BAWAH garis itu.
    expect(
      kartu.top,
      lessThan(hero.bottom),
      reason: 'Kartu overlap seluruhnya di bawah hero — tidak menumpang.',
    );
    expect(
      kartu.bottom,
      greaterThan(hero.bottom),
      reason:
          'Kartu overlap seluruhnya di dalam hero — tenggelam, '
          'bukan menumpang.',
    );

    // Dan tepat SETENGAH tingginya yang naik, sesuai janji docblock-nya.
    expect(kartu.center.dy, moreOrLessEquals(hero.bottom, epsilon: 0.01));
  });

  testWidgets('ClayEntrance berakhir terlihat penuh', (
    WidgetTester tester,
  ) async {
    await pasang(
      tester,
      kecerahan: Brightness.light,
      child: const Scaffold(
        body: Column(
          children: <Widget>[
            ClayEntrance(index: 0, child: Text('pertama')),
            ClayEntrance(index: 3, child: Text('terakhir')),
          ],
        ),
      ),
    );

    // Saat frame pertama, giliran index 3 belum mulai: masih tak terlihat.
    final FadeTransition sebelum = tester.widget(
      find
          .ancestor(
            of: find.text('terakhir'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(sebelum.opacity.value, 0);

    await tester.pumpAndSettle();

    for (final String teks in <String>['pertama', 'terakhir']) {
      final FadeTransition sesudah = tester.widget(
        find
            .ancestor(
              of: find.text(teks),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(
        sesudah.opacity.value,
        1,
        reason:
            'Elemen "$teks" tidak berakhir di opacity 1 — animasi masuknya '
            'berhenti di tengah jalan.',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('ClayEntrance aman di-dispose sebelum animasinya selesai', (
    WidgetTester tester,
  ) async {
    await pasang(
      tester,
      kecerahan: Brightness.light,
      child: const Scaffold(
        body: ClayEntrance(index: 5, child: Text('pergi duluan')),
      ),
    );

    // Baru 50 ms — giliran index 5 (jeda 350 ms) bahkan belum mulai.
    await tester.pump(const Duration(milliseconds: 50));

    // Pengguna pindah layar: widget-nya dibuang saat animasi masih berjalan.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason:
          'Membuang ClayEntrance di tengah animasi melempar — ada callback '
          'atau ticker yang hidup lebih lama dari State-nya.',
    );
  });
}
