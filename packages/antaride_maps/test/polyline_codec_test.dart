import 'package:antaride_maps/antaride_maps.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
///  KENAPA POLYLINE YANG DIUJI PALING KETAT
/// ============================================================================
///  Kesalahan di sini tidak menghasilkan galat. Yang dihasilkannya adalah rute
///  yang tergambar di tempat yang salah — dan kalau salahnya kecil, tidak ada
///  yang menyadarinya sampai ada penumpang yang membandingkan jarak di peta
///  dengan ongkos yang dia bayar.
///
///  Nilai acuan di bawah diambil dari spesifikasi Google Encoded Polyline
///  Algorithm Format, bukan dari hasil implementasi ini sendiri. Test yang
///  memakai keluaran implementasinya sendiri sebagai acuan hanya membuktikan
///  bahwa kodenya konsisten dengan dirinya.
/// ============================================================================
void main() {
  group('PolylineCodec.decode', () {
    test('menguraikan contoh acuan dari spesifikasi', () {
      // Contoh kanonik: tiga titik, presisi 5.
      const String encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

      final List<LatLng> titik = PolylineCodec.decode(encoded);

      expect(titik, hasLength(3));

      expect(titik[0].latitude, closeTo(38.5, 0.00001));
      expect(titik[0].longitude, closeTo(-120.2, 0.00001));

      expect(titik[1].latitude, closeTo(40.7, 0.00001));
      expect(titik[1].longitude, closeTo(-120.95, 0.00001));

      expect(titik[2].latitude, closeTo(43.252, 0.00001));
      expect(titik[2].longitude, closeTo(-126.453, 0.00001));
    });

    test('presisinya 5, sama dengan OSRM di backend', () {
      // Presisi 6 akan menghasilkan koordinat sepuluh kali lipat lebih kecil.
      // Kalau konstanta ini berubah tanpa backend ikut berubah, rute akan
      // tergambar di tengah laut — dan test ini yang menangkapnya.
      expect(PolylineCodec.precision, 5);
    });

    test('masukan kosong dan null menghasilkan daftar kosong, bukan galat', () {
      expect(PolylineCodec.decode(null), isEmpty);
      expect(PolylineCodec.decode(''), isEmpty);
    });

    /// ========================================================================
    ///  POLYLINE RUSAK TIDAK BOLEH MELEMPAR
    /// ========================================================================
    ///  Layar pelacakan harus tetap tampil dengan penanda jemput dan tujuan
    ///  walaupun rutenya tidak bisa digambar. Exception di sini akan
    ///  menjatuhkan seluruh layar — pada penumpang yang sedang menunggu driver.
    /// ========================================================================
    test(
      'masukan rusak tidak melempar dan mengembalikan yang sudah terurai',
      () {
        // Dipotong di tengah blok varint: byte terakhir menandakan masih ada
        // lanjutan yang tidak ada.
        const String terpotong = '_p~iF~ps|U_ulL';

        expect(() => PolylineCodec.decode(terpotong), returnsNormally);
        expect(PolylineCodec.decode(terpotong), isNotEmpty);
      },
    );

    test('karakter di luar rentang tidak melempar', () {
      expect(() => PolylineCodec.decode('!!!!'), returnsNormally);
    });
  });

  group('PolylineCodec.encode', () {
    test('encode lalu decode mengembalikan titik yang sama', () {
      // Rute pendek di Medan: Lapangan Merdeka ke arah Jl. Iskandar Muda.
      final List<LatLng> asli = <LatLng>[
        const LatLng(3.59520, 98.67220),
        const LatLng(3.59810, 98.66940),
        const LatLng(3.60150, 98.66510),
        const LatLng(3.60420, 98.66120),
      ];

      final List<LatLng> pulang = PolylineCodec.decode(
        PolylineCodec.encode(asli),
      );

      expect(pulang, hasLength(asli.length));

      for (int i = 0; i < asli.length; i++) {
        // Toleransi 1e-5 = presisi 5, yaitu sekitar satu meter. Itu batas
        // ketelitian formatnya, bukan kelonggaran yang dipilih.
        expect(pulang[i].latitude, closeTo(asli[i].latitude, 0.00001));
        expect(pulang[i].longitude, closeTo(asli[i].longitude, 0.00001));
      }
    });

    test('koordinat negatif ikut bertahan lewat encode-decode', () {
      // Medan ada di bujur positif, jadi tanda negatif tidak akan pernah
      // teruji oleh data sungguhan — padahal encoding zigzag-nya justru
      // paling mudah salah pada nilai negatif.
      final List<LatLng> asli = <LatLng>[
        const LatLng(-6.20880, 106.84560),
        const LatLng(-6.21500, 106.85210),
      ];

      final List<LatLng> pulang = PolylineCodec.decode(
        PolylineCodec.encode(asli),
      );

      expect(pulang[0].latitude, closeTo(-6.20880, 0.00001));
      expect(pulang[1].latitude, closeTo(-6.21500, 0.00001));
    });

    test('daftar kosong menghasilkan string kosong', () {
      expect(PolylineCodec.encode(const <LatLng>[]), '');
    });

    test('satu titik tetap bisa dienkode', () {
      final List<LatLng> pulang = PolylineCodec.decode(
        PolylineCodec.encode(<LatLng>[const LatLng(3.5952, 98.6722)]),
      );

      expect(pulang, hasLength(1));
      expect(pulang.first.latitude, closeTo(3.5952, 0.00001));
    });
  });
}
