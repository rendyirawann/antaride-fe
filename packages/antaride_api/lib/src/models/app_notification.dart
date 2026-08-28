/// Satu notifikasi in-app.
///
/// ============================================================================
///  PENGGANTI PUSH NOTIFICATION, BUKAN PELENGKAPNYA
/// ============================================================================
///  Push notification (FCM) ditunda. Yang menggantikannya: notifikasi yang
///  disimpan backend dan dibaca aplikasi saat dibuka.
///
///  Bedanya harus disadari saat merancang layar: push MENDATANGI pengguna,
///  notifikasi in-app MENUNGGU dia membuka aplikasi.
///
///  Untuk penumpang itu cukup — dia memang sedang menatap layar saat menunggu
///  driver. Untuk driver TIDAK cukup, dan itu sebabnya tawaran order TIDAK
///  lewat sini: tawaran hanya berlaku 15 detik, dan yang hanya muncul saat
///  aplikasi dibuka akan selalu sudah kadaluarsa. Tawaran tetap dijemput lewat
///  penarikan berkala di `DriverController`.
/// ============================================================================
class AppNotification {
  const AppNotification({
    required this.uuid,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.action,
    this.readAt,
    this.createdAt,
  });

  final String uuid;

  /// Nilai mentah, misalnya `order.accepted`. Dipakai memilih ikon.
  ///
  /// Jenis yang TIDAK dikenali diperlakukan sebagai notifikasi biasa dengan ikon
  /// bawaan — bukan disembunyikan, dan bukan galat. Itu yang membuat backend
  /// bisa menambah jenis baru tanpa menunggu semua pengguna memperbarui
  /// aplikasinya.
  final String type;

  final String title;
  final String body;

  /// Tujuan saat notifikasi ditekan, misalnya
  /// `{"screen": "order", "order_uuid": "..."}`.
  ///
  /// Bentuknya map, bukan URL atau deep link. Aplikasi yang menerjemahkannya ke
  /// navigasi — jadi struktur layar bisa berubah tanpa membuat notifikasi lama
  /// menunjuk ke layar yang tidak ada lagi.
  final Map<String, dynamic>? action;

  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  /// Uuid order yang dituju, kalau notifikasi ini soal order.
  ///
  /// Dibaca dari `action`, bukan disimpan sebagai field tersendiri: yang
  /// menentukan tujuan adalah `action`, dan dua sumber untuk informasi yang sama
  /// pasti akan berbeda suatu hari.
  String? get orderUuid {
    if (action == null || action!['screen'] != 'order') {
      return null;
    }

    final Object? uuid = action!['order_uuid'];

    return uuid is String && uuid.isNotEmpty ? uuid : null;
  }

  /// Berapa lama sejak notifikasi ini dibuat, dalam bentuk siap tampil.
  ///
  /// Ditulis manual, bukan lewat paket relative-time. Untuk lima bentuk yang
  /// tidak akan berubah, satu dependency tambahan beserta inisialisasi locale-nya
  /// tidak sebanding.
  String get relativeTime {
    final DateTime? dibuat = createdAt;

    if (dibuat == null) {
      return '';
    }

    final Duration lalu = DateTime.now().difference(dibuat);

    if (lalu.inMinutes < 1) {
      return 'Baru saja';
    }

    if (lalu.inMinutes < 60) {
      return '${lalu.inMinutes} menit lalu';
    }

    if (lalu.inHours < 24) {
      return '${lalu.inHours} jam lalu';
    }

    if (lalu.inDays < 7) {
      return '${lalu.inDays} hari lalu';
    }

    const List<String> bulan = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${dibuat.day} ${bulan[dibuat.month - 1]}';
  }

  /// Salinan dengan status baca yang diubah.
  ///
  /// Hanya dua field itu yang bisa berubah setelah notifikasi dibuat; sisanya
  /// ditetapkan backend dan tidak pernah diperbarui. Jadi `copyWith` ini sengaja
  /// TIDAK menerima seluruh field — parameter yang tidak pernah dipakai hanya
  /// membuka jalan bagi layar untuk mengarang judul notifikasi sendiri.
  AppNotification copyWith({bool? isRead, DateTime? readAt}) => AppNotification(
    uuid: uuid,
    type: type,
    title: title,
    body: body,
    action: action,
    isRead: isRead ?? this.isRead,
    readAt: readAt ?? this.readAt,
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        uuid: json['uuid'] as String,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        action: json['action'] as Map<String, dynamic>?,
        isRead: json['is_read'] as bool? ?? false,
        readAt: DateTime.tryParse(json['read_at'] as String? ?? '')?.toLocal(),
        createdAt: DateTime.tryParse(
          json['created_at'] as String? ?? '',
        )?.toLocal(),
      );
}

/// Satu halaman notifikasi, beserta jumlah yang belum dibaca.
///
/// `unreadCount` ikut di setiap halaman supaya lencana di ikon lonceng bisa
/// diperbarui dari response yang SAMA — tanpa request kedua.
class NotificationPage {
  const NotificationPage({
    required this.notifications,
    required this.unreadCount,
    required this.hasMore,
    this.nextCursor,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final bool hasMore;
  final String? nextCursor;

  /// Uraikan SELURUH envelope response, bukan hanya bagian `data`.
  ///
  /// ==========================================================================
  ///  DI SINI, BUKAN DI REPOSITORY — SUPAYA BISA DIUJI
  /// ==========================================================================
  ///  Halaman notifikasi memerlukan dua bagian yang terpisah di response:
  ///  daftarnya dari `data`, dan `unread_count` beserta `next_cursor` dari
  ///  `meta`.
  ///
  ///  Kalau penguraiannya ditulis di dalam repository, satu-satunya cara
  ///  mengujinya adalah membangun `ApiClient` beserta Dio dan adapter palsunya.
  ///  Yang biasanya terjadi kemudian: test kontrak menulis ULANG logika
  ///  penguraiannya sendiri — dan test seperti itu tetap lulus walaupun
  ///  repository-nya membaca dari tempat yang salah.
  ///
  ///  Dengan penguraiannya di sini, test kontrak memanggil fungsi yang SAMA
  ///  dengan yang dipakai aplikasi.
  /// ==========================================================================
  factory NotificationPage.fromEnvelope(Map<String, dynamic> envelope) {
    final List<dynamic> data =
        (envelope['data'] as List<dynamic>?) ?? const <dynamic>[];

    final Map<String, dynamic> meta =
        (envelope['meta'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return NotificationPage(
      notifications: data
          .map(
            (dynamic e) => AppNotification.fromJson(e as Map<String, dynamic>),
          )
          .toList(),

      // `unread_count` ada di `meta`, bukan di dalam tiap notifikasi. Dibaca
      // dari tempat yang salah hasilnya nol — dan lencana yang selalu nol
      // terlihat persis sama dengan "tidak ada notifikasi baru".
      unreadCount: (meta['unread_count'] as num?)?.toInt() ?? 0,

      nextCursor: meta['next_cursor'] as String?,
      hasMore: meta['has_more'] as bool? ?? false,
    );
  }
}
