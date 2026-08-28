import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Satu titik yang dipilih pengguna.
class ChosenPlace {
  const ChosenPlace({required this.position, required this.address, this.note});

  final LatLng position;

  /// Alamat yang ditampilkan dan dikirim ke backend.
  ///
  /// Fase 1 belum punya reverse geocoding, jadi ini teks yang DIKETIK pengguna,
  /// bukan hasil pencarian alamat. Yang dipakai driver untuk menemukan titiknya
  /// tetap koordinat; alamat teks adalah keterangan tambahan — dan justru
  /// keterangan yang diketik pengguna sendiri ("depan pagar hitam, sebelah
  /// warung") lebih berguna daripada nama jalan dari geocoder.
  final String address;

  final String? note;

  ChosenPlace copyWith({String? address, String? note}) => ChosenPlace(
    position: position,
    address: address ?? this.address,
    note: note ?? this.note,
  );
}

/// State pemesanan satu order, dari pemilihan titik sampai order terbuat.
///
/// ============================================================================
///  KENAPA SATU CONTROLLER UNTUK SELURUH ALUR, BUKAN SATU PER LAYAR
/// ============================================================================
///  Alurnya melewati tiga layar: pilih titik, pilih layanan, konfirmasi. State
///  yang dibawanya — titik jemput, tujuan, quote, layanan terpilih, promo,
///  metode bayar — dipakai lintas layar.
///
///  Kalau setiap layar punya state sendiri dan meneruskannya lewat constructor,
///  yang terjadi adalah data yang sama disalin tiga kali, dan tombol kembali
///  membuat salinan itu menyimpang: pengguna kembali untuk mengganti tujuan,
///  quote lama masih terpakai di layar berikutnya.
/// ============================================================================
class OrderFlowController extends ChangeNotifier {
  OrderFlowController({
    required QuoteRepository quotes,
    required OrderRepository orders,
  }) : _quotes = quotes,
       _orders = orders;

  final QuoteRepository _quotes;
  final OrderRepository _orders;

  ChosenPlace? _pickup;
  ChosenPlace? _destination;

  Quote? _quote;
  String? _serviceCode;
  String _paymentMethod = 'cash';
  String? _promoCode;

  bool _loadingQuote = false;
  bool _submitting = false;
  ApiFailure? _failure;

  /// Kunci idempotency untuk PERCOBAAN pembuatan order yang sedang berjalan.
  ///
  /// ==========================================================================
  ///  DIBUAT SEKALI, DIPAKAI ULANG SAMPAI ORDERNYA BERHASIL
  /// ==========================================================================
  ///  Ini inti dari perlindungan double-tap. Kunci baru setiap percobaan berarti
  ///  backend melihat dua permintaan berbeda dan membuat DUA order — dan pada
  ///  pembayaran wallet, dananya ditahan dua kali.
  ///
  ///  Dibuang HANYA setelah order berhasil dibuat, atau saat alurnya di-reset
  ///  untuk order yang benar-benar baru. Percobaan yang gagal karena jaringan
  ///  memakai kunci yang SAMA.
  /// ==========================================================================
  String? _idempotencyKey;

  // ---------------------------------------------------------------------------

  ChosenPlace? get pickup => _pickup;

  ChosenPlace? get destination => _destination;

  Quote? get quote => _quote;

  String? get serviceCode => _serviceCode;

  String get paymentMethod => _paymentMethod;

  String? get promoCode => _promoCode;

  bool get isLoadingQuote => _loadingQuote;

  bool get isSubmitting => _submitting;

  ApiFailure? get failure => _failure;

  bool get hasRoute => _pickup != null && _destination != null;

  QuoteService? get selectedService {
    final Quote? q = _quote;
    final String? kode = _serviceCode;

    if (q == null || kode == null) {
      return null;
    }

    return q.serviceFor(kode);
  }

  /// Titik-titik rute untuk digambar di peta.
  List<LatLng> get routePoints => PolylineCodec.decode(_quote?.polyline);

  /// Potongan promo untuk layanan yang sedang dipilih.
  int? get promoDiscount {
    final String? promo = _promoCode;
    final String? layanan = _serviceCode;

    if (promo == null || layanan == null) {
      return null;
    }

    return _quote?.discountFor(promoCode: promo, serviceCode: layanan);
  }

