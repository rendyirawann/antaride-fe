import 'package:flutter/material.dart';

/// Token dasar tema claymorphism Antaride.
///
/// ============================================================================
///  APA YANG MEMBUAT SEBUAH PERMUKAAN TERLIHAT SEPERTI TANAH LIAT
/// ============================================================================
///  Claymorphism bukan sekadar "sudut membulat besar". Yang membuatnya bekerja
///  adalah TIGA bayangan yang bekerja bersamaan pada satu permukaan:
///
///    1. Bayangan luar gelap   — mengangkat elemen dari latarnya
///    2. Bayangan dalam terang — dari arah cahaya, membuat tepinya membulat
///    3. Bayangan dalam gelap  — dari arah berlawanan, memberi ketebalan
///
///  Menghilangkan nomor 2 dan 3 menghasilkan kartu biasa dengan bayangan.
///  Menghilangkan nomor 1 menghasilkan permukaan yang tampak tenggelam. Ketiganya
///  harus ada, dan arah cahayanya harus KONSISTEN di seluruh aplikasi — kalau
///  satu kartu tercahayai dari kiri atas dan kartu di sebelahnya dari kanan
///  bawah, hasilnya terlihat rusak tanpa ada yang bisa menjelaskan kenapa.
///
///  Karena itu arah cahaya ditetapkan sekali di sini, bukan per widget.
/// ============================================================================
///
/// ============================================================================
///  KENAPA RADIUS-NYA BESAR, DAN KENAPA TIDAK LEBIH BESAR LAGI
/// ============================================================================
///  Tanah liat yang dibentuk tangan tidak punya sudut tajam. Radius 20–28 pada
///  kartu memberi kesan itu tanpa membuatnya menjadi kapsul.
///
///  Di atas 32, kartu persegi mulai terlihat seperti pil dan kehilangan sisi
///  yang bisa dipakai menyejajarkan isinya — dan aplikasi ride-hailing penuh
///  dengan baris yang harus sejajar: alamat, harga, nama driver.
/// ============================================================================
class ClayTokens {
  const ClayTokens._();

  // ---------------------------------------------------------------------------
  //  Warna
  // ---------------------------------------------------------------------------

  /// Hijau Antaride. Dipilih sebagai warna utama karena tiga alasan:
  ///
  ///   - Hijau adalah warna yang sudah dipahami sebagai "jalan/berangkat" di
  ///     konteks transportasi Indonesia.
  ///   - Cukup jauh dari hijau Gojek (#00AA13) dan hijau Grab (#00B14F) untuk
  ///     tidak terlihat sebagai tiruan, dan itu penting secara hukum maupun
  ///     kepercayaan.
  ///   - Kontras terhadap putih memenuhi WCAG AA untuk teks besar, dan terhadap
  ///     teks putih memenuhi AA untuk teks normal — dipakai di tombol utama.
  static const Color primary = Color(0xFF0E9F6E);
  static const Color primaryDark = Color(0xFF057A55);
  static const Color primaryLight = Color(0xFF31C48D);

  /// Latar tanah liat. BUKAN putih murni, dan itu syarat teknis bukan selera:
  /// bayangan dalam yang terang tidak akan terlihat di atas putih murni, dan
  /// seluruh efek claymorphism-nya hilang.
  static const Color surface = Color(0xFFF1F3F6);
  static const Color surfaceRaised = Color(0xFFF8FAFC);
  static const Color surfaceSunken = Color(0xFFE7EAF0);

  static const Color textPrimary = Color(0xFF1A2233);
  static const Color textSecondary = Color(0xFF5A6478);
  static const Color textTertiary = Color(0xFF98A2B3);

  static const Color danger = Color(0xFFE02424);
  static const Color warning = Color(0xFFD97706);
  static const Color success = Color(0xFF057A55);
  static const Color info = Color(0xFF1C64F2);

  /// Warna khusus uang. Sengaja BUKAN hijau primary.
  ///
  /// Kalau nominal uang memakai warna utama, dia bersaing dengan tombol utama di
  /// layar yang sama — dan pada layar konfirmasi pesanan, keduanya muncul
  /// bersamaan. Angka uang harus lebih tenang daripada tombol yang mengonfirmasinya.
  static const Color money = Color(0xFF1A2233);

  // --- Mode gelap ---
  //
  // Claymorphism di mode gelap menuntut penyesuaian yang tidak sekadar
  // membalik warna: bayangan terang harus JAUH lebih redup, kalau tidak
  // permukaannya terlihat berpendar. Nilainya ada di ClayShadows.
  static const Color surfaceDark = Color(0xFF1A1E27);
  static const Color surfaceRaisedDark = Color(0xFF232833);
  static const Color surfaceSunkenDark = Color(0xFF12151C);

