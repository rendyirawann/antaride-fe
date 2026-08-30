import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Form penilaian driver.
///
/// ============================================================================
///  BINTANG WAJIB, SISANYA TIDAK
/// ============================================================================
///  Tombol kirim mati sampai bintangnya dipilih. Tag dan komentar opsional —
///  memaksanya berarti sebagian besar penumpang menutup form tanpa menilai, dan
///  yang hilang justru data yang paling berguna: skornya.
/// ============================================================================
///
/// ============================================================================
///  TAG BERBEDA UNTUK SKOR TINGGI DAN RENDAH
/// ============================================================================
///  Menawarkan "kendaraan kotor" pada penumpang yang memberi bintang 5 tidak
///  masuk akal, dan sebaliknya "sangat ramah" pada bintang 1 terbaca seperti
///  aplikasi tidak membaca apa yang baru dia pilih.
///
///  Ambangnya di bintang 4: 4–5 dianggap puas, 1–3 dianggap ada masalah.
///  Batasnya dipilih di situ karena bintang 3 di layanan seperti ini praktis
///  selalu berarti ada yang salah, bukan "biasa saja".
/// ============================================================================
///
/// ============================================================================
///  GAYA V2 DI DALAM SHEET: CHIP GRADIEN + ANIMASI MIKRO, TANPA HERO
/// ============================================================================
///  Ini bottom sheet, bukan halaman — hero gradien di dalamnya membuat sheet
///  bersaing dengan layar di belakangnya. Bahasa v2 masuk lewat dua hal:
///  avatar driver bergradien aksen (yang dinilai adalah ORANGNYA, bukan
///  ordernya), dan animasi mikro — bintang yang membal saat dipilih, blok tag
///  yang mengalir masuk lewat AnimatedSize alih-alih melompat.
/// ============================================================================
class RatingSheet extends StatefulWidget {
  const RatingSheet({super.key, required this.order});

  final Order order;

  /// Tampilkan sebagai bottom sheet.
  ///
  /// Mengembalikan penilaian yang terkirim, atau null kalau ditutup tanpa
  /// mengirim.
  ///
  /// `isDismissible: true` — penumpang HARUS bisa menutupnya tanpa menilai.
  /// Form yang tidak bisa ditutup akan membuat orang menutup seluruh aplikasi,
  /// dan itu tidak menghasilkan penilaian juga.
  static Future<OrderRating?> show({
    required BuildContext context,
    required Order order,
  }) {
    return ClayBottomSheet.show<OrderRating>(
      context: context,
      title: 'Nilai perjalanan',
      child: RatingSheet(order: order),
    );
  }

  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  final TextEditingController _komentar = TextEditingController();
  final Set<String> _tagTerpilih = <String>{};

  int _skor = 0;
  bool _mengirim = false;

  /// Tag untuk penumpang yang puas.
  static const List<String> _tagPuas = <String>[
    'Ramah',
    'Berkendara aman',
    'Kendaraan bersih',
    'Tepat waktu',
    'Tahu jalan',
  ];

  /// Tag untuk penumpang yang tidak puas.
  static const List<String> _tagTidakPuas = <String>[
    'Mengebut',
    'Kendaraan kotor',
    'Datang terlambat',
    'Kurang sopan',
    'Minta tambahan ongkos',
  ];

  List<String> get _tagTersedia => _skor >= 4 ? _tagPuas : _tagTidakPuas;

  @override
  void dispose() {
    _komentar.dispose();
    super.dispose();
  }

  void _pilihSkor(int skor) {
    setState(() {
      // Tag dikosongkan saat skornya berpindah antara puas dan tidak puas.
      //
      // Tanpa ini, penumpang yang memilih "Ramah" lalu menurunkan bintangnya ke
      // 2 akan mengirim tag positif bersama skor negatif — dan yang membaca
      // laporannya di panel admin tidak punya cara menafsirkannya.
      final bool pindahKategori = (_skor >= 4) != (skor >= 4);

      _skor = skor;

      if (pindahKategori) {
        _tagTerpilih.clear();
      }
    });
  }

