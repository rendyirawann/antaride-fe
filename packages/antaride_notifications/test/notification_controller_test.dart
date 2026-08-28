import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_notifications/antaride_notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
///  EMPAT ATURAN YANG SEMUANYA GAGAL TANPA SUARA
/// ============================================================================
///  1. `as` menentukan notifikasi SIAPA yang dibaca. Satu orang bisa punya akun
///     penumpang dan driver yang sama — driver memesan ojek saat kendaraannya di
///     bengkel. Nilai yang salah tidak menghasilkan galat: daftarnya tetap
///     terisi, hanya isinya milik peran yang lain.
///
///  2. Penandaan sudah-dibaca dilakukan di layar LEBIH DULU, lalu dikirim. Kalau
///     requestnya gagal, keadaannya harus DIKEMBALIKAN — kalau tidak, notifikasi
///     yang terlihat sudah dibaca akan muncul lagi sebagai belum dibaca pada
///     pemuatan berikutnya, dan angka lencana naik sendiri tanpa notifikasi baru.
///
///  3. Angka lencana tidak pernah negatif, dan pengembaliannya harus SIMETRIS
///     dengan pengurangannya.
///
///  4. `muatLagi` MENAMBAH ke daftar, tidak menggantinya. Cursor pagination tidak
///     punya cara melompat kembali ke halaman yang sudah dibaca, jadi daftar yang
///     tergantikan berarti halaman-halaman sebelumnya hilang untuk selamanya
///     sampai aplikasi dibuka ulang.
///
///  Tidak satu pun dari keempatnya menghasilkan pesan galat kalau dilanggar.
/// ============================================================================
void main() {
  late _Adapter adapter;
  late ApiClient client;

  NotificationController buat({RecipientRole peran = RecipientRole.customer}) {
    return NotificationController(NotificationRepository(client, role: peran));
  }

  setUp(() {
    adapter = _Adapter();

    client = ApiClient(
      tokenStore: TokenStore(),
      baseUrl: 'http://127.0.0.1:8000/api/v1',
      dio: Dio()..httpClientAdapter = adapter,
    );
  });

  group('Memuat daftar', () {
    test(
      'daftar dan jumlah belum dibaca terurai dari response backend',
      () async {
        final NotificationController c = buat();

        await c.muatUlang();

        expect(c.items, hasLength(2));
        expect(c.unreadCount, 1);
        expect(c.galat, isNull);
        expect(c.sudahDimuat, isTrue);
        expect(c.adaLagi, isFalse, reason: 'Fixture-nya satu halaman penuh.');

        addTearDown(c.dispose);
      },
    );

    /// ========================================================================
    ///  INI TEST YANG PALING PENTING DI BERKAS INI
    /// ========================================================================
    ///  `as=driver` di aplikasi driver, `as=user` di aplikasi penumpang.
    ///
    ///  Nilai yang salah tidak menghasilkan galat apa pun — daftarnya tetap
    ///  terisi dan tetap tampil rapi. Yang terjadi: driver melihat notifikasi
    ///  penumpangnya, dan tidak pernah melihat notifikasi drivernya. Untuk orang
    ///  yang punya kedua peran, itu berarti kabar order yang ditugaskan
    ///  kepadanya tidak pernah sampai.
    /// ========================================================================
    test('peran driver mengirim as=driver, bukan as=user', () async {
      final NotificationController c = buat(peran: RecipientRole.driver);

      await c.muatUlang();
      await c.refreshBadge();

      expect(
        adapter.peranTerkirim,
        everyElement('driver'),
        reason:
            'Nilai `as` yang terkirim: ${adapter.peranTerkirim}. Aplikasi driver '
            'harus SELALU mengirim `driver` — kalau tidak, driver yang juga '
            'punya akun penumpang akan melihat notifikasi yang salah tanpa satu '
            'pun galat.',
      );

      addTearDown(c.dispose);
    });

    test('peran penumpang mengirim as=user', () async {
      final NotificationController c = buat();

      await c.muatUlang();

      expect(adapter.peranTerkirim, everyElement('user'));

      addTearDown(c.dispose);
    });

    /// Halaman pertama TIDAK mengirim `cursor`.
    ///
    /// Cursor kosong yang terkirim dibaca backend sebagai cursor yang tidak sah,
    /// dan halaman pertamanya akan kosong.
    test('halaman pertama tidak mengirim cursor', () async {
      final NotificationController c = buat();

      await c.muatUlang();

      expect(adapter.cursorTerkirim, <String?>[null]);

      addTearDown(c.dispose);
    });

    /// `muatLagi` MENAMBAH, tidak mengganti.
    test('halaman berikutnya ditambahkan, bukan menggantikan', () async {
      adapter.adaHalamanKedua = true;

      final NotificationController c = buat();

      await c.muatUlang();

      expect(c.items, hasLength(2));
      expect(c.adaLagi, isTrue);

      await c.muatLagi();

      expect(
        c.items,
        hasLength(4),
        reason:
            'Daftarnya tergantikan, bukan ditambah. Dengan cursor pagination '
            'tidak ada cara melompat kembali ke halaman yang sudah dibaca — '
            'halaman pertamanya hilang sampai aplikasi dibuka ulang.',
      );

      expect(adapter.cursorTerkirim, <String?>[null, 'kursor-halaman-2']);

      addTearDown(c.dispose);
    });

    /// Tanpa cursor, `muatLagi` tidak mengirim request sama sekali.
    ///
    /// Yang dihindari: `ClayRefresh.onLoad` yang terpicu berulang di ujung
    /// daftar dan menarik halaman pertama lagi dan lagi.
    test('muatLagi di akhir daftar tidak mengirim request', () async {
      final NotificationController c = buat();

      await c.muatUlang();

      final int sebelum = adapter.jumlahRequestDaftar;

      await c.muatLagi();

      expect(adapter.jumlahRequestDaftar, sebelum);

      addTearDown(c.dispose);
    });

    /// Kegagalan tidak menghapus daftar yang sudah tampil.
    test('daftar lama dipertahankan saat pemuatan berikutnya gagal', () async {
      adapter.adaHalamanKedua = true;

      final NotificationController c = buat();

      await c.muatUlang();

      expect(c.items, hasLength(2));

      adapter.gagalkanSemua = true;

      await c.muatLagi();

      expect(
        c.items,
        hasLength(2),
        reason: 'Daftarnya dikosongkan saat gagal.',
      );
      expect(c.galat, isNotNull, reason: 'Kegagalannya tetap dicatat.');

      addTearDown(c.dispose);
    });
  });

  group('Menandai sudah dibaca', () {
    test(
      'penandaan berhasil menurunkan jumlah dan mengubah statusnya',
      () async {
        final NotificationController c = buat();

        await c.muatUlang();

        final AppNotification belumDibaca = c.items.firstWhere(
          (AppNotification n) => !n.isRead,
        );

        await c.tandaiDibaca(belumDibaca.uuid);

        expect(c.unreadCount, 0);

        expect(
          c.items
              .firstWhere((AppNotification n) => n.uuid == belumDibaca.uuid)
              .isRead,
          isTrue,
        );

        addTearDown(c.dispose);
      },
    );

    /// ========================================================================
    ///  PENGEMBALIAN SAAT GAGAL — INI YANG MENJAGA LENCANA TETAP JUJUR
    /// ========================================================================
    ///  Tanpa pengembalian: notifikasinya terlihat sudah dibaca, tapi server
    ///  tidak mencatatnya. Pada pemuatan berikutnya dia muncul lagi sebagai
    ///  belum dibaca, dan angka lencana naik sendiri tanpa ada notifikasi baru.
    ///
    ///  Pengguna akan mencari kabar baru yang tidak pernah ada.
    /// ========================================================================
    test('penandaan yang gagal dikembalikan seluruhnya', () async {
      final NotificationController c = buat();

      await c.muatUlang();

      final AppNotification belumDibaca = c.items.firstWhere(
        (AppNotification n) => !n.isRead,
      );

      adapter.gagalkanSemua = true;

      await c.tandaiDibaca(belumDibaca.uuid);

      expect(
        c.items
            .firstWhere((AppNotification n) => n.uuid == belumDibaca.uuid)
            .isRead,
        isFalse,
        reason:
            'Status bacanya dibiarkan berubah walaupun servernya menolak. '
            'Notifikasinya akan muncul lagi sebagai belum dibaca nanti.',
      );

      expect(
        c.unreadCount,
        1,
        reason:
            'Angka lencananya dibiarkan turun. Dia akan naik sendiri pada '
            'pemuatan berikutnya, dan itu terbaca sebagai notifikasi baru.',
      );

      addTearDown(c.dispose);
    });

    /// Notifikasi yang SUDAH dibaca tidak mengirim request lagi.
    ///
    /// Yang dihindari: angka lencana turun dua kali untuk satu notifikasi karena
    /// pengguna menekannya dua kali.
    test('notifikasi yang sudah dibaca tidak dikirim ulang', () async {
      final NotificationController c = buat();

      await c.muatUlang();

      final AppNotification sudahDibaca = c.items.firstWhere(
        (AppNotification n) => n.isRead,
      );

      await c.tandaiDibaca(sudahDibaca.uuid);

      expect(adapter.uuidDitandai, isEmpty);
      expect(c.unreadCount, 1, reason: 'Angkanya tidak boleh berubah.');

      addTearDown(c.dispose);
    });

    /// Lencana tidak pernah negatif.
    ///
    /// Bisa terjadi kalau notifikasi yang sama sudah dibaca dari perangkat lain,
    /// sehingga `unread_count` yang datang bersama daftarnya sudah nol.
    test('lencana tidak turun di bawah nol', () async {
      adapter.unreadCountPalsu = 0;

      final NotificationController c = buat();

      await c.muatUlang();

      expect(c.unreadCount, 0);

      final AppNotification belumDibaca = c.items.firstWhere(
        (AppNotification n) => !n.isRead,
      );

      adapter.gagalkanSemua = true;

      await c.tandaiDibaca(belumDibaca.uuid);

      expect(
        c.unreadCount,
        0,
        reason:
            'Pengembaliannya menambah satu padahal pengurangannya tidak pernah '
            'terjadi. Lencana akan menampilkan angka untuk notifikasi yang '
            'tidak ada.',
      );

      addTearDown(c.dispose);
    });
  });

  group('Menandai semua sudah dibaca', () {
    test('semuanya berubah dan jumlahnya nol', () async {
      final NotificationController c = buat();

      await c.muatUlang();

      final bool berhasil = await c.tandaiSemuaDibaca();

      expect(berhasil, isTrue);
      expect(c.unreadCount, 0);
      expect(c.items.every((AppNotification n) => n.isRead), isTrue);

      addTearDown(c.dispose);
    });

    test('kegagalan mengembalikan seluruh daftar', () async {
      final NotificationController c = buat();

      await c.muatUlang();

      adapter.gagalkanSemua = true;

      final bool berhasil = await c.tandaiSemuaDibaca();

      expect(berhasil, isFalse);

      expect(
        c.items.where((AppNotification n) => !n.isRead).length,
        1,
        reason:
            'Seluruh daftar harus kembali ke keadaan semula. Kalau tidak, tidak '
            'ada satu pun notifikasi yang terlihat belum dibaca padahal '
            'servernya tidak mencatat apa pun.',
      );

      expect(c.unreadCount, 1);

      addTearDown(c.dispose);
    });

    /// Tidak ada request kalau memang tidak ada yang belum dibaca.
    test('tanpa notifikasi belum dibaca tidak mengirim request', () async {
      adapter.unreadCountPalsu = 0;
      adapter.semuanyaSudahDibaca = true;

      final NotificationController c = buat();

      await c.muatUlang();

      expect(await c.tandaiSemuaDibaca(), isTrue);
      expect(adapter.jumlahReadAll, 0);

      addTearDown(c.dispose);
    });
  });

  group('Menyegarkan lencana', () {
    /// `refreshBadge` HANYA memanggil endpoint jumlah, bukan daftarnya.
    ///
    /// Dipanggil setiap kali aplikasi kembali ke depan. Memuat dua puluh baris
    /// notifikasi untuk menampilkan satu angka adalah data yang dibayar pengguna
    /// tanpa dia lihat.
    test('hanya memanggil endpoint jumlah, bukan daftarnya', () async {
      final NotificationController c = buat();

      await c.refreshBadge();

      expect(c.unreadCount, 1);
      expect(
        adapter.jumlahRequestDaftar,
        0,
        reason:
            'Daftarnya ikut ditarik hanya untuk memperbarui satu angka. Itu '
            'terjadi setiap kali aplikasi kembali ke depan.',
      );

      addTearDown(c.dispose);
    });

    /// Kegagalan tidak mengubah apa pun dan tidak dicatat sebagai galat.
    ///
    /// Angka lencana yang gagal diperbarui bukan hal yang perlu ditampilkan —
    /// pesan galatnya akan muncul di layar yang tidak sedang membicarakan
    /// notifikasi.
    test('kegagalan tidak mengubah angka dan tidak jadi galat', () async {
      final NotificationController c = buat();

      await c.muatUlang();

      expect(c.unreadCount, 1);

      adapter.gagalkanSemua = true;

      await c.refreshBadge();

      expect(c.unreadCount, 1);
      expect(c.galat, isNull);

      addTearDown(c.dispose);
    });
  });
}

