# Antaride — Aplikasi Mobile

Monorepo Flutter untuk tiga aplikasi Antaride: **penumpang**, **driver**, dan
**merchant**. Satu repo, satu resolusi dependensi, tiga binary.

Backend ada di `../antaride-be`.

---

## Isi repo

```
antaride-fe/
├── pubspec.yaml              # akar pub workspace + konfigurasi melos
├── test_fixtures/            # response API sungguhan, dihasilkan backend
├── .vscode/launch.json       # profil run untuk Chrome/Brave di 127.0.0.1
│
├── apps/
│   ├── customer/             # aplikasi penumpang
│   ├── driver/               # aplikasi driver
│   └── merchant/             # aplikasi merchant
│
└── packages/
    ├── antaride_core/        # config, Money, Result, ApiFailure — tanpa Flutter
    ├── antaride_ui/          # design system claymorphism
    ├── antaride_api/         # client HTTP, model, repository
    ├── antaride_auth/        # SessionController + wadah dependency
    ├── antaride_realtime/    # klien Centrifugo
    ├── antaride_maps/        # peta Mapbox/OSM, lokasi, polyline
    ├── antaride_notifications/  # notifikasi in-app (penumpang + driver)
    └── antaride_media/       # kamera, galeri, dan izin perangkat
```

`antaride_notifications` adalah paket **fitur**, bukan design system. Dia tahu
soal API — dia memanggil repository — jadi tempatnya bukan di `antaride_ui`,
yang sengaja tidak tahu apa pun soal bentuk response backend.

Isinya dipakai dua aplikasi tanpa satu pun percabangan di dalamnya. Yang berbeda
antar aplikasi disuntikkan dari luar: notifikasi siapa yang dibaca ditentukan
`AntarideServices.build(notificationRole: ...)`, dan tujuan saat notifikasi
ditekan lewat callback `onOpenAction`. Layar order di aplikasi penumpang dan
driver memang berbeda, dan paket ini tidak boleh tahu nama keduanya.

### Kenapa tiga aplikasi, bukan satu dengan peran

Penumpang, driver, dan merchant memakai aplikasi berbeda di HP mereka — sama
seperti Gojek dan GoPartner. Alasannya bukan preferensi:

| | |
|---|---|
| **Ukuran** | Driver butuh peta, GPS latar belakang, dan foreground service. Penumpang tidak. Menyatukannya berarti penumpang mengunduh puluhan megabyte untuk kode yang tidak pernah dia jalankan. |
| **Izin** | Izin lokasi latar belakang wajib dijelaskan ke Play Store, dan aplikasi penumpang yang memintanya akan ditolak review. |
| **Siklus rilis** | Driver butuh pembaruan lebih sering. Satu aplikasi berarti setiap perbaikan kecil di sisi driver memaksa seluruh penumpang memperbarui. |

Yang **dibagi** adalah `packages/` — tema, lapisan API, model, dan sesi. Yang
**tidak** dibagi adalah layar, karena memang tidak ada layar yang sama.

---

## Menjalankan

Prasyarat: Flutter 3.44+, dan backend Laravel hidup di `127.0.0.1:8000`.

```bash
flutter pub get          # sekali di akar — workspace resolve semuanya
```

### Web (pengembangan sehari-hari)

```bash
dart pub global activate melos      # sekali saja
melos run run:customer              # 127.0.0.1:5001
melos run run:driver                # 127.0.0.1:5002
melos run run:merchant              # 127.0.0.1:5003
```

Kalau `melos` tidak dikenali setelah `activate`, direktori binary pub belum ada
di PATH — pub memperingatkannya saat instalasi lalu melanjutkan. Jalan pintasnya
tanpa mengubah PATH:

```bash
dart pub global run melos:melos run run:customer
```

Untuk menjalankan ketiganya sekaligus, pakai tiga terminal — atau lewat **VS
Code**: pilih profil di panel Run, sudah ada varian **Chrome** dan **Brave**
untuk masing-masing aplikasi.

Konfigurasi melos ada di `pubspec.yaml` di bawah kunci `melos:`, bukan di
`melos.yaml`. Melos 8 mengabaikan `melos.yaml` untuk proyek yang memakai pub
workspace, dan kegagalannya menyesatkan: `melos run test` berbunyi *"workspace
has no scripts defined"* padahal berkasnya ada dan isinya benar.

**`127.0.0.1`, bukan `localhost`.** Di Windows, `localhost` bisa di-resolve ke
`::1` (IPv6) sementara Laravel mendengarkan di `127.0.0.1` (IPv4). Akibatnya:
halaman terbuka normal dan **setiap** request API gagal dengan connection
refused, tanpa satu pun petunjuk di layar bahwa penyebabnya resolusi nama.

**Port berbeda per aplikasi juga bukan kerapian.** `flutter_secure_storage` di
web memakai `localStorage`, yang terikat ke *origin* — dan origin ditentukan
port. Kalau ketiganya di port yang sama, token driver menimpa token penumpang.
Dengan port tetap, ketiganya bisa dibuka bersamaan dengan akun berbeda — dan itu
alur pengujian yang paling sering dipakai: pesan dari satu tab, terima dari tab
lain.

### Android

