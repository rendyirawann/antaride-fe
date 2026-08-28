/// Design system Antaride: claymorphism.
///
/// ============================================================================
///  SATU PAKET UNTUK TIGA APLIKASI
/// ============================================================================
///  Customer, driver, dan merchant memakai design system YANG SAMA. Yang
///  berbeda hanya susunan layarnya.
///
///  Alasannya bukan penghematan kode: tiga aplikasi dengan design system
///  terpisah akan menyimpang dalam tiga bulan — radius yang sedikit berbeda,
///  hijau yang tidak persis sama, tombol yang tingginya lain. Pengguna melihat
///  ketiganya sebagai satu merek, dan penyimpangan itu terbaca sebagai
///  kurangnya perhatian.
///
///  Yang boleh berbeda per aplikasi disebut eksplisit — misalnya tinggi tombol
///  utama di aplikasi driver, yang lebih besar karena dipakai sambil di jalan.
/// ============================================================================
library;

/// `IndicatorResult` diekspor ulang supaya layar bisa mengembalikan
/// `IndicatorResult.noMore` dari `ClayRefresh.onLoad` tanpa menambahkan
/// `easy_refresh` sebagai dependency langsung.
///
/// Itu yang menjaga janji di docblock ClayRefresh: mengganti paketnya nanti
/// menyentuh paket ini saja.
export 'package:easy_refresh/easy_refresh.dart'
    show EasyRefreshController, IndicatorResult;

export 'src/theme/clay_shadows.dart';
export 'src/theme/clay_theme.dart';
export 'src/theme/clay_tokens.dart';
export 'src/widgets/clay_bottom_sheet.dart';
export 'src/widgets/clay_button.dart';
export 'src/widgets/clay_drawer_shell.dart';
export 'src/widgets/clay_empty_state.dart';
export 'src/widgets/clay_input.dart';
export 'src/widgets/clay_loader.dart';
export 'src/widgets/clay_refresh.dart';
export 'src/widgets/clay_skeleton.dart';
export 'src/widgets/clay_money.dart';
export 'src/widgets/clay_status_badge.dart';
export 'src/widgets/clay_surface.dart';