// =============================================================================

/// Adapter HTTP palsu yang membalas dengan fixture dari backend.
///
/// Yang dipalsukan hanya lapisan jaringannya. `ApiClient`, `NotificationRepository`,
/// dan `NotificationController` yang diuji adalah yang sungguhan — termasuk
/// penyusunan query `as` dan `cursor`, yang justru bagian paling rawan.
class _Adapter implements HttpClientAdapter {
  bool gagalkanSemua = false;
  bool adaHalamanKedua = false;
  bool semuanyaSudahDibaca = false;

  /// Menimpa `unread_count` di response, untuk menguji batas bawah lencana.
  int? unreadCountPalsu;

  final List<String> peranTerkirim = <String>[];
  final List<String?> cursorTerkirim = <String?>[];
  final List<String> uuidDitandai = <String>[];

  int jumlahRequestDaftar = 0;
  int jumlahReadAll = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.path;

    /*
     * `as` dicatat SEBELUM pemeriksaan kegagalan.
     *
     * Test yang menguji nilai `as` juga perlu bekerja pada request yang gagal —
     * dan kalau pencatatannya di bawah, request yang digagalkan tidak akan
     * pernah tercatat.
     *
     * Dibaca dari `queryParameters` untuk GET dan dari query di dalam path untuk
     * POST, karena `ApiClient.post` tidak punya parameter query.
     */
    final String? peran =
        (options.queryParameters['as'] as String?) ?? _dariPath(path, 'as');

