import 'package:flutter/material.dart';

/// Gradien aksen desain v2.
///
/// ============================================================================
///  SATU WARNA MASUK, BUKAN DUA
/// ============================================================================
///  Semua gradien di aplikasi ini dibangun dari SATU warna aksen yang di-lerp
///  ke hitam — bukan dari dua warna yang dipilih terpisah.
///
///  Alasannya: aksen berbeda per aplikasi (hijau customer, hijau tua driver,
///  amber merchant). Kalau gradien butuh dua warna, harus ada tabel kombinasi
///  tiga baris yang dirawat tiap kali aksen berubah — dan yang terjadi pada
///  tabel seperti itu adalah satu barisnya tertinggal. Lerp ke hitam menjamin
///  aksen APA PUN menghasilkan gradien yang serasi tanpa tabel.
///
///  Arahnya selalu topLeft→bottomRight, mengikuti arah cahaya clay
///  ([ClayTokens.lightDirection]): sisi yang menghadap cahaya lebih terang.
///  Gradien yang arahnya melawan cahaya permukaan di sekitarnya terlihat
///  rusak tanpa ada yang bisa menjelaskan kenapa.
/// ============================================================================
class ClayGradients {
  const ClayGradients._();

  /// Gradien bidang hero — bidang besar di puncak layar.
  ///
  /// Lerp 0.32: cukup gelap supaya teks putih di ujung terangnya TETAP lolos
  /// kontras (aksen paling terang adalah amber merchant, dan di situlah
  /// batasnya diuji), tapi tidak segelap itu sampai ujung bawahnya terbaca
  /// sebagai warna lain.
  static LinearGradient hero(Color aksen) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[aksen, gelapkan(aksen)],
  );

  /// Ujung gelap gradien hero, untuk yang membutuhkan WARNANYA saja.
  ///
  /// Dipakai tempat yang harus sepadan dengan hero tapi bukan bidang bergradien:
  /// warna latar menu di balik sidebar, dan teks di atas lencana putih. Kalau
  /// tempat-tempat itu menghitung lerp-nya sendiri, angka 0.32 tersebar ke
  /// beberapa berkas dan akan menyimpang saat salah satunya disetel.
  static Color gelapkan(Color aksen) => Color.lerp(aksen, Colors.black, 0.32)!;

  /// Gradien chip/tile kecil (40–44 px).
  ///
  /// Lerp 0.28, sedikit lebih landai daripada hero: pada bidang sekecil chip,
  /// gradien sekuat hero berubah jadi dua warna yang bertabrakan karena tidak
  /// ada ruang untuk peralihannya.
  static LinearGradient chip(Color aksen) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[aksen, Color.lerp(aksen, Colors.black, 0.28)!],
  );
}
