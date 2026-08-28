import 'dart:async';
import 'dart:convert';

import 'package:antaride_core/antaride_core.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_client.dart';

/// Klien Centrifugo lewat protokol JSON-nya.
///
/// ============================================================================
///  KENAPA WEBSOCKET MENTAH, BUKAN SDK centrifuge-dart
/// ============================================================================
///  Protokol JSON Centrifugo untuk kebutuhan kami hanya empat perintah:
///  connect, subscribe, unsubscribe, ping. Itu sekitar seratus baris.
///
///  SDK-nya membawa Protobuf, riwayat, presence, dan recovery — yang tidak
///  dipakai satu pun di Fase 1 — dan mengikat versi kami ke jadwal rilisnya.
///  Untuk komponen yang duduk di jalur paling kritis aplikasi driver, kode yang
///  bisa dibaca seluruhnya dalam satu duduk lebih berharga daripada fitur yang
///  tidak dipakai.
/// ============================================================================
///
/// ============================================================================
///  SAMBUNG ULANG MEMAKAI BACKOFF EKSPONENSIAL, DAN ITU WAJIB
/// ============================================================================
///  Tanpa backoff, seribu aplikasi driver yang terputus karena server
///  di-restart akan menyambung ulang serentak setiap detik — dan server yang
///  baru hidup langsung jatuh lagi. Itu bukan skenario hipotetis; itu yang
///  terjadi setiap kali deploy.
///
///  Jeda diacak (jitter) supaya seluruh aplikasi tidak menabrak pada detik yang
///  sama. Backoff tanpa jitter hanya memindahkan tabrakannya, tidak
///  menghilangkannya.
/// ============================================================================
class CentrifugoClient implements RealtimeClient {
  CentrifugoClient({String? url}) : _url = url ?? AppConfig.realtimeUrl;

  final String _url;

  final ValueStream<RealtimeState> _state = ValueStream<RealtimeState>(
    RealtimeState.disconnected,
  );

  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _listener;
  Timer? _reconnect;
  Timer? _ping;

  String? _token;
  int _commandId = 0;
  int _attempt = 0;
  bool _dibuang = false;

  /// Kanal yang dilangganani, beserta jumlah pelanggannya.
  ///
  /// Menghitung referensinya, bukan hanya menyimpan namanya: dua widget di satu
  /// layar bisa berlangganan kanal order yang sama, dan yang pertama dibuang
  /// tidak boleh mencabut langganan yang masih dipakai yang kedua.
  final Map<String, int> _langganan = <String, int>{};

  @override
  ValueStream<RealtimeState> get state => _state;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  // ---------------------------------------------------------------------------

  @override
  Future<void> connect({required String token}) async {
    _token = token;
    _attempt = 0;

    await _buka();
  }

  Future<void> _buka() async {
    if (_dibuang || _token == null) {
      return;
    }

    _reconnect?.cancel();

    _state.emit(
      _attempt == 0 ? RealtimeState.connecting : RealtimeState.reconnecting,
    );

    try {
      final WebSocketChannel channel = WebSocketChannel.connect(
        Uri.parse(_url),
      );

      _channel = channel;

      _listener = channel.stream.listen(
        _terima,
        onError: (Object _) => _tanganiPutus(),
        onDone: _tanganiPutus,
        cancelOnError: true,
      );

      _kirim(<String, dynamic>{
        'connect': <String, dynamic>{'token': _token},
      });
    } catch (_) {
      _tanganiPutus();
    }
  }

  @override
  Future<void> subscribe(String channel) async {
    final int sebelum = _langganan[channel] ?? 0;

    _langganan[channel] = sebelum + 1;

    // Hanya pelanggan PERTAMA yang mengirim perintah ke server. Yang kedua dan
    // seterusnya cukup menaikkan hitungannya.
    if (sebelum == 0 && _state.value == RealtimeState.connected) {
      _kirim(<String, dynamic>{
        'subscribe': <String, dynamic>{'channel': channel},
      });
    }
  }

  @override
  Future<void> unsubscribe(String channel) async {
    final int sebelum = _langganan[channel] ?? 0;

    if (sebelum <= 1) {
      _langganan.remove(channel);

      if (_state.value == RealtimeState.connected) {
        _kirim(<String, dynamic>{
          'unsubscribe': <String, dynamic>{'channel': channel},
        });
      }

      return;
    }

    _langganan[channel] = sebelum - 1;
  }

  @override
  Future<void> disconnect() async {
    _reconnect?.cancel();
    _ping?.cancel();

    await _listener?.cancel();
    _listener = null;

    await _channel?.sink.close();
    _channel = null;

    _langganan.clear();
    _state.emit(RealtimeState.disconnected);
  }

  @override
  void dispose() {
    _dibuang = true;

    _reconnect?.cancel();
    _ping?.cancel();
    _listener?.cancel();
    _channel?.sink.close();

    _state.close();
    _events.close();
  }

  // ---------------------------------------------------------------------------

  void _kirim(Map<String, dynamic> perintah) {
    final WebSocketChannel? channel = _channel;

    if (channel == null) {
      return;
    }

    _commandId++;

    try {
      channel.sink.add(
        jsonEncode(<String, dynamic>{'id': _commandId, ...perintah}),
      );
    } catch (_) {
      _tanganiPutus();
    }
  }