    if (peran != null) {
      peranTerkirim.add(peran);
    }

    if (path.contains('/notifications/unread-count')) {
      if (gagalkanSemua) {
        return _gagal(503, 'SERVICE_UNAVAILABLE', 'Server sedang sibuk.');
      }

      return _sukses(<String, dynamic>{'unread_count': _jumlah});
    }

    if (path.contains('/notifications/read-all')) {
      jumlahReadAll++;

      if (gagalkanSemua) {
        return _gagal(503, 'SERVICE_UNAVAILABLE', 'Server sedang sibuk.');
      }

      return _sukses(<String, dynamic>{'unread_count': 0});
    }

    if (path.contains('/read')) {
      if (gagalkanSemua) {
        return _gagal(503, 'SERVICE_UNAVAILABLE', 'Server sedang sibuk.');
      }

      // `/api/v1/notifications/{uuid}/read`
      final List<String> bagian = path.split('?').first.split('/');
      final int posisi = bagian.indexOf('read');

      if (posisi > 0) {
        uuidDitandai.add(bagian[posisi - 1]);
      }

      return _sukses(<String, dynamic>{'unread_count': 0});
    }

    if (path.endsWith('/notifications')) {
      jumlahRequestDaftar++;
      cursorTerkirim.add(options.queryParameters['cursor'] as String?);

      if (gagalkanSemua) {
        return _gagal(503, 'SERVICE_UNAVAILABLE', 'Server sedang sibuk.');
      }

      return _halaman(options.queryParameters['cursor'] as String?);
    }

