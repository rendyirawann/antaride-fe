import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Kolom alamat dengan saran, seperti kolom pencarian di aplikasi peta.
///
/// ============================================================================
///  KENAPA MENGETIK ALAMAT HARUS DIBANTU
/// ============================================================================
///  Versi sebelumnya hanya kolom teks biasa: apa pun yang diketik pengguna
///  dipakai apa adanya sebagai alamat, dan titik order tetap diambil dari
///  tengah peta.
///
///  Akibatnya alamat dan koordinat bisa menunjuk ke tempat yang BERBEDA —
///  seseorang mengetik "Jl. Gatot Subroto No. 12" sementara petanya masih di
///  posisi bawaan, lalu drivernya berangkat ke titik yang tidak ada
///  hubungannya dengan tulisan di layarnya. Tidak ada satu pun galat: kedua
///  nilainya sah, hanya tidak sepakat.
///
///  Di sini memilih saran MEMINDAHKAN peta ke koordinat saran itu, jadi kedua
///  nilainya selalu berasal dari satu sumber.
/// ============================================================================
///
/// ============================================================================
///  MENGETIK BEBAS TETAP BOLEH
/// ============================================================================
///  Saran adalah bantuan, bukan syarat. Banyak alamat di Medan dan Deli Serdang
///  tidak ada di peta mana pun — gang tanpa nama, patokan warung, rumah yang
///  hanya dikenal tetangganya.
///
///  Jadi teks yang diketik tetap dipakai walaupun tidak cocok dengan satu pun
///  saran, dan koordinatnya tetap dari peta. Kolom yang menolak alamat di luar
///  daftar akan membuat sebagian orang tidak bisa memesan sama sekali.
/// ============================================================================
class PlaceSearchField extends StatefulWidget {
  const PlaceSearchField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onPilih,
    this.dekatLat,
    this.dekatLng,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  /// Dipanggil saat pengguna memilih salah satu saran. Layar pemanggil
  /// memindahkan petanya ke koordinat ini.
  final void Function(Place) onPilih;

  /// Titik acuan untuk mengurutkan hasil dari yang terdekat.
  final double? dekatLat;
  final double? dekatLng;

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  Timer? _tunda;

  List<Place> _saran = const <Place>[];
  bool _mencari = false;

  /// Ditutup setelah memilih, supaya daftar tidak muncul lagi hanya karena
  /// teksnya berubah oleh pilihan itu sendiri.
  bool _tertutup = true;

  @override
  void dispose() {
    _tunda?.cancel();
    super.dispose();
  }

  void _ketik(String nilai) {
    _tunda?.cancel();

    if (nilai.trim().length < 3) {
      setState(() {
        _saran = const <Place>[];
        _mencari = false;
      });

      return;
    }

    setState(() {
      _tertutup = false;
      _mencari = true;
    });

    /*
     * Ditahan 400 ms setelah ketikan TERAKHIR.
     *
     * Tanpa penahanan ini, mengetik "lubuk pakam" mengirim sebelas permintaan —
     * satu per huruf — dan sepuluh di antaranya jawabannya sudah tidak relevan
     * sebelum sampai. Yang dihabiskan bukan hanya kuota geocoder tapi juga
     * kuota data pengguna.
     *
     * 400 ms dipilih dari kecepatan mengetik: di bawah 300 ms, pengetik cepat
     * masih memicu permintaan di tengah kata; di atas 600 ms, jeda antara
     * berhenti mengetik dan munculnya saran mulai terasa seperti aplikasi yang
     * menggantung.
     */
    _tunda = Timer(const Duration(milliseconds: 400), () => _cari(nilai));
  }

