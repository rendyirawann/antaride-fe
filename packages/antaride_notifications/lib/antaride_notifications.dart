/// Notifikasi in-app: controller, layar daftar, dan ikon lonceng berlencana.
///
/// ============================================================================
///  SATU IMPLEMENTASI UNTUK PENUMPANG DAN DRIVER
/// ============================================================================
///  Keduanya memakai layar yang sama. Yang berbeda hanya dua hal, dan keduanya
///  disuntikkan dari luar:
///
///    Notifikasi siapa      `NotificationRepository.role`, disetel sekali di
///                          `AntarideServices.build(notificationRole: ...)`.
///
///    Tujuan saat ditekan   callback `onOpenAction`, karena nama layar order di
///                          aplikasi penumpang dan driver memang berbeda.
///
///  Paket ini TIDAK tahu nama layar di aplikasi mana pun, dan itu batas yang
///  membuatnya bisa dipakai keduanya tanpa satu pun percabangan di dalamnya.
/// ============================================================================
library;

export 'src/notification_controller.dart';
export 'src/notification_icon.dart';
export 'src/notification_screen.dart';
export 'src/notification_sync.dart';
