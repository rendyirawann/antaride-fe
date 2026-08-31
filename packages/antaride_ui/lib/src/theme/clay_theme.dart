import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'clay_tokens.dart';

/// ThemeData Antaride.
///
/// ============================================================================
///  MATERIAL DIPAKAI, TAPI PERMUKAANNYA DILUCUTI
/// ============================================================================
///  Widget Material tetap dipakai — MaterialApp, Scaffold, InkWell, Navigator —
///  karena menggantinya berarti menulis ulang seluruh navigasi dan aksesibilitas.
///
///  Yang dilucuti adalah PERMUKAANNYA: elevation Material dan bayangan bawaannya
///  dimatikan di mana-mana, karena keduanya bertabrakan dengan bayangan clay.
///  Kartu Material yang punya elevation 2 DI DALAM permukaan clay menghasilkan
///  dua sistem bayangan yang saling menimpa, dan hasilnya terlihat kotor tanpa
///  ada yang bisa menunjuk penyebabnya.
///
///  Karena itu `elevation: 0` muncul berulang di bawah. Itu bukan kelalaian.
/// ============================================================================
class ClayTheme {
  const ClayTheme._();

  static ThemeData light() => _bangun(Brightness.light);

  static ThemeData dark() => _bangun(Brightness.dark);

  static ThemeData _bangun(Brightness kecerahan) {
    final bool gelap = kecerahan == Brightness.dark;

    final Color latar = gelap ? ClayTokens.surfaceDark : ClayTokens.surface;
    final Color teksUtama = gelap
        ? ClayTokens.textPrimaryDark
        : ClayTokens.textPrimary;
    final Color teksKedua = gelap
        ? ClayTokens.textSecondaryDark
        : ClayTokens.textSecondary;

    final ColorScheme skema =
        ColorScheme.fromSeed(
          seedColor: ClayTokens.primary,
          brightness: kecerahan,
        ).copyWith(
          primary: ClayTokens.primary,
          surface: latar,
          error: ClayTokens.danger,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: kecerahan,
      colorScheme: skema,
      scaffoldBackgroundColor: latar,

      /*
       * Font: Plus Jakarta Sans.
       *
       * Dipilih karena tiga hal:
       *   - Dirancang di Jakarta, dan bentuk hurufnya cocok untuk bahasa
       *     Indonesia yang banyak memakai huruf tegak.
       *   - Punya angka tabular, yang WAJIB untuk kolom nominal uang.
       *   - Lisensi terbuka, jadi bisa dipaketkan ke aplikasi tanpa memanggil
       *     Google Fonts saat runtime — dan itu penting: font yang diunduh saat
       *     runtime berarti layar pertama menampilkan font pengganti lalu
       *     berkedip, dan pada jaringan lambat kedipannya terlihat jelas.
       */
      fontFamily: ClayTokens.fontFamily,

      textTheme: _teks(teksUtama, teksKedua),

      appBarTheme: AppBarTheme(
        backgroundColor: latar,
        surfaceTintColor: Colors.transparent,
        foregroundColor: teksUtama,

        // Nol, bukan bawaan. Lihat penjelasan di docblock kelas.
        elevation: 0,
        scrolledUnderElevation: 0,

        centerTitle: false,
        titleTextStyle: TextStyle(
          color: teksUtama,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          fontFamily: ClayTokens.fontFamily,
        ),

        systemOverlayStyle: gelap
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: gelap ? ClayTokens.surfaceRaisedDark : ClayTokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: gelap
            ? ClayTokens.surfaceRaisedDark
            : ClayTokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ClayTokens.radiusLarge),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: gelap
            ? ClayTokens.surfaceRaisedDark
            : ClayTokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayTokens.radiusLarge),
        ),
      ),

      /*
       * Splash factory diganti InkRipple, bukan InkSparkle bawaan Material 3.
       *
       * InkSparkle punya animasi partikel yang terlihat bagus di permukaan
       * datar dan terlihat salah di atas permukaan clay — partikelnya menembus
       * ilusi ketebalan yang justru dibangun bayangannya.
       */
      splashFactory: InkRipple.splashFactory,

      // Divider hampir tidak terlihat, dan itu memang tujuannya. Pada antarmuka
      // yang pemisahnya adalah BAYANGAN, garis tegas menjadi elemen ketiga yang
      // bersaing.
      dividerTheme: DividerThemeData(
        color: gelap
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        thickness: 1,
        space: ClayTokens.space4,
      ),

      // Widget input bawaan tetap ditema supaya form yang belum memakai
      // ClayInput tidak terlihat asing.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: gelap
            ? ClayTokens.surfaceSunkenDark
            : ClayTokens.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ClayTokens.space4,
          vertical: ClayTokens.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
          borderSide: const BorderSide(color: ClayTokens.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
          borderSide: const BorderSide(color: ClayTokens.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
          borderSide: const BorderSide(color: ClayTokens.danger, width: 2),
        ),
        hintStyle: TextStyle(
          color: gelap ? ClayTokens.textTertiaryDark : ClayTokens.textTertiary,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Tombol Material dinonaktifkan visualnya supaya tidak ada yang memakainya
      // tanpa sadar — ClayButton yang dipakai di seluruh aplikasi.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: ClayTokens.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(ClayTokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: ClayTokens.fontFamily,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: gelap
            ? ClayTokens.surfaceRaised
            : ClayTokens.textPrimary,
        contentTextStyle: TextStyle(
          color: gelap ? ClayTokens.textPrimary : Colors.white,
          fontWeight: FontWeight.w600,
          fontFamily: ClayTokens.fontFamily,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
        ),
        elevation: 0,
      ),
    );
  }

  static TextTheme _teks(Color utama, Color kedua) {
    // Skala tipografi yang sengaja pendek: enam ukuran, bukan tiga belas.
    //
    // Material menyediakan tiga belas gaya teks, dan aplikasi yang memakai
    // semuanya kehilangan hierarki — kalau ada tiga belas tingkat, tidak ada
    // yang menonjol. Enam cukup untuk seluruh layar di aplikasi ini.
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: utama,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: utama,
        height: 1.25,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: utama,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: utama,
        height: 1.35,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: utama,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: kedua,
        height: 1.4,
      ),
    );
  }
}
