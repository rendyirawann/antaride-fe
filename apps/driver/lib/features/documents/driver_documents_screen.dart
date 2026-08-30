import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_media/antaride_media.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Aksen aplikasi driver — hijau tua, bukan hijau penumpang.
///
/// Dipakai untuk indikator unggahan dan panel "siap bekerja". Diambil dari
/// token, bukan ditulis ulang sebagai `Color(0xFF057A55)` di beberapa tempat:
/// nilai yang disalin akan menyimpang dari palet begitu paletnya berubah.
const Color _aksenDriver = ClayTokens.primaryDark;

/// Batas giliran animasi masuk.
///
/// Daftar ini bisa berisi delapan kartu. Dengan jeda 70 ms per tingkat, kartu
/// terakhir baru selesai lebih dari satu detik setelah halaman dibuka — dan
/// layar yang masih bergerak saat driver sudah mulai membacanya terbaca sebagai
/// lambat, bukan hidup. Mulai tingkat kelima seluruh sisanya masuk bersamaan.
int _giliran(int urutan) => urutan > 5 ? 5 : urutan;

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
///
/// ============================================================================
///  KEPALA HALAMAN v2: PANEL GRADIEN, BUKAN HERO YANG MENEMBUS STATUS BAR
/// ============================================================================
///  Halaman ini hidup DI DALAM `ClayDrawerShell`, yang sudah memasang bilah atas
///  beserta hamburger-nya. Hero v2 yang menembus status bar akan menghasilkan
///  dua kepala halaman bertumpuk — bilah shell di atas bidang gradien.
///
///  Yang dipakai di sini bentuk yang sama dengan strip status di layar order
///  berjalan: KARTU bergradien (radius kartu, bayangan berwarna) di puncak isi.
///  Bahasanya v2, tempatnya di bawah bilah shell — dan itu yang membuat halaman
///  driver terlihat dikerjakan orang yang sama.
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

    /*
     * Dokumen TAMBAHAN yang sudah diunggah tapi tidak wajib.
     *
     * SKCK dan sertifikat vaksin masuk di sini: boleh diunggah, tidak
     * menghalangi driver bekerja. Menampilkannya di bagian terpisah mencegahnya
     * terbaca sebagai syarat — dan driver yang mengira SKCK wajib akan menunda
     * mendaftar berminggu-minggu untuk pengurusan yang di luar kendalinya.
     *
     * Dikumpulkan lebih dulu — saringan dan urutannya PERSIS seperti sebelumnya
     * — supaya label bagiannya hanya muncul kalau memang ada isinya. Judul
     * bagian tanpa satu kartu pun di bawahnya terbaca sebagai daftar yang gagal
     * dimuat.
     */
    final List<DriverDocument> tambahan = keadaan.documents
        .where((DriverDocument d) => !keadaan.required.contains(d.type))
        .toList(growable: false);

    // Giliran animasi masuk berjalan LINTAS bagian: panel, label, kartu wajib,
    // lalu kartu tambahan. Nomor yang dihitung ulang per bagian akan membuat
    // kartu pertama bagian kedua muncul bersamaan dengan kartu pertama bagian
    // pertama, dan urutannya berhenti terbaca sebagai urutan.
    int urutan = 0;

    return ClayRefresh(
      onRefresh: _muat,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          ClayTokens.space5,
          ClayTokens.space4,
          ClayTokens.space5,
          ClayTokens.space8,
        ),
        children: <Widget>[
          ClayEntrance(
            key: const ValueKey<String>('ringkasan'),
            index: _giliran(urutan++),
            child: _PanelRingkasan(keadaan: keadaan),
          ),

          const SizedBox(height: ClayTokens.space5),

          ClayEntrance(
            key: const ValueKey<String>('label-wajib'),
            index: _giliran(urutan++),
            child: const _LabelBagian('Dokumen wajib'),
          ),

          /*
           * Yang digambar daftar JENIS WAJIB, bukan daftar dokumen yang ada.
           *
           * Itu yang membuat driver baru — yang daftar dokumennya kosong — tetap
           * melihat apa yang harus dia unggah.
           */
          for (final String jenis in keadaan.required)
            Padding(
              padding: const EdgeInsets.only(bottom: ClayTokens.space3),

              /*
               * Key per JENIS, bukan per posisi.
               *
               * Halaman ini dibangun ulang pada setiap detak kemajuan unggahan.
               * Tanpa key yang mengikuti identitas datanya, kartu yang bergeser
               * posisi (daftar wajib bertambah setelah `_muat`) akan mengambil
               * alih State milik tetangganya dan memutar ulang animasi masuknya
               * — seluruh daftar berkedip saat unggahan sedang berjalan.
               */
              child: ClayEntrance(
                key: ValueKey<String>('wajib-$jenis'),
                index: _giliran(urutan++),
                child: _KartuDokumen(
                  type: jenis,
                  dokumen: keadaan.forType(jenis),
                  kemajuan: _mengunggah[jenis],
                  onUnggah: (String label) => _unggah(jenis, label),
                ),
              ),
            ),

          if (tambahan.isNotEmpty) ...<Widget>[
            const SizedBox(height: ClayTokens.space3),

            ClayEntrance(
              key: const ValueKey<String>('label-tambahan'),
              index: _giliran(urutan++),
              child: const _LabelBagian('Dokumen tambahan'),
            ),

            for (final DriverDocument d in tambahan)
              Padding(
                padding: const EdgeInsets.only(bottom: ClayTokens.space3),
                child: ClayEntrance(
                  key: ValueKey<String>('tambahan-${d.type}'),
                  index: _giliran(urutan++),
                  child: _KartuDokumen(
                    type: d.type,
                    dokumen: d,
                    kemajuan: _mengunggah[d.type],
                    onUnggah: (String label) => _unggah(d.type, label),
                  ),
                ),
              ),
          ],

          const SizedBox(height: ClayTokens.space3),

          ClayEntrance(
            key: const ValueKey<String>('catatan'),
            index: _giliran(urutan++),
            child: const _CatatanFoto(),
          ),
        ],
      ),
    );
  }
}

