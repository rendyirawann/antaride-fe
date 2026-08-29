import 'dart:convert';
import 'dart:io';

import 'package:antaride_api/antaride_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
///  TEST KONTRAK: FIXTURE DIHASILKAN BACKEND, BUKAN DITULIS DI SINI
/// ============================================================================
///  Berkas di `test_fixtures/` ditulis oleh `ContractFixtureTest` di repo
///  backend — response HTTP sungguhan dari endpoint sungguhan.
///
///  Kenapa itu penting, dan bukan sekadar kerapian:
///
///    Fixture yang ditulis tangan di sisi Dart hanya membuktikan bahwa parser
///    ini konsisten dengan apa yang PENULISNYA yakini soal bentuk API. Itu tepat
///    jenis kesalahan yang sudah terjadi sekali di proyek ini: model quote
///    dibuat dengan asumsi `fare.total` sebagai objek Money bersarang, padahal
///    endpoint quote mengirimnya rata sebagai `total_fare` dan `total_formatted`.
///
///    Analyzer tidak bisa melihat itu. Test dengan fixture tulisan tangan akan
///    lulus. Yang terlihat di layar adalah harga Rp 0 di seluruh pilihan
///    layanan — dan tidak ada satu pun galat di log.
///
///  Dengan fixture yang dihasilkan backend, perubahan bentuk response gagal di
///  sini, pada test run berikutnya. Bukan pada penumpang.
///
///  Cara memperbaruinya:
///
///      cd antaride-be && php artisan test tests/Feature/Api/ContractFixtureTest.php
/// ============================================================================
void main() {
  group('Quote.fromJson terhadap response backend sungguhan', () {
    late Map<String, dynamic> json;

    setUpAll(() {
      json = _fixture('quote.json');
    });

    test('field dasar terurai', () {
      final Quote quote = Quote.fromJson(json);

      expect(quote.id, isNotEmpty);
      expect(quote.distanceM, greaterThan(0));
      expect(quote.durationS, greaterThan(0));
      expect(quote.services, isNotEmpty);
    });

    /// ========================================================================
    ///  INI TEST YANG PALING PENTING DI BERKAS INI
    /// ========================================================================
    ///  Ongkos di endpoint quote berbentuk RATA (`total_fare` +
    ///  `total_formatted`); di endpoint order berbentuk BERSARANG (`total`
    ///  sebagai objek Money).
    ///
    ///  Memakai bentuk yang salah tidak menghasilkan galat — hanya nol. Test ini
    ///  menyatakan nominalnya harus positif, jadi salah bentuk langsung gagal.
    /// ========================================================================
    test('nominal ongkos terbaca, tidak nol', () {
      final Quote quote = Quote.fromJson(json);
      final QuoteService layanan = quote.services.first;

      expect(
        layanan.total.amount,
        greaterThan(0),
        reason:
            'Nol di sini berarti bentuk `fare` dibaca salah. Endpoint quote '
            'mengirim `total_fare` dan `total_formatted` secara rata, bukan '
            '`total` sebagai objek Money seperti di endpoint order.',
      );

      expect(layanan.total.formatted, startsWith('Rp'));
      expect(layanan.fareLines, isNotEmpty);
    });

    test('rincian ongkos punya label dan nominal terformat', () {
      final QuoteService layanan = Quote.fromJson(json).services.first;

      for (final FareLine baris in layanan.fareLines) {
        expect(baris.label, isNotEmpty);
        expect(baris.formatted, isNotEmpty);
      }
    });

    /// ========================================================================
    ///  `orderable`, BUKAN `is_orderable`
    /// ========================================================================
    ///  Kalau nama kuncinya salah, default `false` yang berlaku — dan tombol
    ///  pesan mati untuk SELURUH layanan tanpa satu pun galat di log.
    ///
    ///  Fixture-nya bernilai false (tidak ada driver di lingkungan test), jadi
    ///  membacanya apa adanya tidak akan membedakan kunci yang benar dari kunci
    ///  yang salah — keduanya menghasilkan false.
    ///
    ///  Karena itu fixture-nya DISALIN dengan nilai dibalik menjadi true. Kunci
    ///  yang salah akan tetap menghasilkan false, dan test ini gagal.
    /// ========================================================================
    test('kunci orderable dibaca dengan nama yang benar', () {
      expect(json['services'][0], containsPair('orderable', isA<bool>()));

      final Map<String, dynamic> disalin =
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

      (disalin['services'] as List<dynamic>)[0]['orderable'] = true;

      final QuoteService layanan = Quote.fromJson(disalin).services.first;

      expect(
        layanan.isOrderable,
        isTrue,
        reason:
            'Model membaca false padahal JSON-nya true — nama kuncinya salah. '
            'Backend mengirim `orderable`, bukan `is_orderable`.',
      );
    });

    test('surge terurai dari objek bersarang', () {
      final QuoteService layanan = Quote.fromJson(json).services.first;

      expect(layanan.surgeMultiplier, isNotEmpty);
      expect(
        layanan.hasSurge,
        layanan.surgeActive || layanan.surgeMultiplier != '1.00',
      );
    });

    test('polyline rute ikut terurai', () {
      final Quote quote = Quote.fromJson(json);

      expect(quote.polyline, isNotNull);
      expect(quote.polyline, isNotEmpty);
    });

    test('masa berlaku dihitung dari expires_at', () {
      final Quote quote = Quote.fromJson(json);

      // Fixture-nya sudah lama saat test dijalankan, jadi yang diuji bukan
      // nilainya tapi bahwa cap waktunya BENAR-BENAR terurai — kalau gagal
      // diurai, `expiresAt` diisi satu detik yang lalu, dan itu akan lolos
      // pemeriksaan "sudah kadaluarsa" tanpa membedakan sebabnya.
      expect(quote.expiresAt.year, greaterThan(2020));
    });
  });

  group('Order.fromJson terhadap response backend sungguhan', () {
    late Map<String, dynamic> json;

    setUpAll(() {
      json = _fixture('order_customer.json');
    });

    test('field dasar terurai', () {
      final Order order = Order.fromJson(json);

      expect(order.uuid, isNotEmpty);
      expect(order.orderNumber, isNotEmpty);
      expect(order.status, isNotEmpty);
      expect(order.statusLabel, isNotEmpty);
      expect(order.pickup.address, isNotEmpty);
    });

    /// Di order, `total` BERSARANG — kebalikan dari quote.
    test('nominal total terbaca dari objek Money bersarang', () {
      final Order order = Order.fromJson(json);

      expect(
        order.total.amount,
        greaterThan(0),
        reason:
            'Nol di sini berarti `fare.total` dibaca sebagai bentuk rata milik '
            'quote, bukan objek Money milik order.',
      );

      expect(order.total.formatted, startsWith('Rp'));
    });

    /// `can_cancel` datang dari backend, tidak disimpulkan aplikasi.
    ///
    /// Aturannya ada di `OrderStatus::isCancellable()`. Kalau aplikasi
    /// menyimpulkannya sendiri, versi aplikasi lama akan menampilkan tombol
    /// batalkan yang selalu ditolak.
    test('can_cancel dibaca dari backend', () {
      expect(json, containsPair('can_cancel', isA<bool>()));
      expect(Order.fromJson(json).canCancel, json['can_cancel']);
    });

    /// `can_rate` juga dari backend, dengan alasan yang sama seperti
    /// `can_cancel`.
    ///
    /// Aturannya dua: order harus `completed` DAN belum dinilai. Aplikasi hanya
    /// bisa memeriksa yang pertama — dia tidak tahu apakah order sudah dinilai
    /// dari perangkat lain atau di sesi sebelumnya. Yang terjadi kalau
    /// disimpulkan sendiri: form penilaian muncul lagi di riwayat untuk
    /// perjalanan yang sudah dinilai, dan pengirimannya ditolak 409.
    test('can_rate dibaca dari backend', () {
      expect(json, containsPair('can_rate', isA<bool>()));
      expect(Order.fromJson(json).canRate, json['can_rate']);
    });

    /// Order yang sudah dinilai membawa penilaiannya.
    ///
    /// Fixture-nya order baru, jadi `rating` memang tidak ada. Yang diuji: model
    /// menanganinya sebagai null, dan MEMBACANYA kalau ada — bukan melempar.
    test('rating null pada order yang belum dinilai, terurai kalau ada', () {
      expect(Order.fromJson(json).rating, isNull);

      final Map<String, dynamic> dinilai =
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

      dinilai['can_rate'] = false;
      dinilai['rating'] = <String, dynamic>{
        'score': 4,
        'tags': <String>['ramah', 'tepat waktu'],
        'comment': 'Cepat dan aman.',
        'rated_at': '2026-08-28T05:47:29+00:00',
      };

      final OrderRating? rating = Order.fromJson(dinilai).rating;

      expect(rating, isNotNull);
      expect(rating!.score, 4);
      expect(rating.tags, hasLength(2));
      expect(rating.comment, 'Cepat dan aman.');
      expect(rating.ratedAt, isNotNull);
    });

    test('status order baru dikenali sebagai berjalan', () {
      final Order order = Order.fromJson(json);

      expect(
        order.isActive,
        isTrue,
        reason:
            'Order yang baru dibuat harus dikenali sebagai berjalan, kalau '
            'tidak beranda tidak akan menampilkan pita order berjalan dan '
            'penumpang kehilangan jalan ke layar pelacakan.',
      );
    });

    test('catatan penjemputan ikut terurai', () {
      expect(Order.fromJson(json).pickup.note, isNotNull);
    });

    test('cap waktu diubah ke waktu lokal', () {
      final Order order = Order.fromJson(json);

      expect(order.requestedAt, isNotNull);
      expect(
        order.requestedAt!.isUtc,
        isFalse,
        reason:
            'Tanpa toLocal(), "diterima 08:14" akan tampil sebagai 01:14 di HP '
            'pengguna — dan tidak ada yang akan mengira penyebabnya zona waktu.',
      );
    });
  });

  group('DriverStatus.fromJson terhadap response backend sungguhan', () {
    test('seluruh bagian terurai', () {
      final DriverStatus status = DriverStatus.fromJson(
        _fixture('driver_status.json'),
      );

      expect(status.name, isNotEmpty);
      expect(status.accountStatus, isNotEmpty);
      expect(status.ratingAverage, greaterThan(0));
      expect(status.balance.formatted, startsWith('Rp'));
      expect(status.todayEarning.formatted, startsWith('Rp'));
    });

    /// Ambang saldo untuk order tunai datang dari backend.
    ///
    /// Kalau aplikasi menuliskannya sendiri, dia akan menolak order yang
    /// seharusnya boleh begitu kebijakannya berubah.
    test('ambang deposit tunai dibaca dari backend', () {
      final DriverStatus status = DriverStatus.fromJson(
        _fixture('driver_status.json'),
      );

      expect(status.cashDepositMinimum, greaterThan(0));
    });
  });

  group('WalletBalance.fromJson terhadap response backend sungguhan', () {
    test('tiga nominal terurai terpisah', () {
      final WalletBalance saldo = WalletBalance.fromJson(
        _fixture('wallet.json'),
      );

      expect(saldo.available.formatted, startsWith('Rp'));
      expect(saldo.held.formatted, startsWith('Rp'));
      expect(saldo.total.formatted, startsWith('Rp'));
      expect(saldo.isFrozen, isFalse);
    });
  });

  group('DriverCancellationReason terhadap response backend sungguhan', () {
    late List<dynamic> json;

    setUpAll(() {
      json = _fixtureList('driver_cancellation_reasons.json');
    });

    test('seluruh alasan terurai dengan kode dan teks', () {
      final List<DriverCancellationReason> alasan = json
          .map(
            (dynamic e) =>
                DriverCancellationReason.fromJson(e as Map<String, dynamic>),
          )
          .toList();

      expect(alasan, isNotEmpty);

      for (final DriverCancellationReason a in alasan) {
        expect(a.code, isNotEmpty);
        expect(a.text, isNotEmpty);
      }
    });

    /// ========================================================================
    ///  KODENYA HARUS BERAWALAN `DRV_`
    /// ========================================================================
    ///  Ini yang dulu salah: aplikasi memakai daftar cadangan dengan kode
    ///  `driver_vehicle_issue`, sementara tabelnya memakai `DRV_VEHICLE_PROBLEM`.
    ///  Akibatnya SETIAP pembatalan oleh driver ditolak 422.
    ///
    ///  Test ini bukan menguji parser — dia menguji bahwa aplikasi memanggil
    ///  endpoint DRIVER, bukan endpoint penumpang. Alasan penumpang berawalan
    ///  `CANCEL_`.
    /// ========================================================================
    test('kodenya milik driver, bukan penumpang', () {
      for (final dynamic e in json) {
        final String code = (e as Map<String, dynamic>)['code'] as String;

        expect(
          code,
          startsWith('DRV_'),
          reason:
              'Kode "$code" bukan kode driver. Fixture ini berasal dari '
              'endpoint driver; kalau isinya kode penumpang, penyaringan '
              'actor_type di backend rusak.',
        );
      }
    });

    test('penanda penurun skor ikut terkirim', () {
      final bool adaYangMenurunkan = json.any(
        (dynamic e) => (e as Map<String, dynamic>)['lowers_score'] == true,
      );

      expect(
        adaYangMenurunkan,
        isTrue,
        reason:
            'Tanpa penanda ini, driver tidak punya cara mengetahui pilihan mana '
            'yang menurunkan prioritasnya di mesin pencocokan.',
      );
    });
  });

  group('AppNotification & NotificationPage terhadap response sungguhan', () {
    late Map<String, dynamic> badan;

    setUpAll(() {
      badan = _fixture('notifications.json');
    });

    /// Fungsi yang SAMA dengan yang dipakai `NotificationRepository.list`.
    ///
    /// Bukan salinan logikanya. Test yang menulis ulang penguraiannya sendiri
    /// akan tetap lulus walaupun repository-nya membaca `unread_count` dari
    /// tempat yang salah — dan itu justru yang paling perlu dijaga di sini.
    NotificationPage urai(Map<String, dynamic> b) =>
        NotificationPage.fromEnvelope(b);

    test('daftar dan meta terurai', () {
      final NotificationPage halaman = urai(badan);

      expect(halaman.notifications, hasLength(2));
      expect(halaman.hasMore, isFalse);
      expect(halaman.nextCursor, isNull);
    });

    /// ========================================================================
    ///  `unread_count` DIBACA DARI `meta`, BUKAN DARI `data`
    /// ========================================================================
    ///  Ini yang menggerakkan lencana angka di ikon lonceng. Kalau dibaca dari
    ///  tempat yang salah, hasilnya nol — dan lencana yang selalu nol terlihat
    ///  persis sama dengan "tidak ada notifikasi baru".
    ///
    ///  Tidak ada galat, tidak ada log. Hanya notifikasi yang tidak pernah
    ///  diberitahukan.
    /// ========================================================================
    test('unread_count terbaca dari meta', () {
      expect(
        urai(badan).unreadCount,
        1,
        reason:
            'Nol di sini berarti `unread_count` dibaca dari tempat yang salah. '
            'Nilainya ada di `meta`, bukan di dalam tiap notifikasi.',
      );
    });

    /// Status baca dibedakan per notifikasi, bukan nilai tetap.
    ///
    /// Fixture-nya sengaja memuat satu yang sudah dibaca dan satu yang belum —
    /// lihat `test_menulis_fixture_notifikasi` di backend. Parser yang
    /// mengembalikan nilai tetap akan lulus kalau keduanya sama.
    test('is_read dibedakan per notifikasi', () {
      final List<AppNotification> daftar = urai(badan).notifications;

      final int belumDibaca = daftar
          .where((AppNotification n) => !n.isRead)
          .length;

      expect(belumDibaca, 1);
      expect(daftar.where((AppNotification n) => n.isRead).length, 1);

      final AppNotification sudah = daftar.firstWhere(
        (AppNotification n) => n.isRead,
      );

      expect(sudah.readAt, isNotNull);
    });

    /// ========================================================================
    ///  `orderUuid` DIBACA DARI `action`, DAN NAMA KUNCINYA HARUS PERSIS
    /// ========================================================================
    ///  `{"screen": "order", "order_uuid": "..."}` — nama yang berbeda
    ///  (`orderUuid`, `order_id`) membuat notifikasi terbuka ke layar kosong
    ///  tanpa satu pun galat, karena getter-nya hanya mengembalikan null dan
    ///  penerjemah aksinya memang mengabaikan null.
    /// ========================================================================
    test('orderUuid terbaca dari action', () {
      final AppNotification notif = urai(badan).notifications.firstWhere(
        (AppNotification n) => n.type == 'order.accepted',
      );

      expect(
        notif.orderUuid,
        isNotNull,
        reason:
            'Null di sini berarti kunci di dalam `action` bukan `order_uuid`, '
            'atau `screen`-nya bukan `order`. Notifikasi akan tidak melakukan '
            'apa pun saat ditekan.',
      );

      expect(notif.orderUuid, hasLength(36));
    });

    /// Notifikasi tanpa `action` tidak punya orderUuid, dan itu bukan galat.
    ///
    /// Pengumuman umum memang tidak menuju ke mana pun. Yang harus dihindari:
    /// getter yang melempar pada `action` null, karena itu akan mematikan
    /// SELURUH daftar hanya karena ada satu pengumuman di dalamnya.
    test('notifikasi tanpa action aman dibaca', () {
      final AppNotification pengumuman = urai(badan).notifications.firstWhere(
        (AppNotification n) => n.type == 'announcement',
      );

      expect(pengumuman.action, isNull);
      expect(pengumuman.orderUuid, isNull);
    });

    /// ========================================================================
    ///  `created_at` HARUS DIURAI SEBAGAI WAKTU BERZONA
    /// ========================================================================
    ///  Backend mengirimnya ISO 8601 dengan offset. Kalau penanda zonanya
    ///  diabaikan, Dart menguraikannya sebagai waktu LOKAL — dan di WIB (UTC+7)
    ///  notifikasi yang baru dibuat akan tampil sebagai "7 jam lalu".
    ///
    ///  ------------------------------------------------------------------------
    ///  DIPERIKSA LANGSUNG, BUKAN LEWAT "UMURNYA MASUK AKAL"
    ///  ------------------------------------------------------------------------
    ///  Versi pertama test ini membandingkan `createdAt` dengan `DateTime.now()`
    ///  dan menuntut selisihnya di bawah enam jam. Itu bukti TIDAK LANGSUNG, dan
    ///  dia rusak sendiri: fixture yang berumur sehari gagal karena umurnya,
    ///  bukan karena parsingnya — dengan pesan yang menuduh penanda zona.
    ///
    ///  Yang diperiksa sekarang: momen hasil parsing sama persis dengan momen
    ///  yang dinyatakan string aslinya. Tidak bergantung pada jam berapa
    ///  sekarang, dan tidak bergantung pada kapan fixture dibuat.
    /// ========================================================================
    test('created_at diurai berzona, bukan sebagai waktu lokal', () {
      final Map<String, dynamic> mentah =
          (badan['data'] as List<dynamic>).first as Map<String, dynamic>;

      final String asli = mentah['created_at'] as String;

      final AppNotification notif = urai(badan).notifications.first;

      expect(notif.createdAt, isNotNull);

      expect(
        notif.createdAt!.toUtc(),
        DateTime.parse(asli).toUtc(),
        reason:
            'Momen hasil parsing berbeda dari yang dinyatakan "$asli". Penanda '
            'zona diabaikan, jadi setiap notifikasi tampil bergeser sebesar '
            'offset zona perangkat.',
      );
    });

    /// Offset zona benar-benar menggeser momennya.
    ///
    /// ------------------------------------------------------------------------
    ///  MEMBANDINGKAN DUA OFFSET, BUKAN MEMERIKSA SATU NILAI
    /// ------------------------------------------------------------------------
    ///  Versi pertama test ini memakai satu nilai `+07:00` dan menuntut hasilnya
    ///  jam 1 UTC. Dia LOLOS SECARA KEBETULAN di mesin WIB: kalau offsetnya
    ///  diabaikan, jam dinding 08:41 diurai sebagai waktu lokal WIB — yang juga
    ///  menghasilkan 01:41 UTC.
    ///
    ///  Test yang hanya benar di zona pengembangnya lebih buruk daripada tidak
    ///  ada: dia memberi rasa aman, lalu gagal di CI yang berjalan UTC.
    ///
    ///  Yang diperiksa sekarang: SELISIH antara dua jam dinding yang sama dengan
    ///  offset berbeda. Kalau offsetnya dihormati, selisihnya persis tujuh jam.
    ///  Kalau diabaikan, keduanya diurai identik dan selisihnya nol — apa pun
    ///  zona mesin yang menjalankannya.
    test('offset zona menggeser momennya, bukan diabaikan', () {
      DateTime pada(String createdAt) =>
          AppNotification.fromJson(<String, dynamic>{
            'uuid': '01a04787-0000-7000-8000-000000000000',
            'type': 'announcement',
            'title': 'Uji zona',
            'body': 'Uji zona',
            'is_read': false,
            'created_at': createdAt,
          }).createdAt!.toUtc();

      // Jam dinding yang SAMA, offset berbeda tujuh jam.
      final DateTime wib = pada('2026-08-28T08:41:25+07:00');
      final DateTime utc = pada('2026-08-28T08:41:25+00:00');

      expect(
        utc.difference(wib),
        const Duration(hours: 7),
        reason:
            'Selisihnya ${utc.difference(wib).inHours} jam, seharusnya 7. Nol '
            'berarti offset zona diabaikan sepenuhnya — dan setiap notifikasi '
            'akan tampil bergeser sebesar offset perangkat.',
      );
    });

    /// Jenis notifikasi yang tidak dikenali tetap terurai utuh.
    ///
    /// Ini yang membuat backend bisa menambah jenis baru tanpa menunggu semua
    /// pengguna memperbarui aplikasinya. Aplikasi lama menampilkan ikon umum,
    /// dan judul serta isinya — yang datang dari backend — tetap terbaca.
    test('jenis yang tidak dikenali tetap terurai', () {
      final AppNotification asing = AppNotification.fromJson(<String, dynamic>{
        'uuid': '01a04787-0000-7000-8000-000000000000',
        'type': 'sesuatu.yang.belum.ada',
        'title': 'Jenis baru',
        'body': 'Dikirim backend versi yang lebih baru.',
        'action': null,
        'is_read': false,
        'read_at': null,
        'created_at': '2026-08-28T08:41:25+00:00',
      });

      expect(asing.type, 'sesuatu.yang.belum.ada');
      expect(asing.title, 'Jenis baru');
      expect(asing.orderUuid, isNull);
    });
  });

  group('DriverDocumentState terhadap response backend sungguhan', () {
    late DriverDocumentState keadaan;

    setUpAll(() {
      keadaan = DriverDocumentState.fromJson(_fixture('driver_documents.json'));
    });

    test('daftar wajib dan dokumennya terurai', () {
      expect(keadaan.required, isNotEmpty);
      expect(keadaan.documents, isNotEmpty);

      for (final DriverDocument d in keadaan.documents) {
        expect(d.uuid, isNotEmpty);
        expect(d.type, isNotEmpty);

        expect(
          d.label,
          isNotEmpty,
          reason:
              'Label dari backend kosong. Layar akan menampilkan kode mentah '
              'seperti `bank_book` kepada driver.',
        );
      }
    });

    /// ========================================================================
    ///  INI TEST YANG PALING PENTING DI GRUP INI
    /// ========================================================================
    ///  Dokumen yang statusnya `approved` TAPI tanggalnya sudah lewat harus
    ///  terbaca sebagai kadaluarsa.
    ///
    ///  Keduanya benar sekaligus — dia pernah lolos verifikasi, dan sekarang
    ///  tidak berlaku. Yang perlu driver ketahui yang kedua: `GoOnline` akan
    ///  menolaknya sampai dia memperbaruinya.
    ///
    ///  Kalau `is_expired` tidak terbaca, layar menampilkan "Disetujui" dan
    ///  driver ditolak online tanpa satu pun petunjuk kenapa.
    /// ========================================================================
    test('dokumen approved yang kadaluarsa terbaca kadaluarsa', () {
      final DriverDocument sim = keadaan.documents.firstWhere(
        (DriverDocument d) => d.type == 'sim',
      );

      expect(sim.isApproved, isTrue);

      expect(
        sim.isExpired,
        isTrue,
        reason:
            '`is_expired` tidak terbaca. Layar akan menampilkan "Disetujui" '
            'untuk SIM yang sudah habis masa berlakunya.',
      );

      expect(
        sim.statusLabel,
        'Kadaluarsa',
        reason:
            'Label statusnya masih "Disetujui". Yang perlu driver ketahui '
            'adalah bahwa dia tidak bisa online sampai memperbaruinya.',
      );
    });

    /// `expired` dipisah dari `missing`, karena tindakannya berbeda.
    ///
    /// Yang `missing` difoto dan dikirim dari aplikasi. Yang `expired`
    /// diperpanjang di kantor yang menerbitkannya — memfotonya ulang tidak
    /// menyelesaikan apa pun.
    test('expired dan missing terurai terpisah', () {
      expect(
        keadaan.expired,
        contains('sim'),
        reason:
            'Daftar `expired` tidak terbaca. Layar tidak bisa membedakan '
            '"belum diunggah" dari "perlu diperpanjang", dan kalimat yang '
            'menyuruh driver mengunggah ulang SIM kadaluarsa akan membuatnya '
            'mencoba berulang untuk masalah yang tidak ada di aplikasi.',
      );

      expect(keadaan.missing, isNotEmpty);
    });

    /// ========================================================================
    ///  `can_go_online` DARI BACKEND, TIDAK DISIMPULKAN APLIKASI
    /// ========================================================================
    ///  Fixture-nya memuat SIM kadaluarsa, jadi jawabannya false. Aplikasi yang
    ///  menghitungnya sendiri dari `missing` saja akan menjawab berbeda — dan
    ///  yang terjadi kemudian: layar menyatakan driver siap, lalu tombol
    ///  online-nya ditolak backend.
    /// ========================================================================
    test('can_go_online mengikuti backend', () {
      expect(
        keadaan.canGoOnline,
        isFalse,
        reason:
            'Fixture memuat SIM yang kadaluarsa, jadi backend menolaknya '
            'online. Nilai true di sini berarti aplikasi menyimpulkannya '
            'sendiri dan tidak sepakat dengan backend.',
      );
    });

    /// Alasan penolakan terbaca.
    ///
    /// Ini satu-satunya cara driver mengetahui apa yang salah dengan dokumennya.
    /// Tanpa itu dia mengunggah foto yang sama berulang kali — dan setiap putaran
    /// memakan waktu verifikator juga.
    test('alasan penolakan terbaca', () {
      final DriverDocument stnk = keadaan.documents.firstWhere(
        (DriverDocument d) => d.type == 'stnk',
      );

      expect(stnk.isRejected, isTrue);
      expect(stnk.rejectReason, isNotNull);
      expect(stnk.rejectReason, isNotEmpty);
    });

    /// ========================================================================
    ///  PATH BERKAS TIDAK BOLEH ADA DI RESPONSE, DAN FIXTURE MEMBUKTIKANNYA
    /// ========================================================================
    ///  Fixture ini adalah response HTTP sungguhan yang ditulis ke repo ini.
    ///  Kalau backend mengirimkan `file_path`, dia akan tertulis ke berkas ini —
    ///  dan hidup di riwayat git selamanya.
    ///
    ///  Path dokumen KYC tidak berguna bagi aplikasi (disknya privat), tapi
    ///  berguna bagi orang yang sedang mencari cara menebak path dokumen driver
    ///  lain.
    /// ========================================================================
    test('fixture tidak memuat path berkas', () {
      expect(
        _baca('driver_documents.json'),
        isNot(contains('file_path')),
        reason:
            'Backend mengirim `file_path`, dan fixture di repo ini sekarang '
            'memuatnya.',
      );
    });

    /// `forType` menemukan dokumen berdasarkan jenisnya.
    ///
    /// Dipakai layar untuk memasangkan setiap jenis wajib dengan dokumennya —
    /// dan mengembalikan null untuk yang belum diunggah, yang menjadi kartu
    /// dengan tombol unggah.
    test('forType mengembalikan null untuk yang belum diunggah', () {
      expect(keadaan.forType('ktp'), isNotNull);
      expect(keadaan.forType('bank_book'), isNull);
    });
  });
}