  /// Siap dikirim: ada rute, ada quote yang belum kadaluarsa, dan layanan yang
  /// dipilih memang bisa dipesan.
  bool get canSubmit {
    final Quote? q = _quote;
    final QuoteService? layanan = selectedService;

    return !_submitting &&
        !_loadingQuote &&
        q != null &&
        !q.isExpired &&
        layanan != null &&
        layanan.isOrderable &&
        _pickup != null;
  }

  // ---------------------------------------------------------------------------

  void setPickup(ChosenPlace tempat) {
    _pickup = tempat;
    _invalidateQuote();
    notifyListeners();
  }

  void setDestination(ChosenPlace tempat) {
    _destination = tempat;
    _invalidateQuote();
    notifyListeners();
  }

  void selectService(String code) {
    _serviceCode = code;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setPromoCode(String? code) {
    _promoCode = (code == null || code.trim().isEmpty) ? null : code.trim();
    notifyListeners();
  }

  void clearFailure() {
    if (_failure == null) {
      return;
    }

    _failure = null;
    notifyListeners();
  }

  /// Kosongkan seluruh alur, untuk order berikutnya.
  void reset() {
    _pickup = null;
    _destination = null;
    _quote = null;
    _serviceCode = null;
    _paymentMethod = 'cash';
    _promoCode = null;
    _failure = null;
    _idempotencyKey = null;
    notifyListeners();
  }

  /// Quote lama dibuang begitu rutenya berubah.
  ///
  /// Kalau tidak dibuang, layar berikutnya akan menampilkan harga untuk rute
  /// LAMA — dan pengguna memesan dengan harga yang tidak sesuai tujuannya. Yang
  /// terjadi kemudian: backend menghitung ulang dari quote itu dan mengantarkan
  /// ke tempat yang salah, atau menolak dengan galat yang tidak menjelaskan
  /// apa pun.
  void _invalidateQuote() {
    _quote = null;
    _serviceCode = null;
    _idempotencyKey = null;
  }

  // ---------------------------------------------------------------------------

  /// Minta estimasi harga untuk rute yang sudah dipilih.
  Future<void> loadQuote({List<String> serviceCodes = const <String>[]}) async {
    final ChosenPlace? jemput = _pickup;
    final ChosenPlace? tujuan = _destination;

    if (jemput == null || tujuan == null || _loadingQuote) {
      return;
    }

    // Dicatat SEBELUM request, supaya bisa dibandingkan dengan id quote yang
    // datang. Lihat penjelasan di cabang Ok di bawah.
    final String? idQuoteLama = _quote?.id;

    _loadingQuote = true;
    _failure = null;
    notifyListeners();

    final Result<Quote> hasil = await _quotes.create(
      pickupLat: jemput.position.latitude,
      pickupLng: jemput.position.longitude,
      destLat: tujuan.position.latitude,
      destLng: tujuan.position.longitude,
      serviceCodes: serviceCodes,
    );

    _loadingQuote = false;

    switch (hasil) {
      case Ok<Quote>(value: final Quote q):
        _quote = q;

        /*
         * Layanan yang sudah dipilih DIPERTAHANKAN kalau masih ada di quote
         * baru, bukan direset ke yang pertama.
         *
         * Pengguna yang memilih Antaride Car lalu menggeser pin sedikit tidak
         * boleh dikembalikan ke motor tanpa dia sadari — dan kalau tidak
         * disadari, dia menekan pesan dan mendapat ojek.
         */
        final String? sebelumnya = _serviceCode;

        _serviceCode = (sebelumnya != null && q.serviceFor(sebelumnya) != null)
            ? sebelumnya
            : _layananPertamaYangBisaDipesan(q);

        /*
         * ====================================================================
         *  QUOTE BARU BERARTI KUNCI IDEMPOTENCY BARU
         * ====================================================================
         *  Middleware idempotency di backend memeriksa HASH PAYLOAD, bukan
         *  hanya kuncinya. Kunci yang sama dengan payload berbeda ditolak
         *  `IDEMPOTENCY_KEY_REUSED` — karena membiarkannya lolos berarti
         *  mengembalikan response order A untuk permintaan order B.
         *
         *  Alur yang memicunya nyata:
         *
         *    1. Penumpang menekan "Pesan". Jaringan mati; kunci K tersimpan
         *       bersama quote A.
         *    2. Dia menatap layar beberapa saat. Quote A kadaluarsa.
         *    3. Dia menekan "Pesan" lagi. `submit()` mengambil quote B, lalu
         *       mengirim `quote_id` B dengan kunci K yang lama.
         *    4. Backend menolak: kunci sama, payload berbeda. Dan mencoba lagi
         *       tidak menolong, karena kuncinya tetap yang lama.
         *
         *  Aturannya: kunci dipakai ulang untuk PAYLOAD YANG SAMA, dan dibuang
         *  begitu payload-nya berubah. Id quote berubah berarti payload
         *  berubah.
         *
         *  Perbandingannya pada ID, bukan sekadar "loadQuote dipanggil": quote
         *  yang dihitung ulang dengan id yang sama — kalau backend nanti
         *  meng-cache-nya — tetap payload yang sama, dan di situ kuncinya harus
         *  DIPERTAHANKAN supaya perlindungan double-tap tidak hilang.
         * ====================================================================
         */
        if (idQuoteLama != null && idQuoteLama != q.id) {
          _idempotencyKey = null;
        }

      case Err<Quote>(failure: final ApiFailure f):
        _failure = f;
    }

    notifyListeners();
  }

  /// Buat order dari quote yang aktif.
  ///
  /// Mengembalikan order kalau berhasil, null kalau gagal — dan alasannya ada
  /// di [failure].
  Future<Order?> submit() async {
    final Quote? q = _quote;
    final ChosenPlace? jemput = _pickup;

    if (q == null || jemput == null || _serviceCode == null || _submitting) {
      return null;
    }

    /*
     * Quote yang sudah kadaluarsa DICEGAH DI SINI, sebelum request terkirim.
     *
     * Backend akan menolaknya juga, tapi penolakan itu muncul sebagai galat
     * tepat saat pengguna menekan tombol pesan — momen paling buruk untuk
     * menampilkan pesan galat. Memeriksanya lebih dulu membuat aplikasi bisa
     * meminta quote baru dan melanjutkan tanpa pengguna melihat kegagalan.
     */
    if (q.isExpired) {
      await loadQuote();

      final Quote? baru = _quote;

      if (baru == null || baru.isExpired) {
        _failure = const ApiFailure(
          code: 'QUOTE_EXPIRED',
          message: 'Harga sudah berubah. Silakan cek ulang.',
        );
        notifyListeners();

        return null;
      }
    }

    /*
     * Quote dan layanan dibaca ULANG di sini, SETELAH kemungkinan reload.
     *
     * Keduanya bisa berubah di `loadQuote()` di atas: id quote-nya baru, dan
     * layanan yang dipilih bisa bergeser kalau yang lama tidak lagi ada di
     * quote baru.
     *
     * Membacanya sekali di awal method lalu memakainya di sini berarti mengirim
     * `service_code` milik quote LAMA bersama `quote_id` yang BARU — dan backend
     * menolaknya, karena layanan itu tidak ada di quote yang dia baca dari
     * Redis.
     */
    final Quote quoteTerkirim = _quote!;
    final String layananTerkirim = _serviceCode!;

    _submitting = true;
    _failure = null;
    notifyListeners();

    // Dibuat SEKALI. Percobaan berikutnya memakai yang sama — itu seluruh
    // gunanya. Lihat penjelasan di field-nya, dan aturan pembuangannya di
    // `loadQuote`.
    _idempotencyKey ??= const Uuid().v4();

    final Result<Order> hasil = await _orders.create(
      idempotencyKey: _idempotencyKey!,
      quoteId: quoteTerkirim.id,
      serviceCode: layananTerkirim,
      paymentMethod: _paymentMethod,
      pickupAddress: jemput.address,
      destinationAddress: _destination?.address,
      pickupNote: jemput.note,
      promoCode: _promoCode,
    );

    _submitting = false;

    switch (hasil) {
      case Ok<Order>(value: final Order order):
        // Kunci dibuang HANYA di sini: ordernya sudah ada, dan kunci yang sama
        // dipakai lagi akan memutar ulang response order ini alih-alih membuat
        // yang baru.
        _idempotencyKey = null;
        notifyListeners();

        return order;

      case Err<Order>(failure: final ApiFailure f):
        _failure = f;
        notifyListeners();

        return null;
    }
  }

  String? _layananPertamaYangBisaDipesan(Quote q) {
    for (final QuoteService s in q.services) {
      if (s.isOrderable) {
        return s.code;
      }
    }

    // Kalau tidak ada yang bisa dipesan, yang pertama tetap dipilih supaya
    // layar menampilkan harga dan alasan kenapa tidak tersedia — bukan layar
    // kosong tanpa keterangan.
    return q.services.isEmpty ? null : q.services.first.code;
  }
}
