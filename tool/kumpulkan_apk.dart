// ignore_for_file: avoid_print
//
// `print` memang alat yang benar di sini: ini skrip baris perintah, dan
// keluarannya untuk orang yang sedang menonton terminal — bukan log aplikasi.

import 'dart:io';

/// Mengumpulkan APK universal ketiga aplikasi ke satu folder di Desktop.
///
/// ============================================================================
///  KENAPA PERLU LANGKAH TERSENDIRI
/// ============================================================================
///  `flutter build apk` menaruh hasilnya di
///  `apps/<aplikasi>/build/app/outputs/flutter-apk/app-release.apk`.
///
///  Tiga masalah sekaligus:
///
///    Namanya SAMA     ketiganya bernama `app-release.apk`. Dikirim lewat
///                     WhatsApp, penerimanya mendapat tiga berkas bernama sama
///                     di folder unduhan — dan tidak ada cara membedakan mana
///                     yang driver.
///
///    Jalurnya dalam   enam tingkat direktori, dan orang yang mengambilnya
///                     bukan yang membuildnya.
///
///    Tidak berversi   APK lama dan baru tidak bisa dibedakan setelah disalin.
///                     Penguji yang melaporkan bug pada "versi kemarin" tidak
///                     punya cara menyebut versi mana.
/// ============================================================================
///
/// ============================================================================
///  DART, BUKAN SHELL SCRIPT
/// ============================================================================
///  Melos menjalankan `exec` lewat shell bawaan sistem. Di Windows itu
///  `cmd.exe`, yang tidak punya `cp`, `mkdir -p`, maupun ekspansi `$VAR` gaya
///  POSIX.
///
///  Proyek ini dikembangkan di Windows dan akan di-build di Linux nanti. Skrip
///  shell berarti dua versi yang harus dijaga sepakat — dan yang jarang
///  dijalankan akan menyimpang tanpa ada yang menyadarinya.
/// ============================================================================
void main(List<String> args) {
  final Directory akar = Directory.current;

  final String versi = _bacaVersi(akar);

  final Directory tujuan = Directory(_folderTujuan(args));

  if (!tujuan.existsSync()) {
    tujuan.createSync(recursive: true);
  }

  print('Menyalin APK ke: ${tujuan.path}\n');

  int berhasil = 0;

  for (final _Aplikasi app in _aplikasi) {
    final File sumber = File(
      '${akar.path}/apps/${app.direktori}/build/app/outputs/'
      'flutter-apk/app-release.apk',
    );

    if (!sumber.existsSync()) {
      /*
       * TIDAK melempar, dan tidak menghentikan yang lain.
       *
       * Yang paling sering menyebabkannya: `apk:universal:all` dijalankan
       * setelah `apk:*` (split-per-abi), yang TIDAK menghasilkan
       * `app-release.apk` — dia menghasilkan tiga berkas per arsitektur.
       *
       * Menghentikan seluruh proses untuk satu aplikasi yang belum di-build
       * berarti dua APK yang sudah jadi ikut tidak tersalin.
       */
      print('  LEWAT  ${app.label}');
      print('         Tidak ada di ${sumber.path}');
      print('         Jalankan dulu: melos run apk:universal:${app.skrip}\n');

      continue;
    }

    final String nama = 'antaride-${app.berkas}-v$versi.apk';
    final File target = File('${tujuan.path}/$nama');

    sumber.copySync(target.path);

    final double mb = target.lengthSync() / (1024 * 1024);

    print('  OK     $nama  (${mb.toStringAsFixed(1)} MB)');

    berhasil++;
  }

  if (berhasil == 0) {
    print('\nTidak ada APK yang disalin.');

    // Kode keluar bukan nol supaya `melos run` menandainya gagal. Langkah yang
    // "berhasil" tanpa menghasilkan apa pun adalah kegagalan yang paling mudah
    // terlewat.
    exit(1);
  }

  _tulisPetunjuk(tujuan, versi);

  print('\nSelesai. $berhasil APK di ${tujuan.path}');
}

/// Folder tujuan.
///
/// Argumen pertama kalau ada, kalau tidak Desktop pengguna.
///
/// Desktop dicari di dua tempat: `%USERPROFILE%\Desktop` dan
/// `%USERPROFILE%\OneDrive\Desktop`. OneDrive MEMINDAHKAN folder Desktop saat
/// sinkronisasi dinyalakan, dan yang lama tetap ada tapi kosong — jadi menulis
/// ke jalur pertama yang ditemukan akan menaruh berkas di folder yang tidak
/// dilihat siapa pun.
String _folderTujuan(List<String> args) {
  if (args.isNotEmpty && args.first.trim().isNotEmpty) {
    return args.first;
  }

  final Map<String, String> env = Platform.environment;

  final String? profil = env['USERPROFILE'] ?? env['HOME'];

  if (profil == null) {
    return 'apk-siap-bagikan';
  }

  // OneDrive lebih dulu: kalau dia ada, DIA yang dilihat pengguna di layar.
  for (final String kandidat in <String>[
    '$profil/OneDrive/Desktop',
    '$profil/Desktop',
  ]) {
    if (Directory(kandidat).existsSync()) {
      return '$kandidat/Antaride-APK';
    }
  }

  return '$profil/Antaride-APK';
}

