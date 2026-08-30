import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'order_flow_controller.dart';

/// Pilih layanan, lihat harga, lalu pesan.
///
/// ============================================================================
///  KOMPOSISI V2: HERO TIPIS → PETA → PANEL KEPUTUSAN → BILAH TOTAL
/// ============================================================================
///  Ini layar keputusan terpenting penumpang, dan hierarkinya disusun begitu:
///  hero gradien compact hanya penanda konteks (judul + kembali), peta cukup
///  untuk memastikan rutenya benar, lalu SEMUA keputusan (layanan, bayar,
///  promo) hidup di satu panel bersudut atas 36 yang menimpa tepi bawah peta —
///  cermin sudut hero, supaya panelnya terbaca sebagai lapisan konten, bukan
///  potongan layar. Total + tombol pesan menetap di bilah bawah: dua hal yang
///  tidak boleh ikut tergulir.
///
///  Hero penuh sengaja TIDAK dipakai: peta harus tetap terlihat, dan hero
///  setinggi beranda akan mendorong kartu layanan ke bawah lipatan di HP
///  pendek — padahal kartu layanan adalah alasan layar ini ada.
/// ============================================================================
class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key, required this.serviceCode});

  final String serviceCode;

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  Timer? _detik;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderFlowController>().loadQuote(
        serviceCodes: <String>[widget.serviceCode],
      );
    });

    /*
     * Timer satu detik untuk menggerakkan hitungan mundur masa berlaku quote.
     *
     * Berjalan terus, bukan hanya saat quote hidup: yang menentukan apa yang
     * tampil adalah `Quote.secondsUntilExpiry`, dan menghentikan timer saat
     * quote kadaluarsa berarti label "kadaluarsa" tidak pernah muncul karena
     * tidak ada rebuild yang menampilkannya.
     */
    _detik = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _detik?.cancel();
    super.dispose();
  }

  Future<void> _pesan() async {
    final OrderFlowController alur = context.read<OrderFlowController>();

    final Order? order = await alur.submit();

    if (!mounted) {
      return;
    }

    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alur.failure?.message ?? 'Tidak bisa membuat order. Coba lagi.',
          ),
          backgroundColor: ClayTokens.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    /*
     * Order dikembalikan sebagai HASIL layar ini, bukan dipakai untuk push
     * layar pelacakan dari sini.
     *
     * `RoutePickerScreen` meneruskannya ke beranda, dan beranda yang membuka
     * pelacakan. Kalau pelacakan di-push dari sini, tombol kembali dari
     * pelacakan akan membawa penumpang ke layar quote untuk order yang SUDAH
     * dia pesan — dengan tombol "Pesan sekarang" yang masih aktif.
     */
    Navigator.of(context).pop(order);
  }

  Future<void> _pilihPromo() async {
    final OrderFlowController alur = context.read<OrderFlowController>();

    final List<QuotePromo> promos = alur.quote?.promos ?? const <QuotePromo>[];

    if (promos.isEmpty) {
      return;
    }

    await ClayBottomSheet.show<void>(
      context: context,
      title: 'Pilih promo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final QuotePromo p in promos)
            ClayCard(
              onTap: () {
                alur.setPromoCode(p.code);
                Navigator.of(context).pop();
              },
              child: Row(
                children: <Widget>[
                  const ClayIconChip(
                    icon: Icons.local_offer_rounded,
                    accent: ClayTokens.primary,
                    size: 36,
                  ),
                  const SizedBox(width: ClayTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          p.title,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          p.code,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? ClayTokens.textSecondaryDark
                                : ClayTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (alur.promoCode == p.code)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: ClayTokens.primary,
                      size: 20,
                    ),
                ],
              ),
            ),
          if (alur.promoCode != null)
            ClayButton(
              label: 'Hapus promo',
              variant: ClayButtonVariant.ghost,
              onPressed: () {
                alur.setPromoCode(null);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final OrderFlowController alur = context.watch<OrderFlowController>();
    final Quote? quote = alur.quote;
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: <Widget>[
          const ClayEntrance(
            index: 0,
            child: ClayHeroHeader(
              accent: ClayTokens.primary,
              compact: true,
              title: 'Konfirmasi pesanan',
              leading: ClayBackButton(),
            ),
          ),

          Expanded(
            child: Stack(
              children: <Widget>[
                /*
                 * Peta rute, sepertiga atas. Cukup untuk memastikan tujuannya
                 * benar, dan tidak lebih — yang perlu dibandingkan di layar
                 * ini adalah harga antar layanan, bukan bentuk rutenya.
                 *
                 * Peta di lapisan BAWAH Stack dan panel isi menimpanya 24 px:
                 * platform view tidak boleh dianimasikan/di-transform, tapi
                 * ditindih lapisan lain aman — dan tindihan itulah yang
                 * membuat sambungan peta→konten tidak lagi garis lurus keras.
                 */
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 190,
                    child: AntarideMap(
                      interactive: false,
                      route: alur.routePoints,
                      pins: <MapPin>[
                        if (alur.pickup != null)
                          MapPin(
                            position: alur.pickup!.position,
                            icon: Icons.trip_origin_rounded,
                            color: ClayTokens.primary,
                            size: 30,
                          ),
                        if (alur.destination != null)
                          MapPin(
                            position: alur.destination!.position,
                            icon: Icons.place_rounded,
                            color: ClayTokens.danger,
                            size: 30,
                          ),
                      ],
                    ),
                  ),
                ),

                // Panel keputusan: sudut atas 36 mencerminkan sudut bawah hero.
                Positioned.fill(
                  top: 166,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: gelap
                          ? ClayTokens.surfaceDark
                          : ClayTokens.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(ClayTokens.radiusLarge),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: gelap ? 0.35 : 0.08,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: alur.isLoadingQuote && quote == null
                        ? const ClayLoader(message: 'Menghitung harga…')
                        : quote == null
                        ? ClayErrorState(
                            message:
                                alur.failure?.message ??
                                'Tidak bisa menghitung harga.',
                            onRetry: () => alur.loadQuote(
                              serviceCodes: <String>[widget.serviceCode],
                            ),
                          )
                        : _Isi(
                            quote: quote,
                            alur: alur,
                            onPilihPromo: _pilihPromo,
                          ),
                  ),
                ),
              ],
            ),
          ),

          if (quote != null)
            _BilahBawah(
              alur: alur,
              quote: quote,
              onPesan: _pesan,
              onSegarkan: () =>
                  alur.loadQuote(serviceCodes: <String>[widget.serviceCode]),
            ),
        ],
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({
    required this.quote,
    required this.alur,
    required this.onPilihPromo,
  });

  final Quote quote;
  final OrderFlowController alur;
  final VoidCallback onPilihPromo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ClayTokens.space5,
        ClayTokens.space6,
        ClayTokens.space5,
        ClayTokens.space5,
      ),
      children: <Widget>[
        ClayEntrance(index: 0, child: _Ringkasan(quote: quote)),

        const SizedBox(height: ClayTokens.space6),

        /*
         * Satu ClayEntrance per BAGIAN, bukan per kartu: daftar layanan bisa
         * 2–4 kartu, dan giliran per kartu membuat total animasinya melewati
         * ~750 ms — layar keputusan tidak boleh menunggu dekorasinya sendiri.
         */
        ClayEntrance(
          index: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(bottom: ClayTokens.space3),
                child: ClaySectionLabel('Pilih layanan'),
              ),
              for (final QuoteService s in quote.services)
                _KartuLayanan(
                  layanan: s,
                  terpilih: alur.serviceCode == s.code,
                  potongan: alur.promoCode == null
                      ? null
                      : quote.discountFor(
                          promoCode: alur.promoCode!,
                          serviceCode: s.code,
                        ),
                  onTap: s.isOrderable
                      ? () => alur.selectService(s.code)
                      : null,
                ),
            ],
          ),
        ),

        const SizedBox(height: ClayTokens.space5),

        ClayEntrance(
          index: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(bottom: ClayTokens.space3),
                child: ClaySectionLabel('Metode pembayaran'),
              ),
              _PilihanBayar(alur: alur),
            ],
          ),
        ),

        const SizedBox(height: ClayTokens.space5),

        ClayEntrance(
          index: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(bottom: ClayTokens.space3),
                child: ClaySectionLabel('Promo'),
              ),
              _KartuPromo(
                quote: quote,
                promoCode: alur.promoCode,
                onTap: quote.promos.isEmpty ? null : onPilihPromo,
              ),
            ],
          ),
        ),

        const SizedBox(height: ClayTokens.space5),

        if (alur.selectedService != null)
          ClayEntrance(
            index: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(bottom: ClayTokens.space3),
                  child: ClaySectionLabel('Rincian ongkos'),
                ),
                ClaySurface(
                  depth: ClayDepth.pressed,
                  child: Column(
                    children: <Widget>[
                      for (final FareLine baris
                          in alur.selectedService!.fareLines)
                        ClayMoneyRow(
                          label: baris.label,
                          formatted: baris.formatted,
                        ),

                      if (alur.promoDiscount != null && alur.promoDiscount! > 0)
                        ClayMoneyRow(
                          label: 'Potongan promo',
                          formatted: '-Rp ${_ribuan(alur.promoDiscount!)}',
                        ),

                      const Divider(height: ClayTokens.space5),

                      ClayMoneyRow(
                        label: 'Total',
                        formatted: _totalTerformat(alur),
                        emphasized: true,
                        hint: alur.selectedService!.hasSurge
                            ? alur.selectedService!.surgeExplanation
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: ClayTokens.space8),
      ],
    );
  }

  /// Total setelah potongan promo.
  ///
  /// ==========================================================================
  ///  ANGKA INI TAMPILAN, BUKAN PERHITUNGAN YANG DIPERCAYA
  /// ==========================================================================
  ///  Yang ditagih adalah hasil hitungan BACKEND dari `quote_id` dan
  ///  `promo_code` yang dikirim — bukan angka ini.
  ///
  ///  Penjumlahannya di sini hanya supaya total di layar sudah memperhitungkan
  ///  promo yang baru dipilih tanpa menunggu quote baru. Kalau ada selisih
  ///  dengan yang ditagih, yang salah adalah baris ini, dan yang benar adalah
  ///  backend.
  ///
  ///  Static supaya `_BilahBawah` (yang menampilkan total di samping tombol
  ///  pesan) memakai HITUNGAN YANG SAMA — dua rumus total di satu layar pasti
  ///  menyimpang suatu hari.
  /// ==========================================================================
  static String _totalTerformat(OrderFlowController alur) {
    final QuoteService? layanan = alur.selectedService;

    if (layanan == null) {
      return 'Rp 0';
    }

    final int potongan = alur.promoDiscount ?? 0;

    if (potongan <= 0) {
      return layanan.total.formatted;
    }

    final int total = layanan.total.amount - potongan;

    return 'Rp ${_ribuan(total < 0 ? 0 : total)}';
  }

  static String _ribuan(int nilai) {
    final String digit = nilai.abs().toString();
    final StringBuffer hasil = StringBuffer();

    for (int i = 0; i < digit.length; i++) {
      if (i > 0 && (digit.length - i) % 3 == 0) {
        hasil.write('.');
      }

      hasil.write(digit[i]);
    }

    return hasil.toString();
  }
}

