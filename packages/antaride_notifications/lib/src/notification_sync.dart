import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notification_controller.dart';

/// Menjaga angka lencana tetap mutakhir tanpa polling.
///
/// ============================================================================
///  MASALAHNYA: PUSH DITUNDA, JADI TIDAK ADA YANG MEMBERI TAHU
/// ============================================================================
///  Tanpa push notification, aplikasi tidak pernah diberi tahu ada notifikasi
///  baru. Angka lencananya hanya berubah kalau aplikasi MENANYAKANNYA.
///
///  Dua jalan yang salah, dan keduanya menggoda:
///
///    Timer berkala      sepuluh detik terasa responsif, dan berarti 8.640
///                       request per hari per pengguna untuk angka yang hampir
///                       selalu sama. Di jaringan seluler itu kuota dan baterai
///                       yang dibayar pengguna untuk kabar yang boleh terlambat.
///
///    Tidak sama sekali   angkanya benar sekali saat aplikasi dibuka lalu
///                       membeku. Pengguna yang membiarkan aplikasi terbuka di
///                       latar selama satu jam kembali ke lencana yang salah.
///
///  Yang dipakai: satu permintaan saat dipasang, dan satu lagi setiap kali
///  aplikasi KEMBALI KE DEPAN. Itu tepat momen ketika pengguna bisa melihat
///  lencananya — dan tidak ada satu pun request saat dia tidak melihat.
/// ============================================================================
///
/// ============================================================================
///  DIPASANG DI KERANGKA SETELAH MASUK — TIDAK LEBIH TINGGI, TIDAK LEBIH RENDAH
/// ============================================================================
///  Tidak lebih rendah: kalau observernya dipasang di beranda, dia berhenti
///  bekerja begitu pengguna membuka layar lain — dan lencananya berhenti
///  diperbarui tanpa gejala apa pun.
///
///  Tidak lebih tinggi: dipasang di ATAS gerbang sesi, widget ini akan meminta
///  jumlah notifikasi saat pengguna BELUM masuk. Request tanpa token dibalas
///  401, dan 401 di `ApiClient` memicu penanganan sesi berakhir — jadi lencana
///  notifikasi akan memaksa keluar dari sesi yang bahkan belum dimulai.
///
///  Jadi tempatnya persis satu: membungkus kerangka yang hidup selama sesi
///  masuk berlangsung.
/// ============================================================================
class NotificationSync extends StatefulWidget {
  const NotificationSync({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends State<NotificationSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Post-frame, bukan langsung: `context.read` di dalam `initState` berjalan
    // sebelum widget ini terpasang di tree, dan provider di atasnya belum bisa
    // ditemukan.
    WidgetsBinding.instance.addPostFrameCallback((_) => _segarkan());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _segarkan();
    }
  }

  void _segarkan() {
    if (!mounted) {
      return;
    }

    // Kegagalannya ditelan di dalam controller. Lencana yang gagal diperbarui
    // bukan hal yang perlu diberitahukan — angka lamanya tetap masuk akal, dan
    // pesan galat akan muncul di layar yang tidak sedang membicarakan notifikasi.
    context.read<NotificationController>().refreshBadge();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
