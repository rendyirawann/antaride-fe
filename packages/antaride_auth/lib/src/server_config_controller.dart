import 'package:antaride_api/antaride_api.dart';
import 'package:flutter/foundation.dart';

/// Memegang konfigurasi yang datang dari server.
///
/// ============================================================================
///  KENAPA CONTROLLER, BUKAN SEKADAR FUTURE DI SATU LAYAR
/// ============================================================================
///  Area layanan dibutuhkan di beberapa tempat yang tidak saling mengenal:
///  peta beranda, pemilih rute, dan kolom pencarian alamat. Kalau tiap layar
///  memanggilnya sendiri, membuka pemilih rute berarti satu request tambahan
///  untuk jawaban yang sudah ada di memori — di jaringan seluler yang buruk,
///  itu terlihat sebagai peta yang lambat muncul.
///
///  Satu instans di akar aplikasi, dimuat sekali saat mulai.
/// ============================================================================
///
/// ============================================================================
///  TIDAK PERNAH GAGAL, DAN ITU DISENGAJA
/// ============================================================================
///  [config] selalu berisi sesuatu: [ServerConfig.bawaan] sebelum jawaban
///  pertama datang, dan tetap bawaan kalau servernya tidak bisa dihubungi.
///
///  Alternatifnya — keadaan "belum dimuat" yang harus ditangani setiap
///  pembaca — berarti peta harus memutuskan apa yang digambar saat konfigurasi
///  belum ada, di SETIAP layar. Yang biasanya terjadi: satu layar lupa, dan
///  petanya terbuka di koordinat (0, 0) yaitu Teluk Guinea.
/// ============================================================================
class ServerConfigController extends ChangeNotifier {
  ServerConfigController(this._places);

  final PlaceRepository _places;

  ServerConfig _config = ServerConfig.bawaan;

  ServerConfig get config => _config;

  /// Sudah pernah mendapat jawaban dari server.
  ///
  /// Dipakai untuk memutuskan apakah perlu memuat ulang, BUKAN untuk
  /// memutuskan apakah [config] boleh dibaca — dia selalu boleh dibaca.
  bool get sudahDimuat => _sudahDimuat;
  bool _sudahDimuat = false;

  /// Dipanggil sekali saat aplikasi mulai.
  ///
  /// Kegagalan tidak dilaporkan ke mana pun: yang terjadi hanyalah peta memakai
  /// titik tengah bawaan sampai pemuatan berikutnya berhasil, dan tidak ada
  /// yang bisa dilakukan pengguna soal itu.
  Future<void> muat() async {
    final ServerConfig hasil = await _places.config();

    _config = hasil;
    _sudahDimuat = true;

    notifyListeners();
  }
}
