import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Daftar akun demo di bawah form masuk, dengan tombol yang langsung masuk.
///
/// Dinamai `Picker`, bukan `List`: `DemoAccountList` sudah dipakai model di
/// `antaride_api`, dan dua nama yang sama di satu berkas menuntut alias impor
/// yang membuat setiap pemakaiannya lebih panjang.
///
/// ============================================================================
///  ADA KARENA OTP TIDAK DIKIRIM KE MANA PUN
/// ============================================================================
///  Backend hanya punya `LogSmsSender` — kodenya ditulis ke berkas log, bukan
///  dikirim ke HP. Dan di produksi kode itu pun disembunyikan.
///
///  Jadi tanpa daftar ini, aplikasi yang menunjuk ke server yang sudah
///  ter-deploy tidak bisa dimasuki siapa pun. Bukan sulit — tidak bisa.
/// ============================================================================
///
/// ============================================================================
///  MENYEMBUNYIKAN DIRI SENDIRI SAAT FITURNYA MATI
/// ============================================================================
///  Server produksi sungguhan akan mematikan `ANTARIDE_DEMO_LOGIN`. Saat itu
///  terjadi, widget ini tidak menampilkan apa pun — bukan judul kosong, bukan
///  pesan "tidak ada akun demo".
///
///  Yang dihindari: layar masuk yang memuat bagian kosong bertuliskan sesuatu
///  tentang akun demo, di aplikasi yang dipakai pengguna sungguhan.
///
///  Kegagalan request juga berakhir sama — tersembunyi. Bagian tambahan yang
///  opsional tidak boleh menampilkan galat di layar pertama.
/// ============================================================================
class DemoAccountPicker extends StatefulWidget {
  const DemoAccountPicker({super.key, required this.role, this.onMasuk});

  /// `customer`, `driver`, atau `merchant`.
  ///
  /// ==========================================================================
  ///  SALAH PERAN BERARTI LAYAR KOSONG TANPA GALAT
  /// ==========================================================================
  ///  Aplikasi driver yang meminta peran `customer` akan menampilkan akun
  ///  penumpang — dan yang menekannya masuk sebagai penumpang DI APLIKASI
  ///  DRIVER. Token-nya sah, jadi tidak ada galat autentikasi; yang terjadi
  ///  setiap layar driver menjawab 403 dan terbaca sebagai aplikasi rusak.
  ///
  ///  Backend menyaringnya juga, tapi penyaringan di satu sisi saja berarti
  ///  bug ini hanya tertangkap kalau ada yang mengujinya di server yang benar.
  /// ==========================================================================
  final String role;

  /// Dipanggil setelah berhasil masuk.
  ///
  /// Boleh null: gerbang sesi di akar aplikasi sudah memindahkan layarnya
  /// sendiri begitu `stage` berubah. Callback ini untuk layar yang perlu
  /// menutup dirinya lebih dulu — misalnya yang dibuka sebagai route.
  final VoidCallback? onMasuk;

  @override
  State<DemoAccountPicker> createState() => _DemoAccountPickerState();
}

class _DemoAccountPickerState extends State<DemoAccountPicker> {
  List<DemoAccount> _akun = const <DemoAccount>[];
  bool _aktif = false;
  bool _memuat = true;

  /// uuid akun yang sedang diproses.
  ///
  /// Per akun, bukan satu penanda global: dua tombol yang keduanya berputar
  /// membuat pengguna tidak tahu mana yang dia tekan.
  String? _sedangMasuk;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() async {
    if (!mounted) {
      return;
    }

    final SessionController sesi = context.read<SessionController>();

    final DemoAccountList hasil = await sesi.demoAccounts(widget.role);

    if (!mounted) {
      return;
    }

    setState(() {
      _memuat = false;
      _aktif = hasil.enabled;
      _akun = hasil.accounts;
    });
  }

  Future<void> _masuk(DemoAccount akun) async {
    if (_sedangMasuk != null) {
      return;
    }

    setState(() => _sedangMasuk = akun.uuid);

    final SessionController sesi = context.read<SessionController>();

    final bool berhasil = await sesi.demoLogin(akun.uuid);

    if (!mounted) {
      return;
    }

    setState(() => _sedangMasuk = null);

    if (berhasil) {
      widget.onMasuk?.call();

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sesi.lastFailure?.message ??
              'Tidak bisa masuk dengan akun demo ini. Coba lagi.',
        ),
        backgroundColor: ClayTokens.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Saat masih memuat, saat fiturnya mati, dan saat gagal: TIDAK ADA APA PUN.
    //
    // Skeleton di sini akan berkedip di layar pertama untuk bagian yang mungkin
    // memang tidak ada — dan kedipan itu terlihat seperti kerusakan.
    if (_memuat || !_aktif) {
      return const SizedBox.shrink();
    }

    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: ClayTokens.space6),

        Row(
          children: <Widget>[
            Expanded(
              child: Divider(
                color: ClayTokens.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ClayTokens.space3,
              ),
              child: Text(
                'AKUN DEMO',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: gelap
                      ? ClayTokens.textTertiaryDark
                      : ClayTokens.textTertiary,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: ClayTokens.textTertiary.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),

        const SizedBox(height: ClayTokens.space3),

        /*
         * Fiturnya menyala tapi belum ada akun: dikatakan apa adanya.
         *
         * Ini berbeda dari fiturnya mati, dan bedanya penting bagi yang
         * menyiapkan server — dia lupa menjalankan seeder-nya, bukan salah
         * konfigurasi.
         */
        if (_akun.isEmpty)
          Text(
            'Fitur akun demo menyala, tapi belum ada akun yang disiapkan. '
            'Jalankan di server: php artisan db:seed --class=DemoAccountSeeder',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              height: 1.5,
              color: gelap
                  ? ClayTokens.textTertiaryDark
                  : ClayTokens.textTertiary,
            ),
          )
        else ...<Widget>[
          Text(
            'Untuk pengujian. Tekan Masuk untuk langsung memakai akun ini '
            'tanpa kode OTP.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              height: 1.5,
              color: gelap
                  ? ClayTokens.textTertiaryDark
                  : ClayTokens.textTertiary,
            ),
          ),

          const SizedBox(height: ClayTokens.space3),

          for (final DemoAccount a in _akun)
            Padding(
              padding: const EdgeInsets.only(bottom: ClayTokens.space3),
              child: _Kartu(
                akun: a,
                memuat: _sedangMasuk == a.uuid,

                // Tombol lain DIMATIKAN selama satu sedang diproses. Menekan dua
                // akun berturut-turut akan menerbitkan dua token dan yang menang
                // bergantung pada urutan balasan.
                aktif: _sedangMasuk == null,

                onTekan: () => _masuk(a),
              ),
            ),
        ],
      ],
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({
    required this.akun,
    required this.memuat,
    required this.aktif,
    required this.onTekan,
  });

  final DemoAccount akun;
  final bool memuat;
  final bool aktif;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.low,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  akun.name,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: gelap
                        ? ClayTokens.textPrimaryDark
                        : ClayTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  akun.phone,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    color: gelap
                        ? ClayTokens.textSecondaryDark
                        : ClayTokens.textSecondary,
                  ),
                ),
                if (akun.note != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    akun.note!,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      height: 1.4,
                      color: gelap
                          ? ClayTokens.textTertiaryDark
                          : ClayTokens.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: ClayTokens.space3),

          ClayButton(
            label: 'Masuk',
            onPressed: aktif ? onTekan : null,
            isLoading: memuat,
            variant: ClayButtonVariant.secondary,
            height: 40,
          ),
        ],
      ),
    );
  }
}
