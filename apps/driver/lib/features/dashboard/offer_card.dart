import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';

/// Aksen aplikasi driver. Sama dengan yang dipakai dasbor — disalin sebagai
/// konstanta berkas, bukan diimpor dari layar dasbor, supaya kartu ini tidak
/// bergantung balik pada layar yang menampungnya.
const Color _aksen = ClayTokens.primaryDark;

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
///
///  Perombakan v2 hanya menata panggungnya — urutan keempat angka itu keputusan
///  produk, dan tidak satu pun angka baru ditambahkan.
/// ============================================================================
///
/// ============================================================================
///  TANPA ANIMASI, DAN ITU DISENGAJA
/// ============================================================================
///  Widget ini STATELESS dan digerakkan `setState` dari `Timer.periodic` satu
///  detik milik dasbor. Setiap animasi masuk — ClayEntrance, fade, scale —
///  berisiko diputar ulang tiap detik begitu daftar tawaran berubah panjang
///  dan elemennya bergeser posisi. Kartu yang berkedip di bawah jempol yang
///  sedang bergerak ke "Terima" adalah kegagalan yang jauh lebih mahal
///  daripada animasi masuk yang tidak ada.
///
///  Yang menarik perhatian ke tawaran baru di sini adalah bidang gradien di
///  kepala kartu, bukan gerakan.
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
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final int sisa = offer.secondsLeft;
    final bool hampirHabis = sisa <= 5;

    final Color warna = hampirHabis ? ClayTokens.danger : _aksen;

    return ClaySurface(
      depth: ClayDepth.high,
      radius: ClayTokens.radiusLarge,
      margin: const EdgeInsets.only(bottom: ClayTokens.space4),

      // Padding NOL: kepala hitungan mundur harus menempel ke tiga tepi kartu.
      // Isi selebihnya memberi paddingnya sendiri di bawah.
      padding: EdgeInsets.zero,
      borderColor: warna,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _KepalaHitungMundur(sisa: sisa, warna: warna),

          Padding(
            padding: const EdgeInsets.all(ClayTokens.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Pendapatan Anda',
                            style: TextStyle(
                              fontFamily: ClayTokens.fontFamily,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: gelap
                                  ? ClayTokens.textTertiaryDark
                                  : ClayTokens.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Angka terbesar di kartu, dan harus tetap terbesar:
                          // diperkecil hanya kalau nominalnya benar-benar tidak
                          // muat, bukan dipotong ellipsis.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: ClayMoney(
                              // Pendapatan DRIVER, bukan total ongkos
                              // penumpang. Backend tidak mengirimkan total
                              // ongkos di tawaran, dan itu sengaja: di dalamnya
                              // ada komisi dan diskon promo, dan keduanya bukan
                              // urusan driver.
                              formatted: offer.earning.formatted,
                              size: ClayMoneySize.hero,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: ClayTokens.space3),
                    _LencanaPembayaran(tunai: offer.isCash),
                  ],
                ),

                const SizedBox(height: ClayTokens.space4),

                ClaySurface(
                  depth: ClayDepth.pressed,
                  padding: const EdgeInsets.all(ClayTokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Titik(
                        icon: Icons.trip_origin_rounded,
                        warna: _aksen,
                        // Jarak ke penjemputan ditempel di label titiknya, bukan
                        // ditaruh di baris terpisah. Ini angka kedua terpenting,
                        // dan di baris terpisah dia terbaca sebagai keterangan
                        // tambahan.
                        label:
                            '${offer.pickupDistanceKm.toStringAsFixed(1)} km '
                            'dari Anda',
                        teks: offer.pickup.address,
                      ),
                      if (offer.destination != null) ...<Widget>[
                        const SizedBox(height: ClayTokens.space3),
                        _Titik(
                          icon: Icons.place_rounded,
                          warna: ClayTokens.danger,
                          label:
                              'Perjalanan '
                              '${(offer.distanceM / 1000).toStringAsFixed(1)} '
                              'km',
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
          ),
        ],
      ),
    );
  }
}