  Future<void> _cari(String kueri) async {
    final AntarideServices services = context.read<AntarideServices>();

    final List<Place> hasil = await services.places.search(
      kueri,
      lat: widget.dekatLat,
      lng: widget.dekatLng,
    );

    if (!mounted) {
      return;
    }

    /*
     * Jawaban yang datang terlambat DIBUANG.
     *
     * Dua permintaan bisa hidup bersamaan kalau pengguna mengetik lagi sebelum
     * yang pertama selesai, dan urutan datangnya tidak dijamin. Tanpa
     * pemeriksaan ini, jawaban untuk "lubuk" bisa tiba SETELAH jawaban untuk
     * "lubuk pakam" dan menimpanya — daftar sarannya jadi tidak cocok dengan
     * yang tertulis di kolom, dan itu terlihat seperti hasil yang acak.
     */
    if (widget.controller.text.trim() != kueri.trim()) {
      return;
    }

    setState(() {
      _mencari = false;
      _saran = hasil;
    });
  }

  void _pilih(Place tempat) {
    // Teks diisi dari alamat lengkap, bukan namanya saja: yang dibaca driver
    // nanti adalah teks ini, dan nama tempat tanpa jalannya tidak cukup untuk
    // menemukan lokasi.
    widget.controller.text = tempat.address;

    setState(() {
      _tertutup = true;
      _saran = const <Place>[];
      _mencari = false;
    });

    FocusScope.of(context).unfocus();

    widget.onPilih(tempat);
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    // Fitur ini disembunyikan seluruhnya kalau server tidak punya geocoder.
    // Kolom pencarian yang tidak pernah menemukan apa pun terbaca sebagai
    // aplikasi rusak, bukan sebagai fitur yang belum dinyalakan.
    final bool menyala = context.select<ServerConfigController, bool>(
      (ServerConfigController c) => c.config.placesEnabled,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClayInput(
          controller: widget.controller,
          label: widget.label,
          hint: widget.hint,
          prefixIcon: widget.icon,
          maxLength: 200,
          onChanged: menyala ? _ketik : null,
        ),

        if (menyala && !_tertutup) ...<Widget>[
          const SizedBox(height: ClayTokens.space2),

          if (_mencari)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: ClayTokens.space3),
              child: ClayInlineLoader(size: 16),
            )
          else if (_saran.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: ClayTokens.space2,
                horizontal: ClayTokens.space2,
              ),
              child: Text(
                'Alamat tidak ditemukan. Anda tetap bisa mengetiknya sendiri '
                'dan menggeser peta ke titik yang benar.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  height: 1.45,
                  color: gelap
                      ? ClayTokens.textTertiaryDark
                      : ClayTokens.textTertiary,
                ),
              ),
            )
          else
            /*
             * Tinggi daftar DIBATASI.
             *
             * Panel ini duduk di atas peta dan tumbuh ke atas. Delapan saran
             * tanpa batas tinggi akan mendorong tombol lanjut keluar layar di
             * HP pendek — dan tombol itulah satu-satunya jalan maju.
             */
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 196),
              child: ClaySurface(
                depth: ClayDepth.pressed,
                radius: ClayTokens.radiusSmall,
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _saran.length,
                  separatorBuilder: (BuildContext _, int _) => Divider(
                    height: 1,
                    color: ClayTokens.textTertiary.withValues(alpha: 0.18),
                  ),
                  itemBuilder: (BuildContext _, int i) => _BarisSaran(
                    tempat: _saran[i],
                    onTekan: () => _pilih(_saran[i]),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Satu baris saran: nama tebal, alamat lengkap kecil di bawahnya.
class _BarisSaran extends StatelessWidget {
  const _BarisSaran({required this.tempat, required this.onTekan});

  final Place tempat;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTekan,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ClayTokens.space4,
          vertical: ClayTokens.space3,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.place_outlined,
              size: 18,
              color: gelap
                  ? ClayTokens.textTertiaryDark
                  : ClayTokens.textTertiary,
            ),

            const SizedBox(width: ClayTokens.space3),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tempat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: gelap
                          ? ClayTokens.textPrimaryDark
                          : ClayTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    tempat.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: gelap
                          ? ClayTokens.textTertiaryDark
                          : ClayTokens.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
