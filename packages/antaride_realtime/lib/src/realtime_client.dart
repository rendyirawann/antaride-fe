import 'dart:async';

/// Peristiwa yang datang dari server realtime.
class RealtimeEvent {
  const RealtimeEvent({
    required this.channel,
    required this.name,
    required this.payload,
  });

  /// Kanal asalnya, misalnya `order:9f1c...`.
  final String channel;

  /// Nama peristiwa, misalnya `order.status_changed`.
  final String name;

  final Map<String, dynamic> payload;

  @override
  String toString() => 'RealtimeEvent($channel/$name)';
}

/// Keadaan koneksi.
enum RealtimeState {
  disconnected,
  connecting,
  connected,

  /// Terputus dan sedang mencoba tersambung lagi.
  ///
  /// Dibedakan dari [connecting] karena tampilannya berbeda: yang ini
  /// menampilkan pita "menyambungkan ulang" di layar pelacakan, sementara
  /// [connecting] pertama tidak perlu menampilkan apa pun.
  reconnecting,

  /// Tidak akan mencoba lagi.
  ///
  /// Layar BERALIH ke penarikan berkala lewat REST. Yang tidak boleh terjadi:
  /// layar pelacakan yang berhenti diperbarui tanpa memberi tahu apa pun —
  /// penumpang menatap posisi driver yang membeku dan menyimpulkan drivernya
  /// berhenti di jalan.
  failed,
}

/// Antarmuka klien realtime.
///
/// ============================================================================
///  KENAPA ABSTRAKSI, BUKAN LANGSUNG WEBSOCKET
/// ============================================================================
///  Centrifugo BELUM terpasang di lingkungan pengembangan sekarang. Kalau layar
///  memanggil WebSocket langsung, seluruh aplikasi tidak bisa dijalankan sampai
///  server itu ada — dan pengembangan layar berhenti karena satu komponen
///  infrastruktur.
///
///  Dengan antarmuka ini, aplikasi menyuntikkan implementasi yang tersedia:
///  [CentrifugoClient] kalau servernya hidup, atau [NullRealtimeClient] kalau
///  belum. Layar tidak berubah satu baris pun di antara keduanya.
///
///  Yang PENTING dan bukan kebetulan: layar harus tetap benar walaupun tidak ada
///  peristiwa yang datang sama sekali. Realtime mempercepat pembaruan, dia bukan
///  satu-satunya sumbernya — REST tetap jadi kebenaran, dan layar pelacakan
///  tetap menarik ulang secara berkala. Aplikasi yang menggantungkan seluruh
///  pembaruannya pada WebSocket akan membeku bagi setiap pengguna yang jaringan
///  operatornya memblokir koneksi panjang, dan itu bukan kasus yang jarang.
/// ============================================================================
abstract interface class RealtimeClient {
  /// Keadaan koneksi, untuk pita status di layar.
  ValueStream<RealtimeState> get state;

  /// Seluruh peristiwa dari kanal yang sedang dilangganani.
  Stream<RealtimeEvent> get events;

  /// Sambungkan dengan token dari backend.
  Future<void> connect({required String token});

  /// Berlangganan satu kanal.
  ///
  /// Aman dipanggil berulang untuk kanal yang sama — implementasi menghitung
  /// referensinya. Itu perlu karena dua widget di satu layar bisa berlangganan
  /// kanal order yang sama, dan yang satu dibuang lebih dulu.
  Future<void> subscribe(String channel);

  Future<void> unsubscribe(String channel);

  Future<void> disconnect();

  void dispose();
}

/// Stream yang menyimpan nilai terakhirnya.
///
/// Ada karena widget yang baru dibangun perlu tahu keadaan koneksi SEKARANG,
/// bukan menunggu perubahan berikutnya. `StreamBuilder` tanpa nilai awal akan
/// menampilkan keadaan kosong sampai ada peristiwa — dan kalau koneksinya
/// stabil, peristiwa itu tidak akan datang.
class ValueStream<T> {
  ValueStream(T awal) : _nilai = awal;

  final StreamController<T> _controller = StreamController<T>.broadcast();

  T _nilai;

  T get value => _nilai;

  Stream<T> get stream => _controller.stream;

  void emit(T nilai) {
    if (_nilai == nilai) {
      return;
    }

    _nilai = nilai;

    if (!_controller.isClosed) {
      _controller.add(nilai);
    }
  }

  Future<void> close() => _controller.close();
}

/// Klien yang tidak menyambung ke mana pun.
///
/// ============================================================================
///  BUKAN STUB UNTUK PENGUJIAN — INI JALUR PRODUKSI SEMENTARA
/// ============================================================================
///  Dipakai selama Centrifugo belum terpasang, dan juga sebagai jalur cadangan
///  di web kalau koneksi WebSocket-nya diblokir proxy.
///
///  Keadaannya langsung [RealtimeState.failed], BUKAN `connected`. Itu yang
///  membuat layar tahu harus menarik ulang lewat REST — kalau dia melaporkan
///  `connected`, layar akan menunggu peristiwa yang tidak akan pernah datang,
///  dan gejalanya adalah layar pelacakan yang membeku tanpa keterangan apa pun.
/// ============================================================================
class NullRealtimeClient implements RealtimeClient {
  NullRealtimeClient();

  final ValueStream<RealtimeState> _state = ValueStream<RealtimeState>(
    RealtimeState.failed,
  );

  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();

  @override
  ValueStream<RealtimeState> get state => _state;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Future<void> connect({required String token}) async {}

  @override
  Future<void> subscribe(String channel) async {}

  @override
  Future<void> unsubscribe(String channel) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    _state.close();
    _events.close();
  }
}