    return _gagal(404, 'NOT_FOUND', 'Endpoint tidak dikenali: $path');
  }

  int get _jumlah => unreadCountPalsu ?? 1;

  /// Satu halaman notifikasi, dibangun dari fixture backend.
  ///
  /// Halaman kedua memakai uuid yang berbeda supaya `muatLagi` yang MENGGANTI
  /// alih-alih MENAMBAH terlihat sebagai jumlah item yang salah, bukan sebagai
  /// daftar yang isinya sama.
  ResponseBody _halaman(String? cursor) {
    final Map<String, dynamic> envelope = _fixture();

    final List<dynamic> data = List<dynamic>.from(
      envelope['data'] as List<dynamic>,
    );

    if (semuanyaSudahDibaca) {
      for (final dynamic satu in data) {
        (satu as Map<String, dynamic>)['is_read'] = true;
      }
    }

    if (cursor != null) {
      // Halaman kedua: uuid diberi akhiran supaya tidak bertabrakan.
      for (final dynamic satu in data) {
        final Map<String, dynamic> m = satu as Map<String, dynamic>;
        m['uuid'] = '${m['uuid']}-h2';
        m['is_read'] = true;
      }
    }

    final bool masihAda = adaHalamanKedua && cursor == null;

    return _envelope(<String, dynamic>{
      'success': true,
      'data': data,
      'meta': <String, dynamic>{
        'per_page': 20,
        'next_cursor': masihAda ? 'kursor-halaman-2' : null,
        'has_more': masihAda,
        'unread_count': _jumlah,
      },
    });
  }

  static String? _dariPath(String path, String kunci) {
    final int tanya = path.indexOf('?');

    if (tanya < 0) {
      return null;
    }

    for (final String pasangan in path.substring(tanya + 1).split('&')) {
      final List<String> kv = pasangan.split('=');

      if (kv.length == 2 && kv[0] == kunci) {
        return kv[1];
      }
    }

    return null;
  }

  ResponseBody _sukses(Object? data) =>
      _envelope(<String, dynamic>{'success': true, 'data': data});

  ResponseBody _envelope(Map<String, dynamic> badan, {int status = 200}) {
    return ResponseBody.fromString(
      jsonEncode(badan),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  ResponseBody _gagal(int status, String code, String message) {
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'success': false,
        'error': <String, dynamic>{'code': code, 'message': message},
      }),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Fixture dihasilkan backend — lihat `ContractFixtureTest` di `antaride-be`.
///
/// Diurai ulang setiap pemanggilan, bukan di-cache: `_halaman` mengubah field di
/// dalamnya, dan map yang dibagi antar test akan membawa perubahan itu ke test
/// berikutnya.
Map<String, dynamic> _fixture() {
  final File berkas = File('../../test_fixtures/notifications.json');

  if (!berkas.existsSync()) {
    fail(
      'Fixture "notifications.json" tidak ada.\n\n'
      'Fixture dihasilkan backend. Jalankan:\n'
      '  cd antaride-be && php artisan test tests/Feature/Api/ContractFixtureTest.php\n',
    );
  }

  return jsonDecode(berkas.readAsStringSync()) as Map<String, dynamic>;
}
