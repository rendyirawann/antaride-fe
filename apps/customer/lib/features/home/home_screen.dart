import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_maps/antaride_maps.dart';
import 'package:antaride_notifications/antaride_notifications.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notifications/notification_action.dart';
import '../order/order_flow_controller.dart';
import '../order/route_picker_screen.dart';
import '../order/tracking_screen.dart';

/// Beranda penumpang.
///
/// ============================================================================
///  YANG PERTAMA DIPERIKSA ADALAH ORDER BERJALAN, BUKAN KATALOG
/// ============================================================================
///  Kalau ada order berjalan, layar ini mengarahkan langsung ke pelacakan.
///
///  Alasannya: penumpang yang sedang menunggu driver membuka aplikasi untuk
///  SATU hal — melihat di mana drivernya. Beranda dengan daftar layanan di saat
///  itu memaksanya mencari jalan ke layar yang dia butuhkan, dan yang biasanya
///  terjadi adalah dia menekan "pesan ojek" lagi.
/// ============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ServiceTypeInfo> _layanan = const <ServiceTypeInfo>[];
  Order? _orderBerjalan;

  bool _memuat = true;
  ApiFailure? _galat;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _memuat = true;
      _galat = null;
    });

    final AntarideServices services = context.read<AntarideServices>();

    /*
     * Dua request BERSAMAAN, bukan berurutan.
     *
     * Keduanya tidak saling bergantung, dan beranda tidak bisa ditampilkan
     * sebelum keduanya selesai. Menjalankannya berurutan menggandakan waktu
     * tunggu pembukaan aplikasi tanpa alasan.
     */
    final List<Object?> hasil = await Future.wait<Object?>(<Future<Object?>>[
      services.quotes.serviceTypes(),
      services.orders.active(),
    ]);

    if (!mounted) {
      return;
    }

    final Result<List<ServiceTypeInfo>> katalog =
        hasil[0]! as Result<List<ServiceTypeInfo>>;

    final Result<Order?> aktif = hasil[1]! as Result<Order?>;

    setState(() {
      _memuat = false;
      _layanan = katalog.valueOrNull ?? const <ServiceTypeInfo>[];
      _orderBerjalan = aktif.valueOrNull;

      /*
       * HANYA kegagalan katalog yang ditampilkan sebagai galat layar.
       *
       * Kegagalan pemeriksaan order berjalan dibiarkan senyap: beranda tetap
       * berguna tanpanya, dan kalau memang ada order berjalan, pita di atas
       * akan muncul pada pemuatan berikutnya. Menampilkan layar galat penuh
       * untuk itu berarti pengguna tidak bisa memesan apa pun karena satu
       * request tambahan gagal.
       */
      _galat = katalog.failureOrNull;
    });
  }

  Future<void> _mulaiPesan(ServiceTypeInfo layanan) async {
    if (layanan.requiresMerchant) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${layanan.name} belum tersedia di Fase 1.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final AntarideServices services = context.read<AntarideServices>();

    final Order? dibuat = await Navigator.of(context).push<Order>(
      MaterialPageRoute<Order>(
        builder: (BuildContext _) =>
            ChangeNotifierProvider<OrderFlowController>(
              create: (BuildContext _) => OrderFlowController(
                quotes: services.quotes,
                orders: services.orders,
              ),
              child: RoutePickerScreen(serviceCode: layanan.code),
            ),
      ),
    );

    if (!mounted || dibuat == null) {
      return;
    }

    setState(() {
      _orderBerjalan = dibuat;
    });

    await _bukaPelacakan(dibuat.uuid);
  }

  Future<void> _bukaPelacakan(String uuid) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => TrackingScreen(orderUuid: uuid),
      ),
    );

    // Order bisa selesai atau dibatalkan di layar pelacakan. Memuat ulang saat
    // kembali adalah cara memastikan pita "order berjalan" hilang — kalau
    // tidak, pita itu bertahan sampai aplikasi dibuka ulang.
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final String? nama = context.select<SessionController, String?>(
      (SessionController s) => s.user?.name,
    );

    return Scaffold(
      /*
       * TANPA SafeArea di atas, dan itu wajib.
       *
       * Beranda terdaftar di `ClayDrawerShell.fullBleedPages`, jadi tidak ada
       * AppBar shell di atasnya — hero gradien inilah kepala halamannya, dan
       * gradien itu harus MENEMBUS status bar. SafeArea di sini akan menyisakan
       * pita warna latar di atas hero, yang terbaca sebagai kesalahan render.
       *
       * Konsekuensinya: hamburger jadi tanggung jawab halaman ini. Diambil dari
       * `ClayDrawerScope` — tanpa itu sidebar tidak bisa dibuka sama sekali.
       */
      body: ClayRefresh(
        onRefresh: _muat,
        child: ListView(
          padding: const EdgeInsets.only(bottom: ClayTokens.space8),
          children: <Widget>[
            // Hero ikut sebagai butir pertama daftar, bukan dipatok di atasnya:
            // dia bergulir pergi saat pengguna menelusuri layanan, dan itu
            // mengembalikan tinggi layar yang berharga di HP pendek.
            _HeroBeranda(nama: nama),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                ClayTokens.space5,
                ClayTokens.space5,
                ClayTokens.space5,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_orderBerjalan != null) ...<Widget>[
                    ClayEntrance(
                      index: 1,
                      child: _PitaOrderBerjalan(
                        order: _orderBerjalan!,
                        onTap: () => _bukaPelacakan(_orderBerjalan!.uuid),
                      ),
                    ),
                    const SizedBox(height: ClayTokens.space5),
                  ],

                  if (_galat != null && _layanan.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: ClayTokens.space8),
                      child: ClayErrorState(
                        message: _galat!.message,
                        onRetry: _muat,
                      ),
                    )
                  else ...<Widget>[
                    ClayEntrance(
                      index: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Mau ke mana hari ini?',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: gelap
                                ? ClayTokens.textPrimaryDark
                                : ClayTokens.textPrimary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: ClayTokens.space4),

                    if (_memuat)
                      const ClaySkeletonGrid()
                    else
                      ClayEntrance(
                        index: 3,
                        child: _KisiLayanan(
                          layanan: _layanan,
                          onPilih: _mulaiPesan,
                        ),
                      ),

                    const SizedBox(height: ClayTokens.space6),

                    /*
                     * Peta SENGAJA di luar ClayEntrance.
                     *
                     * `AntarideMap` adalah platform view. Membungkusnya dengan
                     * animasi opacity/transform memaksa compositor menyalinnya
                     * ke layer terpisah tiap frame — mahal, dan pada sebagian
                     * perangkat petanya berkedip hitam selama animasi.
                     */
                    const _PetaSekilas(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kepala beranda: gradien penuh dengan sapaan, hamburger, dan lonceng.
class _HeroBeranda extends StatelessWidget {
  const _HeroBeranda({this.nama});

  final String? nama;

  @override
  Widget build(BuildContext context) {
    return ClayEntrance(
      index: 0,
      child: ClayHeroHeader(
        accent: ClayTokens.primary,
        title: nama ?? 'Pengguna Antaride',
        subtitle: 'Selamat datang di Antaride',

        // Hamburger. `ClayDrawerScope` boleh null — beranda bisa dipasang
        // sendirian di test widget, dan tombol yang tidak melakukan apa-apa di
        // sana lebih baik daripada test yang tidak bisa memasang layarnya.
        leading: ClayGlassButton(
          icon: Icons.menu_rounded,
          semanticLabel: 'Menu',
          onPressed: ClayDrawerScope.of(context)?.toggle,
        ),

        /*
         * Lonceng notifikasi.
         *
         * Lencana angkanya datang dari `NotificationController` di akar
         * aplikasi, jadi angkanya berubah sendiri saat notifikasi dibaca di
         * layar lain — tanpa beranda ini perlu tahu apa pun soal itu.
         *
         * Bentuknya kini kaca buram, sama dengan hamburger di seberangnya:
         * keduanya duduk di atas gradien, dan pil clay yang dulu dipakai di
         * latar pucat tenggelam di sini.
         */
        trailing: NotificationBadge(
          child: ClayGlassButton(
            icon: Icons.notifications_none_rounded,
            semanticLabel: 'Notifikasi',
            onPressed: () =>
                NotificationIcon.buka(context, onOpenAction: bukaNotifikasi),
          ),
        ),
      ),
    );
  }
}

/// Pita yang menunjukkan ada order berjalan.
class _PitaOrderBerjalan extends StatelessWidget {
  const _PitaOrderBerjalan({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    /*
     * Satu-satunya kartu bergradien di beranda, dan itu disengaja.
     *
     * Order yang sedang berjalan adalah hal paling mendesak di layar ini —
     * penumpang yang membuka aplikasi saat drivernya dalam perjalanan mencari
     * INI, bukan katalog layanan. Versi lama hanya kartu clay ber-border, jadi
     * bobotnya sama dengan sel katalog di bawahnya.
     *
     * Gradien dipakai hemat justru supaya tetap berarti: kalau semua kartu
     * bergradien, tidak ada yang menonjol.
     */
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
        splashColor: Colors.white.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            gradient: ClayGradients.hero(ClayTokens.primary),
            borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
          ),
          padding: const EdgeInsets.all(ClayTokens.space4),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: Icon(
                  order.isSearching
                      ? Icons.radar_rounded
                      : Icons.directions_bike_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: ClayTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Label status dari backend, ditulis di atas kaca buram —
                    // ClayStatusBadge memakai warna latar pucat yang hilang di
                    // atas gradien.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ClayTokens.space2,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(
                          ClayTokens.radiusPill,
                        ),
                      ),
                      child: Text(
                        order.statusLabel,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: ClayTokens.space2),
                    Text(
                      order.destination?.address ?? order.pickup.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _KisiLayanan extends StatelessWidget {
  const _KisiLayanan({required this.layanan, required this.onPilih});

  final List<ServiceTypeInfo> layanan;
  final void Function(ServiceTypeInfo) onPilih;

  /// Ikon per kode layanan.
  ///
  /// Backend mengirim `icon_url`, tapi Fase 1 belum punya asetnya. Ikon
  /// bawaan Material dipakai sebagai pengganti — dan pemetaannya di sini, satu
  /// tempat, bukan tersebar di widget.
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
    if (layanan.isEmpty) {
      return const ClayEmptyState(
        icon: Icons.inbox_rounded,
        title: 'Belum ada layanan',
        message: 'Layanan Antaride belum aktif di area Anda. Coba lagi nanti.',
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: ClayTokens.space3,
        crossAxisSpacing: ClayTokens.space3,
        childAspectRatio: 0.92,
      ),
      itemCount: layanan.length,
      itemBuilder: (BuildContext context, int i) {
        final ServiceTypeInfo s = layanan[i];

        final bool siap = !s.requiresMerchant;

        return ClaySurface(
          depth: siap ? ClayDepth.low : ClayDepth.flat,
          padding: const EdgeInsets.all(ClayTokens.space3),
          onTap: () => onPilih(s),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Layanan yang belum siap dibuat REDUP, bukan disembunyikan.
              // Pilihan yang hilang membuat orang menyimpulkan Antaride tidak
              // punya layanan itu sama sekali. Chipnya tetap bergradien, hanya
              // warnanya abu — bentuknya sama supaya kisinya tidak belang.
              ClayIconChip(
                icon: _ikon[s.code] ?? Icons.category_rounded,
                accent: siap ? ClayTokens.primary : ClayTokens.textTertiary,
                size: 40,
              ),
              const SizedBox(height: ClayTokens.space2),
              Text(
                s.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: siap ? null : ClayTokens.textTertiary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Peta kecil sebagai konteks, bukan alat.
///
/// Tidak interaktif dan tidak bisa ditekan. Yang dilakukannya hanya
/// memberitahu di kota mana aplikasi ini bekerja — dan itu berguna, karena
/// Fase 1 memang hanya Medan.
class _PetaSekilas extends StatelessWidget {
  const _PetaSekilas();

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.pressed,
      padding: const EdgeInsets.all(ClayTokens.space2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
        child: const SizedBox(
          height: 150,
          child: AntarideMap(
            interactive: false,
            fitToContent: false,
            initialZoom: 12,
            pins: <MapPin>[
              MapPin(
                position: medanCenter,
                icon: Icons.location_city_rounded,
                color: ClayTokens.primary,
                size: 34,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