/// Label bagian beserta jarak bawahnya.
///
/// Bentuk yang sama dipakai layar order berjalan — ritme vertikal dua halaman
/// driver jadi identik tanpa masing-masing menebak jaraknya sendiri.
class _LabelBagian extends StatelessWidget {
  const _LabelBagian(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: ClayTokens.space1,
        bottom: ClayTokens.space2,
      ),
      child: ClaySectionLabel(teks),
    );
  }
}

/// Panel ringkasan: siap bekerja, atau berapa yang masih kurang.
///
/// ============================================================================
///  KENAPA INI SATU-SATUNYA BIDANG BERGRADIEN DI HALAMAN
/// ============================================================================
///  Ini jawaban atas satu-satunya pertanyaan yang membawa driver kemari: boleh
///  kerja atau belum. Versi lama menaruhnya di kartu clay yang bobotnya sama
///  dengan kartu dokumen di bawahnya — jawabannya tenggelam di antara daftar.
///
///  Warnanya IKUT jawabannya: gradien hijau saat lengkap, gradien amber saat
///  belum. Statusnya terbaca dari warna seluruh panel sebelum satu huruf pun
///  dibaca — dan itu yang dibutuhkan aplikasi yang dibuka sambil berdiri di
///  pinggir jalan. Gradiennya diturunkan `ClayGradients.hero`: satu warna masuk,
///  satu gradien keluar, sama seperti hero v2 di layar lain.
/// ============================================================================
class _PanelRingkasan extends StatelessWidget {
  const _PanelRingkasan({required this.keadaan});

  final DriverDocumentState keadaan;