  Future<void> _kirim() async {
    if (_skor == 0 || _mengirim) {
      return;
    }

    setState(() => _mengirim = true);

    final AntarideServices services = context.read<AntarideServices>();

    final Result<OrderRating> hasil = await services.orders.rate(
      uuid: widget.order.uuid,
      score: _skor,
      tags: _tagTerpilih.toList(),
      comment: _komentar.text,
    );

    if (!mounted) {
      return;
    }

    switch (hasil) {
      case Ok<OrderRating>(value: final OrderRating rating):
        Navigator.of(context).pop(rating);

      case Err<OrderRating>(failure: final ApiFailure f):
        setState(() => _mengirim = false);

        /*
         * "Sudah dinilai" MENUTUP form, bukan menampilkan galat.
         *
         * Keadaannya sudah tercapai — penilaiannya masuk, entah dari percobaan
         * sebelumnya yang response-nya tidak sampai, atau dari perangkat lain.
         * Menampilkannya sebagai galat merah membuat penumpang mengira
         * penilaiannya hilang.
         */
        if (f.code == 'RATING_ALREADY_SUBMITTED') {
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perjalanan ini sudah Anda nilai.'),
              behavior: SnackBarBehavior.floating,
            ),
          );

          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(f.message),
            backgroundColor: ClayTokens.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final OrderDriver? driver = widget.order.driver;
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    /*
     * Digulung: sheet ini bisa tinggi (avatar + bintang + tag + komentar) dan
     * saat keyboard terbuka ClayBottomSheet menyusutkan ruangnya lewat
     * Flexible. Tanpa scroll, kombinasi bintang-terisi + keyboard meluap di HP
     * pendek — dan yang tertutup justru tombol kirimnya.
     */
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (driver != null) ...<Widget>[
            Center(child: _AvatarDriver(nama: driver.name)),

            const SizedBox(height: ClayTokens.space3),

            Text(
              'Bagaimana perjalanan Anda dengan ${driver.name}?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                height: 1.45,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: ClayTokens.space5),

          // Bintang. Ukurannya besar — ini satu-satunya bagian form yang wajib,
          // dan target sentuh yang kecil pada lima pilihan berdempetan
          // menghasilkan skor yang bukan yang dimaksud.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 1; i <= 5; i++)
                IconButton(
                  onPressed: _mengirim ? null : () => _pilihSkor(i),
                  iconSize: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClayTokens.space1,
                  ),
                  /*
                   * Membal saat terisi: bintang kosong menunggu di 0.86, dan
                   * easeOutBack membawanya ke 1.0 dengan sedikit lampauan —
                   * umpan balik bahwa sentuhannya mendarat, tanpa controller
                   * tambahan. AnimatedScale hanya bergerak saat NILAINYA
                   * berubah, jadi rebuild lain tidak memutar ulang apa pun.
                   */
                  icon: AnimatedScale(
                    scale: i <= _skor ? 1 : 0.86,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      i <= _skor
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i <= _skor
                          ? ClayTokens.warning
                          : (gelap
                                ? ClayTokens.textTertiaryDark
                                : ClayTokens.textTertiary),
                    ),
                  ),
                ),
            ],
          ),

          /*
           * Blok label skor + tag + komentar MENGALIR masuk, bukan melompat:
           * tanpa AnimatedSize, sentuhan bintang pertama membuat seluruh sheet
           * tersentak setinggi bloknya. Alignment ke atas supaya isinya
           * terlihat tumbuh dari bawah bintang.
           */
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _skor == 0
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: Text(
                          _labelSkor(_skor),
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            // Warna mengikuti arti skornya: 1–3 ada masalah,
                            // 4–5 puas — ambang yang sama dengan pergantian tag.
                            color: _skor >= 4
                                ? ClayTokens.primary
                                : ClayTokens.warning,
                          ),
                        ),
                      ),

                      const SizedBox(height: ClayTokens.space5),

                      Wrap(
                        spacing: ClayTokens.space2,
                        runSpacing: ClayTokens.space2,
                        children: <Widget>[
                          for (final String tag in _tagTersedia)
                            _ChipTag(
                              label: tag,
                              terpilih: _tagTerpilih.contains(tag),
                              onTap: _mengirim
                                  ? null
                                  : () => setState(() {
                                      if (!_tagTerpilih.remove(tag)) {
                                        // Maksimal 5, sama dengan batas
                                        // validasi backend. Membatasinya di
                                        // sini berarti penumpang tidak pernah
                                        // melihat 422 untuk sesuatu yang bisa
                                        // dicegah di layar.
                                        if (_tagTerpilih.length < 5) {
                                          _tagTerpilih.add(tag);
                                        }
                                      }
                                    }),
                            ),
                        ],
                      ),

                      const SizedBox(height: ClayTokens.space4),

                      ClayInput(
                        controller: _komentar,
                        label: 'Komentar (opsional)',
                        hint: _skor >= 4
                            ? 'Apa yang paling Anda sukai?'
                            : 'Ceritakan apa yang terjadi',
                        maxLines: 3,
                        maxLength: 1000,
                        enabled: !_mengirim,
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: ClayTokens.space5),

          ClayButton(
            label: 'Kirim penilaian',
            icon: Icons.send_rounded,
            isLoading: _mengirim,

            // Mati sampai bintangnya dipilih. Tombol aktif yang menolak saat
            // ditekan lebih membingungkan daripada tombol yang jelas belum siap.
            onPressed: _skor == 0 || _mengirim ? null : _kirim,
          ),

          const SizedBox(height: ClayTokens.space2),

          Center(
            child: TextButton(
              onPressed: _mengirim ? null : () => Navigator.of(context).pop(),
              child: const Text('Nanti saja'),
            ),
          ),
        ],
      ),
    );
  }

  static String _labelSkor(int skor) => switch (skor) {
    1 => 'Sangat buruk',
    2 => 'Buruk',
    3 => 'Cukup',
    4 => 'Bagus',
    _ => 'Sangat bagus',
  };
}

