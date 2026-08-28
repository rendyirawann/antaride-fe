import 'package:latlong2/latlong.dart';

/// Encoded Polyline Algorithm Format.
///
/// ============================================================================
///  DITULIS SENDIRI, DAN ALASANNYA BUKAN KEENGGANAN MEMAKAI PAKET
/// ============================================================================
///  Algoritmanya tetap dan sudah puluhan tahun tidak berubah — sekitar empat
///  puluh baris. Paket yang menyediakannya biasanya juga membawa perhitungan
///  jarak, simplifikasi, dan tipe koordinatnya sendiri, dan tipe koordinat
///  tersendiri itu yang bermasalah: dia harus dikonversi ke `LatLng` milik
///  flutter_map di setiap pemakaian.
///
///  PRESISINYA HARUS 5, sama dengan yang dipakai OSRM di backend. Presisi 6 —
///  yang dipakai sebagian pustaka sebagai bawaan — menghasilkan koordinat yang
///  sepuluh kali lipat salah, dan gejalanya rute yang tergambar di tengah laut.
///  Itu terlihat jelas dan mudah diperbaiki; yang lebih berbahaya adalah kalau
///  hanya sebagian jalur yang salah.
/// ============================================================================
class PolylineCodec {
  const PolylineCodec._();

  /// Presisi OSRM. Lihat penjelasan di atas — jangan diubah tanpa mengubah
  /// backend.
  static const int precision = 5;

  /// Urai polyline terenkode menjadi daftar titik.
  ///
  /// Mengembalikan daftar kosong untuk masukan kosong atau rusak. TIDAK
  /// melempar: polyline yang rusak berarti rutenya tidak bisa digambar, dan
  /// layar peta harus tetap tampil dengan penanda jemput dan tujuan. Exception
  /// di sini akan menjatuhkan seluruh layar pelacakan.
  static List<LatLng> decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return const <LatLng>[];
    }

    final List<LatLng> titik = <LatLng>[];
    final int pembagi = _pow10(precision);

    int indeks = 0;
    int lat = 0;
    int lng = 0;

    try {
      while (indeks < encoded.length) {
        lat += _bacaSelisih(encoded, indeks, (int i) => indeks = i);
        lng += _bacaSelisih(encoded, indeks, (int i) => indeks = i);

        titik.add(LatLng(lat / pembagi, lng / pembagi));
      }
    } catch (_) {
      // Kembalikan yang sudah berhasil diurai. Separuh rute lebih berguna
      // daripada tidak ada rute — dan penanda jemput serta tujuan tetap ada,
      // jadi peta tidak pernah kosong sama sekali.
      return titik;
    }

    return titik;
  }

  /// Rangkai daftar titik menjadi polyline terenkode.
  ///
  /// Dipakai aplikasi driver untuk mengirim jejak GPS perjalanan saat
  /// menyelesaikan order. Kirim sebagai polyline, bukan sebagai array JSON
  /// berisi ribuan objek `{lat, lng}`: sebuah perjalanan 30 menit dengan ping
  /// tiap 4 detik menghasilkan 450 titik, dan bedanya sekitar 18 KB melawan
  /// 1 KB. Di jaringan yang buruk, itu bedanya antara terkirim dan timeout.
  static String encode(List<LatLng> titik) {
    if (titik.isEmpty) {
      return '';
    }

    final StringBuffer hasil = StringBuffer();
    final int pengali = _pow10(precision);

    int latSebelum = 0;
    int lngSebelum = 0;

    for (final LatLng t in titik) {
      final int lat = (t.latitude * pengali).round();
      final int lng = (t.longitude * pengali).round();

      _tulisSelisih(hasil, lat - latSebelum);
      _tulisSelisih(hasil, lng - lngSebelum);

      latSebelum = lat;
      lngSebelum = lng;
    }

    return hasil.toString();
  }

  // ---------------------------------------------------------------------------

  static int _bacaSelisih(
    String encoded,
    int mulai,
    void Function(int) setIndeks,
  ) {
    int indeks = mulai;
    int hasil = 0;
    int geser = 0;
    int b;

    do {
      b = encoded.codeUnitAt(indeks++) - 63;
      hasil |= (b & 0x1f) << geser;
      geser += 5;
    } while (b >= 0x20);

    setIndeks(indeks);

    return (hasil & 1) != 0 ? ~(hasil >> 1) : hasil >> 1;
  }

  static void _tulisSelisih(StringBuffer keluar, int nilai) {
    int v = nilai < 0 ? ~(nilai << 1) : nilai << 1;

    while (v >= 0x20) {
      keluar.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }

    keluar.writeCharCode(v + 63);
  }

  static int _pow10(int eksponen) {
    int hasil = 1;

    for (int i = 0; i < eksponen; i++) {
      hasil *= 10;
    }

    return hasil;
  }
}