class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.low,
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Metrik(
              icon: Icons.straighten_rounded,
              label: 'Jarak',
              nilai: '${quote.distanceKm.toStringAsFixed(1)} km',
            ),
          ),
          Expanded(
            child: _Metrik(
              icon: Icons.schedule_rounded,
              label: 'Perkiraan',
              nilai: '${quote.durationMinutes} menit',
            ),
          ),
          if (quote.zoneName != null)
            Expanded(
              child: _Metrik(
                icon: Icons.map_rounded,
                label: 'Zona',
                nilai: quote.zoneName!,
              ),
            ),
        ],
      ),
    );
  }
}

class _Metrik extends StatelessWidget {
  const _Metrik({required this.icon, required this.label, required this.nilai});

  final IconData icon;
  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: <Widget>[
        // Chip 32: satu tingkat di bawah chip kartu (42) — metrik adalah
        // konteks, bukan pilihan, dan tidak boleh bersaing dengan kartu layanan.
        ClayIconChip(icon: icon, accent: ClayTokens.primary, size: 32),
        const SizedBox(height: ClayTokens.space2),
        Text(
          nilai,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            color: gelap
                ? ClayTokens.textTertiaryDark
                : ClayTokens.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _KartuLayanan extends StatelessWidget {
  const _KartuLayanan({
    required this.layanan,
    required this.terpilih,
    required this.onTap,
    this.potongan,
  });

  final QuoteService layanan;
  final bool terpilih;
  final VoidCallback? onTap;
  final int? potongan;

  /// Ikon per kode layanan.
  ///
  /// Duplikat sadar dari peta ikon `_KisiLayanan` di `home_screen.dart` —
  /// berkas itu di luar wilayah perombakan ini. Kalau daftar layanan berubah,
  /// dua peta ini harus diubah bersama (fallback `category_rounded` menjaga
  /// kode baru tetap tampil sementara).
  static const Map<String, IconData> _ikon = <String, IconData>{
    'ride_bike': Icons.two_wheeler_rounded,
    'ride_car': Icons.local_taxi_rounded,
    'send': Icons.local_shipping_rounded,
    'food': Icons.restaurant_rounded,
    'mart': Icons.storefront_rounded,
    'shop': Icons.shopping_bag_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final bool bisa = layanan.isOrderable;
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      // Yang terpilih TENGGELAM, yang lain timbul. Itu isyarat clay untuk
      // "sedang aktif" — dan lebih jelas daripada border berwarna pada
      // permukaan yang kontrasnya rendah.
      depth: terpilih
          ? ClayDepth.pressed
          : (bisa ? ClayDepth.low : ClayDepth.flat),
      borderColor: terpilih ? ClayTokens.primary : null,
      margin: const EdgeInsets.only(bottom: ClayTokens.space3),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          // Layanan mati memakai aksen abu: gradiennya tetap satu bahasa
          // dengan yang hidup, tapi jelas bukan pilihan.
          ClayIconChip(
            icon: _ikon[layanan.code] ?? Icons.category_rounded,
            accent: bisa
                ? ClayTokens.primary
                : (gelap
                      ? ClayTokens.textTertiaryDark
                      : ClayTokens.textTertiary),
          ),
          const SizedBox(width: ClayTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        layanan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: bisa
                              ? null
                              : (gelap
                                    ? ClayTokens.textTertiaryDark
                                    : ClayTokens.textTertiary),
                        ),
                      ),
                    ),
                    if (layanan.hasSurge) ...<Widget>[
                      const SizedBox(width: ClayTokens.space2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ClayTokens.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            ClayTokens.radiusPill,
                          ),
                        ),
                        child: const Text(
                          'Jam sibuk',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ClayTokens.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _keterangan(),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    color: gelap
                        ? ClayTokens.textSecondaryDark
                        : ClayTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ClayTokens.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              // Harga layanan terpilih naik satu tingkat ukuran: pembanding
              // utama layar ini adalah harga, dan yang sedang dipilih harus
              // paling mudah dibaca ulang sebelum menekan "Pesan sekarang".
              ClayMoney(
                formatted: layanan.total.formatted,
                size: terpilih ? ClayMoneySize.large : ClayMoneySize.medium,
                // Harga layanan yang tidak bisa dipesan tetap DITAMPILKAN, dan
                // dicoret. Menyembunyikannya membuat pengguna tidak bisa
                // membandingkan, dan perbandingan itu yang membuat dia mau
                // menunggu driver.
                strikethrough: !bisa,
              ),
              if (potongan != null && potongan! > 0)
                const Text(
                  'Promo aktif',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _keterangan() {
    if (!layanan.isOrderable) {
      return layanan.hasNoDriver
          ? 'Tidak ada driver di sekitar'
          : 'Sedang tidak tersedia';
    }

    final String eta = layanan.pickupEtaMinutes == null
        ? 'Driver tersedia'
        : 'Dijemput ± ${layanan.pickupEtaMinutes} menit';

    return '$eta · ${layanan.availableDrivers} driver terdekat';
  }
}

class _PilihanBayar extends StatelessWidget {
  const _PilihanBayar({required this.alur});

  final OrderFlowController alur;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _TombolBayar(
            icon: Icons.payments_rounded,
            label: 'Tunai',
            terpilih: alur.paymentMethod == 'cash',
            onTap: () => alur.setPaymentMethod('cash'),
          ),
        ),
        const SizedBox(width: ClayTokens.space3),
        Expanded(
          child: _TombolBayar(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Dompet',
            terpilih: alur.paymentMethod == 'wallet',
            onTap: () => alur.setPaymentMethod('wallet'),
          ),
        ),
      ],
    );
  }
}

