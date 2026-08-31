import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';

/// Satu halaman perkenalan.
class IntroPage {
  const IntroPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// Perkenalan aplikasi sebelum layar sambutan — "get started".
///
/// ============================================================================
///  TAMPIL SEKALI SEUMUR PEMASANGAN, DAN ITU SYARATNYA
/// ============================================================================
///  Perkenalan yang muncul setiap kali aplikasi dibuka berubah dari penjelasan
///  menjadi penghalang: orang yang sudah tahu aplikasinya harus melewati tiga
///  layar sebelum bisa memesan, setiap hari.
///
///  Penandanya disimpan pemanggil (lihat [onSelesai]), bukan di sini — layar
///  ini tidak tahu apa pun soal penyimpanan, dan itu yang membuatnya bisa
///  dipakai ketiga aplikasi dengan penyimpanan yang berbeda.
/// ============================================================================
///
/// ============================================================================
///  BISA DILEWATI DARI HALAMAN MANA PUN
/// ============================================================================
///  Tombol "Lewati" ada di setiap halaman, bukan hanya di halaman terakhir.
///  Perkenalan yang memaksa menggeser sampai habis sebelum boleh masuk membuat
///  orang yang hanya ingin memesan merasa aplikasinya menahan dia — dan yang
///  paling sering terjadi berikutnya adalah dia menutup aplikasinya.
/// ============================================================================
class IntroScreen extends StatefulWidget {
  const IntroScreen({
    super.key,
    required this.pages,
    required this.onSelesai,
    this.accent,
  });

  final List<IntroPage> pages;

  /// Dipanggil saat perkenalan selesai atau dilewati. Pemanggil yang menyimpan
  /// penandanya dan berpindah layar.
  final VoidCallback onSelesai;

  final Color? accent;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _halaman = PageController();

  int _indeks = 0;

  @override
  void dispose() {
    _halaman.dispose();
    super.dispose();
  }

  bool get _terakhir => _indeks >= widget.pages.length - 1;

  void _lanjut() {
    if (_terakhir) {
      widget.onSelesai();

      return;
    }

    _halaman.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final Color aksen = widget.accent ?? ClayTokens.primary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Tombol lewati di kanan atas — kebiasaan yang sudah dikenal, dan
            // pola yang dikenal tidak perlu dijelaskan.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: ClayTokens.space2,
                  right: ClayTokens.space4,
                ),
                child: TextButton(
                  onPressed: widget.onSelesai,
                  child: Text(
                    'Lewati',
                    style: TextStyle(
                      fontFamily: ClayTokens.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: gelap
                          ? ClayTokens.textSecondaryDark
                          : ClayTokens.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _halaman,
                itemCount: widget.pages.length,
                onPageChanged: (int i) => setState(() => _indeks = i),
                itemBuilder: (BuildContext _, int i) =>
                    _Halaman(halaman: widget.pages[i], aksen: aksen),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                ClayTokens.space6,
                ClayTokens.space4,
                ClayTokens.space6,

                // Bilah navigasi Android duduk persis di bawah tombol ini.
                // `viewPaddingOf`, bukan `paddingOf`: yang terakhir menjadi nol
                // begitu ada SafeArea di atasnya yang sudah mengonsumsinya.
                ClayTokens.space5 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                children: <Widget>[
                  _Titik(
                    jumlah: widget.pages.length,
                    aktif: _indeks,
                    aksen: aksen,
                  ),

                  const SizedBox(height: ClayTokens.space5),

                  ClayButton(
                    label: _terakhir ? 'Mulai' : 'Lanjut',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _lanjut,
                    expanded: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Halaman extends StatelessWidget {
  const _Halaman({required this.halaman, required this.aksen});

  final IntroPage halaman;
  final Color aksen;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ClayTokens.space8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Lingkaran gradien besar sebagai gambar. Ilustrasi sungguhan akan
          // lebih baik, tapi menambah aset per aplikasi — dan bentuk ini sudah
          // memakai bahasa yang sama dengan chip ikon di seluruh aplikasi.
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              gradient: ClayGradients.hero(aksen),
              shape: BoxShape.circle,
            ),
            child: Icon(halaman.icon, size: 58, color: Colors.white),
          ),

          const SizedBox(height: ClayTokens.space8),

          Text(
            halaman.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ClayTokens.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.2,
              color: gelap
                  ? ClayTokens.textPrimaryDark
                  : ClayTokens.textPrimary,
            ),
          ),

          const SizedBox(height: ClayTokens.space3),

          Text(
            halaman.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: ClayTokens.fontFamily,
              fontSize: 14,
              height: 1.55,
              color: gelap
                  ? ClayTokens.textSecondaryDark
                  : ClayTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Titik penanda halaman. Yang aktif memanjang jadi kapsul.
class _Titik extends StatelessWidget {
  const _Titik({
    required this.jumlah,
    required this.aktif,
    required this.aksen,
  });

  final int jumlah;
  final int aktif;
  final Color aksen;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < jumlah; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == aktif ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == aktif
                  ? aksen
                  : ClayTokens.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
            ),
          ),
      ],
    );
  }
}
