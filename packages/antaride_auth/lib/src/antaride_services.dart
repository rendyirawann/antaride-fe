import 'package:antaride_api/antaride_api.dart';
import 'package:flutter/foundation.dart';

import 'session_controller.dart';

/// Wadah dependency untuk satu aplikasi.
///
/// ============================================================================
///  KENAPA WADAH EKSPLISIT, BUKAN SERVICE LOCATOR GLOBAL
/// ============================================================================
///  Pola `GetIt.I<ApiClient>()` bekerja, dan itu masalahnya: dia bekerja dari
///  MANA SAJA. Widget yang memanggilnya tidak menyatakan apa yang dia butuhkan,
///  dan tidak ada cara mengetahuinya selain membaca seluruh isinya.
///
///  Akibat yang paling nyata muncul di pengujian: widget yang mengambil
///  dependency dari singleton global tidak bisa diuji tanpa menyiapkan
///  singleton itu — dan pengujian yang menyiapkannya akan saling bocor lewat
///  state yang sama.
///
///  Wadah ini dibuat SEKALI di `main()`, lalu disalurkan lewat provider. Widget
///  yang butuh sesuatu meminta lewat context, dan pengujian menyuntikkan wadah
///  lain tanpa menyentuh apa pun yang global.
/// ============================================================================
///
/// ============================================================================
///  URUTAN PEMBUATANNYA MELINGKAR, DAN ITU DISELESAIKAN DI SINI
/// ============================================================================
///  `ApiClient` perlu memanggil `SessionController.handleUnauthenticated` saat
///  backend membalas 401. Tapi `SessionController` perlu `AuthRepository`, yang
///  perlu `ApiClient`.
///
///  Diselesaikan dengan callback yang membaca field yang diisi belakangan —
///  bukan dengan meneruskan controller-nya ke constructor. Kalau tidak, salah
///  satu dari keduanya harus dibuat setengah jadi, dan yang biasanya terjadi
///  adalah `late` yang belum terisi saat 401 pertama datang.
/// ============================================================================
class AntarideServices {
  AntarideServices._({
    required this.tokenStore,
    required this.apiClient,
    required this.auth,
    required this.orders,
    required this.quotes,
    required this.wallet,
    required this.driver,
    required this.notifications,
    required this.places,
  });

  final TokenStore tokenStore;
  final ApiClient apiClient;

  final AuthRepository auth;
  final OrderRepository orders;
  final QuoteRepository quotes;
  final WalletRepository wallet;
  final DriverRepository driver;

  /// Konfigurasi server dan pencarian alamat.
  final PlaceRepository places;

  /// Notifikasi in-app.
  ///
  /// Perannya ditetapkan sekali di sini, bukan dikirim per pemanggilan.
  /// Aplikasi driver menyuntikkan `RecipientRole.driver`; dua aplikasi lainnya
  /// memakai bawaannya.
  ///
  /// Alasannya: satu orang bisa jadi penumpang DAN driver dengan akun yang
  /// sama — driver memesan ojek saat kendaraannya di bengkel. Kalau perannya
  /// dikirim per pemanggilan, satu layar yang lupa mengirimnya akan menampilkan
  /// notifikasi penumpang di aplikasi driver, dan itu tidak terlihat sebagai
  /// galat: daftarnya tetap terisi, hanya isinya milik peran yang salah.
  final NotificationRepository notifications;

  SessionController? _session;

  /// Controller sesi. Tersedia setelah [attachSession].
  SessionController get session {
    final SessionController? s = _session;

    if (s == null) {
      throw StateError(
        'SessionController belum dipasang. Panggil AntarideServices.build() '
        'lalu attachSession() sebelum memakai services.session.',
      );
    }

    return s;
  }

  /// Bangun seluruh lapisan API untuk satu aplikasi.
  ///
  /// [platform] dikirim ke backend saat verifikasi OTP supaya notifikasi
  /// dikirim lewat kanal yang benar. Nilainya `android`, `ios`, atau `web`.
  static AntarideServices build({
    required String platform,
    String? appVersion,
    String? baseUrl,
    RecipientRole notificationRole = RecipientRole.customer,
  }) {
    final TokenStore tokenStore = TokenStore();

    late final AntarideServices wadah;

    final ApiClient client = ApiClient(
      tokenStore: tokenStore,
      baseUrl: baseUrl,

      // Membaca `wadah._session` saat 401 TERJADI, bukan saat client dibuat.
      // Itu yang memutus lingkaran dependency-nya.
      onUnauthenticated: () => wadah._session?.handleUnauthenticated(),
    );

    final AuthRepository auth = AuthRepository(
      client: client,
      tokenStore: tokenStore,
    );

    wadah = AntarideServices._(
      tokenStore: tokenStore,
      apiClient: client,
      auth: auth,
      orders: OrderRepository(client),
      quotes: QuoteRepository(client),
      wallet: WalletRepository(client),
      driver: DriverRepository(client),
      places: PlaceRepository(client),
      notifications: NotificationRepository(client, role: notificationRole),
    );

    wadah._session = SessionController(
      auth: auth,
      tokenStore: tokenStore,
      platform: platform,
      appVersion: appVersion,
    );

    return wadah;
  }

  /// Ganti controller sesi, untuk pengujian.
  @visibleForTesting
  void attachSession(SessionController controller) {
    _session = controller;
  }
}
