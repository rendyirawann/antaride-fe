import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_customer/features/order/order_flow_controller.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
///  ATURAN PALING BERKONSEKUENSI DI SELURUH APLIKASI PENUMPANG
/// ============================================================================
///  `Idempotency-Key` dibuat SEKALI per operasi dan DIPAKAI ULANG untuk setiap
///  percobaan berikutnya.
///
///  Kalau kunci baru dibuat setiap percobaan, backend melihat dua permintaan
///  berbeda dan membuat DUA order. Pada pembayaran wallet, dananya ditahan dua
///  kali — dan penumpang melihat saldonya terpotong dua kali untuk satu
///  perjalanan.
///
///  Ini bukan skenario hipotetis: penumpang di jaringan buruk menekan "Pesan",
///  tidak melihat respons, lalu menekan lagi. Itu justru perilaku yang wajar.
/// ============================================================================
///
/// ============================================================================
///  DIUJI LEWAT ADAPTER DIO, BUKAN DENGAN MEMALSUKAN REPOSITORY
/// ============================================================================
///  Repository yang dipalsukan hanya membuktikan controller memanggilnya dengan
///  kunci yang sama. Yang TIDAK dibuktikannya: bahwa kuncinya benar-benar
///  terkirim sebagai header HTTP.
///
///  Adapter di bawah mencatat header dari request sungguhan yang dibangun Dio,
///  jadi yang diperiksa adalah apa yang benar-benar keluar ke jaringan.
/// ============================================================================
void main() {
  late _AdapterPencatat adapter;
  late OrderFlowController alur;

  setUp(() {
    adapter = _AdapterPencatat();

    final Dio dio = Dio()..httpClientAdapter = adapter;

    final ApiClient client = ApiClient(
      tokenStore: TokenStore(),
      baseUrl: 'http://127.0.0.1:8000/api/v1',
      dio: dio,
    );

    alur = OrderFlowController(
      quotes: QuoteRepository(client),
      orders: OrderRepository(client),
    );
  });

  /// Menyiapkan alur sampai siap kirim: dua titik terpilih dan quote termuat.
  Future<void> siapkan() async {
    alur.setPickup(
      const ChosenPlace(
        position: LatLng(3.5952, 98.6722),
        address: 'Jl. Gatot Subroto No. 12',
      ),
    );

    alur.setDestination(
      const ChosenPlace(
        position: LatLng(3.6000, 98.6800),
        address: 'Jl. Iskandar Muda No. 4',
      ),
    );

    await alur.loadQuote();
  }

  test('quote termuat dari response backend', () async {
    await siapkan();

    expect(alur.quote, isNotNull);
    expect(alur.selectedService, isNotNull);
    expect(alur.selectedService!.total.amount, greaterThan(0));
  });

  /// ==========================================================================
  ///  INTI DARI BERKAS INI
  /// ==========================================================================
  test('percobaan yang gagal memakai ULANG kunci idempotency yang sama', () async {
    await siapkan();

    // Dua percobaan pertama gagal — meniru jaringan yang mati di tengah jalan.
    adapter.gagalkanPostOrder = 2;

    final Order? pertama = await alur.submit();
    final Order? kedua = await alur.submit();
    final Order? ketiga = await alur.submit();

    expect(pertama, isNull);
    expect(kedua, isNull);
    expect(ketiga, isNotNull, reason: 'Percobaan ketiga seharusnya berhasil.');

    expect(
      adapter.kunciOrder,
      hasLength(3),
      reason: 'Tiga percobaan berarti tiga request keluar.',
    );

    expect(
      adapter.kunciOrder.toSet(),
      hasLength(1),
      reason:
          'Tiga kunci berbeda berarti backend melihat tiga permintaan berbeda '
          'dan membuat TIGA order. Pada pembayaran wallet, dananya ditahan tiga '
          'kali. Kunci HARUS dipakai ulang saat mencoba lagi.\n'
          'Kunci yang terkirim: ${adapter.kunciOrder}',
    );
  });

  test(
    'kunci dibuang setelah order berhasil, supaya order berikutnya baru',
    () async {
      await siapkan();

      final Order? pertama = await alur.submit();

      expect(pertama, isNotNull);

      final String kunciOrderPertama = adapter.kunciOrder.single;

      // Order kedua: alur di-reset seperti yang dilakukan aplikasi setelah
      // penumpang kembali ke beranda.
      alur.reset();
      await siapkan();

      final Order? kedua = await alur.submit();

      expect(kedua, isNotNull);

      expect(
        adapter.kunciOrder.last,
        isNot(kunciOrderPertama),
        reason:
            'Order kedua memakai kunci yang sama dengan order pertama. Backend '
            'akan MEMUTAR ULANG response order pertama alih-alih membuat order '
            'baru — penumpang mengira sudah memesan, dan tidak ada driver yang '
            'dicarikan.',
      );
    },
  );

  test('header Idempotency-Key benar-benar terkirim', () async {
    await siapkan();

    await alur.submit();

    expect(
      adapter.kunciOrder.single,
      isNotEmpty,
      reason:
          'Tanpa header ini, middleware idempotency di backend tidak aktif dan '
          'seluruh perlindungan double-tap hilang.',
    );

    // UUID v4: 36 karakter dengan tanda hubung. Bukan sekadar tidak kosong —
    // string kosong atau nilai tetap juga "tidak kosong", dan keduanya akan
    // membuat setiap penumpang berbagi kunci yang sama.
    expect(adapter.kunciOrder.single, hasLength(36));
  });

  /// ==========================================================================
  ///  QUOTE YANG DIPERBARUI HARUS DISERTAI KUNCI IDEMPOTENCY BARU
  /// ==========================================================================
  ///  Middleware idempotency di backend memeriksa HASH PAYLOAD, bukan hanya
  ///  kuncinya. Kunci yang sama dengan payload berbeda ditolak dengan
  ///  `IDEMPOTENCY_KEY_REUSED` — karena membiarkannya lolos berarti
  ///  mengembalikan response order A untuk permintaan order B.
  ///
  ///  Alur yang memicunya nyata dan tidak jarang:
  ///
  ///    1. Penumpang menekan "Pesan". Jaringan mati, request gagal. Kunci K
  ///       tersimpan bersama quote A.
  ///    2. Dia menatap layar beberapa saat. Quote A kadaluarsa.
  ///    3. Dia menekan "Pesan" lagi. Aplikasi mengambil quote B, lalu mengirim
  ///       `quote_id` B dengan kunci K yang lama.
  ///    4. Backend menolak: kunci sama, payload berbeda.
  ///
  ///  Yang dilihat penumpang: pesanan gagal dengan galat yang tidak dia
  ///  sebabkan, tepat pada percobaan kedua — dan mencoba lagi tidak menolong
  ///  karena kuncinya tetap yang lama.
  ///
  ///  Aturannya: kunci dipakai ulang untuk PAYLOAD YANG SAMA, dan dibuang
  ///  begitu payload-nya berubah.
  /// ==========================================================================
  test('quote yang diperbarui membuang kunci idempotency yang lama', () async {
    // Masa berlaku pendek supaya quote pertama benar-benar kadaluarsa dalam
    // rentang test. Setelah jeda di bawah, quote itu PASTI lewat — mesin yang
    // lambat hanya membuatnya lebih lewat, bukan sebaliknya.
    adapter.masaBerlakuDetik = 2;

    await siapkan();

    final String quotePertama = alur.quote!.id;

    // Percobaan pertama gagal karena jaringan.
    adapter.gagalkanPostOrder = 1;

    expect(await alur.submit(), isNull);

    expect(adapter.kunciOrder, hasLength(1));
    expect(adapter.quoteIdOrder.single, quotePertama);

    // Quote pertama kadaluarsa selagi penumpang menatap layar konfirmasi.
    await Future<void>.delayed(const Duration(milliseconds: 2400));

    expect(
      alur.quote!.isExpired,
      isTrue,
      reason: 'Quote seharusnya sudah kadaluarsa setelah jeda.',
    );

    // Quote berikutnya berlaku normal lagi.
    adapter.masaBerlakuDetik = 300;

    // Percobaan kedua: aplikasi mengambil quote baru lalu mengirim ulang.
    expect(await alur.submit(), isNotNull);

    expect(adapter.kunciOrder, hasLength(2));
    expect(adapter.quoteIdOrder, hasLength(2));

    expect(
      adapter.quoteIdOrder[1],
      isNot(adapter.quoteIdOrder[0]),
      reason:
          'quote_id tidak berubah setelah refresh. Test ini tidak menguji apa '
          'pun kalau payload-nya sama.',
    );

    expect(
      adapter.kunciOrder[1],
      isNot(adapter.kunciOrder[0]),
      reason:
          'quote_id berubah tapi Idempotency-Key TETAP. Backend akan menolak '
          'dengan IDEMPOTENCY_KEY_REUSED — kunci yang sama dengan payload '
          'berbeda adalah bug di sisi client. '
          'quote_id: ${adapter.quoteIdOrder}, '
          'kunci: ${adapter.kunciOrder}',
    );
  });

  /// Quote yang berubah rute membuang kuncinya juga.
  ///
  /// Kalau tidak, penumpang yang mengganti tujuan lalu memesan akan memakai
  /// kunci yang sama dengan percobaan untuk rute LAMA — dan backend memutar
  /// ulang order lama, ke tujuan yang sudah dia ganti.
  test('mengganti tujuan membuang quote dan kunci lama', () async {
    await siapkan();

    expect(alur.quote, isNotNull);

    alur.setDestination(
      const ChosenPlace(
        position: LatLng(3.6100, 98.6900),
        address: 'Tujuan lain',
      ),
    );

    expect(
      alur.quote,
      isNull,
      reason:
          'Quote lama yang tidak dibuang berarti aplikasi memesan dengan harga '
          'untuk rute yang berbeda dari tujuan yang dipilih.',
    );

    expect(alur.canSubmit, isFalse);
  });
}