/// Kepala kartu: bidang gradien berisi sisa waktu dan bilah yang menyusut.
///
/// ============================================================================
///  KENAPA HITUNGAN MUNDUR MENDAPAT BIDANG SENDIRI
/// ============================================================================
///  Versi lama menyampaikan sisa waktu lewat bilah 5 px dan teks 12 px di sudut
///  kanan. Keduanya menuntut layar ditatap; kartu ini justru dibaca dari
///  dudukan HP di motor, dengan sisa waktu belasan detik.
///
///  Di sini sisa waktunya jadi angka 30 px putih di atas bidang gradien yang
///  menempel ke tepi atas kartu — dan seluruh bidang itu berubah dari hijau
///  aksen ke merah pada lima detik terakhir. Yang berubah warna adalah bidang,
///  bukan garis: itu yang membuatnya terbaca dari sudut mata.
///
///  Bilahnya tetap ada di bawah angka, dipertebal jadi 8 px: angka menyampaikan
///  BERAPA, bilah menyampaikan SEBERAPA CEPAT habisnya tanpa dibaca.
/// ============================================================================
class _KepalaHitungMundur extends StatelessWidget {
  const _KepalaHitungMundur({required this.sisa, required this.warna});

  final int sisa;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      /*
       * Radius kepala dikurangi lebar border kartu (1,5 px).
       *
       * `ClaySurface` menggambar bordernya di dalam kotaknya lalu menggeser
       * anaknya masuk sebesar lebar border itu. Kepala dengan radius yang sama
       * persis dengan kartunya akan menonjol setipis rambut melewati lengkung
       * bordernya di keempat sudut — tidak bisa disebut namanya, tapi terlihat
       * sebagai sudut yang kotor.
       */
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(ClayTokens.radiusLarge - 1.5),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: ClayGradients.hero(warna)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ClayTokens.space5,
            ClayTokens.space4,
            ClayTokens.space5,
            ClayTokens.space4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'SISA WAKTU',
                      style: TextStyle(
                        fontFamily: ClayTokens.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        height: 1.0,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                  Text(
                    '$sisa',
                    style: const TextStyle(
                      fontFamily: ClayTokens.fontFamily,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      height: 1.0,
                      color: Colors.white,

                      // Angka berlebar tetap. Tanpa ini "13" dan "12" punya
                      // lebar berbeda, dan kata "detik" di sebelahnya bergeser
                      // sekali setiap detik.
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'detik',
                      style: TextStyle(
                        fontFamily: ClayTokens.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: ClayTokens.space3),

              ClipRRect(
                borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
                child: LinearProgressIndicator(
                  // Dibagi 15 detik — masa berlaku tawaran di backend. Kalau
                  // nilainya lebih besar, bilahnya penuh dan tetap benar; yang
                  // penting adalah dia menyusut sampai nol pada waktu yang sama
                  // dengan tawarannya.
                  value: (sisa / 15).clamp(0.0, 1.0),
                  minHeight: 8,

                  // Track dan isian keduanya putih-alpha, bukan warna token:
                  // bilah ini duduk di atas gradien, dan warna pucat clay di
                  // sini terbaca sebagai lubang di bidangnya.
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lencana cara bayar: TUNAI atau DOMPET.
///
/// Tetap pil bernada lembut, bukan gradien pekat: gradien di kartu ini sudah
/// dipakai kepala hitungan mundur, dan pil kedua yang sama pekatnya akan
/// bersaing dengan angka pendapatan — yang harus tetap menang.
class _LencanaPembayaran extends StatelessWidget {
  const _LencanaPembayaran({required this.tunai});

  final bool tunai;

  @override
  Widget build(BuildContext context) {
    final Color warna = tunai ? ClayTokens.warning : ClayTokens.info;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space3,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
        border: Border.all(color: warna.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            tunai
                ? Icons.payments_rounded
                : Icons.account_balance_wallet_rounded,
            size: 14,
            color: warna,
          ),
          const SizedBox(width: 5),
          Text(
            tunai ? 'TUNAI' : 'DOMPET',
            style: TextStyle(
              fontFamily: ClayTokens.fontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              height: 1.0,
              color: warna,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu titik rute: chip gradien, jaraknya, lalu alamatnya.
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
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Chip gradien 30 px menggantikan ikon telanjang 15 px. Di panel yang
        // tenggelam, ikon setipis itu hilang sama sekali di bawah matahari —
        // dan dua titik yang tidak bisa dibedakan membuat alamat jemput dan
        // alamat tujuan tertukar.
        ClayIconChip(icon: icon, accent: warna, size: 30),
        const SizedBox(width: ClayTokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontFamily: ClayTokens.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: warna,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                teks,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: ClayTokens.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: gelap
                      ? ClayTokens.textPrimaryDark
                      : ClayTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