Emulator memakai `10.0.2.2` sebagai alias host, bukan `127.0.0.1` — yang di
dalam emulator menunjuk ke emulator itu sendiri. Profil `Customer · Android` dan
`Driver · Android` di `launch.json` sudah mengaturnya.

Untuk perangkat fisik: ganti ke IP komputer di jaringan yang sama, dan jalankan
Laravel dengan `--host=0.0.0.0` (bawaannya hanya mendengarkan `127.0.0.1`).

### Perintah lain

```bash
melos run analyze:all    # analisis satu jalan untuk seluruh workspace
melos run format         # periksa format, tanpa mengubah
melos run format:fix     # dart format lib/ dan test/ seluruh package
melos run test           # test di package yang punya test
melos run apk:all        # rilis APK ketiga aplikasi
```

`format` menunjuk `lib` dan `test`, bukan `.`. Alasannya: `dart format .` masuk
ke `build/`, dan artefak Gradle di sana punya jalur yang melewati batas MAX_PATH
Windows — direktorinya ada tapi tidak bisa dibuka lagi, jadi formatter berhenti
dengan `PathNotFoundException`. Kegagalan yang hanya muncul di mesin yang pernah
membangun APK adalah kegagalan yang paling sulit dipercaya.

---

## Test

```bash
melos run test            # semua (flutter test + dart test)
melos run test:flutter    # hanya package yang bergantung pada Flutter
melos run test:dart       # hanya package Dart murni (antaride_core)
```

117 test, dan letaknya mengikuti tempat kesalahan paling mahal:

| Berkas | Jml | Isi |
|---|---|---|
| `packages/antaride_api/test/contract_test.dart` | 35 | Parsing seluruh model terhadap response backend sungguhan |
| `packages/antaride_notifications/test/notification_controller_test.dart` | 16 | Peran `as`, penandaan optimistis, dan pengembaliannya saat gagal |
| `packages/antaride_auth/test/phone_display_test.dart` | 15 | Aturan bahwa aplikasi TIDAK menormalkan nomor HP |
| `packages/antaride_core/test/money_test.dart` | 11 | `Money` hanya membandingkan, tidak pernah menghitung |
| `apps/driver/test/driver_controller_test.dart` | 25 | Tawaran, order berjalan, kunci idempotency, siklus hidup tiket lokasi, dan keputusan foreground service |
| `packages/antaride_maps/test/polyline_codec_test.dart` | 9 | Encode/decode polyline, diuji terhadap contoh acuan spesifikasi |
| `apps/customer/test/order_flow_idempotency_test.dart` | 6 | Kunci idempotency dipakai ulang saat mencoba lagi |

`antaride_core` memakai `package:test` dan `dart test`, bukan `flutter_test` —
paket itu sengaja bebas Flutter, dan itulah yang menjaga janji tersebut tetap
benar.

### Fixture kontrak dihasilkan backend, bukan ditulis tangan

Berkas di `test_fixtures/` ditulis oleh `ContractFixtureTest` di repo backend —
response HTTP sungguhan dari endpoint sungguhan.

```bash
cd ../antaride-be && php artisan test tests/Feature/Api/ContractFixtureTest.php
```

Alasannya bukan kerapian. Fixture yang ditulis tangan di sisi Dart hanya
membuktikan bahwa parser-nya konsisten dengan apa yang **penulisnya yakini**
soal bentuk API — dan itu tepat jenis kesalahan yang sudah pernah terjadi di
proyek ini: model quote dibuat dengan asumsi `fare.total` sebagai objek Money
bersarang, padahal endpoint quote mengirimnya rata sebagai `total_fare` dan
`total_formatted`. Analyzer tidak bisa melihatnya, dan test dengan fixture
tulisan tangan akan lulus. Yang terlihat di layar adalah harga Rp 0 di seluruh
pilihan layanan, tanpa satu pun galat di log.

Dengan fixture yang dihasilkan backend, perubahan bentuk response gagal di test
run berikutnya — bukan pada penumpang.

### Setiap test regresi sudah dibuktikan gagal

Aturan di bawah diuji dengan cara **membalik implementasinya lebih dulu** dan
memastikan test-nya benar-benar merah:

| Aturan | Kalau dilanggar |
|---|---|
| `fare.total_fare` (quote) vs `fare.total` (order) | Harga Rp 0 di semua layanan |
| `orderable`, bukan `is_orderable` | Tombol pesan mati untuk semua layanan |
| Kunci idempotency order dipakai ulang | Tiga percobaan → tiga order, dana ditahan tiga kali |
| Kunci idempotency DIBUANG saat quote berubah | Backend menolak `IDEMPOTENCY_KEY_REUSED`, dan mencoba lagi tidak menolong |
| Kunci idempotency `complete` per order | Pembagian uang dijalankan berkali-kali |
| Order berjalan tidak dihapus request gagal | Driver kehilangan layar ordernya di area tanpa sinyal |
| Presisi polyline = 5 | Rute tergambar di tengah laut |

Test yang belum pernah dilihat gagal belum membuktikan apa pun.

### Satu bug nyata yang ditemukan pendekatan ini

