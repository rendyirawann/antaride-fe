import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:flutter/foundation.dart';

/// State notifikasi untuk satu aplikasi.
///
/// ============================================================================
///  SATU CONTROLLER UNTUK LENCANA DAN UNTUK DAFTARNYA
/// ============================================================================
///  Lencana angka di ikon lonceng dan daftar notifikasi menampilkan hal yang
///  sama dari dua tempat berbeda di layar. Kalau keduanya punya state sendiri,
///  yang terjadi: pengguna membuka daftar, membaca semuanya, kembali ke
///  beranda — dan lencananya masih menunjukkan angka lama.
///
///  Itu terbaca sebagai ada notifikasi baru yang tidak bisa ditemukan, dan
///  pengguna akan membuka daftarnya lagi untuk mencari sesuatu yang tidak ada.
///
///  Jadi controller ini hidup di atas kedua-duanya — dipasang sekali di root
///  aplikasi, bukan di dalam layar notifikasinya. Membuang controller saat layar
///  ditutup berarti membuang juga angka lencananya.
/// ============================================================================
///
/// ============================================================================
///  TIDAK ADA POLLING BERKALA DI SINI, DAN ITU DISENGAJA
/// ============================================================================
///  Push notification ditunda, jadi satu-satunya cara angka ini berubah adalah
///  aplikasi menanyakannya. Yang menggoda: timer setiap sepuluh detik.
///
///  Yang menahannya: notifikasi di sini semuanya boleh terlambat dibaca — order
///  diterima, driver tiba, perjalanan selesai. Tidak ada satu pun yang kedaluwarsa
///  dalam hitungan detik (tawaran order, yang memang begitu, sengaja TIDAK lewat
///  sini). Timer sepuluh detik berarti 8.640 request per hari per pengguna untuk
///  angka yang biasanya tidak berubah — dan di jaringan seluler Indonesia itu
///  kuota dan baterai yang dibayar pengguna.
///
///  Yang dipakai sebagai gantinya: [refreshBadge] dipanggil pada peristiwa yang
///  memang berarti — aplikasi kembali ke depan, dan setelah transisi status order.
/// ============================================================================
class NotificationController extends ChangeNotifier {
  NotificationController(this._repository);

  final NotificationRepository _repository;

  final List<AppNotification> _items = <AppNotification>[];

  int _unreadCount = 0;
  String? _cursor;
  bool _adaLagi = true;
  bool _memuat = false;
  bool _pernahDimuat = false;
  ApiFailure? _galat;

  /// Notifikasi yang sudah dimuat, terbaru di atas.
  List<AppNotification> get items => List<AppNotification>.unmodifiable(_items);

  /// Angka untuk lencana di ikon lonceng.
  int get unreadCount => _unreadCount;

  bool get isLoading => _memuat;

  /// True setelah percobaan pemuatan pertama selesai — berhasil maupun gagal.
  ///
  /// Dipakai layar untuk membedakan "belum pernah dimuat" (tampilkan skeleton)
  /// dari "sudah dimuat dan memang kosong" (tampilkan empty state). Tanpa
  /// pembeda ini, daftar kosong saat pemuatan pertama akan menampilkan "belum
  /// ada notifikasi" sekejap sebelum datanya datang.
  bool get sudahDimuat => _pernahDimuat;

  bool get adaLagi => _adaLagi;

  ApiFailure? get galat => _galat;

  bool get kosong => _items.isEmpty;

  /// Ambil halaman pertama, atau muat ulang dari awal.
  Future<void> muatUlang() => _muat(dariAwal: true);

  /// Ambil halaman berikutnya.
  Future<void> muatLagi() => _muat(dariAwal: false);

  Future<void> _muat({required bool dariAwal}) async {
    if (_memuat) {
      return;
    }

    if (!dariAwal && (!_adaLagi || _cursor == null)) {
      return;
    }

    _memuat = true;
    _galat = null;
    notifyListeners();

    final Result<NotificationPage> hasil = await _repository.list(
      cursor: dariAwal ? null : _cursor,
    );

    _memuat = false;
    _pernahDimuat = true;

    switch (hasil) {
      case Ok<NotificationPage>(value: final NotificationPage halaman):
        if (dariAwal) {
          _items.clear();
        }

        _items.addAll(halaman.notifications);
        _cursor = halaman.nextCursor;
        _adaLagi = halaman.hasMore && halaman.nextCursor != null;

        // Lencananya ikut diperbarui dari response yang SAMA — tanpa request
        // kedua. Itu sebabnya `unread_count` ada di setiap halaman.
        _unreadCount = halaman.unreadCount;

      case Err<NotificationPage>(failure: final ApiFailure f):
        _galat = f;
    }

    notifyListeners();
  }