/// Versi dari `apps/customer/pubspec.yaml`.
///
/// Ketiga aplikasi memakai versi yang sama, dan aplikasi penumpang yang jadi
/// acuannya. Kalau nanti versinya dipisah per aplikasi, baca masing-masing —
/// tapi selama masih sama, satu sumber lebih baik daripada tiga yang harus
/// sepakat.
String _bacaVersi(Directory akar) {
  final File pubspec = File('${akar.path}/apps/customer/pubspec.yaml');

  if (!pubspec.existsSync()) {
    return '0.0.0';
  }

  for (final String baris in pubspec.readAsLinesSync()) {
    if (!baris.startsWith('version:')) {
      continue;
    }

    // `1.0.0+1` → `1.0.0`. Build number dibuang: yang dibaca penguji versi
    // semantiknya, dan `+1` hanya menambah kebingungan pada nama berkas.
    return baris.split(':')[1].trim().split('+').first;
  }

  return '0.0.0';
}

/// Catatan singkat untuk yang menerima APK-nya.
void _tulisPetunjuk(Directory tujuan, String versi) {
  final File berkas = File('${tujuan.path}/BACA-DULU.txt');

  berkas.writeAsStringSync('''
ANTARIDE — APK uji coba v$versi
==============================================================================

ISI FOLDER INI
------------------------------------------------------------------------------
  antaride-penumpang-v$versi.apk   aplikasi untuk penumpang
  antaride-driver-v$versi.apk      aplikasi untuk driver
  antaride-merchant-v$versi.apk    aplikasi untuk merchant

Ketiganya aplikasi TERPISAH dan bisa dipasang bersamaan di satu HP.


CARA MEMASANG
------------------------------------------------------------------------------
  1. Salin APK-nya ke HP Android.
  2. Buka berkasnya lewat aplikasi Berkas / File Manager.
  3. Android akan meminta izin "Instal aplikasi tidak dikenal" — izinkan untuk
     aplikasi Berkas yang Anda pakai.
  4. Tekan Pasang.

APK ini UNIVERSAL: bisa dipasang di HP Android mana pun tanpa memilih
arsitektur. Tidak perlu tahu HP Anda arm64 atau bukan.


SERVER YANG DIHUBUNGI
------------------------------------------------------------------------------
  https://beoulve-dev.biz.id/antaride-be/api/v1

Alamat ini TERTANAM di dalam APK saat build — tidak ada pengaturan di dalam
aplikasi untuk mengubahnya. Untuk menunjuk ke server lain, APK-nya harus
di-build ulang.

Kalau server itu belum hidup, yang muncul di setiap layar adalah
"Terjadi gangguan. Coba lagi." Itu bukan aplikasi yang rusak.


IZIN YANG DIMINTA
------------------------------------------------------------------------------
  Semua       internet, lokasi, kamera, galeri
  Driver      TAMBAHAN: lokasi latar belakang, notifikasi

Lokasi latar belakang di aplikasi driver dipakai untuk mengirim posisi selama
bekerja, termasuk saat layar mati. Tanpa itu driver berhenti menerima order
begitu HP-nya dikunci.

Izin notifikasi di aplikasi driver WAJIB diberikan. Android mewajibkan
notifikasi yang terlihat selama posisi dikirim di latar belakang; kalau ditolak,
posisi hanya terkirim selama aplikasi terbuka — dan aplikasi akan memberi tahu
Anda kalau itu terjadi.


CATATAN
------------------------------------------------------------------------------
APK ini ditandatangani kunci DEBUG. Bisa dipasang lewat sideload, TIDAK bisa
diunggah ke Play Store. Untuk rilis sungguhan, siapkan keystore dan
android/key.properties lebih dulu.
''');

  print('  OK     BACA-DULU.txt');
}

/// Satu aplikasi yang akan disalin.
class _Aplikasi {
  const _Aplikasi({
    required this.direktori,
    required this.skrip,
    required this.berkas,
    required this.label,
  });

  /// Nama direktori di `apps/`.
  final String direktori;

  /// Akhiran nama skrip melos, untuk pesan bantuan saat berkasnya tidak ada.
  final String skrip;

  /// Bagian nama berkas hasil salinan.
  ///
  /// Bahasa Indonesia, bukan nama direktorinya: yang membaca nama berkas ini
  /// penguji, bukan pengembang. `antaride-penumpang.apk` langsung terbaca;
  /// `antaride-customer.apk` menuntut satu langkah penerjemahan.
  final String berkas;

  final String label;
}

const List<_Aplikasi> _aplikasi = <_Aplikasi>[
  _Aplikasi(
    direktori: 'customer',
    skrip: 'customer',
    berkas: 'penumpang',
    label: 'Penumpang',
  ),
  _Aplikasi(
    direktori: 'driver',
    skrip: 'driver',
    berkas: 'driver',
    label: 'Driver',
  ),
  _Aplikasi(
    direktori: 'merchant',
    skrip: 'merchant',
    berkas: 'merchant',
    label: 'Merchant',
  ),
];