// ---------------------------------------------------------------------------

/// Adapter Dio yang membalas dari fixture dan mencatat header yang dikirim.
class _AdapterPencatat implements HttpClientAdapter {
  /// Nilai `Idempotency-Key` dari setiap POST /orders, dalam urutan pengiriman.
  final List<String> kunciOrder = <String>[];

  /// `quote_id` dari setiap POST /orders, dalam urutan pengiriman.
  ///
  /// Dicatat supaya test bisa memeriksa hubungan antara payload dan kuncinya:
  /// payload yang berubah HARUS disertai kunci yang berubah.
  final List<String> quoteIdOrder = <String>[];

  /// Berapa POST /orders berikutnya yang dibalas gagal.
  int gagalkanPostOrder = 0;

  /// Masa berlaku quote yang dikembalikan, dalam detik.
  int masaBerlakuDetik = 300;

  /// Penghitung supaya setiap quote punya id yang berbeda — seperti backend,
  /// yang membuat quote baru setiap kali dihitung.
  int _nomorQuote = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.path;

    if (path.endsWith('/quotes') && options.method == 'POST') {
      return _sukses(_quoteBaru());
    }

    if (path.endsWith('/orders') && options.method == 'POST') {
      kunciOrder.add((options.headers['Idempotency-Key'] ?? '').toString());
      quoteIdOrder.add(_bacaQuoteId(options.data));

      if (gagalkanPostOrder > 0) {
        gagalkanPostOrder--;

        // 503, bukan 422: yang ditiru adalah kegagalan yang LAYAK dicoba lagi.
        // Kegagalan validasi tidak akan dicoba ulang oleh penumpang dengan
        // masukan yang sama.
        return _gagal(
          503,
          'SERVICE_UNAVAILABLE',
          'Server sedang sibuk. Coba lagi.',
        );
      }

      return _sukses(_fixture('order_customer.json'), status: 201);
    }