  /// Perbarui angka lencana saja, tanpa memuat daftarnya.
  ///
  /// Dipanggil saat aplikasi kembali ke depan dan setelah transisi status order.
  /// Sengaja TIDAK memuat daftarnya: yang terlihat di beranda hanya angkanya,
  /// dan memuat dua puluh baris notifikasi untuk menampilkan satu angka adalah
  /// data yang dibayar pengguna tanpa dia lihat.
  ///
  /// Kegagalan diabaikan tanpa suara. Angka lencana yang gagal diperbarui bukan
  /// hal yang perlu ditampilkan sebagai galat — yang lama tetap masuk akal, dan
  /// pesan galat untuk lencana akan muncul di layar yang tidak ada kaitannya
  /// dengan notifikasi.
  Future<void> refreshBadge() async {
    final Result<int> hasil = await _repository.unreadCount();

    if (hasil case Ok<int>(value: final int jumlah)) {
      if (jumlah != _unreadCount) {
        _unreadCount = jumlah;
        notifyListeners();
      }
    }
  }

  /// Tandai satu notifikasi sudah dibaca.
  ///
  /// ==========================================================================
  ///  DITANDAI DI LAYAR DULU, LALU DIKIRIM — DAN DIKEMBALIKAN KALAU GAGAL
  /// ==========================================================================
  ///  Pengguna menekan notifikasi dan langsung berpindah ke layar order. Kalau
  ///  penandaannya menunggu balasan server, notifikasi itu masih terlihat belum
  ///  dibaca selama satu detik penuh setelah dia menekannya — dan sebagian
  ///  pengguna akan menekannya dua kali.
  ///
  ///  Jadi tampilannya diubah lebih dulu. Kalau requestnya gagal, keadaannya
  ///  DIKEMBALIKAN — bukan dibiarkan, karena notifikasi yang terlihat sudah
  ///  dibaca padahal server tidak mencatatnya akan muncul lagi sebagai belum
  ///  dibaca pada pemuatan berikutnya, dan angka lencana akan naik sendiri tanpa
  ///  notifikasi baru.
  /// ==========================================================================
  Future<void> tandaiDibaca(String uuid) async {
    final int posisi = _items.indexWhere((AppNotification n) => n.uuid == uuid);

    if (posisi < 0) {
      return;
    }

    final AppNotification sebelum = _items[posisi];

    if (sebelum.isRead) {
      return;
    }

    _items[posisi] = sebelum.copyWith(isRead: true, readAt: DateTime.now());

    // Tidak pernah di bawah nol. Bisa sudah nol di sini kalau lencananya
    // diperbarui lebih dulu dari perangkat lain, dan lencana bernilai -1 akan
    // tampil sebagai teks "-1" di ikon loncengnya.
    //
    // Dicatat apakah pengurangannya benar-benar terjadi, karena pengembalian di
    // bawah harus mengembalikan PERSIS apa yang diubah. Menambah satu tanpa
    // syarat akan menaikkan lencana dari 0 ke 1 untuk request yang gagal — dan
    // pengguna akan mencari notifikasi baru yang tidak ada.
    final bool dikurangi = _unreadCount > 0;

    if (dikurangi) {
      _unreadCount -= 1;
    }

    notifyListeners();

    final Result<int> hasil = await _repository.markRead(uuid);

    switch (hasil) {
      case Ok<int>(value: final int sisa):
        // Angka dari server yang menang, bukan hasil pengurangan lokal. Keduanya
        // biasanya sama; kalau berbeda, yang benar adalah server — misalnya
        // karena notifikasi yang sama sudah dibaca dari perangkat lain.
        if (sisa != _unreadCount) {
          _unreadCount = sisa;
          notifyListeners();
        }

      case Err<int>():
        _items[posisi] = sebelum;

        if (dikurangi) {
          _unreadCount += 1;
        }

        notifyListeners();
    }
  }

  /// Tandai semua sudah dibaca.
  ///
  /// Sama seperti [tandaiDibaca]: diubah di layar dulu, dikembalikan kalau gagal.
  /// Yang dikembalikan di sini seluruh daftarnya, jadi salinannya disimpan
  /// sebelum diubah.
  Future<bool> tandaiSemuaDibaca() async {
    if (_unreadCount == 0 && _items.every((AppNotification n) => n.isRead)) {
      return true;
    }

    final List<AppNotification> sebelum = List<AppNotification>.of(_items);
    final int jumlahSebelum = _unreadCount;
    final DateTime sekarang = DateTime.now();

    for (int i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true, readAt: sekarang);
      }
    }

    _unreadCount = 0;
    notifyListeners();

    final Result<int> hasil = await _repository.markAllRead();

    switch (hasil) {
      case Ok<int>(value: final int sisa):
        // Bisa bukan nol: notifikasi baru yang masuk di antara request dikirim
        // dan balasannya datang belum ikut ditandai.
        if (sisa != 0) {
          _unreadCount = sisa;
          notifyListeners();
        }

        return true;

      case Err<int>():
        _items
          ..clear()
          ..addAll(sebelum);

        _unreadCount = jumlahSebelum;
        notifyListeners();

        return false;
    }
  }
}