Fixture yang dihasilkan backend menyingkap bahwa `expires_at` pada tawaran driver
dikirim sebagai `"2026-08-28 05:47:29"` — string mentah Postgres **tanpa penanda
zona waktu**, berbeda dari setiap cap waktu lain di API.

`DateTime.tryParse` di Dart memperlakukan string tanpa penanda zona sebagai waktu
**lokal**. Nilainya UTC dan WIB adalah UTC+7, jadi tawaran yang masih berlaku 15
detik terbaca sebagai kadaluarsa tujuh jam yang lalu — dan **setiap** kartu
tawaran akan disaring keluar oleh `DriverOffer.isExpired`.

Gejalanya: driver online, motornya di tempat, dan tidak ada satu pun order yang
masuk. Tanpa galat di kedua sisi. Sudah diperbaiki di backend, dan ada assertion
di `ContractFixtureTest` yang menjaganya tidak kembali.

---

## Keputusan arsitektur

### `Result<T>`, bukan exception

Dengan exception, kegagalan tidak muncul di tanda tangan fungsi — dan yang
terjadi adalah layar yang lupa menangkapnya, lalu menampilkan layar merah kepada
penumpang yang sedang memesan. Dengan `Result<T>`, kegagalannya ada di tipe
kembaliannya, dan kompiler yang menegakkan penanganannya.

Yang tetap dilempar sebagai exception: bug pemrograman. Itu bukan kegagalan yang
perlu ditangani layar.

### Model ditulis tangan, tidak di-generate

Backend punya spesifikasi OpenAPI lengkap dan `swagger_parser` bisa menghasilkan
model Dart darinya. Itu tidak dipakai, dan alasannya bukan ketidakpercayaan pada
alatnya.

Model hasil generate memetakan field API satu-satu. Yang hilang di situ adalah
hal yang justru paling dipakai layar: field **turunan** seperti `canCancel`,
`isActive`, `secondsUntilExpiry`. Kalau model-nya di-generate, ketiganya berakhir
tersebar di widget sebagai perbandingan string status — dan salah satu widget
akan melupakan satu status. Bug itu tidak menghasilkan error, hanya tombol yang
tidak muncul di layar tertentu.

`fromJson` tetap mengikuti bentuk OpenAPI persis, jadi perubahan API gagal di
satu tempat, bukan menyebar.

### Aplikasi tidak pernah menghitung uang

`Money` di `antaride_core` **tidak punya** `plus`, `minus`, atau `percentage`.
Seluruh perhitungan ada di backend; mobile hanya menampilkan.

API mengirim setiap nominal sebagai `{amount, currency, formatted}` — angka
mentah untuk membandingkan, string terformat untuk ditampilkan. Kalau hanya
`amount` yang dikirim, tiga aplikasi harus sepakat soal pemisah ribuan dan letak
tanda minus, dan yang paling sering berbeda adalah tanda minus.

Satu pengecualian yang disebut eksplisit di kodenya: total setelah potongan promo
di layar konfirmasi dijumlahkan di aplikasi supaya angkanya tidak menunggu quote
baru. Yang ditagih tetap hasil hitungan backend dari `quote_id` dan `promo_code`.

### `Idempotency-Key` dibuat sekali per operasi

Dua endpoint memindahkan uang: buat order, dan selesaikan order. Kuncinya dibuat
**sekali** — saat tombol ditekan — dan dipakai ulang untuk setiap percobaan
berikutnya. Kunci baru setiap percobaan berarti backend melihat dua permintaan
berbeda: dua order, atau pembagian uang yang dijalankan dua kali.

Itu sebabnya kuncinya diminta sebagai parameter repository, bukan dibuat di
dalamnya — method yang membuat kuncinya sendiri tidak punya cara memakai ulang
kunci yang sama.

### Realtime mempercepat, bukan jadi sumber kebenaran

Setiap layar harus tetap benar walaupun tidak ada satu pun peristiwa realtime
yang datang. Penarikan berkala lewat REST yang jadi tulang punggungnya; Centrifugo
nanti hanya memicu penarikan lebih awal.

Sebagian jaringan operator dan hampir semua WiFi kantor memblokir koneksi
WebSocket panjang. Aplikasi yang menggantungkan seluruh pembaruannya di sana akan
membeku bagi pengguna itu — dan membeku tanpa galat, yang jauh lebih sulit
dilaporkan.

Interval penarikannya berbeda per status, dan itu bukan optimasi mikro:

| Status | Interval | Alasan |
|---|---|---|
| `searching` | 4 s | Penumpang menunggu jawaban; setiap detik terasa. |
| driver menuju | 6 s | Posisi driver bergerak, dan itu yang ditatap. |
| `in_progress` | 10 s | Tidak banyak yang berubah selain kapan sampai. |
| selesai | berhenti | Tidak ada lagi yang bisa berubah. |

Satu interval untuk semua akan salah di kedua arah: 10 detik terasa lambat saat
mencari driver, dan 4 detik selama perjalanan 40 menit menghasilkan 600 request
untuk satu order.

### Paket pub.dev untuk yang bukan khas Antaride

