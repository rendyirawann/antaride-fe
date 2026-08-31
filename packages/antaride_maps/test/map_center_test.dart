import 'dart:typed_data';

import 'package:antaride_maps/antaride_maps.dart';
// `flutter_map` diimpor langsung: paket antaride_maps sengaja TIDAK
// mengekspornya ulang, supaya layar aplikasi tidak menyentuh API peta mentah.
// Test ini justru harus menyentuhnya — yang diperiksa keadaan kamera peta.
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Peta harus BERGERAK saat titik tengahnya berubah.
///
/// ============================================================================
///  BUG YANG DICEGAH BERKAS INI
/// ============================================================================
///  `MapOptions.initialCenter` dibaca `FlutterMap` sekali saja, saat peta
///  dibuat. Sesuai namanya — tapi akibatnya tidak terlihat sampai ada yang
///  mengubah `center` belakangan.
///
///  Itu persis yang dilakukan layar pemilih rute: peta dibangun lebih dulu
///  dengan titik tengah bawaan, lalu GPS menjawab beberapa detik kemudian.
///  Tanpa perbaikannya, jawaban GPS itu tidak melakukan apa pun — dan yang
///  dilaporkan pengguna adalah "titik penjemputan tidak mendeteksi lokasi
///  saya", padahal izin lokasinya sudah diberikan dan posisinya sudah sampai.
///
///  Analyzer tidak bisa melihat ini: memberi nilai baru ke parameter bernama
///  `initialCenter` adalah kode yang sah dan masuk akal.
/// ============================================================================
void main() {
  /*
   * ==========================================================================
   *  TILE PETA DIPALSUKAN, BUKAN DIBIARKAN GAGAL
   * ==========================================================================
   *  `FlutterMap` meminta belasan tile lewat HTTP begitu dia tergambar. Di
   *  lingkungan test, HttpClient bawaan menolak semuanya dengan 400 — dan tiap
   *  penolakan menjadi exception yang menggagalkan test, walaupun yang diuji
   *  di sini bukan tile-nya melainkan posisi kamera.
   *
   *  Diganti penyedia tile yang tidak menyentuh jaringan sama sekali, jadi
   *  kegagalannya hilang tanpa menyembunyikan galat lain: exception apa pun DI
   *  LUAR pemuatan tile tetap menggagalkan test seperti biasa.
   * ==========================================================================
   */
  setUpAll(() {
    // ignore: invalid_use_of_visible_for_testing_member
    AntarideMapTestHooks.penyediaTile = _TileKosong();
  });

  tearDownAll(() {
    // ignore: invalid_use_of_visible_for_testing_member
    AntarideMapTestHooks.penyediaTile = null;
  });

  const LatLng awal = LatLng(3.5697, 98.7748); // titik tengah area
  const LatLng gps = LatLng(3.5497, 98.8756); // Lubuk Pakam

  testWidgets('peta mengikuti center yang berubah setelah dibangun', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<LatLng> pusat = ValueNotifier<LatLng>(awal);
    addTearDown(pusat.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<LatLng>(
            valueListenable: pusat,
            builder: (BuildContext _, LatLng nilai, Widget? _) =>
                AntarideMap(center: nilai, fitToContent: false),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_kamera(tester).center, awal);

    // GPS menjawab.
    pusat.value = gps;
    await tester.pumpAndSettle();

    expect(
      _kamera(tester).center,
      gps,
      reason:
          'Peta tidak pindah ke posisi GPS. Pengguna melihat peta yang membuka '
          'kota bawaan walaupun izin lokasinya sudah diberikan, tanpa satu pun '
          'galat yang menjelaskannya.',
    );
  });

  testWidgets('zoom pengguna tidak dibuang saat peta pindah', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<LatLng> pusat = ValueNotifier<LatLng>(awal);
    addTearDown(pusat.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<LatLng>(
            valueListenable: pusat,
            builder: (BuildContext _, LatLng nilai, Widget? _) => AntarideMap(
              center: nilai,
              initialZoom: 12,
              fitToContent: false,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Pengguna memperbesar peta sebelum GPS menjawab.
    _kontroler(tester).move(awal, 16);
    await tester.pumpAndSettle();

    pusat.value = gps;
    await tester.pumpAndSettle();

    expect(
      _kamera(tester).zoom,
      16,
      reason:
          'Zoom dikembalikan ke nilai awal saat peta pindah — penyesuaian yang '
          'baru saja dilakukan pengguna dibuang.',
    );
  });
}

// `MapCamera.of` dan `MapController.of` menuntut context KETURUNAN FlutterMap,
// bukan context FlutterMap itu sendiri. TileLayer selalu ada di dalamnya.
MapCamera _kamera(WidgetTester tester) {
  return MapCamera.of(tester.element(find.byType(TileLayer)));
}

MapController _kontroler(WidgetTester tester) {
  return MapController.of(tester.element(find.byType(TileLayer)));
}

// -----------------------------------------------------------------------------

/// Penyedia tile yang tidak pernah menyentuh jaringan.
class _TileKosong extends TileProvider {
  _TileKosong();

  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return MemoryImage(_png);
  }

  /// PNG 1x1 transparan.
  static final Uint8List _png = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);
}