// ---------------------------------------------------------------------------

/// Direktori fixture, relatif terhadap package ini.
///
/// `flutter test` berjalan dengan CWD di direktori package, jadi jalurnya naik
/// dua tingkat ke akar workspace.
const String _dir = '../../test_fixtures';

Map<String, dynamic> _fixture(String nama) =>
    jsonDecode(_baca(nama)) as Map<String, dynamic>;

List<dynamic> _fixtureList(String nama) =>
    jsonDecode(_baca(nama)) as List<dynamic>;

String _baca(String nama) {
  final File berkas = File('$_dir/$nama');

  if (!berkas.existsSync()) {
    /*
     * Pesannya menyebutkan cara memperbaikinya, bukan hanya menyatakan
     * berkasnya tidak ada.
     *
     * Fixture ini dihasilkan repo BACKEND, jadi orang yang menjalankan test FE
     * dan melihat kegagalan ini tidak punya alasan menduga jawabannya ada di
     * repo lain.
     */
    fail(
      'Fixture "$nama" tidak ada.\n\n'
      'Fixture dihasilkan oleh backend. Jalankan:\n'
      '  cd antaride-be && php artisan test tests/Feature/Api/ContractFixtureTest.php\n',
    );
  }

  return berkas.readAsStringSync();
}