`flutter_zoom_drawer` (sidebar beranimasi), `shimmer` (skeleton), `easy_refresh`
(tarik-untuk-menyegarkan + muat-saat-menggulir), `flutter_spinkit` (spinner).
Keempatnya dibungkus di `antaride_ui` — `ClayDrawerShell`, `ClaySkeleton`,
`ClayRefresh`, `ClayLoader` — dan **tidak** dipakai langsung dari layar.

Itu yang membuat penggantian paket nanti menyentuh satu file, bukan lima puluh
layar; dan yang membuat ketiga aplikasi memakai teks dan warna yang sama.

`permission_handler` dan `image_picker` dibungkus di `antaride_media` — bukan di
`antaride_ui`, karena design system tidak boleh tahu apa pun soal izin perangkat
maupun plugin platform. Satu pintu masuk: `MediaSourceSheet.show(...)`.

`flutter_foreground_task` berdiri sendiri di aplikasi driver, bukan di
`antaride_ui`: dia bukan komponen tampilan, dan dua aplikasi lainnya tidak boleh
punya foreground service sama sekali. Dia pun dibungkus — di balik antarmuka
`LocationBackgroundService` — dengan alasan yang berbeda: task handler-nya
berjalan di isolate terpisah yang tidak bisa disentuh test, jadi yang diuji
adalah keputusan `DriverController` terhadap antarmuka itu.

Yang tetap ditulis sendiri: apa pun yang menyentuh uang, status order, dan
permukaan claymorphism — di situ tidak ada paket yang cocok, dan di situ
kesalahan kecil berakibat nyata.

### Peta memakai `flutter_map`, tile-nya dari Mapbox

Backend sudah memakai OSRM dan OSM untuk routing. Google Maps di aplikasi berarti
dua sumber data geografis berbeda — dan gejalanya adalah rute di peta yang tidak
sama dengan rute yang dipakai menghitung ongkos. Penumpang yang
membandingkannya akan menyimpulkan jaraknya dimanipulasi.

Yang berubah dari rencana awal hanya **sumber tile**-nya, bukan pustakanya:
`tile.openstreetmap.org` melarang pemakaian massal dan memblokir pelanggarnya
**per IP** — yang berarti peta kosong untuk semua pengguna di jaringan operator
yang sama, sekaligus. Tile-nya sekarang dari Mapbox, disetel lewat
`--dart-define`:

```
MAPBOX_TOKEN=pk....        token publik (pk.*), boleh ada di dalam APK
MAPBOX_STYLE=mapbox/streets-v12
```

Dua hal yang tidak boleh diubah tanpa mengubah pasangannya:

| | |
|---|---|
| `tileSize: 512` **wajib** dipasangkan dengan `zoomOffset: -1` | Mapbox menyajikan tile 512px, sementara `flutter_map` menghitung zoom untuk tile 256px. Tanpa `zoomOffset`, petanya tampil satu tingkat terlalu dekat — dan yang terlihat bukan galat, hanya peta yang salah skala. |
| Atribusi Mapbox + OpenStreetMap **wajib tampil** | Itu syarat lisensi keduanya, bukan hiasan. `AntarideMap` sudah memuatnya lewat `RichAttributionWidget`; menghapusnya melanggar ToS. |

**Token yang dipakai sekarang token publik `pk.*`** — memang dirancang untuk ada
di dalam aplikasi klien, jadi keberadaannya di APK bukan kebocoran. Tapi
pembatasannya harus disetel di dashboard Mapbox (URL/asal yang diizinkan dan
kuota), karena token publik tanpa pembatasan bisa dipakai siapa pun yang
membongkar APK-nya — dan tagihannya tetap tagihan Anda.

### Izin perangkat: dideklarasikan per aplikasi, bukan satu blok yang sama

Ketiga aplikasi TIDAK meminta izin yang sama. Kebijakan Play Store menuntut
setiap izin bisa dikaitkan dengan fungsi yang benar-benar ada, dan blok izin yang
disalin ke tiga aplikasi berarti dua di antaranya meminta sesuatu yang tidak bisa
dijelaskan saat review.

| | Penumpang | Driver | Merchant |
|---|---|---|---|
| `INTERNET` | ✓ | ✓ | ✓ |
| Lokasi (`FINE`/`COARSE`) | ✓ titik jemput | ✓ | ✓ titik toko |
| `ACCESS_BACKGROUND_LOCATION` | — | ✓ | — |
| `FOREGROUND_SERVICE_LOCATION` | — | ✓ | — |
| `POST_NOTIFICATIONS` | — | ✓ *(syarat foreground service)* | — |
| `CAMERA` | ✓ foto profil | ✓ dokumen + bukti antar | ✓ foto produk |
| `READ_MEDIA_IMAGES` | ✓ | ✓ | ✓ |
| `RECORD_AUDIO` | ⚠ | ⚠ | ⚠ |
| `location.gps` wajib? | tidak | **ya** | tidak |

Empat hal yang mudah salah, dan semuanya sudah diverifikasi lewat `aapt2` pada
APK rilis:

**`uses-feature required="false"` untuk kamera — WAJIB ADA.** Play Store
menyimpulkan syarat perangkat dari izin yang dideklarasikan. Izin `CAMERA` tanpa
`uses-feature required="false"` membuat aplikasi **tidak muncul** di Play Store
untuk perangkat tanpa kamera — dan tidak ada galat apa pun yang menjelaskannya,
aplikasinya hanya tidak ada di sana.

