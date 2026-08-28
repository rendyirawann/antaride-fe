import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';

/// Kartu satu tawaran order.
///
/// ============================================================================
///  EMPAT ANGKA, DALAM URUTAN YANG DIPUTUSKAN DRIVER
/// ============================================================================
///  Driver punya belasan detik untuk memutuskan, sering sambil memegang HP di
///  satu tangan. Yang dia baca, dalam urutan ini:
///
///    1. Pendapatan          apakah sebanding
///    2. Jarak ke penjemputan  yang paling sering menggagalkan tawaran — order
///                             Rp 40.000 dengan jemputan 6 km sering kurang
///                             menarik dibanding Rp 20.000 dengan jemputan 400 m
///    3. Tunai atau tidak    menentukan apakah dia perlu menyiapkan kembalian
///    4. Tujuan              apakah searah dengan rencananya
///
///  Apa pun yang bukan salah satu dari empat itu TIDAK ada di kartu ini. Nomor
///  HP penumpang khususnya: driver yang belum menerima order tidak punya alasan
///  menghubunginya, dan kalau nomornya dikirim di tahap tawaran, satu driver
///  bisa mengumpulkan nomor dari tawaran yang dia tolak semuanya.
/// ============================================================================
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.busy,
    required this.onTerima,
    required this.onTolak,
  });

  final DriverOffer offer;
  final bool busy;
  final VoidCallback onTerima;
  final VoidCallback onTolak;

  @override
  Widget build(BuildContext context) {
    final int sisa = offer.secondsLeft;
    final bool hampirHabis = sisa <= 5;

    return ClaySurface(
      depth: ClayDepth.high,
      radius: ClayTokens.radiusLarge,
      margin: const EdgeInsets.only(bottom: ClayTokens.space4),
      padding: const EdgeInsets.all(ClayTokens.space5),
      borderColor: hampirHabis ? ClayTokens.danger : ClayTokens.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Hitungan mundur di paling atas, sebagai bilah. Angka saja mudah
          // terlewat; bilah yang menyusut terlihat tanpa dibaca.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              // Dibagi 15 detik — masa berlaku tawaran di backend. Kalau
              // nilainya lebih besar, bilahnya penuh dan tetap benar; yang
              // penting adalah dia menyusut sampai nol pada waktu yang sama
              // dengan tawarannya.
              value: (sisa / 15).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: ClayTokens.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(
                hampirHabis ? ClayTokens.danger : ClayTokens.primary,
              ),
            ),
          ),

          const SizedBox(height: ClayTokens.space4),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Pendapatan Anda',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ClayMoney(
                      // Pendapatan DRIVER, bukan total ongkos penumpang. Backend
                      // tidak mengirimkan total ongkos di tawaran, dan itu
                      // sengaja: di dalamnya ada komisi dan diskon promo, dan
                      // keduanya bukan urusan driver.
                      formatted: offer.earning.formatted,
                      size: ClayMoneySize.hero,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ClayTokens.space3,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: offer.isCash
                          ? ClayTokens.warning.withValues(alpha: 0.15)
                          : ClayTokens.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      offer.isCash ? 'TUNAI' : 'DOMPET',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: offer.isCash
                            ? ClayTokens.warning
                            : ClayTokens.info,
                      ),
                    ),
                  ),
                  const SizedBox(height: ClayTokens.space2),
                  Text(
                    '$sisa detik',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: hampirHabis
                          ? ClayTokens.danger
                          : ClayTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: ClayTokens.space4),

          ClaySurface(
            depth: ClayDepth.pressed,
            padding: const EdgeInsets.all(ClayTokens.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Titik(
                  icon: Icons.trip_origin_rounded,
                  warna: ClayTokens.primary,
                  // Jarak ke penjemputan ditempel di label titiknya, bukan
                  // ditaruh di baris terpisah. Ini angka kedua terpenting, dan
                  // di baris terpisah dia terbaca sebagai keterangan tambahan.
                  label:
                      '${offer.pickupDistanceKm.toStringAsFixed(1)} km dari '
                      'Anda',
                  teks: offer.pickup.address,
                ),
                if (offer.destination != null) ...<Widget>[
                  const SizedBox(height: ClayTokens.space3),
                  _Titik(
                    icon: Icons.place_rounded,
                    warna: ClayTokens.danger,
                    label:
                        'Perjalanan '
                        '${(offer.distanceM / 1000).toStringAsFixed(1)} km',
                    teks: offer.destination!.address,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: ClayTokens.space4),

          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: ClayButton(
                  label: 'Lewati',
                  variant: ClayButtonVariant.ghost,
                  height: ClayTokens.driverPrimaryButtonHeight,
                  onPressed: busy ? null : onTolak,
                ),
              ),
              const SizedBox(width: ClayTokens.space3),
              Expanded(
                flex: 3,
                child: ClayButton(
                  label: 'Terima',
                  icon: Icons.check_rounded,
                  isLoading: busy,
                  height: ClayTokens.driverPrimaryButtonHeight,
                  onPressed: busy ? null : onTerima,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Titik extends StatelessWidget {
  const _Titik({
    required this.icon,
    required this.warna,
    required this.label,
    required this.teks,
  });

  final IconData icon;
  final Color warna;
  final String label;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: warna),
        ),
        const SizedBox(width: ClayTokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: warna,
                ),
              ),
              Text(
                teks,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
