import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_media/antaride_media.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Dokumen KYC driver: unggah, lihat status, unggah ulang.
///
/// ============================================================================
///  LAYAR INI YANG MENENTUKAN APAKAH DRIVER BISA MULAI BEKERJA SAMA SEKALI
/// ============================================================================
///  `GoOnline` menolak driver yang dokumen wajibnya belum disetujui. Jadi selama
///  layar ini tidak ada, tidak ada satu pun driver yang bisa online — dan
///  satu-satunya jalan mendaftarkannya adalah admin memasukkan barisnya langsung
///  ke database.
/// ============================================================================
///
/// ============================================================================
///  JENIS YANG BELUM DIUNGGAH TETAP DITAMPILKAN
/// ============================================================================
///  Daftar dokumen yang sudah ada saja tidak cukup: driver baru punya daftar
///  KOSONG, dan layar kosong tidak memberi tahu dia harus mengunggah apa.
///
///  Jadi yang digambar adalah daftar JENIS WAJIB — dari backend, bukan dari
///  konstanta di aplikasi — dan masing-masing menampilkan dokumennya kalau sudah
///  ada, atau tombol unggah kalau belum.
///
///  Daftar wajibnya dari backend karena bisa berubah: peraturan daerah baru bisa
///  menuntut dokumen tambahan, dan aplikasi yang menyimpan daftarnya sendiri akan
///  menyatakan driver sudah lengkap sementara backend menolaknya online.
/// ============================================================================
class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({super.key, this.embedded = false});

  /// True kalau layar ini sudah berada di dalam `Scaffold` milik orang lain.
  ///
  /// Sama seperti `ActiveOrderScreen` dan `NotificationScreen`: di sidebar
  /// driver, `ClayDrawerShell` sudah menyediakan Scaffold beserta bilah atasnya.
  final bool embedded;

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  DriverDocumentState? _keadaan;

  bool _memuat = true;
  ApiFailure? _galat;

  /// Jenis dokumen yang sedang diunggah, beserta kemajuannya 0..1.
  ///
  /// Per JENIS, bukan satu penanda global. Driver bisa menekan unggah untuk KTP
  /// lalu langsung untuk SIM; penanda global akan membuat indikator muncul di
  /// kartu yang salah — dan yang selesai lebih dulu akan mematikan indikator
  /// yang lain.
  final Map<String, double> _mengunggah = <String, double>{};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() async {
    if (!mounted) {
      return;
    }

    setState(() => _memuat = true);

    final AntarideServices services = context.read<AntarideServices>();

    final Result<DriverDocumentState> hasil = await services.driver.documents();

    if (!mounted) {
      return;
    }

    setState(() {
      _memuat = false;

      switch (hasil) {
        case Ok<DriverDocumentState>(value: final DriverDocumentState k):
          _keadaan = k;
          _galat = null;

        case Err<DriverDocumentState>(failure: final ApiFailure f):
          // Keadaan lama dipertahankan. Driver yang mengunggah di jaringan buruk
          // tidak boleh kehilangan daftar yang sudah dia lihat setiap kali satu
          // request gagal.
          _galat = f;
      }
    });
  }

  /// Ambil foto lalu unggah.
  Future<void> _unggah(String type, String label) async {
    if (_mengunggah.containsKey(type)) {
      return;
    }

    final MediaPicked? foto = await MediaSourceSheet.show(
      context: context,
      title: 'Foto $label',
      namaDasar: type,
    );

    if (foto == null || !mounted) {
      return;
    }

    setState(() => _mengunggah[type] = 0);

    final AntarideServices services = context.read<AntarideServices>();

    final Result<DriverDocument> hasil = await services.driver.uploadDocument(
      type: type,
      bytes: foto.bytes,
      fileName: foto.fileName,
      mimeType: foto.mimeType,
      onProgress: (int terkirim, int total) {
        if (!mounted || total <= 0) {
          return;
        }

        // `setState` di dalam callback kemajuan, dan itu memang perlu — tanpa
        // indikator yang bergerak, unggahan setengah menit di jaringan buruk
        // terbaca sebagai aplikasi yang menggantung.
        setState(() => _mengunggah[type] = terkirim / total);
      },
    );

    if (!mounted) {
      return;
    }

    setState(() => _mengunggah.remove(type));

    switch (hasil) {
      case Ok<DriverDocument>():
        /*
         * Seluruh daftar dimuat ulang, bukan hanya barisnya yang diganti.
         *
         * Yang ikut berubah dan tidak terlihat dari satu baris: `missing` dan
         * `can_go_online`. Keduanya dihitung backend dari dokumen yang
         * DISETUJUI, dan unggahan yang mengganti dokumen `approved` justru
         * MENAMBAH daftar kurang — bukan menguranginya.
         *
         * Memperbarui satu baris saja akan membuat layar menyatakan driver siap
         * bekerja tepat setelah dia kehilangan persetujuannya.
         */
        await _muat();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$label terkirim. Menunggu verifikasi — biasanya 1×24 jam.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

      case Err<DriverDocument>(failure: final ApiFailure f):
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
    final Widget isi = _isi();

    if (widget.embedded) {
      return isi;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dokumen Saya')),
      body: isi,
    );
  }

  Widget _isi() {
    final DriverDocumentState? keadaan = _keadaan;

    if (keadaan == null && _memuat) {
      return const ClaySkeletonList(itemHeight: 104);
    }

    if (keadaan == null) {
      return ClayErrorState(
        message: _galat?.message ?? 'Daftar dokumen tidak bisa dimuat.',
        onRetry: _muat,
      );
    }

    return ClayRefresh(
      onRefresh: _muat,
      child: ListView(
        padding: const EdgeInsets.all(ClayTokens.space4),
        children: <Widget>[
          _Ringkasan(keadaan: keadaan),

          const SizedBox(height: ClayTokens.space5),

          /*
           * Yang digambar daftar JENIS WAJIB, bukan daftar dokumen yang ada.
           *
           * Itu yang membuat driver baru — yang daftar dokumennya kosong — tetap
           * melihat apa yang harus dia unggah.
           */
          for (final String jenis in keadaan.required)
            Padding(
              padding: const EdgeInsets.only(bottom: ClayTokens.space3),
              child: _KartuDokumen(
                type: jenis,
                dokumen: keadaan.forType(jenis),
                kemajuan: _mengunggah[jenis],
                onUnggah: (String label) => _unggah(jenis, label),
              ),
            ),

          /*
           * Dokumen TAMBAHAN yang sudah diunggah tapi tidak wajib.
           *
           * SKCK dan sertifikat vaksin masuk di sini: boleh diunggah, tidak
           * menghalangi driver bekerja. Menampilkannya di bagian terpisah
           * mencegahnya terbaca sebagai syarat — dan driver yang mengira SKCK
           * wajib akan menunda mendaftar berminggu-minggu untuk pengurusan yang
           * di luar kendalinya.
           */
          for (final DriverDocument d in keadaan.documents)
            if (!keadaan.required.contains(d.type))
              Padding(
                padding: const EdgeInsets.only(bottom: ClayTokens.space3),
                child: _KartuDokumen(
                  type: d.type,
                  dokumen: d,
                  kemajuan: _mengunggah[d.type],
                  onUnggah: (String label) => _unggah(d.type, label),
                ),
              ),

          const SizedBox(height: ClayTokens.space4),

          Text(
            'Foto akan dikecilkan sebelum dikirim, dan data lokasi di dalam '
            'fotonya dihapus. Pastikan seluruh tulisan pada dokumen terbaca '
            'jelas dan tidak ada bagian yang terpotong.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              height: 1.5,
              color: Theme.of(context).brightness == Brightness.dark
                  ? ClayTokens.textTertiaryDark
                  : ClayTokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan di atas: siap bekerja, atau berapa yang masih kurang.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.keadaan});

  final DriverDocumentState keadaan;

  @override
  Widget build(BuildContext context) {
    final bool siap = keadaan.canGoOnline;

    return ClaySurface(
      depth: ClayDepth.low,
      borderColor: siap ? ClayTokens.success : ClayTokens.warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            siap ? Icons.verified_rounded : Icons.pending_actions_rounded,
            size: 22,
            color: siap ? ClayTokens.success : ClayTokens.warning,
          ),
          const SizedBox(width: ClayTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  siap
                      ? 'Dokumen lengkap'
                      : keadaan.expired.isEmpty
                      ? '${keadaan.missing.length} dokumen belum disetujui'
                      : '${keadaan.expired.length} dokumen kadaluarsa',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: siap ? ClayTokens.success : ClayTokens.warning,
                  ),
                ),
                const SizedBox(height: 3),

                // Menyebut AKIBATNYA. "2 dokumen belum disetujui" tanpa kalimat
                // ini tidak memberi tahu driver bahwa itulah sebabnya dia tidak
                // bisa online.
                /*
                 * Kalimatnya membedakan "belum diunggah" dari "kadaluarsa",
                 * karena yang harus dilakukan driver berbeda:
                 *
                 *   belum diunggah   difoto dan dikirim dari aplikasi ini
                 *   kadaluarsa       diperpanjang di kantor yang menerbitkannya
                 *
                 * Menyuruh driver mengunggah ulang SIM yang kadaluarsa akan
                 * membuatnya mencoba berulang untuk masalah yang tidak ada di
                 * aplikasi.
                 */
                Text(
                  siap
                      ? 'Anda sudah bisa mulai bekerja.'
                      : keadaan.expired.isEmpty
                      ? 'Anda belum bisa mulai bekerja sampai semuanya '
                            'disetujui. Dokumen yang sudah dikirim '
                            'biasanya diperiksa dalam 1×24 jam.'
                      : 'Ada dokumen yang masa berlakunya sudah habis. '
                            'Perpanjang dulu di kantor yang '
                            'menerbitkannya, lalu unggah yang baru — '
                            'memfoto ulang yang lama tidak akan '
                            'diterima.',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    height: 1.5,
                    color: ClayTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu jenis dokumen: statusnya, dan tombol unggah/ganti.
class _KartuDokumen extends StatelessWidget {
  const _KartuDokumen({
    required this.type,
    required this.dokumen,
    required this.kemajuan,
    required this.onUnggah,
  });

  final String type;
  final DriverDocument? dokumen;

  /// Kemajuan unggahan 0..1, atau null kalau tidak sedang mengunggah.
  final double? kemajuan;

  final void Function(String label) onUnggah;

  /// Nama jenis dokumen untuk yang BELUM pernah diunggah.
  ///
  /// Untuk yang sudah ada, labelnya datang dari backend — jadi jenis baru yang
  /// ditambahkan backend tetap tampil dengan nama yang benar. Daftar di sini
  /// hanya untuk kartu kosong, dan jenis yang tidak dikenali memakai kodenya apa
  /// adanya alih-alih disembunyikan.
  static const Map<String, String> _label = <String, String>{
    'ktp': 'KTP',
    'sim': 'SIM',
    'stnk': 'STNK',
    'skck': 'SKCK',
    'selfie': 'Foto selfie',
    'bank_book': 'Buku rekening',
    'vaccine': 'Sertifikat vaksin',
  };

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final DriverDocument? d = dokumen;
    final String label = d?.label ?? _label[type] ?? type;

    final bool sedangUnggah = kemajuan != null;

    return ClaySurface(
      depth: ClayDepth.low,
      borderColor: _warnaTepi(d),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClaySurface(
                depth: ClayDepth.pressed,
                radius: ClayTokens.radiusSmall,
                padding: const EdgeInsets.all(ClayTokens.space3),
                child: Icon(_ikon(d), size: 20, color: _warna(d)),
              ),
              const SizedBox(width: ClayTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: gelap
                            ? ClayTokens.textPrimaryDark
                            : ClayTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d == null ? 'Belum diunggah' : d.statusLabel,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _warna(d),
                      ),
                    ),
                  ],
                ),
              ),

              if (!sedangUnggah)
                TextButton(
                  onPressed: () => onUnggah(label),
                  child: Text(d == null ? 'Unggah' : 'Ganti'),
                ),
            ],
          ),

          /*
           * Alasan penolakan ditampilkan APA ADANYA dari verifikator.
           *
           * Ini satu-satunya cara driver mengetahui apa yang salah. Tanpa itu dia
           * mengunggah foto yang sama berulang kali — dan setiap putaran memakan
           * waktu verifikator juga.
           */
          if (d != null && d.isRejected && d.rejectReason != null) ...<Widget>[
            const SizedBox(height: ClayTokens.space3),
            ClaySurface(
              depth: ClayDepth.pressed,
              radius: ClayTokens.radiusSmall,
              padding: const EdgeInsets.all(ClayTokens.space3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: ClayTokens.danger,
                  ),
                  const SizedBox(width: ClayTokens.space2),
                  Expanded(
                    child: Text(
                      d.rejectReason!,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        height: 1.45,
                        color: ClayTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (d != null && d.expiresAt != null) ...<Widget>[
            const SizedBox(height: ClayTokens.space2),
            Text(
              'Berlaku sampai ${_tanggal(d.expiresAt!)}',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: d.isExpired
                    ? ClayTokens.danger
                    : (gelap
                          ? ClayTokens.textTertiaryDark
                          : ClayTokens.textTertiary),
              ),
            ),
          ],

          if (sedangUnggah) ...<Widget>[
            const SizedBox(height: ClayTokens.space3),

            // Indikator BERNILAI, bukan yang berputar tanpa akhir. Driver di
            // jaringan buruk perlu tahu bahwa unggahannya bergerak — indikator
            // tak tentu tidak membedakan "sedang berjalan" dari "menggantung".
            ClipRRect(
              borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
              child: LinearProgressIndicator(
                value: kemajuan,
                minHeight: 6,
                backgroundColor: gelap
                    ? ClayTokens.surfaceSunkenDark
                    : ClayTokens.surfaceSunken,
              ),
            ),
            const SizedBox(height: ClayTokens.space2),
            Text(
              'Mengirim ${((kemajuan ?? 0) * 100).round()}%',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: ClayTokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color? _warnaTepi(DriverDocument? d) {
    if (d == null) {
      return null;
    }

    if (d.isRejected || (d.isApproved && d.isExpired)) {
      return ClayTokens.danger;
    }

    return d.isApproved ? ClayTokens.success : null;
  }

  static Color _warna(DriverDocument? d) {
    if (d == null) {
      return ClayTokens.textTertiary;
    }

    if (d.isRejected || (d.isApproved && d.isExpired)) {
      return ClayTokens.danger;
    }

    return d.isApproved ? ClayTokens.success : ClayTokens.warning;
  }

  static IconData _ikon(DriverDocument? d) {
    if (d == null) {
      return Icons.add_a_photo_rounded;
    }

    if (d.isRejected || (d.isApproved && d.isExpired)) {
      return Icons.error_rounded;
    }

    return d.isApproved
        ? Icons.check_circle_rounded
        : Icons.hourglass_top_rounded;
  }

  static String _tanggal(DateTime t) {
    const List<String> bulan = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${t.day} ${bulan[t.month - 1]} ${t.year}';
  }
}
