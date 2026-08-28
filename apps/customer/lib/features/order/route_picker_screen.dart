import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'order_flow_controller.dart';
import 'quote_screen.dart';

/// Pilih titik jemput dan tujuan.
///
/// ============================================================================
///  TITIKNYA DIPILIH DENGAN MENGGESER PETA, BUKAN DENGAN MENEKANNYA
/// ============================================================================
///  Pin-nya TETAP di tengah layar, dan petanya yang bergerak di belakangnya.
///
///  Alasannya bukan estetika. Menekan peta untuk menaruh pin menuntut ketepatan
///  jari di titik yang sekaligus tertutup jari itu sendiri — dan setiap koreksi
///  kecil menuntut menekan lagi. Dengan pin di tengah, jari menggeser dari mana
///  saja di layar dan pin-nya selalu terlihat.
///
///  Ini juga pola yang dipakai Gojek dan Grab, jadi pengguna di Medan sudah
///  mengenalnya — dan pola yang dikenal tidak perlu dijelaskan.
/// ============================================================================
class RoutePickerScreen extends StatefulWidget {
  const RoutePickerScreen({super.key, required this.serviceCode});

  /// Layanan yang dipilih di beranda. Dipakai membatasi quote supaya
  /// perhitungannya lebih ringan dan response-nya lebih kecil.
  final String serviceCode;

  @override
  State<RoutePickerScreen> createState() => _RoutePickerScreenState();
}

enum _Tahap { jemput, tujuan }

class _RoutePickerScreenState extends State<RoutePickerScreen> {
  final TextEditingController _alamat = TextEditingController();
  final TextEditingController _catatan = TextEditingController();
  final LocationService _lokasi = const LocationService();

  _Tahap _tahap = _Tahap.jemput;
  LatLng _tengah = medanCenter;
  bool _mencariPosisi = true;

  @override
  void initState() {
    super.initState();

    _posisiAwal();
  }