  void _terima(dynamic pesan) {
    if (pesan is! String || pesan.isEmpty) {
      return;
    }

    /*
     * Centrifugo bisa mengirim BEBERAPA balasan dalam satu frame, dipisahkan
     * newline. Membaca frame-nya sebagai satu objek JSON akan gagal — dan
     * gagalnya senyap, karena try/catch di bawah menelannya.
     *
     * Gejalanya kalau ini salah: peristiwa yang datang berdempetan hilang
     * seluruhnya, dan itu justru terjadi pada saat paling sibuk — ketika
     * beberapa pembaruan status datang berbarengan.
     */
    for (final String baris in pesan.split('\n')) {
      if (baris.trim().isEmpty) {
        continue;
      }

      try {
        final dynamic diurai = jsonDecode(baris);

        if (diurai is Map<String, dynamic>) {
          _tangani(diurai);
        }
      } catch (_) {
        // Satu baris yang rusak tidak boleh menjatuhkan koneksi. Baris
        // berikutnya di frame yang sama masih bisa sah.
      }
    }
  }

  void _tangani(Map<String, dynamic> balasan) {
    // Balasan connect. Setelah ini langganan yang tertunda dikirim ulang.
    if (balasan.containsKey('connect')) {
      _attempt = 0;
      _state.emit(RealtimeState.connected);

      for (final String channel in _langganan.keys) {
        _kirim(<String, dynamic>{
          'subscribe': <String, dynamic>{'channel': channel},
        });
      }

      _mulaiPing();

      return;
    }

    // Ping dari server. Balas dengan objek kosong; Centrifugo menutup koneksi
    // yang tidak menjawab.
    if (balasan.isEmpty || balasan.containsKey('ping')) {
      _channel?.sink.add('{}');

      return;
    }

    final Map<String, dynamic>? push = balasan['push'] as Map<String, dynamic>?;

    if (push == null) {
      return;
    }

    final String channel = push['channel'] as String? ?? '';

    final Map<String, dynamic>? publikasi =
        push['pub'] as Map<String, dynamic>?;

    if (publikasi == null) {
      return;
    }

    final Map<String, dynamic> data =
        (publikasi['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    if (_events.isClosed) {
      return;
    }

    _events.add(
      RealtimeEvent(
        channel: channel,

        // Nama peristiwa ada DI DALAM payload, bukan di bingkai Centrifugo.
        // Centrifugo hanya mengangkut; bentuk isinya ditentukan backend.
        name: data['event'] as String? ?? 'unknown',
        payload: (data['data'] as Map<String, dynamic>?) ?? data,
      ),
    );
  }

  void _mulaiPing() {
    _ping?.cancel();

    // 25 detik: di bawah batas timeout bawaan Centrifugo (30 detik), dan cukup
    // jarang untuk tidak membebani baterai. Ini juga yang menahan proxy
    // operator menutup koneksi yang dianggapnya menganggur.
    _ping = Timer.periodic(const Duration(seconds: 25), (Timer _) {
      _channel?.sink.add('{}');
    });
  }

  void _tanganiPutus() {
    if (_dibuang) {
      return;
    }

    _ping?.cancel();
    _listener?.cancel();
    _listener = null;
    _channel = null;

    _attempt++;

    /*
     * Berhenti mencoba setelah 8 percobaan — sekitar dua menit.
     *
     * Bukan menyerah diam-diam: keadaannya menjadi `failed`, dan layar beralih
     * ke penarikan berkala lewat REST. Percobaan tanpa batas akan menghabiskan
     * baterai driver yang HP-nya berada di area tanpa sinyal sepanjang hari.
     */
    if (_attempt > 8) {
      _state.emit(RealtimeState.failed);

      return;
    }

    _state.emit(RealtimeState.reconnecting);

    final Duration jeda = _backoff(_attempt);

    if (kDebugMode) {
      debugPrint(
        'Realtime terputus. Percobaan $_attempt dalam ${jeda.inMilliseconds}ms.',
      );
    }

    _reconnect?.cancel();
    _reconnect = Timer(jeda, _buka);
  }

  /// Jeda sebelum percobaan berikutnya: 1s, 2s, 4s, ... maksimum 30s, ditambah
  /// jitter sampai 40%.
  ///
  /// Jitter-nya diturunkan dari [_commandId] dan nomor percobaan, BUKAN dari
  /// `Random()`. Alasannya cukup praktis: hasilnya bisa diprediksi dalam
  /// pengujian, dan tetap berbeda antar perangkat karena jumlah perintah yang
  /// sudah dikirim setiap aplikasi berbeda.
  Duration _backoff(int percobaan) {
    final int dasarMs = 1000 * (1 << (percobaan - 1).clamp(0, 5));
    final int dibatasi = dasarMs > 30000 ? 30000 : dasarMs;
    final int jitter =
        ((_commandId * 37 + percobaan * 101) % 41) * dibatasi ~/ 100;

    return Duration(milliseconds: dibatasi + jitter);
  }
}
