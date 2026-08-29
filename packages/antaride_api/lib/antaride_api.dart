/// Lapisan API Antaride: client HTTP, penyimpanan token, model, dan repository.
///
/// ============================================================================
///  SATU-SATUNYA PAKET YANG TAHU BENTUK JSON BACKEND
/// ============================================================================
///  Di luar paket ini, tidak ada satu pun `json['field']`. Layar bekerja dengan
///  kelas Dart, dan perubahan bentuk response berakhir di satu `fromJson` —
///  bukan menyebar ke widget yang membaca map mentah.
///
///  Paket ini juga TIDAK punya widget dan TIDAK punya state management. Yang
///  memanggil repository adalah controller/notifier di masing-masing aplikasi,
///  dan itu yang membuat tiga aplikasi bisa memakai lapisan yang sama tanpa
///  ikut memakai struktur layar yang sama.
/// ============================================================================
library;

export 'src/client/api_client.dart';
export 'src/client/location_pinger.dart';
export 'src/client/token_store.dart';

export 'src/models/app_notification.dart';
export 'src/models/demo_account.dart';
export 'src/models/driver_document.dart';
export 'src/models/driver_order.dart';
export 'src/models/order.dart';
export 'src/models/quote.dart';
export 'src/models/user.dart';
export 'src/models/wallet.dart';

export 'src/repositories/auth_repository.dart';
export 'src/repositories/driver_repository.dart';
export 'src/repositories/notification_repository.dart';
export 'src/repositories/order_repository.dart';
export 'src/repositories/quote_repository.dart';
export 'src/repositories/wallet_repository.dart';
