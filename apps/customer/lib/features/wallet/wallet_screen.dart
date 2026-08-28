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
            // saat datanya datang.
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
      body: ClayRefresh(
        onRefresh: () => _muat(awal: true),
        onLoad: _muatLagi,
        child: ListView.builder(
          padding: const EdgeInsets.all(ClayTokens.space5),
          itemCount: _mutasi.length + 2,
          itemBuilder: (BuildContext context, int i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_saldo != null) _KartuSaldo(saldo: _saldo!),
                  const SizedBox(height: ClayTokens.space6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: ClayTokens.space3),
                    child: Text(
                      'Mutasi',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_mutasi.isEmpty && !_memuat)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: ClayTokens.space8,
                      ),
                      child: Text(
                        'Belum ada mutasi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          color: ClayTokens.textTertiary,
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
    );
  }
}

class _KartuSaldo extends StatelessWidget {
  const _KartuSaldo({required this.saldo});

  final WalletBalance saldo;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.high,
      radius: ClayTokens.radiusLarge,
      padding: const EdgeInsets.all(ClayTokens.space6),
      borderColor: saldo.isFrozen ? ClayTokens.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Saldo tersedia',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              color: ClayTokens.textSecondary,
            ),
          ),

          const SizedBox(height: ClayTokens.space2),

          ClayMoney(
            formatted: saldo.available.formatted,
            size: ClayMoneySize.hero,
          ),

          /*
           * Saldo tertahan DITAMPILKAN TERPISAH, tidak dikurangkan diam-diam.
           *
           * Penumpang yang saldonya Rp 50.000 dan sedang naik ojek Rp 15.000
           * akan melihat Rp 35.000, dan tanpa baris ini dia menyimpulkan uangnya
           * sudah terpotong padahal perjalanannya belum selesai. Lalu kalau dia
           * batalkan dan saldonya kembali, dia menyimpulkan sistemnya tidak
           * konsisten.
           */
          if (saldo.hasHeld) ...<Widget>[
            const SizedBox(height: ClayTokens.space3),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.lock_clock_rounded,
                  size: 14,
                  color: ClayTokens.textTertiary,
                ),
                const SizedBox(width: ClayTokens.space2),
                Text(
                  '${saldo.held.formatted} ditahan untuk pesanan berjalan',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    color: ClayTokens.textTertiary,
                  ),
                ),
              ],
            ),
          ],

          if (saldo.isFrozen) ...<Widget>[
            const SizedBox(height: ClayTokens.space4),
            ClaySurface(
              depth: ClayDepth.pressed,
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
                      // Alasannya dari backend kalau ada. Membekukan dompet
                      // tanpa penjelasan membuat orang mengira aplikasinya
                      // rusak, dan dia tidak punya jalan apa pun.
                      saldo.frozenReason ??
                          'Dompet Anda sedang dibekukan. Hubungi bantuan '
                              'Antaride.',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        height: 1.45,
                        color: ClayTokens.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: ClayTokens.space4),

          const Text(
            // Menjelaskan kenapa tidak ada tombol top up. Tanpa kalimat ini,
            // pengguna akan mencarinya dan menyimpulkan aplikasinya belum
            // selesai.
            'Saldo bertambah dari promo dan cashback. Top up lewat aplikasi '
            'belum tersedia.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              height: 1.5,
              color: ClayTokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisMutasi extends StatelessWidget {
  const _BarisMutasi({required this.mutasi});

  final WalletTransaction mutasi;

  @override
  Widget build(BuildContext context) {
    final bool masuk = mutasi.isCredit;

    return ClayCard(
      depth: ClayDepth.flat,
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space4,
        vertical: ClayTokens.space3,
      ),
      child: Row(
        children: <Widget>[
          ClaySurface(
            depth: ClayDepth.pressed,
            radius: ClayTokens.radiusSmall,
            padding: const EdgeInsets.all(ClayTokens.space2),
            child: Icon(
              masuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 16,
              color: masuk ? ClayTokens.success : ClayTokens.textSecondary,
            ),
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
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: ClayTokens.textTertiary,
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