  @override
  void dispose() {
    _alamat.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _posisiAwal() async {
    final LocationOutcome hasil = await _lokasi.current();

    if (!mounted) {
      return;
    }

    setState(() {
      _mencariPosisi = false;

      if (hasil is LocationReady) {
        _tengah = hasil.position;
      }

      // Kalau lokasi tidak tersedia, peta tetap terbuka di pusat Medan dan
      // pengguna menggeser sendiri. Yang TIDAK dilakukan: menolak melanjutkan.
      // Izin lokasi memudahkan, bukan mensyaratkan — dan orang yang menolaknya
      // tetap harus bisa memesan.
    });
  }

  Future<void> _lanjut() async {
    final OrderFlowController alur = context.read<OrderFlowController>();

    final String alamat = _alamat.text.trim();

    final ChosenPlace tempat = ChosenPlace(
      position: _tengah,
      address: alamat.isEmpty ? _alamatCadangan() : alamat,
      note: _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
    );

    if (_tahap == _Tahap.jemput) {
      alur.setPickup(tempat);

      setState(() {
        _tahap = _Tahap.tujuan;
        _alamat.clear();
        _catatan.clear();
      });

      return;
    }

    alur.setDestination(tempat);

    final Order? dibuat = await Navigator.of(context).push<Order>(
      MaterialPageRoute<Order>(
        builder: (BuildContext _) =>
            ChangeNotifierProvider<OrderFlowController>.value(
              // Controller yang SAMA diteruskan, bukan yang baru. Alur pemesanan
              // adalah satu state yang melintasi tiga layar — lihat docblock
              // OrderFlowController.
              value: alur,
              child: QuoteScreen(serviceCode: widget.serviceCode),
            ),
      ),
    );

    if (!mounted || dibuat == null) {
      return;
    }

    // Order diteruskan ke beranda sebagai hasil layar ini, dan bersamanya
    // seluruh alur pemilihan titik ikut ditutup. Beranda yang membuka layar
    // pelacakan.
    Navigator.of(context).pop(dibuat);
  }

  /// Alamat pengganti kalau pengguna tidak mengetik apa pun.
  ///
  /// Koordinat, dibulatkan lima desimal — sekitar satu meter, yang cukup untuk
  /// driver menemukannya lewat navigasi. Lebih baik daripada string kosong,
  /// yang di layar driver terbaca sebagai order tanpa alamat.
  String _alamatCadangan() {
    final String lat = _tengah.latitude.toStringAsFixed(5);
    final String lng = _tengah.longitude.toStringAsFixed(5);

    return 'Titik $lat, $lng';
  }

  @override
  Widget build(BuildContext context) {
    final bool jemput = _tahap == _Tahap.jemput;

    final OrderFlowController alur = context.watch<OrderFlowController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(jemput ? 'Titik penjemputan' : 'Titik tujuan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Kembali dari tahap tujuan mengembalikan ke tahap jemput, bukan
            // keluar dari alur. Pengguna yang ingin memperbaiki titik jemput
            // tidak harus memulai dari beranda lagi.
            if (_tahap == _Tahap.tujuan) {
              setState(() {
                _tahap = _Tahap.jemput;
                _alamat.text = alur.pickup?.address ?? '';
                _catatan.text = alur.pickup?.note ?? '';
                _tengah = alur.pickup?.position ?? _tengah;
              });

              return;
            }

            Navigator.of(context).maybePop();
          },
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AntarideMap(
                  center: _tengah,
                  fitToContent: false,
                  onCenterChanged: (LatLng titik) {
                    // Hanya menyimpan, TIDAK memanggil quote. Quote diminta
                    // sekali di layar berikutnya, setelah kedua titik pasti.
                    _tengah = titik;
                  },
                  pins: <MapPin>[
                    if (!jemput && alur.pickup != null)
                      MapPin(
                        position: alur.pickup!.position,
                        icon: Icons.trip_origin_rounded,
                        color: ClayTokens.primary,
                        size: 32,
                      ),
                  ],
                ),

                // Pin tengah, TIDAK ikut bergerak. Lihat docblock kelas.
                IgnorePointer(
                  child: Padding(
                    // Digeser ke atas separuh tinggi pin supaya UJUNG BAWAHNYA
                    // yang menunjuk ke tengah layar, bukan pusatnya.
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.place_rounded,
                      size: 44,
                      color: jemput ? ClayTokens.primary : ClayTokens.danger,
                      shadows: <Shadow>[
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_mencariPosisi)
                  const Positioned(
                    top: ClayTokens.space4,
                    child: ClaySurface(
                      depth: ClayDepth.medium,
                      radius: ClayTokens.radiusPill,
                      padding: EdgeInsets.symmetric(
                        horizontal: ClayTokens.space4,
                        vertical: ClayTokens.space2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ClayInlineLoader(size: 12, color: ClayTokens.primary),
                          SizedBox(width: ClayTokens.space3),
                          Text(
                            'Mencari posisi Anda…',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          ClaySurface(
            depth: ClayDepth.high,
            radius: 0,
            padding: const EdgeInsets.all(ClayTokens.space5),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ClayInput(
                    controller: _alamat,
                    label: jemput ? 'Alamat penjemputan' : 'Alamat tujuan',
                    hint: jemput
                        ? 'Jl. Gatot Subroto No. 12'
                        : 'Jl. Iskandar Muda No. 4',
                    prefixIcon: jemput
                        ? Icons.trip_origin_rounded
                        : Icons.place_rounded,
                    maxLength: 200,
                  ),

                  if (jemput) ...<Widget>[
                    const SizedBox(height: ClayTokens.space3),
                    ClayInput(
                      controller: _catatan,
                      label: 'Catatan untuk driver',
                      // Contoh yang diberikan sengaja spesifik. Kolom catatan
                      // dengan hint "opsional" hampir selalu dibiarkan kosong,
                      // padahal justru keterangan seperti inilah yang membuat
                      // driver menemukan titiknya tanpa menelepon.
                      hint: 'Pagar hitam, sebelah warung',
                      maxLength: 120,
                    ),
                  ],

                  const SizedBox(height: ClayTokens.space4),

                  ClayButton(
                    label: jemput ? 'Lanjut pilih tujuan' : 'Lihat harga',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _lanjut,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
