import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'media_outcome.dart';

/// Dari mana fotonya diambil.
enum MediaSource {
  camera,
  gallery;

  bool get isCamera => this == MediaSource.camera;
}

/// Pengambil foto, beserta seluruh penanganan izinnya.
///
/// ============================================================================
///  UKURAN DIBATASI DI SINI, BUKAN DI BACKEND SAJA
/// ============================================================================
///  Kamera HP sekarang menghasilkan foto 12 megapixel, sekitar 4–6 MB. Driver
///  yang mengunggah tiga dokumen di jaringan seluler Medan akan menunggu
///  beberapa menit — dan unggahan yang gagal di tengah harus dimulai dari nol.
///
///  Jadi ukurannya diturunkan SEBELUM dikirim: sisi terpanjang 1600 piksel,
///  kualitas JPEG 85. Hasilnya sekitar 200–400 KB, dan tulisan di KTP maupun SIM
///  masih terbaca jelas pada ukuran itu — itu yang menentukan batasnya, bukan
///  angka yang enak dilihat.
///
///  Backend TETAP punya batasnya sendiri. Yang di sini untuk kenyamanan
///  pengguna; yang di sana untuk keamanan, dan keduanya tidak saling
///  menggantikan: aplikasi bisa dimodifikasi, backend tidak.
/// ============================================================================
///
/// ============================================================================
///  PENGUBAHAN UKURAN JUGA MENGHAPUS KOORDINAT GPS DARI FOTONYA
/// ============================================================================
///  Ini efek samping yang justru paling penting di sini, dan bukan kebetulan
///  yang dibiarkan — ia disebut supaya tidak ada yang membuang parameternya
///  nanti dengan alasan "kualitas".
///
///  Foto dari kamera HP membawa metadata EXIF, dan di dalamnya ada KOORDINAT
///  TEMPAT FOTO ITU DIAMBIL. Untuk foto dokumen, itu berarti alamat rumah driver
///  ikut terkirim dan tersimpan di server — data yang tidak pernah diminta, tidak
///  dipakai untuk apa pun, dan menjadi tanggung jawab kalau server ditembus.
///
///  `image_picker` MENGKODE ULANG gambarnya begitu `maxWidth`/`maxHeight` atau
///  `imageQuality` diberikan, dan pengkodean ulang itu membuang EXIF-nya. Tanpa
///  parameter itu, berkas aslinya dikirim apa adanya — beserta koordinatnya.
/// ============================================================================
class MediaPicker {
  const MediaPicker({ImagePicker? picker}) : _picker = picker;

  final ImagePicker? _picker;

  ImagePicker get _plugin => _picker ?? ImagePicker();

  /// Sisi terpanjang gambar setelah dikecilkan.
  static const double maxSisiPiksel = 1600;

  /// Kualitas JPEG setelah dikodekan ulang, 0..100.
  static const int kualitas = 85;

  /// Ambil satu foto.
  ///
  /// [namaDasar] menjadi awalan nama berkas yang dikirim ke backend, misalnya
  /// `ktp` atau `bukti`. Nama yang berarti membuat isi bucket bisa dibaca saat
  /// ada yang perlu diperiksa manual — `image_1730294857.jpg` tidak.
  Future<MediaOutcome> pick({
    required MediaSource source,
    String namaDasar = 'foto',
  }) async {
    final MediaOutcome? masalah = await _pastikanIzin(source);

    if (masalah != null) {
      return masalah;
    }

    try {
      final XFile? berkas = await _plugin.pickImage(
        source: source.isCamera ? ImageSource.camera : ImageSource.gallery,

        // Ketiganya bukan opsional. Lihat kedua docblock di atas: yang pertama
        // soal waktu unggah, yang kedua soal koordinat GPS di dalam fotonya.
        maxWidth: maxSisiPiksel,
        maxHeight: maxSisiPiksel,
        imageQuality: kualitas,

        // Kamera BELAKANG untuk semua pemakaian di aplikasi ini. Bawaan plugin
        // mengikuti kamera terakhir yang dipakai perangkat — jadi driver yang
        // sebelumnya ber-video call akan mendapati kamera depan saat memfoto KTP.
        preferredCameraDevice: CameraDevice.rear,
      );

      if (berkas == null) {
        return const MediaCancelled();
      }

      final Uint8List bytes = await berkas.readAsBytes();

      if (bytes.isEmpty) {
        return const MediaFailed('Fotonya kosong. Coba ambil ulang.');
      }

      return MediaPicked(
        bytes: bytes,
        fileName: _namaBerkas(namaDasar, berkas.name),

        /*
         * Tipe dari plugin dipakai kalau ada, dan `image/jpeg` sebagai
         * cadangannya.
         *
         * Bukan tebakan sembarangan: `imageQuality` di atas memaksa
         * `image_picker` mengkodekan ulang hasilnya sebagai JPEG, apa pun format
         * aslinya. Jadi cadangannya justru yang paling sering benar.
         */
        mimeType: berkas.mimeType ?? 'image/jpeg',
      );
    } catch (e) {
      /*
       * Yang bisa mendarat di sini: kamera sedang dipakai aplikasi lain,
       * penyimpanan penuh, atau `MissingPluginException` di platform tanpa
       * implementasi.
       *
       * Semuanya jadi satu pesan yang bisa dibaca pengguna. Pesan aslinya tidak
       * ditampilkan: `PlatformException(camera_access_denied, null, null, null)`
       * tidak memberi tahu apa pun kepada driver yang sedang di jalan.
       */
      return MediaFailed(
        'Tidak bisa membuka ${source.isCamera ? 'kamera' : 'galeri'}. '
        'Pastikan tidak ada aplikasi lain yang sedang memakainya, lalu coba '
        'lagi.',
      );
    }
  }

