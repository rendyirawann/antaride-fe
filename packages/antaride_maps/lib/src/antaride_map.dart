import 'package:antaride_core/antaride_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'location_service.dart';

/// Satu penanda di peta.
class MapPin {
  const MapPin({
    required this.position,
    required this.icon,
    required this.color,
    this.label,
    this.size = 40,
  });

  final LatLng position;
  final IconData icon;
  final Color color;
  final String? label;
  final double size;
}

/// Peta dengan penanda dan rute.
///
/// ============================================================================
///  TILE DARI MAPBOX, RUTE DARI OSRM — DAN ITU BUKAN CAMPUR ADUK
/// ============================================================================
///  Gambar petanya dari Mapbox; rute, jarak, dan ETA dari OSRM di atas data
///  OpenStreetMap. Keduanya memakai basis data yang sama, jadi garis rute yang
///  digambar di peta adalah rute yang sama dengan yang dipakai menghitung ongkos.
///
///  Itu yang tidak berlaku kalau tile-nya Mapbox dan routing-nya Google: rute di
///  layar akan berbeda dari rute yang ditagih, dan penumpang yang
///  membandingkannya akan menyimpulkan jaraknya dimanipulasi.
///
///  Kenapa tidak `tile.openstreetmap.org` langsung: gratis tapi melarang
///  pemakaian massal, dan pelanggarnya diblokir PER IP — yang berarti peta
///  kosong untuk semua pengguna di jaringan operator yang sama, bukan hanya
///  untuk satu perangkat.
/// ============================================================================
///
/// ============================================================================
///  ATRIBUSI WAJIB, BUKAN PILIHAN
/// ============================================================================
///  Syarat layanan Mapbox MENUNTUT atribusi Mapbox dan OpenStreetMap terlihat
///  di setiap peta. Menghapusnya adalah pelanggaran ToS, bukan sekadar
///  kelalaian desain — dan akun yang melanggarnya bisa ditangguhkan.
///
///  Karena itu `RichAttributionWidget` di bawah TIDAK boleh dihapus, walaupun
///  dia memakan sudut kanan bawah peta. Bentuknya sudah dipilih paling ringkas:
///  tombol "i" kecil yang membuka daftarnya saat ditekan.
/// ============================================================================
class AntarideMap extends StatefulWidget {
  const AntarideMap({
    super.key,
    this.center,
    this.initialZoom = 15,
    this.pins = const <MapPin>[],
    this.route = const <LatLng>[],
    this.routeColor,
    this.onTap,
    this.onCenterChanged,
    this.interactive = true,
    this.fitToContent = true,
  });

  /// Titik tengah awal. Kalau null, memakai [medanCenter].
  final LatLng? center;

  final double initialZoom;

  final List<MapPin> pins;

  /// Rute yang digambar sebagai garis.
  final List<LatLng> route;

  final Color? routeColor;

  /// Dipanggil saat pengguna menekan peta. Dipakai layar pemilihan titik.
  final void Function(LatLng)? onTap;

  /// Dipanggil setelah geseran peta BERHENTI.
  ///
  /// ==========================================================================
  ///  DIPANGGIL SETELAH BERHENTI, BUKAN SELAMA BERGERAK
  /// ==========================================================================
  ///  Layar pemilihan titik memakai ini untuk meminta quote baru. Kalau
  ///  dipanggil pada setiap frame geseran, satu geseran menghasilkan puluhan
  ///  request quote — dan setiap quote memanggil OSRM lalu menghitung tarif
  ///  seluruh layanan.
  ///
  ///  Batas laju di backend akan tercapai dalam beberapa geseran, dan gejalanya
  ///  bagi pengguna adalah harga yang berhenti muncul tanpa penjelasan.
  /// ==========================================================================
  final void Function(LatLng)? onCenterChanged;

  final bool interactive;

  /// Sesuaikan tampilan supaya seluruh [pins] dan [route] terlihat.
  final bool fitToContent;

  @override
  State<AntarideMap> createState() => _AntarideMapState();
}

class _AntarideMapState extends State<AntarideMap> {
  final MapController _controller = MapController();

  bool _sudahMenyesuaikan = false;