    return _gagal(404, 'NOT_FOUND', 'Endpoint tidak dikenali: $path');
  }

  ResponseBody _sukses(Object data, {int status = 200}) {
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'success': true, 'data': data}),
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

  /// Quote dengan id unik dan masa berlaku yang diatur test.
  ///
  /// ==========================================================================
  ///  FIXTURE MEMASOK BENTUKNYA, TEST MEMASOK ID DAN KESEGARANNYA
  /// ==========================================================================
  ///  `expires_at` di fixture adalah cap waktu saat fixture itu DIHASILKAN.
  ///  Quote di backend hanya berlaku beberapa menit, jadi memakainya apa adanya
  ///  membuat test ini lulus tepat setelah fixture dibuat dan gagal setelah itu —
  ///  `submit()` akan menolak dengan `QUOTE_EXPIRED` sebelum satu request pun
  ///  terkirim.
  ///
  ///  Test yang hasilnya bergantung pada JAM lebih buruk daripada tidak ada
  ///  test: dia akan gagal di CI beberapa hari kemudian, dengan pesan yang
  ///  menunjuk ke idempotency padahal penyebabnya masa berlaku fixture.
  ///
  ///  `quote_id` juga dibuat unik per panggilan, meniru backend: setiap
  ///  perhitungan menghasilkan quote baru dengan id baru, disimpan di Redis
  ///  dengan TTL-nya sendiri. Itu yang membuat test bisa memeriksa hubungan
  ///  antara payload yang berubah dan kunci idempotency.
  ///
  ///  Yang diambil dari fixture tetap BENTUKNYA — nama kunci, susunan
  ///  bersarang, jenis nilai. Hanya dua field yang diganti, dan penggantiannya
  ///  disebutkan di sini supaya tidak terbaca sebagai fixture yang dipalsukan.
  /// ==========================================================================
  Map<String, dynamic> _quoteBaru() {
    final Map<String, dynamic> quote =
        _fixture('quote.json') as Map<String, dynamic>;

    _nomorQuote++;

    quote['quote_id'] = 'quote-uji-$_nomorQuote';

    quote['expires_at'] = DateTime.now()
        .add(Duration(seconds: masaBerlakuDetik))
        .toUtc()
        .toIso8601String();

    return quote;
  }

  /// Ambil `quote_id` dari badan request.
  ///
  /// ==========================================================================
  ///  BADAN REQUEST BISA BERUPA Map ATAU String DI LAPISAN ADAPTER
  /// ==========================================================================
  ///  Dio menjalankan transformer-nya SEBELUM memanggil adapter, jadi
  ///  `options.data` di sini bisa sudah berupa string JSON — bukan Map yang
  ///  dikirim repository.
  ///
  ///  Cast langsung ke `Map<String, dynamic>?` MELEMPAR pada string (bukan
  ///  mengembalikan null), dan exception itu ditelan penanganan galat Dio. Yang
  ///  terlihat: request-nya "gagal" dengan sebab yang tidak ada hubungannya, dan
  ///  daftar pencatatnya tetap kosong — kegagalan test yang menunjuk ke tempat
  ///  yang salah.
  /// ==========================================================================
  String _bacaQuoteId(dynamic data) {
    final dynamic badan = data is String ? jsonDecode(data) : data;

    if (badan is Map) {
      return (badan['quote_id'] ?? '').toString();
    }

    return '';
  }

  @override
  void close({bool force = false}) {}
}

/// Fixture dihasilkan backend — lihat `ContractFixtureTest` di `antaride-be`.
Object _fixture(String nama) {
  final File berkas = File('../../test_fixtures/$nama');

  if (!berkas.existsSync()) {
    fail(
      'Fixture "$nama" tidak ada.\n\n'
      'Jalankan:\n'
      '  cd antaride-be && php artisan test tests/Feature/Api/ContractFixtureTest.php\n',
    );
  }

  // Diurai ulang setiap pemanggilan, bukan di-cache: `_quoteBaru`
  // mengubah salah satu field, dan map yang dibagi antar test akan membawa
  // perubahan itu ke test berikutnya.
  return jsonDecode(berkas.readAsStringSync()) as Object;
}