**Galeri butuh tiga izin, karena Android mengubahnya dua kali.**
`READ_EXTERNAL_STORAGE` (dengan `maxSdkVersion="32"`, agar tidak lagi dihitung
di perangkat modern), `READ_MEDIA_IMAGES` untuk Android 13+, dan
`READ_MEDIA_VISUAL_USER_SELECTED` untuk "pilih beberapa foto saja" di Android 14+.
`READ_MEDIA_VIDEO` dan `READ_MEDIA_AUDIO` sengaja **tidak** ada — yang dipilih
pengguna hanya gambar.

**`location.gps` wajib HANYA di aplikasi driver.** Itu satu-satunya
`required="true"` di seluruh proyek: aplikasi driver tidak bisa bekerja tanpa GPS,
dan tidak punya jalur "ketik alamat saja" seperti aplikasi penumpang. Perangkat
tanpa GPS lebih baik tidak ditawarkan sejak awal daripada mengunduh aplikasi yang
tidak bisa online.

**Kunci `UsageDescription` di iOS bukan soal review — yang hilang menyebabkan
crash.** iOS mematikan proses seketika (`NSInvalidArgumentException`) begitu API
kamera/galeri/mikrofon dipanggil tanpa kuncinya. Bukan dialog yang ditolak, bukan
exception yang bisa ditangkap. Karena itu ketiga `Info.plist` sudah memuat
seluruh kuncinya, termasuk untuk fitur yang belum ada.

⚠ **`RECORD_AUDIO` dideklarasikan tanpa fitur di belakangnya.** Tidak ada satu
pun bagian aplikasi yang merekam audio; izinnya disiapkan untuk pesan suara
penumpang–driver. Sebelum pengajuan pertama ke Play Store, salah satu dari dua
hal **harus** dikerjakan: fitur pesan suaranya dibangun, atau deklarasinya
dibuang. Izin tanpa fungsi yang bisa ditunjukkan adalah alasan penolakan yang
lazim, dan penolakannya terjadi pada pengajuan — bukan pada build.

#### Satu pintu untuk kamera dan galeri

`antaride_media` membungkus `permission_handler` dan `image_picker`. Layar
memanggil `MediaSourceSheet.show(...)` dan mendapat `MediaPicked` atau null —
tidak menyentuh kedua paket itu sama sekali.

Yang dibeli bukan kerapian, tapi satu cabang yang paling mudah terlewat:
**"ditolak PERMANEN"**. Dialog sistem tidak akan muncul lagi apa pun yang
dilakukan aplikasi, dan satu-satunya jalan keluar adalah pengaturan perangkat.
Layar yang memperlakukannya sebagai pembatalan biasa menghasilkan tombol yang
diam — pengguna menekan "ambil foto", tidak ada yang terjadi, dan dia
menekannya lagi. Selamanya.

Karena itu hasilnya `sealed class` dengan lima keadaan, bukan `File?`: dipilih,
dibatalkan, izin ditolak, izin ditolak permanen, dan gagal. Bentuk `File?`
membuat kelima-limanya menjadi `null`.

**Foto dikecilkan sebelum dikirim — dan itu juga yang menghapus koordinat GPS
dari dalamnya.** Sisi terpanjang 1600 piksel, kualitas 85, hasilnya 200–400 KB.
Efek sampingnya yang paling penting: `image_picker` mengkodekan ulang gambarnya
begitu parameter itu diberikan, dan pengkodean ulang membuang metadata EXIF —
termasuk **koordinat tempat foto itu diambil**. Untuk foto KTP, tanpa itu alamat
rumah driver ikut terkirim dan tersimpan di server: data yang tidak pernah
diminta, tidak dipakai untuk apa pun, dan menjadi tanggung jawab kalau server
ditembus.

**`compileSdk` ditetapkan 37 di ketiga aplikasi**, bukan mengikuti bawaan Flutter
(36). Yang memaksanya `permission_handler_android`. Pesan galatnya menyesatkan —
menyebut `minSdk` di baris berikutnya, padahal yang dituntut compileSdk.
Ketiganya disetel sama walaupun sekarang hanya driver yang memakai
`antaride_media`, supaya dua aplikasi lainnya tidak gagal build dengan pesan yang
sama saat unggahan foto profil dan foto produk menyusul.

#### Unggah dokumen KYC driver

`driver_documents` sudah ada sejak awal, panel verifikasi admin sudah lengkap, dan
`GoOnline` sudah menolak driver yang dokumennya belum disetujui. Yang tidak ada:
cara driver **mengirim** dokumennya. Sampai `POST /driver/documents` ada,
satu-satunya jalan mendaftarkan driver adalah admin memasukkan barisnya langsung
ke database.

Layarnya di sidebar driver (`Dokumen Saya`), dan **selalu ada** — bukan hanya
saat dokumennya belum lengkap. Kalau disembunyikan setelah semuanya disetujui,
SIM yang habis masa berlakunya membuat driver ditolak online dan halaman untuk
memperbaruinya sudah hilang dari menunya.

Yang dijaga di sisi backend, semuanya dengan test yang sudah dibuktikan merah:

| | |
|---|---|
| Nama berkas dari client tidak pernah dipakai | Dua driver yang mengunggah `ktp.jpg` akan saling menimpa dokumennya. Verifikator melihat KTP driver A sebagai KTP driver B, tanpa satu pun galat. |
| Ekstensi dari **isi** berkas, bukan namanya | `foto.jpg.php` yang isinya JPEG akan tersimpan dengan ekstensi `.php`. |
| Unggah ulang mengembalikan status ke `pending` | Tanpa itu, driver bisa menukar KTP-nya dengan milik orang lain **setelah** lolos verifikasi, dan barisnya tetap `approved`. |
| Berkas lama dibuang saat diganti | Setiap unggahan ulang meninggalkan satu foto KTP tanpa pemilik: tidak bisa ditemukan, tidak bisa dihapus atas permintaan, tumbuh selamanya. |
| `file_path` tidak pernah keluar ke aplikasi | Path mentah tidak berguna bagi aplikasi (disknya privat), tapi berguna bagi orang yang mencari cara menebak path dokumen driver lain. Fixture kontrak ikut memeriksanya, karena fixture yang memuat path akan hidup di riwayat git repo ini. |

Dan satu bug yang ketahuan saat fixture-nya dibaca: **`can_go_online` mengabaikan
dokumen kadaluarsa.** Endpoint menghitungnya dari status `approved` saja,
sementara `GoOnline` menolak setiap dokumen `approved` yang tanggalnya sudah
lewat. Akibatnya layar menyatakan "Dokumen lengkap, Anda sudah bisa mulai
bekerja" lalu tombol online ditolak — dan driver yang SIM-nya habis bulan lalu
tidak punya satu pun petunjuk, karena layarnya sendiri menyatakan dia siap.
Sekarang keduanya sepakat, dan ada test yang memaksanya tetap begitu.

### GPS latar belakang: foreground service, bukan timer

Driver bekerja dengan HP di dudukan, layar mati, aplikasi di latar belakang.
Android **menghentikan** pembacaan lokasi untuk aplikasi dalam keadaan itu —
bukan melambatkan.

Akibatnya kalau tidak ditangani: ping berhenti, TTL 60 detik di Redis habis,
driver keluar dari indeks ketersediaan, dan tidak ada tawaran yang masuk. Yang
dia lihat: aplikasi menyatakan dia online, motornya di tempat, dan tidak ada
order sepanjang jam sibuk. Tanpa satu pun galat.

Yang dipakai: `flutter_foreground_task` dengan `foregroundServiceType="location"`
dan notifikasi yang terlihat selama shift.

**Ping pindah SEPENUHNYA ke isolate service.** Bukan dibagi dua dengan timer di
aplikasi:

| | |
|---|---|
| Dua pengirim = posisi yang salah menang | Keduanya menulis ke Redis, dan yang menang bergantung pada urutan kedatangan — yang lebih lama bisa menang. |
| Dua pembaca GPS = baterai driver | Chip GPS dibangunkan dua kali sesering yang perlu, sepanjang shift. |

Jadi begitu service jalan, `DriverController` membatalkan timer **dan** aliran
GPS-nya. Posisi untuk peta di dasbor datang dari laporan service — dari
pembacaan yang memang sudah terjadi untuk ping.

**Notifikasinya menyebut keadaan sebenarnya**, bukan kalimat tetap: "Posisi
terkirim 14:32" atau "Posisi belum terkirim — periksa sinyal". Itu satu-satunya
tempat driver bisa memeriksanya tanpa membuka aplikasi — dan ini justru saat
aplikasinya tertutup.

**Kalau service tidak bisa dimulai, driver diberi tahu.** Izin notifikasi yang
ditolak berarti Android menolak foreground service-nya, dan yang tersisa hanya
timer di dalam aplikasi. Dasbor menampilkan "Jangan tutup aplikasi ini" —
kalimat yang menyebut akibatnya, bukan penyebab teknisnya. Tanpa itu driver akan
mengunci HP-nya dan menunggu order yang tidak akan pernah datang.

Tiga hal yang gagal tanpa suara kalau salah, semuanya sudah dijaga test:

1. **`@pragma('vm:entry-point')` pada titik masuk isolate.** Tanpa itu
   tree-shaking build release membuang fungsinya — dia tidak dipanggil dari kode
   Dart mana pun. Gejalanya menyesatkan: jalan normal di debug, lalu di release
   notifikasinya muncul tanpa satu pun ping terkirim. Diverifikasi dengan
   memeriksa `libapp.so` di APK rilis.

2. **`foregroundServiceType="location"` di manifest.** Wajib sejak Android 14;
   tanpa itu `startForeground` melempar dan aplikasi hanya bilang "posisi hanya
   terkirim selama aplikasi terbuka" — tanpa menyebut manifest.

3. **`saveData` hanya menerima int/double/String/bool.** Tipe lain
   dikembalikan false, bukan melempar. Karena itu daftar layanan disimpan sebagai
   String dipisah koma.

#### Dua bug yang ketahuan saat ini dibangun

Keduanya sudah ada di kode sebelumnya, keduanya sepenuhnya senyap, dan keduanya
berarti **posisi driver tidak pernah terkirim sama sekali**:

| Bug | Sebabnya |
|---|---|
| Tiket dibuang tepat setelah diterima | `_hentikanGps` mengosongkan tiket, dan `_mulaiGps` memanggil `_hentikanGps` lebih dulu untuk membersihkan sesi sebelumnya. Jadi urutan setiap kali driver online: simpan tiket → buang tiket → timer menyala → baca tiket → null → keluar. |
| Aplikasi yang di-restart tidak punya tiket | Tiket dulu hanya dikirim `POST /driver/online`. Driver yang aplikasinya ditutup Android — kehabisan memori, atau ditutup sendiri — kembali ke sesi yang masih terbuka, jadi `goOnline` tidak dipanggil. Tidak ada tiket, dan tidak ada cara mendapatkannya. |

Keduanya tidak menghasilkan galat karena `_kirimPosisi` keluar **sebelum**
memanggil pinger — jadi `consecutiveFailures` tetap nol dan peringatan "posisi
tidak terkirim" juga tidak pernah menyala.

Perbaikannya: pembuangan tiket dipindah ke `goOffline`, dan
`GET /driver/status` sekarang ikut mengirim tiket untuk driver yang sesinya masih
terbuka. Yang kedua itu perubahan backend — jalan keluar sebelumnya adalah
menekan offline lalu online, yang memotong catatan jam kerja driver.

### Notifikasi in-app menggantikan push, dan bedanya nyata

Push notification (FCM) ditunda. Yang menggantikannya: notifikasi yang disimpan
backend di tabel `notifications` dan dibaca aplikasi lewat `/notifications`.

Perbedaannya harus disadari saat membaca layarnya: **push MENDATANGI pengguna,
notifikasi in-app MENUNGGU dia membuka aplikasi.**

Untuk penumpang itu cukup — dia memang sedang menatap layar saat menunggu
driver. Untuk driver **tidak** cukup, dan itu sebabnya **tawaran order sengaja
TIDAK lewat sini**: tawaran hanya berlaku 15 detik, dan yang baru terbaca saat
aplikasi dibuka akan selalu sudah kadaluarsa. Tawaran tetap dijemput
`DriverController` lewat penarikan berkala.

Jadi tabel notifikasi hanya untuk kabar yang boleh terlambat dibaca: order
diterima, driver tiba, perjalanan selesai, pengumuman.

**Tidak ada polling berkala untuk lencananya.** Angka di ikon lonceng diperbarui
saat dipasang dan setiap kali aplikasi kembali ke depan — itu yang dilakukan
`NotificationSync`. Timer sepuluh detik akan berarti 8.640 request per hari per
pengguna untuk angka yang hampir selalu sama, dan di jaringan seluler itu kuota
dan baterai yang dibayar pengguna.

**Perannya ditetapkan sekali, bukan per pemanggilan.** Satu orang bisa punya akun
penumpang dan driver yang sama — driver memesan ojek saat kendaraannya di
bengkel. Yang menentukan notifikasi siapa yang tampil adalah dari **aplikasi
mana** requestnya datang, bukan akunnya:

```dart
// apps/driver/lib/main.dart
AntarideServices.build(
  platform: _platform,
  notificationRole: RecipientRole.driver,   // penumpang memakai bawaannya
);
```

Nilai yang salah di sini tidak menghasilkan galat apa pun — daftarnya tetap
terisi dan tetap tampil rapi, hanya isinya milik peran yang lain. Itu sebabnya
ada test yang memeriksa nilai `as` yang benar-benar terkirim.

Backoffice admin **tidak** memakai tabel ini. Lonceng di panel admin diturunkan
dari keadaan sekarang — berapa approval menunggu, berapa order macet — karena
notifikasi yang disimpan bisa basi: baris "2 approval menunggu" dari kemarin
tetap berbunyi begitu walaupun keduanya sudah disetujui.

---

## Yang belum selesai, dan sebabnya