  @override
  void didUpdateWidget(AntarideMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Penyesuaian diulang HANYA kalau isinya benar-benar berubah. Tanpa
    // pemeriksaan ini, setiap rebuild — termasuk yang dipicu hitungan mundur
    // yang berdetak tiap detik — akan menarik peta kembali dan membatalkan
    // geseran yang sedang dilakukan pengguna.
    if (oldWidget.route.length != widget.route.length ||
        oldWidget.pins.length != widget.pins.length) {
      _sudahMenyesuaikan = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    final Color warnaRute = widget.routeColor ?? tema.colorScheme.primary;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center ?? medanCenter,
        initialZoom: widget.initialZoom,

        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),

        onTap: widget.onTap == null
            ? null
            : (TapPosition _, LatLng titik) => widget.onTap!(titik),

        onMapEvent: (MapEvent peristiwa) {
          // HANYA saat geserannya berakhir. Lihat penjelasan di
          // `onCenterChanged`.
          if (peristiwa is MapEventMoveEnd) {
            widget.onCenterChanged?.call(peristiwa.camera.center);
          }
        },

        onMapReady: _sesuaikan,
      ),
      children: <Widget>[
        /*
         * ====================================================================
         *  TANPA TOKEN MAPBOX, TILE-NYA JATUH KE OSM — BUKAN JADI PETA KOSONG
         * ====================================================================
         *  Yang terjadi kalau tokennya kosong atau tidak sah dan tidak ada
         *  cadangannya: Mapbox membalas 401 untuk SETIAP tile, dan `flutter_map`
         *  menggambar kotak abu-abu tanpa satu pun pesan.
         *
         *  Itu bentuk kegagalan yang paling membingungkan di seluruh aplikasi:
         *  petanya "hidup" — bisa digeser, penanda dan rutenya tergambar — hanya
         *  latarnya abu-abu. Tidak ada di layar yang menunjuk ke token.
         *
         *  Jadi tanpa token, tile-nya dari OSM. Petanya lebih sederhana, tapi
         *  terbaca — dan yang salah jadi terlihat sebagai perbedaan tampilan,
         *  bukan sebagai kerusakan.
         *
         *  Cadangan ini untuk PENGEMBANGAN, bukan produksi.
         *  `tile.openstreetmap.org` melarang pemakaian massal dan memblokir
         *  pelanggarnya per IP. Build produksi wajib memakai token — itu yang
         *  dijaga `AppConfig.hasMapboxToken`.
         * ====================================================================
         */
        TileLayer(
          urlTemplate: AppConfig.hasMapboxToken
              ? 'https://api.mapbox.com/styles/v1/${AppConfig.mapboxStyle}'
                    '/tiles/512/{z}/{x}/{y}@2x'
                    '?access_token=${AppConfig.mapboxToken}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

          /*
           * ==================================================================
           *  SKEMA 512 + zoomOffset -1, DAN KEDUANYA HARUS BERPASANGAN
           * ==================================================================
           *  Mapbox menyajikan tile style dalam dua skema: 256 dan 512 piksel
           *  per tile. Skema 512 memuat area empat kali lebih luas per tile,
           *  jadi butuh SATU tingkat zoom lebih rendah untuk menutupi layar yang
           *  sama — itu yang dikoreksi `zoomOffset: -1`.
           *
           *  Kalau `tileSize: 512` dipasang tanpa `zoomOffset: -1`, petanya
           *  tetap tampil tapi SKALANYA salah: label jalan jadi dua kali lebih
           *  besar dan tingkat detailnya tidak cocok dengan tingkat zoom yang
           *  diminta. Tidak ada galat — hanya peta yang terasa "terlalu dekat".
           * ==================================================================
           *
           *  `@2x` untuk layar high-DPI. Biaya datanya sama saja dengan skema
           *  256 pada luas layar yang sama, tapi jumlah request-nya seperempat —
           *  dan pada jaringan seluler berlatensi tinggi, jumlah request yang
           *  menentukan, bukan jumlah byte.
           */
          //
          //  Keduanya HANYA berlaku untuk skema 512 Mapbox. Tile OSM berukuran
          //  256, jadi saat jatuh ke cadangan keduanya harus kembali ke nilai
          //  bawaan — kalau tidak, peta cadangannya tampil satu tingkat terlalu
          //  dekat, yang justru gejala yang dijelaskan di atas.
          tileSize: AppConfig.hasMapboxToken ? 512 : 256,
          zoomOffset: AppConfig.hasMapboxToken ? -1 : 0,

          userAgentPackageName: 'id.antaride.app',

          // Mapbox menyediakan tile sampai zoom 22 untuk style ini. Dibatasi 19
          // karena di atas itu yang bertambah hanya perbesaran gambar yang sama,
          // sementara setiap tingkat menggandakan jumlah tile yang diunduh.
          maxNativeZoom: 19,
        ),

        if (widget.route.length >= 2)
          PolylineLayer<Object>(
            polylines: <Polyline<Object>>[
              /*
               * Dua garis bertumpuk: yang bawah lebih lebar dan putih.
               *
               * Itu yang membuat rute tetap terlihat di atas jalan raya
               * berwarna kuning dan area hijau di tile OSM. Garis tunggal
               * berwarna hilang di sebagian latar, dan hilangnya justru di
               * persimpangan — bagian yang paling perlu terlihat.
               */
              Polyline<Object>(
                points: widget.route,
                strokeWidth: 8,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              Polyline<Object>(
                points: widget.route,
                strokeWidth: 5,
                color: warnaRute,
              ),
            ],
          ),

        if (widget.pins.isNotEmpty)
          MarkerLayer(
            markers: widget.pins
                .map(
                  (MapPin pin) => Marker(
                    point: pin.position,
                    width: pin.size + 16,
                    height: pin.size + 16,

                    // Titik jangkarnya di BAWAH, bukan di tengah. Penanda peta
                    // menunjuk ke titiknya dengan ujung bawahnya; yang berjangkar
                    // di tengah akan tampak menunjuk sekitar 20 meter ke utara.
                    alignment: Alignment.topCenter,

                    child: _Penanda(pin: pin),
                  ),
                )
                .toList(),
          ),

        /*
         * Atribusi Mapbox dan OpenStreetMap.
         *
         * WAJIB menurut syarat layanan Mapbox — lihat docblock kelas. Jangan
         * dihapus, dan jangan disembunyikan di belakang panel yang menutupinya.
         *
         * `permanentHeight: 0` membuatnya hanya berupa tombol "i" kecil di sudut
         * kanan bawah, dan daftarnya muncul saat ditekan. Itu bentuk paling
         * ringkas yang masih memenuhi syaratnya — atribusi yang selalu terpampang
         * penuh akan menutupi bagian peta yang justru sedang dibaca.
         */
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomRight,
          showFlutterMapAttribution: false,
          // Mapbox hanya disebut kalau tile-nya MEMANG dari Mapbox.
          //
          // Atribusi ke penyedia yang tidak dipakai bukan hal netral: itu
          // menyatakan sumber data yang salah, dan justru melanggar semangat
          // syarat atribusi yang jadi alasan widget ini ada.
          //
          // OpenStreetMap disebut di kedua keadaan — style Mapbox `streets`
          // dibangun di atas data OSM.
          attributions: <SourceAttribution>[
            if (AppConfig.hasMapboxToken) const TextSourceAttribution('Mapbox'),
            const TextSourceAttribution('OpenStreetMap'),
          ],
        ),
      ],
    );
  }

  void _sesuaikan() {
    if (!widget.fitToContent || _sudahMenyesuaikan) {
      return;
    }

    final List<LatLng> semua = <LatLng>[
      ...widget.route,
      ...widget.pins.map((MapPin p) => p.position),
    ];

    if (semua.length < 2) {
      return;
    }

    _sudahMenyesuaikan = true;

    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: semua,

        // Padding-nya tidak simetris: bagian bawah lebih besar karena layar
        // pelacakan menaruh panel informasi di sana, dan rute yang tersembunyi
        // di belakang panel terlihat seperti rute yang terpotong.
        padding: const EdgeInsets.only(
          left: 48,
          right: 48,
          top: 64,
          bottom: 200,
        ),
      ),
    );
  }
}

class _Penanda extends StatelessWidget {
  const _Penanda({required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: pin.size,
          height: pin.size,
          decoration: BoxDecoration(
            color: pin.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(pin.icon, color: Colors.white, size: pin.size * 0.5),
        ),
      ],
    );
  }
}
