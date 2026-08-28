import 'package:flutter/material.dart';

import '../order/tracking_screen.dart';

/// Menerjemahkan `action` sebuah notifikasi menjadi navigasi di aplikasi
/// penumpang.
///
/// ============================================================================
///  PENERJEMAHNYA ADA DI APLIKASI, BUKAN DI PAKET NOTIFIKASI
/// ============================================================================
///  Backend mengirim tujuan dalam bentuk data — `{"screen": "order",
///  "order_uuid": "..."}` — bukan sebagai deep link atau nama route.
///
///  Alasannya: nama layar order di aplikasi penumpang dan driver berbeda, dan
///  keduanya bisa berubah. Kalau backend mengirim nama route, mengganti nama
///  layar akan membuat setiap notifikasi lama menunjuk ke layar yang tidak ada
///  lagi — dan yang menerimanya adalah pengguna yang belum memperbarui
///  aplikasinya, yang tidak bisa diperbaiki dari sisi mana pun.
/// ============================================================================
///
/// ============================================================================
///  `screen` YANG TIDAK DIKENALI TIDAK MELAKUKAN APA PUN
/// ============================================================================
///  Bukan melempar, dan bukan menampilkan pesan galat.
///
///  Yang menghasilkannya: backend menambah jenis notifikasi dengan tujuan baru,
///  lalu mengirimkannya ke aplikasi versi lama. Notifikasinya sendiri tetap
///  terbaca utuh — judul dan isinya datang dari backend — dan itu yang penting.
///  Pesan "layar tidak dikenali" hanya memberi tahu pengguna bahwa aplikasinya
///  ketinggalan, dengan cara yang terlihat seperti kerusakan.
/// ============================================================================
void bukaNotifikasi(BuildContext context, Map<String, dynamic> action) {
  final Object? layar = action['screen'];

  if (layar != 'order') {
    return;
  }

  final Object? uuid = action['order_uuid'];

  if (uuid is! String || uuid.isEmpty) {
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => TrackingScreen(orderUuid: uuid),
    ),
  );
}