class _TombolBayar extends StatelessWidget {
  const _TombolBayar({
    required this.icon,
    required this.label,
    required this.terpilih,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: terpilih ? ClayDepth.pressed : ClayDepth.low,
      borderColor: terpilih ? ClayTokens.primary : null,
      padding: const EdgeInsets.symmetric(vertical: ClayTokens.space4),
      onTap: onTap,
      child: Column(
        children: <Widget>[
          // Gradien hanya pada yang terpilih: dua chip beraksen berdampingan
          // saling meniadakan — isyarat "yang ini" hilang.
          if (terpilih)
            ClayIconChip(icon: icon, accent: ClayTokens.primary, size: 38)
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: gelap
                    ? ClayTokens.surfaceSunkenDark
                    : ClayTokens.surfaceSunken,
                borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
              ),
              child: Icon(
                icon,
                size: 19,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
              ),
            ),
          const SizedBox(height: ClayTokens.space2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              fontWeight: terpilih ? FontWeight.w700 : FontWeight.w500,
              color: terpilih ? ClayTokens.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuPromo extends StatelessWidget {
  const _KartuPromo({
    required this.quote,
    required this.promoCode,
    required this.onTap,
  });

  final Quote quote;
  final String? promoCode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final bool ada = quote.promos.isNotEmpty;

    return ClayCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          if (ada)
            const ClayIconChip(
              icon: Icons.local_offer_rounded,
              accent: ClayTokens.primary,
              size: 36,
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: gelap
                    ? ClayTokens.surfaceSunkenDark
                    : ClayTokens.surfaceSunken,
                borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
              ),
              child: Icon(
                Icons.local_offer_rounded,
                size: 18,
                color: gelap
                    ? ClayTokens.textTertiaryDark
                    : ClayTokens.textTertiary,
              ),
            ),
          const SizedBox(width: ClayTokens.space3),
          Expanded(
            child: Text(
              !ada
                  ? 'Belum ada promo untuk rute ini'
                  : (promoCode ?? 'Pilih promo yang tersedia'),
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: !ada
                    ? (gelap
                          ? ClayTokens.textTertiaryDark
                          : ClayTokens.textTertiary)
                    : null,
              ),
            ),
          ),
          if (ada) const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}

/// Bilah bawah: total, hitungan mundur quote, dan tombol pesan.
///
/// ============================================================================
///  TOTAL DI SAMPING TOMBOL, BUKAN HANYA DI RINCIAN
/// ============================================================================
///  Rincian ongkos ikut tergulir; tombol pesan tidak. Penumpang yang sudah
///  menggulir jauh menekan "Pesan sekarang" tanpa melihat angkanya lagi —
///  total yang menempel pada tombolnya menghilangkan keluhan "saya tidak tahu
///  jadinya berapa". Angkanya dari `_Isi._totalTerformat`, hitungan yang sama
///  dengan rincian.
/// ============================================================================
class _BilahBawah extends StatelessWidget {
  const _BilahBawah({
    required this.alur,
    required this.quote,
    required this.onPesan,
    required this.onSegarkan,
  });

  final OrderFlowController alur;
  final Quote quote;
  final VoidCallback onPesan;
  final VoidCallback onSegarkan;

  @override
  Widget build(BuildContext context) {
    final bool kadaluarsa = quote.isExpired;
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    /*
     * Bukan ClaySurface: bilah ini butuh radius HANYA di sudut atas (sudut
     * bawah menempel tepi layar), dan ClaySurface hanya menerima satu radius
     * untuk keempat sudut. Bayangannya diarahkan ke atas — satu-satunya sisi
     * yang berbatasan dengan konten.
     */
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ClayTokens.space5,
        ClayTokens.space4,
        ClayTokens.space5,
        ClayTokens.space5,
      ),
      decoration: BoxDecoration(
        color: gelap ? ClayTokens.surfaceRaisedDark : ClayTokens.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ClayTokens.radiusLarge),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: gelap ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            /*
             * Hitungan mundur DITAMPILKAN, tidak disembunyikan.
             *
             * Harga yang berubah tanpa pemberitahuan adalah keluhan yang paling
             * sulit dijawab. Dengan hitungan mundur terlihat, perubahannya
             * terbaca sebagai aturan yang jelas, bukan sebagai harga yang
             * berubah-ubah.
             */
            Align(
              alignment: Alignment.centerLeft,
              child: kadaluarsa
                  ? _PilCountdown(
                      icon: Icons.timer_off_rounded,
                      teks: 'Harga sudah kadaluarsa',
                      warna: ClayTokens.danger,
                      tegas: true,
                    )
                  : _PilCountdown(
                      icon: Icons.timer_outlined,
                      teks:
                          'Harga berlaku ${quote.secondsUntilExpiry} detik lagi',
                      warna: quote.isExpiringSoon
                          ? ClayTokens.warning
                          : (gelap
                                ? ClayTokens.textTertiaryDark
                                : ClayTokens.textTertiary),
                      tegas: quote.isExpiringSoon,
                    ),
            ),

            const SizedBox(height: ClayTokens.space3),

            Row(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const ClaySectionLabel('Total'),
                    const SizedBox(height: 2),
                    ClayMoney(
                      formatted: _Isi._totalTerformat(alur),
                      size: ClayMoneySize.large,
                    ),
                  ],
                ),

                const SizedBox(width: ClayTokens.space4),

                Expanded(
                  child: ClayButton(
                    label: kadaluarsa ? 'Cek harga baru' : 'Pesan sekarang',
                    icon: kadaluarsa
                        ? Icons.refresh_rounded
                        : Icons.check_rounded,
                    isLoading: alur.isSubmitting || alur.isLoadingQuote,
                    onPressed: kadaluarsa
                        ? onSegarkan
                        : (alur.canSubmit ? onPesan : null),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill kecil status hitungan mundur di bilah bawah.
class _PilCountdown extends StatelessWidget {
  const _PilCountdown({
    required this.icon,
    required this.teks,
    required this.warna,
    required this.tegas,
  });

  final IconData icon;
  final String teks;
  final Color warna;

  /// Saat mendesak (kadaluarsa / hampir): teks menebal dan latar pill
  /// memakai warna semantiknya, bukan abu.
  final bool tegas;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space3,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: tegas
            ? warna.withValues(alpha: 0.14)
            : (gelap ? ClayTokens.surfaceSunkenDark : ClayTokens.surfaceSunken),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: warna),
          const SizedBox(width: ClayTokens.space2),
          Flexible(
            child: Text(
              teks,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: tegas ? FontWeight.w700 : FontWeight.w500,
                color: warna,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
