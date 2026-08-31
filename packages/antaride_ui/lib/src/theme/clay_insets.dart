import 'package:flutter/material.dart';

/// Ruang sistem di tepi layar.
///
/// ============================================================================
///  KENAPA `viewPadding`, BUKAN `padding`
/// ============================================================================
///  Keduanya melaporkan tinggi bilah navigasi Android — tapi `padding` menjadi
///  NOL begitu ada widget di atasnya yang sudah mengonsumsinya, misalnya
///  `SafeArea` di bagian lain layar yang sama.
///
///  Akibatnya khas dan membingungkan: kode yang sama bekerja di satu layar dan
///  tidak di layar lain, tergantung ada tidaknya SafeArea di atasnya. Yang
///  terlihat pengguna adalah tombol terakhir yang duduk persis di belakang
///  tombol kembali/home/aplikasi milik sistem — bisa dilihat, tidak bisa
///  ditekan.
///
///  `viewPadding` selalu melaporkan tinggi bilah yang sebenarnya, jadi
///  hasilnya tidak bergantung pada susunan widget di atasnya.
/// ============================================================================
///
/// ============================================================================
///  KENAPA EXTENSION, BUKAN SafeArea SAJA
/// ============================================================================
///  `SafeArea` membungkus dan MEMOTONG. Untuk daftar yang bisa digulir, itu
///  salah: isinya jadi berhenti di atas bilah navigasi dengan pita kosong yang
///  ikut bergulir, alih-alih mengalir sampai tepi layar dan hanya menambah
///  ruang di AKHIR gulirannya.
///
///  Yang benar untuk daftar adalah menambahkan ruangnya ke `padding` bawah
///  daftar itu — dan itulah yang dipakai extension ini.
/// ============================================================================
extension ClayInsets on BuildContext {
  /// Tinggi bilah navigasi sistem di tepi bawah layar.
  ///
  /// Nol di perangkat dengan navigasi gestur penuh.
  double get ruangBawah => MediaQuery.viewPaddingOf(this).bottom;

  /// Tinggi status bar di tepi atas layar.
  double get ruangAtas => MediaQuery.viewPaddingOf(this).top;
}
