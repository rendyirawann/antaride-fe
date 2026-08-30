import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Dompet: saldo dan mutasi.
///
/// ============================================================================
///  TIDAK ADA TOMBOL TOP UP, DAN ITU DISENGAJA
/// ============================================================================
///  Fase 1 belum punya integrasi payment gateway. Saldo masuk lewat dua jalur:
///  cashback promo, dan penambahan manual admin lewat backoffice.
///
///  Tombol top up yang mengarah ke halaman "segera hadir" lebih buruk daripada
///  tidak ada tombolnya: dia mengundang penumpang mencoba, lalu tidak memberikan
///  apa pun — dan yang dia simpulkan adalah fiturnya rusak, bukan belum ada.
/// ============================================================================
///
/// ============================================================================
///  BAHASA V2 DI LAYAR INI: KARTU SALDO BERGRADIEN, BUKAN HERO
/// ============================================================================
///  Halaman ini hidup DI BAWAH AppBar milik shell tab, jadi hero yang menembus
///  status bar tidak mungkin. Momen uangnya tetap dapat panggungnya: kartu
///  saldo menjadi satu-satunya bidang gradien aksen di layar ([ClayGradients]
///  yang sama dengan hero), dengan saldo putih di atasnya — sisanya kartu clay
///  pucat, sehingga mata jatuh ke saldo lebih dulu.
///
///  Animasi masuk dipasang SEKALI di level layar, bukan pada kartu saldo:
///  kartu saldo adalah item indeks 0 milik `ListView.builder` dan di-dispose
///  saat tergulir keluar viewport — entrance yang menempel padanya akan
///  diputar ulang setiap pengguna menggulir balik ke atas.
/// ============================================================================
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final List<WalletTransaction> _mutasi = <WalletTransaction>[];

  WalletBalance? _saldo;
  String? _cursor;
  bool _adaLagi = true;
  bool _memuat = false;
  bool _pertamaSelesai = false;
  ApiFailure? _galat;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _muat(awal: true));
  }

  /// Muat halaman mutasi berikutnya, untuk `ClayRefresh.onLoad`.
  Future<IndicatorResult> _muatLagi() async {
    await _muat();

    if (_galat != null) {
      return IndicatorResult.fail;
    }

    return _adaLagi ? IndicatorResult.success : IndicatorResult.noMore;
  }

  Future<void> _muat({bool awal = false}) async {
    if (_memuat) {
      return;
    }

    if (!awal && !_adaLagi && _pertamaSelesai) {
      return;
    }

    setState(() {
      _memuat = true;
      _galat = null;
    });

    final AntarideServices services = context.read<AntarideServices>();

    // Saldo ditarik ulang HANYA pada pemuatan awal dan refresh. Halaman mutasi
    // berikutnya tidak mengubah saldo, dan menariknya setiap kali menggulir
    // adalah request yang jawabannya sudah diketahui.
    final Future<Result<WalletBalance>>? saldoNanti = awal
        ? services.wallet.balance()
        : null;

    final Result<WalletTransactionPage> halaman = await services.wallet
        .transactions(cursor: awal ? null : _cursor);

    final Result<WalletBalance>? saldo = await saldoNanti;

    if (!mounted) {
      return;
    }

    setState(() {
      _memuat = false;
      _pertamaSelesai = true;

      if (saldo != null) {
        _saldo = saldo.valueOrNull ?? _saldo;
      }

      switch (halaman) {
        case Ok<WalletTransactionPage>(value: final WalletTransactionPage h):
          if (awal) {
            _mutasi.clear();
          }

          _mutasi.addAll(h.transactions);
          _cursor = h.nextCursor;
          _adaLagi = h.hasMore && h.nextCursor != null;

        case Err<WalletTransactionPage>(failure: final ApiFailure f):
          _galat = f;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_pertamaSelesai && _memuat) {
      return const Scaffold(
        body: Column(
          children: <Widget>[
            // Skeleton kartu saldo lalu skeleton daftar mutasi, dengan tinggi
            // yang sama dengan aslinya. Itu yang membuat layar tidak melompat
            // saat datanya datang. Kartu saldo v2 (label+tile 42, saldo hero,
            // kalimat penjelas) tetap jatuh di kisaran 168, jadi angkanya sama.
            Padding(
              padding: EdgeInsets.fromLTRB(
                ClayTokens.space5,
                ClayTokens.space5,
                ClayTokens.space5,
                0,
              ),
              child: ClaySkeletonGroup(
                child: ClaySkeletonBox(
                  height: 168,
                  radius: ClayTokens.radiusLarge,
                ),
              ),
            ),
            Expanded(child: ClaySkeletonList(itemHeight: 62)),
          ],
        ),
      );
    }

    if (_saldo == null && _galat != null) {
      return Scaffold(
        body: ClayErrorState(
          message: _galat!.message,
          onRetry: () => _muat(awal: true),
        ),
      );
    }

    return Scaffold(
      body: ClayEntrance(
        index: 0,
        child: ClayRefresh(
          onRefresh: () => _muat(awal: true),
          onLoad: _muatLagi,
          child: ListView.builder(
            padding: const EdgeInsets.all(ClayTokens.space5),
            itemCount: _mutasi.length + 2,
            itemBuilder: (BuildContext context, int i) {
              if (i == 0) {
                final bool gelap =
                    Theme.of(context).brightness == Brightness.dark;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_saldo != null) _KartuSaldo(saldo: _saldo!),
                    const SizedBox(height: ClayTokens.space6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: ClayTokens.space3),
                      child: ClaySectionLabel('Mutasi'),
                    ),
                    if (_mutasi.isEmpty && !_memuat)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: ClayTokens.space8,
                        ),
                        child: Text(
                          'Belum ada mutasi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            color: gelap
                                ? ClayTokens.textTertiaryDark
                                : ClayTokens.textTertiary,
                          ),
                        ),
                      ),
                  ],
                );
              }

              // Kaki daftar. Spinner halaman berikutnya dan keterangan "sudah
              // habis" ditangani footer `ClayRefresh`, jadi yang tersisa di sini
              // hanya ruang supaya baris terakhir tidak menempel di dasar layar.
              if (i == _mutasi.length + 1) {
                return const SizedBox(height: ClayTokens.space8);
              }

              return _BarisMutasi(mutasi: _mutasi[i - 1]);
            },
          ),
        ),
      ),
    );
  }
}