| Hal | Keadaan |
|---|---|
| **GPS latar belakang iOS** | Android sudah selesai: foreground service dengan `foregroundServiceType="location"`. iOS belum — bentuknya berbeda sama sekali (`UIBackgroundModes` beserta batasan waktunya sendiri, tanpa foreground service), dan menyamakan keduanya di satu implementasi berarti dua perilaku yang tidak pernah diuji bersamaan. Di iOS aplikasi jatuh ke timer di dalam aplikasi dan memberi tahu driver bahwa posisinya hanya terkirim selama aplikasi terbuka. |
| **Centrifugo** | `CentrifugoClient` sudah lengkap termasuk backoff dan sambung-ulang, tapi servernya belum terpasang. Aplikasi memakai `NullRealtimeClient` dan penarikan berkala. |
| **Aplikasi merchant** | Hanya masuk dan profil. API Fase 1 tidak punya satu pun endpoint merchant; layarnya menyatakan itu, bukan memalsukan sakelar yang tidak memanggil apa pun. |
| **Foto bukti antar** | Kolomnya sudah ada (`order_stops.proof_photo_path`) dan lapisan unggahnya sudah lengkap — `ImageStore` beserta seluruh penjagaannya. Yang belum: endpoint dan tombolnya di layar order berjalan driver. Ini yang menyelesaikan sengketa "barang saya tidak pernah datang". |
| **Foto profil** | Kolomnya ada (`users.photo_url`), izin dan pemilih fotonya sudah siap di aplikasi penumpang. Endpoint unggahnya belum ada. |
| **Pesan suara** | Belum ada sama sekali. Izin `RECORD_AUDIO` sudah dideklarasikan menunggu fitur ini — lihat peringatan di bagian izin perangkat. |
| **Reverse geocoding** | Alamat diketik pengguna, bukan hasil pencarian. Koordinatnya yang dipakai driver. |
| **Top up dompet** | Tidak ada tombolnya. Fase 1 belum punya payment gateway; saldo masuk dari promo dan penambahan manual admin. |
| **Test widget** | Belum ada. Yang sudah ada 117 test untuk lapisan yang paling berkonsekuensi — kontrak API, uang, polyline, nomor HP, notifikasi, tiket lokasi, dan aturan idempotency. Test widget menyusul. |
| **Push notification** | Ditunda atas keputusan proyek. Yang menggantikannya: notifikasi **in-app** yang disimpan backend dan dibaca aplikasi saat dibuka — lihat di bawah. |

---

## Keputusan yang perlu diambil sebelum rilis

Yang berikut sudah **diputuskan** dan tidak lagi menunggu:

| Keputusan | Hasilnya |
|---|---|
| Tile peta | **Mapbox**, token publik lewat `--dart-define`. Yang tersisa: menyetel pembatasan URL dan kuota di dashboard Mapbox. |
| Push notification | **Ditunda.** Diganti notifikasi in-app di aplikasi dan lonceng turunan-keadaan di backoffice. |
| Layanan lokasi Go | **Dibangun.** `services/location-service` di port 8200. |
| GPS latar belakang Android | **Dibangun.** Foreground service dengan notifikasi yang terlihat. Yang tersisa: menyiapkan justifikasi + video Play Store untuk `ACCESS_BACKGROUND_LOCATION`. |
| Payment gateway | **Ditunda.** Dompet tetap hanya untuk promo dan cashback di Fase 1. |
| Nama paket | **Sudah dirapikan** ke `id.antaride.customer` / `.driver` / `.merchant`, sebelum build rilis pertama. |

Yang masih terbuka:

1. **Gateway SMS.** OTP saat ini hanya dicetak ke log dan dikirim sebagai
   `debug_code` di lingkungan non-produksi. Perlu memilih penyedia (Twilio,
   Vonage, atau penyedia lokal seperti Zenziva/Wablas) — dan biayanya per SMS
   menentukan seberapa ketat rate limit OTP harus disetel.

2. **Centrifugo.** `CentrifugoClient` sudah lengkap termasuk backoff dan
   sambung-ulang, tapi servernya belum terpasang. Perlu diputuskan apakah
   dipasang sekarang atau Fase 1 dirilis dengan penarikan berkala — yang bekerja,
   tapi menunda pembaruan status beberapa detik dan menambah beban baterai.

3. **Justifikasi Play Store untuk `ACCESS_BACKGROUND_LOCATION`.** Google
   menuntut penjelasan tertulis **beserta video** yang memperagakan alurnya di
   dalam aplikasi; pengajuan tanpa video ditolak. Aplikasi juga harus meminta
   izinnya bertahap — "saat dipakai" dulu, latar belakang terpisah setelah driver
   menekan "Mulai bekerja".

   Izin ini bisa dibuang sepenuhnya: foreground service yang dimulai saat
   aplikasi terlihat boleh membaca lokasi tanpa izin itu. Yang ditukar kalau
   dibuang adalah kasus service yang di-restart sistem — driver yang HP-nya
   membunuh proses aplikasi di tengah shift berhenti mendapat order tanpa tahu.
   Keputusan ini menunggu Anda, karena yang ditimbang bukan hal teknis.

4. **GPS latar belakang iOS.** Belum ada. Driver iOS jatuh ke timer di dalam
   aplikasi, dan diberi tahu bahwa posisinya hanya terkirim selama aplikasi
   terbuka.

5. **Ikon dan splash screen.** Belum ada aset merek. Sekarang memakai ikon
   Material bawaan.

### Kenapa nama paket harus final sebelum rilis pertama

Sebelumnya bentuknya berulang:

| | Android | iOS |
|---|---|---|
| Penumpang | `id.antaride.antaride_customer` | `id.antaride.antarideCustomer` |
| Driver | `id.antaride.antaride_driver` | `id.antaride.antarideDriver` |
| Merchant | `id.antaride.antaride_merchant` | `id.antaride.antarideMerchant` |

Sekarang `id.antaride.customer` / `.driver` / `.merchant`.

Perubahan itu **harus** dilakukan sebelum build rilis pertama: setelah aplikasi
terbit di Play Store, mengubah `applicationId` berarti aplikasi **baru**, bukan
pembaruan — pengguna lama tidak akan pernah menerimanya, dan tidak ada cara
memperbaikinya dari sisi mana pun. Aturan yang sama berlaku untuk
`PRODUCT_BUNDLE_IDENTIFIER` di iOS.
