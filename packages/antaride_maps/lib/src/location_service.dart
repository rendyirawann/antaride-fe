import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Titik tengah Medan: Lapangan Merdeka.
///
/// ============================================================================
///  KENAPA ADA POSISI CADANGAN SAMA SEKALI
/// ============================================================================
///  Peta HARUS punya sesuatu untuk ditampilkan sejak frame pertama. Peta yang
///  terbuka di koordinat (0, 0) menampilkan Teluk Guinea, dan pengguna yang
///  melihatnya menyimpulkan aplikasinya rusak — bukan menunggu izin lokasi.
///
///  Dipakai kalau izin lokasi ditolak, GPS mati, atau posisinya belum datang.
///  Dan dipakai HANYA untuk menentukan tampilan awal peta: pemesanan tetap
///  menuntut titik jemput yang dipilih pengguna, dan tidak boleh diam-diam
///  memakai koordinat ini.
/// ============================================================================
const LatLng medanCenter = LatLng(3.5896, 98.6739);

/// Hasil permintaan posisi.
sealed class LocationOutcome {
  const LocationOutcome();
}

final class LocationReady extends LocationOutcome {
  const LocationReady(this.position, {this.accuracyM});

  final LatLng position;
  final double? accuracyM;
}

/// Izin ditolak, layanan lokasi mati, atau GPS tidak menjawab.
///
/// ============================================================================
///  SATU TIPE UNTUK KETIGANYA, DENGAN ALASAN YANG BISA DITINDAKLANJUTI
/// ============================================================================
///  Tiga hal itu perlu tindakan yang berbeda dari pengguna:
///
///    deniedForever   harus dibuka di pengaturan sistem — dialog izin tidak
///                    akan muncul lagi, dan tombol "izinkan" yang memanggilnya
///                    ulang tidak melakukan apa pun. Tombol yang tidak
///                    melakukan apa pun adalah bentuk kegagalan yang paling
///                    membingungkan.
///    serviceDisabled GPS perangkatnya mati. Izin aplikasi tidak relevan.
///    timeout         boleh dicoba lagi di tempat yang sama.
/// ============================================================================
final class LocationUnavailable extends LocationOutcome {
  const LocationUnavailable(this.reason, this.message);

  final LocationFailureReason reason;
  final String message;
}

enum LocationFailureReason {
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  unknown,
}

/// Akses posisi perangkat.
class LocationService {
  const LocationService();

  /// Posisi sekarang, sekali ambil.
  ///
  /// Batas waktunya 10 detik. GPS di dalam ruangan bisa tidak menjawab
  /// selamanya, dan menunggu tanpa batas berarti layar peta berputar terus
  /// tanpa memberi jalan keluar apa pun.
  Future<LocationOutcome> current({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final LocationOutcome? masalah = await _pastikanIzin();

    if (masalah != null) {
      return masalah;
    }

    try {
      final Position posisi = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      return LocationReady(
        LatLng(posisi.latitude, posisi.longitude),
        accuracyM: posisi.accuracy,
      );
    } on TimeoutException {
      return const LocationUnavailable(
        LocationFailureReason.timeout,
        'Tidak bisa menemukan posisi Anda. Coba keluar ke tempat terbuka.',
      );
    } catch (_) {
      return const LocationUnavailable(
        LocationFailureReason.unknown,
        'Tidak bisa membaca posisi Anda. Coba lagi.',
      );
    }
  }

  /// Aliran posisi, untuk aplikasi driver.
  ///
  /// ==========================================================================
  ///  [distanceFilterM] ADALAH YANG MENJAGA BATERAI DRIVER
  /// ==========================================================================
  ///  Tanpa filter jarak, aliran ini mengirim pembaruan beberapa kali per detik
  ///  walaupun kendaraannya berhenti di lampu merah — dan setiap pembaruan
  ///  membangunkan CPU.
  ///
  ///  Dengan filter 15 meter, driver yang berhenti tidak menghasilkan pembaruan
  ///  sama sekali. Yang penting: itu TIDAK membuatnya hilang dari indeks
  ///  ketersediaan, karena pengiriman ke backend dijadwalkan timer berdasarkan
  ///  `ping_interval_seconds` — bukan dipicu oleh aliran ini.
  ///
  ///  Dua hal terpisah yang sering tercampur: seberapa sering GPS dibaca, dan
  ///  seberapa sering hasilnya dikirim.
  /// ==========================================================================
  Stream<LatLng> watch({int distanceFilterM = 15}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterM,
      ),
    ).map((Position p) => LatLng(p.latitude, p.longitude));
  }

  /// Buka pengaturan aplikasi di sistem.
  ///
  /// Satu-satunya jalan keluar kalau izinnya sudah ditolak permanen.
  Future<void> openSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  // ---------------------------------------------------------------------------

  /// Mengembalikan null kalau izinnya beres.
  Future<LocationOutcome?> _pastikanIzin() async {
    final bool aktif = await Geolocator.isLocationServiceEnabled();

    if (!aktif) {
      return const LocationUnavailable(
        LocationFailureReason.serviceDisabled,
        'Layanan lokasi perangkat sedang mati. Nyalakan dulu untuk melanjutkan.',
      );
    }

    LocationPermission izin = await Geolocator.checkPermission();

    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }

    if (izin == LocationPermission.deniedForever) {
      return const LocationUnavailable(
        LocationFailureReason.deniedForever,
        'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk '
        'mengizinkannya.',
      );
    }

    if (izin == LocationPermission.denied) {
      return const LocationUnavailable(
        LocationFailureReason.denied,
        'Antaride perlu izin lokasi untuk menentukan titik penjemputan.',
      );
    }

    return null;
  }
}