/// Kartu saldo: satu-satunya bidang gradien aksen di layar.
///
/// ============================================================================
///  KENAPA GRADIEN HERO, PADAHAL INI KARTU
/// ============================================================================
///  Gradiennya [ClayGradients.hero] (lerp 0.32), bukan varian chip: bidangnya
///  cukup besar untuk peralihan warnanya terbaca, dan teks putih di ujung
///  terangnya butuh jaminan kontras yang sama dengan hero. Radiusnya TETAP
///  [ClayTokens.radiusLarge] (28), bukan 36 milik hero — dia kartu di dalam
///  halaman, bukan latar halaman, dan hierarki radius itu yang membedakannya.
///
///  Gradien dan teks putihnya sama di kedua mode tema, seperti semua bidang
///  aksen v2 — karena itu tidak ada ternary gelap di sini.
/// ============================================================================
class _KartuSaldo extends StatelessWidget {
  const _KartuSaldo({required this.saldo});

  final WalletBalance saldo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ClayTokens.radiusLarge),

        // Semantik lama dipertahankan: bingkai danger saat dompet dibekukan.
        border: saldo.isFrozen
            ? Border.all(color: ClayTokens.danger, width: 1.5)
            : null,

        // Bayangan berwarna aksen, bukan hitam: kartu gradien yang diberi
        // bayangan abu terlihat seperti stiker menempel di permukaan clay.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ClayTokens.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ClayTokens.radiusLarge),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: ClayGradients.hero(ClayTokens.primary),
          ),
          child: Stack(
            children: <Widget>[
              // Tekstur lingkaran samar khas hero v2. Duplikat kecil yang
              // disengaja: `_Lingkaran` milik ClayHeroHeader privat dan
              // antaride_ui belum mengekspor teksturnya untuk kartu.
              const Positioned(
                top: -58,
                right: -42,
                child: _LingkaranSamar(diameter: 168, alpha: 0.08),
              ),
              const Positioned(
                bottom: -72,
                left: -54,
                child: _LingkaranSamar(diameter: 190, alpha: 0.06),
              ),

              Padding(
                padding: const EdgeInsets.all(ClayTokens.space6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Saldo tersedia'.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,

                                  // Putih diredupkan, bukan abu-abu: abu-abu
                                  // di atas gradien berwarna terlihat kotor.
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: ClayTokens.space2),
                              ClayMoney(
                                formatted: saldo.available.formatted,
                                size: ClayMoneySize.hero,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        const _TileKaca(
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                      ],
                    ),

                    /*
                     * Saldo tertahan DITAMPILKAN TERPISAH, tidak dikurangkan
                     * diam-diam.
                     *
                     * Penumpang yang saldonya Rp 50.000 dan sedang naik ojek
                     * Rp 15.000 akan melihat Rp 35.000, dan tanpa baris ini dia
                     * menyimpulkan uangnya sudah terpotong padahal
                     * perjalanannya belum selesai. Lalu kalau dia batalkan dan
                     * saldonya kembali, dia menyimpulkan sistemnya tidak
                     * konsisten.
                     */
                    if (saldo.hasHeld) ...<Widget>[
                      const SizedBox(height: ClayTokens.space3),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.lock_clock_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: ClayTokens.space2),
                          Expanded(
                            child: Text(
                              '${saldo.held.formatted} ditahan untuk pesanan '
                              'berjalan',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (saldo.isFrozen) ...<Widget>[
                      const SizedBox(height: ClayTokens.space4),

                      // Tile kaca putih-transparan, bukan ClaySurface: kartu
                      // clay pucat di dalam bidang gradien terbaca sebagai
                      // lubang. Isyarat bahayanya dibawa ikon danger dan
                      // bingkai danger di tepi kartu.
                      Container(
                        padding: const EdgeInsets.all(ClayTokens.space4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            ClayTokens.radiusSmall,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.gpp_bad_rounded,
                              size: 18,
                              color: ClayTokens.danger,
                            ),
                            const SizedBox(width: ClayTokens.space3),
                            Expanded(
                              child: Text(
                                // Alasannya dari backend kalau ada. Membekukan
                                // dompet tanpa penjelasan membuat orang mengira
                                // aplikasinya rusak, dan dia tidak punya jalan
                                // apa pun.
                                saldo.frozenReason ??
                                    'Dompet Anda sedang dibekukan. Hubungi '
                                        'bantuan Antaride.',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  height: 1.45,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: ClayTokens.space4),

                    Text(
                      // Menjelaskan kenapa tidak ada tombol top up. Tanpa
                      // kalimat ini, pengguna akan mencarinya dan menyimpulkan
                      // aplikasinya belum selesai.
                      'Saldo bertambah dari promo dan cashback. Top up lewat '
                      'aplikasi belum tersedia.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarisMutasi extends StatelessWidget {
  const _BarisMutasi({required this.mutasi});

  final WalletTransaction mutasi;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final bool masuk = mutasi.isCredit;

    return ClayCard(
      depth: ClayDepth.flat,
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space4,
        vertical: ClayTokens.space3,
      ),
      child: Row(
        children: <Widget>[
          // Chip gradien kecil menggantikan tile pressed abu: mutasi masuk
          // hijau success, keluar kelabu netral. Kelabu-nya konstan di kedua
          // mode tema — aturan v2: gradien aksen sama di kedua mode, ikon
          // di atasnya selalu putih.
          ClayIconChip(
            icon: masuk
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            accent: masuk ? ClayTokens.success : ClayTokens.textSecondary,
            size: 34,
          ),

          const SizedBox(width: ClayTokens.space3),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  mutasi.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (mutasi.description != null)
                  Text(
                    mutasi.description!,
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

          const SizedBox(width: ClayTokens.space3),

          ClayMoney(
            // Tandanya ditambahkan di sini karena `amount.formatted` dari
            // backend selalu nominal positif; arahnya ada di `direction`.
            formatted: '${masuk ? '+' : '-'}${mutasi.amount.formatted}',
            size: ClayMoneySize.small,
            color: masuk ? ClayTokens.success : null,
          ),
        ],
      ),
    );
  }
}

/// Tile kaca buram di atas gradien — resep yang sama dengan _LogoMark welcome:
/// putih alpha 0.16 + bingkai alpha 0.22, supaya ikut warna aksen apa pun.
class _TileKaca extends StatelessWidget {
  const _TileKaca({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, size: 21, color: Colors.white),
    );
  }
}

/// Lingkaran tekstur samar untuk kartu gradien. Putih transparan supaya ikut
/// aksen apa pun — duplikat lokal karena `_Lingkaran` ClayHeroHeader privat.
class _LingkaranSamar extends StatelessWidget {
  const _LingkaranSamar({required this.diameter, required this.alpha});

  final double diameter;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}
