/// Konfigurasi aplikasi, dibaca dari `--dart-define`.
///
/// ============================================================================
///  KENAPA dart-define, BUKAN FILE .env
/// ============================================================================
///  Paket seperti `flutter_dotenv` membaca file `.env` sebagai ASSET. Artinya
///  file itu ikut dipaketkan ke dalam APK, dan siapa pun yang mengekstrak APK-nya
///  bisa membacanya — termasuk kunci apa pun yang ada di dalamnya.
///
///  `--dart-define` dikompilasi menjadi konstanta. Masih bisa ditemukan dengan
///  membongkar binary-nya, tapi tidak lagi berupa file teks yang bisa dibuka.
///
///  Yang lebih penting: nilai dart-define bisa BERBEDA per build tanpa mengubah
///  satu baris kode, dan itu yang membuat satu basis kode bisa menghasilkan build
///  staging dan produksi dari perintah yang sama.
///
///  Aturan yang tetap berlaku: TIDAK ADA RAHASIA di sini. Aplikasi mobile tidak
///  bisa menyimpan rahasia — apa pun yang ada di dalamnya bisa dibaca pemilik
///  perangkatnya. Yang ada di sini hanya alamat dan pengaturan, bukan kunci.
/// ============================================================================
class AppConfig {
  const AppConfig._();

  /// Alamat dasar API.
  ///
  /// Bawaannya `127.0.0.1`, BUKAN `localhost`, dan itu bukan sekadar selera.
  ///
  /// Di Windows, `localhost` bisa di-resolve ke `::1` (IPv6) sementara backend
  /// Laravel mendengarkan di `127.0.0.1` (IPv4). Akibatnya: aplikasi web Flutter
  /// jalan, halamannya terbuka, dan SETIAP request API gagal dengan connection
  /// refused — tanpa satu pun petunjuk di layar bahwa penyebabnya adalah
  /// resolusi nama.
  ///
  /// Memakai 127.0.0.1 di kedua sisi menghilangkan seluruh kelas masalah itu.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  /// Alamat gateway realtime Centrifugo.
  static const String realtimeUrl = String.fromEnvironment(
    'REALTIME_URL',
    defaultValue: 'ws://127.0.0.1:8100/connection/websocket',
  );

  /// Nama environment: local, staging, atau production.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'local',
  );

  static bool get isProduction => environment == 'production';

  static bool get isLocal => environment == 'local';

  /// Token publik Mapbox untuk tile peta.
  ///
  /// ==========================================================================
  ///  KENAPA MAPBOX, BUKAN TILE OSM LANGSUNG
  /// ==========================================================================
  ///  `tile.openstreetmap.org` gratis tapi melarang pemakaian massal, dan
  ///  pelanggarnya diblokir PER IP — yang berarti peta kosong untuk semua
  ///  pengguna di jaringan operator yang sama, bukan hanya untuk satu perangkat.
  ///
  ///  Routing dan perhitungan jarak TETAP memakai OSRM di atas data OSM. Jadi
  ///  yang berubah hanya sumber GAMBAR petanya; rute yang digambar tetap rute
  ///  yang sama dengan yang dipakai menghitung ongkos.
  /// ==========================================================================
  ///
  /// ==========================================================================
  ///  TOKEN `pk.*` MEMANG BOLEH ADA DI APLIKASI, TAPI ADA SYARATNYA
  /// ==========================================================================
  ///  Token berawalan `pk.` adalah token PUBLIK — Mapbox merancangnya untuk
  ///  disematkan di klien, dan tidak ada cara menyembunyikannya di aplikasi
  ///  mobile: siapa pun yang membongkar APK bisa membacanya.
  ///
  ///  Yang menggantikan kerahasiaan adalah PEMBATASAN, dan itu disetel di dasbor
  ///  Mapbox, bukan di sini:
  ///
  ///    * Batasi token ke URL aplikasi web (`URL restrictions`). Ini tidak
  ///      berlaku untuk build mobile — Mapbox memang tidak menyediakannya.
  ///    * Beri token ini scope MINIMAL: hanya `styles:tiles` dan `styles:read`.
  ///      Token dengan scope tulis di aplikasi berarti siapa pun yang
  ///      membacanya bisa mengubah style peta Anda.
  ///    * Pantau pemakaiannya. Lonjakan yang tidak wajar adalah satu-satunya
  ///      tanda token dipakai orang lain.
  ///
  ///  Bawaannya diisi supaya peta langsung tampil tanpa konfigurasi. Untuk
  ///  produksi, kirim lewat `--dart-define=MAPBOX_TOKEN=pk...` supaya bisa
  ///  diganti tanpa menyentuh kode.
  /// ==========================================================================
  static const String mapboxToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue:
        'pk.eyJ1IjoiYmVvdWx2ZSIsImEiOiJjbXB6NmxzZnMwZmF1MnJuM2JlNzBwNDUyIn0'
        '.ojgWbRaGetdsDviPRN8FRg',
  );

  /// Style Mapbox yang dipakai.
  ///
  /// `streets-v12` dipilih, bukan `navigation-day-v1`: style navigasi menonjolkan
  /// jalan besar dan menyamarkan nama gang. Di Medan, titik jemput justru sering
  /// berada di gang — dan nama gang itu yang dipakai penumpang menerangkan
  /// posisinya kepada driver.
  static const String mapboxStyle = String.fromEnvironment(
    'MAPBOX_STYLE',
    defaultValue: 'mapbox/streets-v12',
  );

  static bool get hasMapboxToken => mapboxToken.startsWith('pk.');

  /// Batas waktu request, dalam detik.
  ///
  /// 20 detik, bukan 30 atau 60. Alasannya: aplikasi ride-hailing dipakai
  /// sambil menunggu, dan request yang menggantung 60 detik terbaca sebagai
  /// aplikasi yang mati — orangnya akan menutup dan membuka ulang, yang
  /// menghasilkan request kedua dan memperburuk keadaan.
  ///
  /// Lebih baik gagal cepat dengan pesan yang jelas dan tombol coba lagi.
  static const int timeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: 20,
  );

  /// Tampilkan alat bantu pengembangan.
  ///
  /// Terikat ke environment, BUKAN ke flag tersendiri. Flag terpisah bisa lupa
  /// dimatikan saat build produksi, dan konsekuensinya adalah alat debug yang
  /// bisa dibuka pengguna sungguhan.
  static bool get showDevTools => !isProduction;
}