  @override
  Widget build(BuildContext context) {
    final bool siap = keadaan.canGoOnline;

    final Color warna = siap ? ClayTokens.success : ClayTokens.warning;

    final int wajib = keadaan.required.length;

    // Angkanya datang dari backend, dan bilah kemajuan tidak boleh mempercayainya
    // buta: `missing` yang lebih panjang dari `required` akan menghasilkan bilah
    // terisi terbalik — lebih buruk daripada bilah yang tidak berubah.
    final int belum = keadaan.missing.length > wajib
        ? wajib
        : keadaan.missing.length;

    final int disetujui = wajib - belum;

    return Container(
      padding: const EdgeInsets.all(ClayTokens.space5),
      decoration: BoxDecoration(
        gradient: ClayGradients.hero(warna),
        borderRadius: BorderRadius.circular(ClayTokens.radiusLarge),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: warna.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _TileKaca(
                child: Icon(
                  siap ? Icons.verified_rounded : Icons.pending_actions_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: ClayTokens.space4),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'STATUS DOKUMEN',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      siap
                          ? 'Dokumen lengkap'
                          : keadaan.expired.isEmpty
                          ? '${keadaan.missing.length} dokumen belum disetujui'
                          : '${keadaan.expired.length} dokumen kadaluarsa',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: ClayTokens.space4),

          // Menyebut AKIBATNYA. "2 dokumen belum disetujui" tanpa kalimat ini
          // tidak memberi tahu driver bahwa itulah sebabnya dia tidak bisa
          // online.
          /*
           * Kalimatnya membedakan "belum diunggah" dari "kadaluarsa", karena
           * yang harus dilakukan driver berbeda:
           *
           *   belum diunggah   difoto dan dikirim dari aplikasi ini
           *   kadaluarsa       diperpanjang di kantor yang menerbitkannya
           *
           * Menyuruh driver mengunggah ulang SIM yang kadaluarsa akan membuatnya
           * mencoba berulang untuk masalah yang tidak ada di aplikasi.
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
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              height: 1.5,

              // Putih diredupkan, bukan abu-abu: abu-abu di atas gradien
              // berwarna terlihat kotor.
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),

          /*
           * Bilah kemajuan verifikasi.
           *
           * Angka "2 dokumen belum disetujui" tidak memberi tahu seberapa jauh
           * driver sudah berjalan — dan yang menentukan apakah dia mau
           * meneruskan pengurusan hari itu justru itu. Disembunyikan kalau
           * daftar wajibnya kosong: bilah tanpa penyebut adalah pembagian nol.
           */
          if (wajib > 0) ...<Widget>[
            const SizedBox(height: ClayTokens.space4),

            Text(
              '$disetujui dari $wajib dokumen wajib disetujui',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),

            const SizedBox(height: ClayTokens.space2),

            ClipRRect(
              borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
              child: LinearProgressIndicator(
                value: disetujui / wajib,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
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

  /// Ikon per JENIS dokumen — identitas kartunya.
  ///
  /// Terpisah dari ikon STATUS ([_ikon], yang duduk di lencana): jenis dokumen
  /// itulah yang dicari driver saat memindai daftar, dan tujuh kartu dengan ikon
  /// status yang sama membuat pemindaian itu berubah jadi membaca satu per satu.
  /// Jenis yang tidak dikenali memakai ikon dokumen generik — TIDAK
  /// disembunyikan, dengan alasan yang sama seperti label di atas.
  static const Map<String, IconData> _ikonJenis = <String, IconData>{
    'ktp': Icons.badge_rounded,
    'sim': Icons.credit_card_rounded,
    'stnk': Icons.two_wheeler_rounded,
    'skck': Icons.local_police_rounded,
    'selfie': Icons.face_rounded,
    'bank_book': Icons.account_balance_rounded,
    'vaccine': Icons.vaccines_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final DriverDocument? d = dokumen;
    final String label = d?.label ?? _label[type] ?? type;

    final bool sedangUnggah = kemajuan != null;

    /*
     * Bentuk tombol mengikuti apakah ada yang harus DIKERJAKAN.
     *
     * Belum diunggah, ditolak, atau kadaluarsa: tombol pejal, terlihat dari
     * jauh — itu pekerjaan yang menghalangi driver bekerja. Sudah disetujui
     * atau sedang diperiksa: tombol garis, karena mengganti fotonya di situ
     * justru MENGHAPUS persetujuan yang sudah didapat, dan tombol pejal
     * mengundang tekanan yang merugikan pemiliknya.
     */
    final bool perluTindakan =
        d == null || d.isRejected || (d.isApproved && d.isExpired);

    return ClaySurface(
      depth: ClayDepth.low,
      borderColor: _warnaTepi(d),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Chip bergradien berwarna STATUS — hijau disetujui, amber sedang
              // diperiksa, merah bermasalah, abu belum diunggah — dengan ikon
              // JENIS dokumennya. Dua informasi dalam satu tile 46 px, dan
              // gradiennya membuatnya benda dalam sistem cahaya yang sama
              // dengan kartunya, bukan stiker yang ditempel.
              ClayIconChip(
                icon: _ikonJenis[type] ?? Icons.description_rounded,
                accent: _warna(d),
                size: 46,
              ),

              const SizedBox(width: ClayTokens.space4),

              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: gelap
                        ? ClayTokens.textPrimaryDark
                        : ClayTokens.textPrimary,
                  ),
                ),
              ),

              if (!sedangUnggah) ...<Widget>[
                const SizedBox(width: ClayTokens.space3),

                // `expanded: false` WAJIB di dalam Row — tanpa itu tombolnya
                // meminta lebar tak terhingga dan keluar dari layar.
                //
                // Tingginya target sentuh penuh, tidak dikecilkan agar muat:
                // driver menekannya dengan sarung tangan.
                ClayButton(
                  label: d == null ? 'Unggah' : 'Ganti',
                  variant: perluTindakan
                      ? ClayButtonVariant.primary
                      : ClayButtonVariant.ghost,
                  expanded: false,
                  height: ClayTokens.minTouchTarget,
                  onPressed: () => onUnggah(label),
                ),
              ],
            ],
          ),

          const SizedBox(height: ClayTokens.space3),

          // Lencana status dan masa berlaku dalam satu Wrap: di HP sempit yang
          // kedua turun ke baris berikutnya alih-alih meluap keluar kartu.
          Wrap(
            spacing: ClayTokens.space2,
            runSpacing: ClayTokens.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _LencanaVerifikasi(
                // Kalimat statusnya dari backend — di sini hanya digayakan.
                label: d == null ? 'Belum diunggah' : d.statusLabel,
                ikon: _ikon(d),
                warna: _warna(d),
              ),

              if (d != null && d.expiresAt != null)
                _ChipTanggal(
                  teks: 'Berlaku sampai ${_tanggal(d.expiresAt!)}',
                  bermasalah: d.isExpired,
                  gelap: gelap,
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
            _PanelCatatan(
              warna: ClayTokens.danger,
              ikon: Icons.info_outline_rounded,
              teks: d.rejectReason!,
              gelap: gelap,
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
                valueColor: const AlwaysStoppedAnimation<Color>(_aksenDriver),
              ),
            ),
            const SizedBox(height: ClayTokens.space2),
            Text(
              'Mengirim ${((kemajuan ?? 0) * 100).round()}%',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
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

/// Lencana status verifikasi dokumen.
///
/// ============================================================================
///  KENAPA BUKAN ClayStatusBadge
/// ============================================================================
///  `ClayStatusBadge` menurunkan warnanya dari status ORDER (`searching`,
///  `driver_arrived`, `completed`). Status dokumen — `approved`, `pending`,
///  `rejected` — tidak ada di peta itu dan jatuh ke cabang `_` yang abu-abu:
///  seluruh lencana di halaman ini akan berwarna sama, padahal justru warna
///  itulah informasinya.
///
///  Menitipkan status order palsu (`completed` untuk dokumen disetujui) supaya
///  warnanya kebetulan benar akan menyandera halaman ini pada peta status milik
///  order — satu perubahan di sana mengubah arti warna di sini tanpa hubungan
///  apa pun. Jadi bentuknya disalin, warnanya milik sendiri.
///
///  Yang seharusnya terjadi di paket bersama: `ClayStatusBadge` menerima warna
///  eksplisit (atau ada lencana berparameter warna) supaya bentuk ini tidak
///  perlu disalin lagi di layar berikutnya yang statusnya bukan status order.
///
///  Titiknya diganti IKON status, karena di sini ikonnya membawa arti yang
///  berbeda per status — bukan sekadar pengulang warna.
/// ============================================================================
class _LencanaVerifikasi extends StatelessWidget {
  const _LencanaVerifikasi({
    required this.label,
    required this.ikon,
    required this.warna,
  });

  final String label;
  final IconData ikon;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space3,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        // Latar transparan dari warnanya, bukan warna penuh — alasan yang sama
        // seperti ClayStatusBadge: lencana pejal bersaing dengan tombol di baris
        // tepat di atasnya.
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(ikon, size: 13, color: warna),
          const SizedBox(width: 6),

          // Flexible + ellipsis: kalimat statusnya datang dari backend dan
          // panjangnya tidak dijamin. Tanpa ini, satu label panjang merobek
          // kartunya dengan pita oranye-hitam alih-alih dipotong.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: warna,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip masa berlaku. Merah kalau tanggalnya sudah lewat.
class _ChipTanggal extends StatelessWidget {
  const _ChipTanggal({
    required this.teks,
    required this.bermasalah,
    required this.gelap,
  });

  final String teks;
  final bool bermasalah;
  final bool gelap;

  @override
  Widget build(BuildContext context) {
    final Color warna = bermasalah
        ? ClayTokens.danger
        : (gelap ? ClayTokens.textTertiaryDark : ClayTokens.textTertiary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.event_rounded, size: 13, color: warna),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            teks,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: warna,
            ),
          ),
        ),
      ],
    );
  }
}

/// Panel catatan bertepi berwarna — dipakai untuk alasan penolakan.
///
/// Tepi kiri 3 px digambar sebagai KOTAK di dalam ClipRRect, bukan sebagai
/// `Border(left: …)` pada BoxDecoration: border tak seragam yang digabung dengan
/// borderRadius melanggar assert BoxDecoration, dan gejalanya pengecualian saat
/// melukis — bukan tampilan yang sedikit meleset.
class _PanelCatatan extends StatelessWidget {
  const _PanelCatatan({
    required this.warna,
    required this.ikon,
    required this.teks,
    required this.gelap,
  });

  final Color warna;
  final IconData ikon;
  final String teks;
  final bool gelap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 3, child: ColoredBox(color: warna)),
            Expanded(
              child: ColoredBox(
                color: warna.withValues(alpha: gelap ? 0.16 : 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(ClayTokens.space3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(ikon, size: 16, color: warna),
                      const SizedBox(width: ClayTokens.space2),
                      Expanded(
                        child: Text(
                          teks,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            height: 1.45,
                            color: gelap
                                ? ClayTokens.textSecondaryDark
                                : ClayTokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Catatan kaki: apa yang terjadi pada foto yang dikirim.
class _CatatanFoto extends StatelessWidget {
  const _CatatanFoto();

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    final Color warna = gelap
        ? ClayTokens.textTertiaryDark
        : ClayTokens.textTertiary;

    return ClaySurface(
      depth: ClayDepth.pressed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.privacy_tip_rounded, size: 18, color: warna),
          const SizedBox(width: ClayTokens.space3),
          Expanded(
            child: Text(
              'Foto akan dikecilkan sebelum dikirim, dan data lokasi di dalam '
              'fotonya dihapus. Pastikan seluruh tulisan pada dokumen terbaca '
              'jelas dan tidak ada bagian yang terpotong.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                height: 1.5,
                color: warna,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile kaca buram untuk DI DALAM panel gradien.
///
/// Putih transparan, bukan warna pejal: dengan begitu tile ini ikut warna
/// panelnya (hijau saat lengkap, amber saat kurang) tanpa satu pun cabang warna
/// — pola yang sama dengan lingkaran tekstur di hero v2.
class _TileKaca extends StatelessWidget {
  const _TileKaca({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(ClayTokens.radiusSmall),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Center(child: child),
    );
  }
}