/// Avatar driver: lingkaran bergradien aksen berisi inisial.
///
/// Backend Fase 1 belum mengirim foto driver, jadi identitas visualnya adalah
/// inisial di atas gradien aksen — [ClayGradients.chip], gradien yang sama
/// dengan chip ikon di seluruh v2, supaya avatarnya tidak jadi sumber warna
/// kedua di sheet. Kalau namanya kosong, jatuh ke ikon orang.
class _AvatarDriver extends StatelessWidget {
  const _AvatarDriver({required this.nama});

  final String nama;

  @override
  Widget build(BuildContext context) {
    final String inisial = nama.trim().isEmpty
        ? ''
        : nama.trim()[0].toUpperCase();

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ClayGradients.chip(ClayTokens.primary),
      ),
      alignment: Alignment.center,
      child: inisial.isEmpty
          ? const Icon(Icons.person_rounded, size: 26, color: Colors.white)
          : Text(
              inisial,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
    );
  }
}

class _ChipTag extends StatelessWidget {
  const _ChipTag({
    required this.label,
    required this.terpilih,
    required this.onTap,
  });

  final String label;
  final bool terpilih;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      // Tenggelam saat terpilih — isyarat clay yang sama dengan pilihan layanan
      // dan metode bayar di layar konfirmasi.
      depth: terpilih ? ClayDepth.pressed : ClayDepth.low,
      radius: ClayTokens.radiusPill,
      borderColor: terpilih ? ClayTokens.primary : null,
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space4,
        vertical: ClayTokens.space2,
      ),
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12.5,
          fontWeight: terpilih ? FontWeight.w700 : FontWeight.w500,
          color: terpilih ? ClayTokens.primary : null,
        ),
      ),
    );
  }
}