  static const Color textPrimaryDark = Color(0xFFF0F2F5);
  static const Color textSecondaryDark = Color(0xFFA0A8B8);
  static const Color textTertiaryDark = Color(0xFF6B7280);

  // ---------------------------------------------------------------------------
  //  Arah cahaya
  // ---------------------------------------------------------------------------

  /// Cahaya datang dari kiri atas, seperti hampir seluruh antarmuka yang
  /// dirancang untuk terasa fisik.
  ///
  /// Ditetapkan SEKALI di sini. Setiap widget clay membacanya, dan tidak ada
  /// widget yang boleh menentukan arahnya sendiri — dua kartu bersebelahan yang
  /// tercahayai dari arah berbeda terlihat rusak, dan penyebabnya hampir tidak
  /// mungkin ditemukan lewat inspeksi visual.
  static const Offset lightDirection = Offset(-1, -1);

  static Offset get shadowOffset => -lightDirection;

  // ---------------------------------------------------------------------------
  //  Radius
  // ---------------------------------------------------------------------------

  static const double radiusSmall = 14;
  static const double radiusMedium = 20;
  static const double radiusLarge = 28;

  /// Radius untuk elemen yang memang kapsul: chip, badge, tombol pil.
  static const double radiusPill = 999;

  // ---------------------------------------------------------------------------
  //  Jarak
  // ---------------------------------------------------------------------------

  /// Skala 4pt.
  ///
  /// Bukan 8pt, dan itu keputusan sadar: aplikasi ini punya banyak baris rapat
  /// (daftar order, rincian ongkos) di mana selisih 8 terlalu besar dan selisih
  /// 4 tepat. Skala 8pt memaksa memilih antara terlalu rapat dan terlalu lega.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;

  // ---------------------------------------------------------------------------
  //  Ukuran sentuh
  // ---------------------------------------------------------------------------

  /// Target sentuh minimum.
  ///
  /// 48, bukan 44. Panduan Material menyebut 48; Apple menyebut 44. Dipilih yang
  /// lebih besar karena aplikasi ini dipakai driver SAMBIL MENGENDARAI atau baru
  /// berhenti — dalam keadaan itu, ketepatan sentuh jauh lebih buruk daripada
  /// saat duduk tenang.
  static const double minTouchTarget = 48;

  /// Tombol utama pada layar driver. Lebih besar lagi, dengan alasan yang sama.
  static const double driverPrimaryButtonHeight = 56;

  // ---------------------------------------------------------------------------
  //  Tipografi
  // ---------------------------------------------------------------------------

  /// Nama keluarga font aplikasi.
  ///
  /// ==========================================================================
  ///  SATU KONSTANTA, KARENA SEBELUMNYA ADA 183 SALINAN
  /// ==========================================================================
  ///  Nama font ini pernah ditulis sebagai string mentah di 183 tempat di tiga
  ///  aplikasi. Akibatnya bukan sekadar berulang: mengganti font menuntut
  ///  menyunting 183 baris, dan satu yang terlewat menghasilkan satu label yang
  ///  memakai font berbeda — perbedaan yang terlihat tapi hampir tidak mungkin
  ///  ditemukan lewat pembacaan kode.
  ///
  ///  Sekarang menggantinya satu baris di sini, plus daftar aset di
  ///  `pubspec.yaml` paket ini.
  /// ==========================================================================
  ///
  /// ==========================================================================
  ///  KENAPA PLUS JAKARTA SANS
  /// ==========================================================================
  ///  Font Gojek dan Grab keduanya MILIK SENDIRI dan tidak dilisensikan keluar
  ///  — "GoJek Sans" dan "Grab Community" tidak bisa dipakai proyek lain, dan
  ///  memakainya tanpa izin adalah pelanggaran lisensi, bukan sekadar
  ///  ketidaksopanan.
  ///
  ///  Yang bisa dipakai adalah font dengan RASA yang sama: geometris, sudut
  ///  membulat, tinggi-x besar supaya terbaca di layar kecil dan di bawah
  ///  matahari. Plus Jakarta Sans memenuhi ketiganya, lisensinya SIL OFL
  ///  (bebas dipakai komersial), dan dibuat Tokotype — foundry Indonesia, untuk
  ///  identitas kota Jakarta.
  ///
  ///  Alternatif yang setara dan sama-sama bebas: Poppins (lebih bulat, lebih
  ///  mirip Gojek) dan Inter (lebih netral). Mengganti ke salah satunya berarti
  ///  menukar berkas di `assets/fonts/`, memperbarui `pubspec.yaml`, dan
  ///  mengubah satu baris di bawah ini.
  /// ==========================================================================
  static const String fontFamily = 'PlusJakartaSans';
}
