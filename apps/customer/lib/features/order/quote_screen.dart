import 'dart:async';

import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'order_flow_controller.dart';

/// Pilih layanan, lihat harga, lalu pesan.
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
                  const Icon(
                    Icons.local_offer_rounded,
                    color: ClayTokens.primary,
                    size: 20,
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
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            color: ClayTokens.textSecondary,
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

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi pesanan')),
      body: Column(
        children: <Widget>[
          // Peta rute, sepertiga atas. Cukup untuk memastikan tujuannya benar,
          // dan tidak lebih — yang perlu dibandingkan di layar ini adalah harga
          // antar layanan, bukan bentuk rutenya.
          SizedBox(
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

          Expanded(
            child: alur.isLoadingQuote && quote == null
                ? const ClayLoader(message: 'Menghitung harga…')
                : quote == null
                ? ClayErrorState(
                    message:
                        alur.failure?.message ?? 'Tidak bisa menghitung harga.',
                    onRetry: () => alur.loadQuote(
                      serviceCodes: <String>[widget.serviceCode],
                    ),
                  )
                : _Isi(quote: quote, alur: alur, onPilihPromo: _pilihPromo),
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
      padding: const EdgeInsets.all(ClayTokens.space5),
      children: <Widget>[
        _Ringkasan(quote: quote),

        const SizedBox(height: ClayTokens.space5),

        const _JudulBagian('Pilih layanan'),

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
            onTap: s.isOrderable ? () => alur.selectService(s.code) : null,
          ),

        const SizedBox(height: ClayTokens.space5),

        const _JudulBagian('Metode pembayaran'),

        _PilihanBayar(alur: alur),

        const SizedBox(height: ClayTokens.space5),

        const _JudulBagian('Promo'),

        ClayCard(
          onTap: quote.promos.isEmpty ? null : onPilihPromo,
          child: Row(
            children: <Widget>[
              Icon(
                Icons.local_offer_rounded,
                size: 20,
                color: quote.promos.isEmpty
                    ? ClayTokens.textTertiary
                    : ClayTokens.primary,
              ),
              const SizedBox(width: ClayTokens.space3),
              Expanded(
                child: Text(
                  quote.promos.isEmpty
                      ? 'Belum ada promo untuk rute ini'
                      : (alur.promoCode ?? 'Pilih promo yang tersedia'),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: quote.promos.isEmpty
                        ? ClayTokens.textTertiary
                        : null,
                  ),
                ),
              ),
              if (quote.promos.isNotEmpty)
                const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),

        const SizedBox(height: ClayTokens.space5),

        if (alur.selectedService != null) ...<Widget>[
          const _JudulBagian('Rincian ongkos'),
          ClaySurface(
            depth: ClayDepth.pressed,
            child: Column(
              children: <Widget>[
                for (final FareLine baris in alur.selectedService!.fareLines)
                  ClayMoneyRow(label: baris.label, formatted: baris.formatted),

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
  /// ==========================================================================
  String _totalTerformat(OrderFlowController alur) {
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
    return Column(
      children: <Widget>[
        Icon(icon, size: 18, color: ClayTokens.primary),
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
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            color: ClayTokens.textTertiary,
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

  @override
  Widget build(BuildContext context) {
    final bool bisa = layanan.isOrderable;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      layanan.name,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: bisa ? null : ClayTokens.textTertiary,
                      ),
                    ),
                    if (layanan.hasSurge) ...<Widget>[
                      const SizedBox(width: ClayTokens.space2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ClayTokens.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
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
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    color: ClayTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              ClayMoney(
                formatted: layanan.total.formatted,
                size: ClayMoneySize.medium,
                // Harga layanan yang tidak bisa dipesan tetap DITAMPILKAN, dan
                // dicoret. Menyembunyikannya membuat pengguna tidak bisa
                // membandingkan, dan perbandingan itu yang membuat dia mau
                // menunggu driver.
                strikethrough: !bisa,
              ),
              if (potongan != null && potongan! > 0)
                Text(
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
    return ClaySurface(
      depth: terpilih ? ClayDepth.pressed : ClayDepth.low,
      borderColor: terpilih ? ClayTokens.primary : null,
      padding: const EdgeInsets.symmetric(vertical: ClayTokens.space4),
      onTap: onTap,
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            size: 22,
            color: terpilih ? ClayTokens.primary : ClayTokens.textSecondary,
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

class _JudulBagian extends StatelessWidget {
  const _JudulBagian(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClayTokens.space3),
      child: Text(
        teks,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Bilah bawah: hitungan mundur quote dan tombol pesan.
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

    return ClaySurface(
      depth: ClayDepth.high,
      radius: 0,
      padding: const EdgeInsets.all(ClayTokens.space5),
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
            if (kadaluarsa)
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.timer_off_rounded,
                    size: 16,
                    color: ClayTokens.danger,
                  ),
                  const SizedBox(width: ClayTokens.space2),
                  const Expanded(
                    child: Text(
                      'Harga sudah kadaluarsa',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ClayTokens.danger,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onSegarkan,
                    child: const Text('Cek harga baru'),
                  ),
                ],
              )
            else
              Row(
                children: <Widget>[
                  Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: quote.isExpiringSoon
                        ? ClayTokens.warning
                        : ClayTokens.textTertiary,
                  ),
                  const SizedBox(width: ClayTokens.space2),
                  Text(
                    'Harga berlaku ${quote.secondsUntilExpiry} detik lagi',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      fontWeight: quote.isExpiringSoon
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: quote.isExpiringSoon
                          ? ClayTokens.warning
                          : ClayTokens.textTertiary,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: ClayTokens.space3),

            ClayButton(
              label: kadaluarsa ? 'Cek harga baru' : 'Pesan sekarang',
              icon: kadaluarsa ? Icons.refresh_rounded : Icons.check_rounded,
              isLoading: alur.isSubmitting || alur.isLoadingQuote,
              onPressed: kadaluarsa
                  ? onSegarkan
                  : (alur.canSubmit ? onPesan : null),
            ),
          ],
        ),
      ),
    );
  }
}