  /// Buka pengaturan aplikasi di sistem.
  ///
  /// Satu-satunya jalan keluar dari izin yang ditolak permanen. Dipanggil layar
  /// setelah menerima [MediaPermissionPermanentlyDenied].
  Future<bool> openSettings() => openAppSettings();

  // ---------------------------------------------------------------------------

  /// Pastikan izinnya ada, atau kembalikan alasan kegagalannya.
  ///
  /// ==========================================================================
  ///  GALERI DI ANDROID MODERN TIDAK MENUNTUT IZIN SAMA SEKALI
  /// ==========================================================================
  ///  Sejak Android 13, `image_picker` memakai Android Photo Picker — pemilih
  ///  milik SISTEM. Yang dipilih pengguna diserahkan ke aplikasi satu per satu,
  ///  dan aplikasi tidak pernah melihat galerinya. Karena itu tidak ada izin
  ///  yang perlu diminta.
  ///
  ///  Meminta `Permission.photos` di sana justru merugikan: dialognya muncul,
  ///  pengguna bertanya-tanya kenapa aplikasi mau melihat SELURUH fotonya untuk
  ///  memilih satu, dan yang menolak akan terhalang dari fitur yang sebenarnya
  ///  tidak butuh izin itu.
  ///
  ///  Jadi galeri di Android dibiarkan langsung ke pemilih sistem. Izin
  ///  `READ_MEDIA_IMAGES` di manifest ada untuk perangkat lama dan untuk jalur
  ///  cadangan plugin — bukan untuk diminta di sini.
  ///
  ///  Kamera BERBEDA: begitu izin CAMERA dideklarasikan di manifest, Android
  ///  MENUNTUT-nya diberikan sebelum intent kamera bisa dipakai. Aplikasi yang
  ///  tidak mendeklarasikannya sama sekali justru tidak perlu memintanya — tapi
  ///  itu bukan pilihan di sini, karena izinnya memang dideklarasikan.
  /// ==========================================================================
  Future<MediaOutcome?> _pastikanIzin(MediaSource source) async {
    if (kIsWeb) {
      // Di web izinnya ditangani browser sendiri, lewat dialognya sendiri.
      // `permission_handler` tidak punya implementasi web, dan memanggilnya
      // melempar.
      return null;
    }

    if (!source.isCamera && defaultTargetPlatform == TargetPlatform.android) {
      return null;
    }

    final Permission izin = source.isCamera
        ? Permission.camera
        : Permission.photos;

    PermissionStatus status = await izin.status;

    if (status.isGranted || status.isLimited) {
      // `isLimited` hanya ada di iOS: pengguna memberi akses ke SEBAGIAN foto.
      // Itu cukup — yang dipilihnya nanti pasti termasuk yang dia izinkan.
      return null;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return MediaPermissionPermanentlyDenied(_pesanPermanen(source));
    }

    status = await izin.request();

    if (status.isGranted || status.isLimited) {
      return null;
    }

    if (status.isPermanentlyDenied) {
      return MediaPermissionPermanentlyDenied(_pesanPermanen(source));
    }

    return MediaPermissionDenied(
      source.isCamera
          ? 'Antaride perlu izin kamera untuk mengambil foto ini.'
          : 'Antaride perlu izin galeri untuk memilih foto ini.',
    );
  }

  /// Pesan untuk izin yang ditolak permanen.
  ///
  /// Menyebut LANGKAHNYA, bukan hanya keadaannya. "Izin ditolak" membuat
  /// pengguna menekan tombol yang sama lagi; menyebut di mana sakelarnya membuat
  /// dia bisa menyelesaikannya.
  static String _pesanPermanen(MediaSource source) {
    final String apa = source.isCamera ? 'Kamera' : 'Foto dan media';

    return 'Izin ${source.isCamera ? 'kamera' : 'galeri'} sudah ditolak, dan '
        'Android tidak akan menanyakannya lagi dari dalam aplikasi.\n\n'
        'Buka Pengaturan → Izin → $apa, lalu izinkan. Setelah itu kembali ke '
        'sini dan coba lagi.';
  }

  /// Nama berkas yang dikirim ke backend.
  ///
  /// Ekstensinya diambil dari nama asli kalau ada, dan `.jpg` sebagai cadangan —
  /// yang juga yang paling sering benar, karena `imageQuality` memaksa hasilnya
  /// dikodekan ulang sebagai JPEG.
  static String _namaBerkas(String namaDasar, String namaAsli) {
    final int titik = namaAsli.lastIndexOf('.');

    final String ekstensi = titik > 0 && titik < namaAsli.length - 1
        ? namaAsli.substring(titik + 1).toLowerCase()
        : 'jpg';

    /*
     * Nama dasarnya DIBERSIHKAN, walaupun asalnya dari kode kita sendiri.
     *
     * Nama berkas ikut ke header multipart, dan karakter seperti `"` atau baris
     * baru di sana bisa merusak batas bagiannya. Membersihkannya di satu tempat
     * jauh lebih murah daripada mengandalkan setiap pemanggil untuk berhati-hati
     * — terutama karena nanti akan ada pemanggil yang menyusun namanya dari
     * masukan pengguna.
     */
    final String aman = namaDasar.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_-]'),
      '_',
    );

    return '$aman.$ekstensi';
  }
}
