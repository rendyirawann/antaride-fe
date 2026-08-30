import 'package:flutter/material.dart';

import '../theme/clay_gradients.dart';
import '../theme/clay_tokens.dart';

/// Header gradien desain v2: bidang warna aksen yang menembus status bar.
///
/// ============================================================================
///  KENAPA MENEMBUS STATUS BAR, BUKAN DI BAWAHNYA
/// ============================================================================
///  Gradien harus ADA di belakang jam dan baterai — isinya saja yang turun.
///  Karena itu `MediaQuery.paddingOf(context).top` dipakai sebagai padding
///  dalam, BUKAN SafeArea sebagai pembungkus: SafeArea mendorong seluruh
///  bidangnya ke bawah dan menyisakan strip warna latar di atasnya, yang
///  terbaca sebagai layar yang belum selesai dimuat.
/// ============================================================================
///
/// ============================================================================
///  SUDUT BAWAH 36, LEBIH BESAR DARI RADIUS KARTU MANA PUN
/// ============================================================================
///  Kartu clay maksimal 28 ([ClayTokens.radiusLarge]). Hero sengaja melewati
///  itu: dia bukan kartu, dia latar — dan sudut yang lebih besar dari semua
///  kartu di bawahnya yang membuat hierarki itu terbaca tanpa dijelaskan.
///  Lingkaran samarnya tekstur, bukan informasi: cukup dua, keduanya putih
///  transparan supaya ikut warna aksen apa pun.
/// ============================================================================
class ClayHeroHeader extends StatelessWidget {
  const ClayHeroHeader({
    super.key,
    required this.accent,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.bottom,
    this.compact = false,
  });

  /// Warna aksen aplikasi. Gradiennya diturunkan lewat [ClayGradients.hero] —
  /// tidak pernah dua warna terpisah.
  final Color accent;

  final String title;
  final String? subtitle;

  /// Slot kiri di baris atas — lazimnya [ClayBackButton] atau mark logo.
  final Widget? leading;

  /// Slot kanan di baris atas — ikon notifikasi, avatar, tombol bantuan.
  final Widget? trailing;

  /// Slot di bawah judul: chip status, kolom cari, saldo.
  final Widget? bottom;

  /// Versi pendek untuk layar sekunder: judul 20, jarak dirapatkan.
  ///
  /// Layar sekunder (form, detail) dibuka BERKALI-KALI dalam satu sesi;
  /// hero setinggi beranda di sana memakan layar yang seharusnya milik isi.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Menembus status bar — lihat docblock kelas.
    final double atas = MediaQuery.paddingOf(context).top;

    final bool adaBarisAtas = leading != null || trailing != null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: ClayGradients.hero(accent)),
        child: Stack(
          children: <Widget>[
            const Positioned(
              top: -70,
              right: -50,
              child: _Lingkaran(diameter: 220, alpha: 0.08),
            ),
            const Positioned(
              bottom: -90,
              left: -70,
              child: _Lingkaran(diameter: 240, alpha: 0.06),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                ClayTokens.space6,
                atas + (compact ? ClayTokens.space4 : ClayTokens.space8),
                ClayTokens.space6,
                compact ? ClayTokens.space5 : ClayTokens.space8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (adaBarisAtas) ...<Widget>[
                    Row(
                      children: <Widget>[?leading, const Spacer(), ?trailing],
                    ),
                    SizedBox(
                      height: compact ? ClayTokens.space4 : ClayTokens.space5,
                    ),
                  ],

                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: compact ? 20 : 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: compact ? -0.4 : -0.6,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),

                  if (subtitle != null) ...<Widget>[
                    SizedBox(
                      height: compact ? ClayTokens.space1 : ClayTokens.space3,
                    ),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: compact ? 12.5 : 14,
                        height: 1.55,

                        // Putih diredupkan, bukan abu-abu: abu-abu di atas
                        // gradien berwarna terlihat kotor, putih transparan
                        // ikut warna aksennya.
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],

                  if (bottom != null) ...<Widget>[
                    const SizedBox(height: ClayTokens.space5),
                    bottom!,
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

/// Kerangka layar dengan hero: header di atas, isi di bawah, dan kartu yang
/// boleh MENUMPANG di tepi bawah hero.
///
/// ============================================================================
///  BAGAIMANA OVERLAP-NYA BEKERJA
/// ============================================================================
///  [overlap] dibungkus `Align(heightFactor: 0.5, alignment: bottomCenter)`:
///  ruang yang diminta ke Column hanya SETENGAH tinggi kartunya, dan setengah
///  sisanya meluap ke atas menindih hero. Column tidak memotong anaknya, dan
///  overlap digambar SESUDAH header, jadi dia menang urutan lukis.
///
///  Alternatif yang DITOLAK: `Transform.translate(0, -tinggi/2)`. Transform
///  hanya menggeser gambarnya, bukan layout-nya — ruang kosong setinggi
///  setengah kartu tertinggal di bawahnya, dan isi layar mulai terlalu jauh.
///  Mengukurnya manual butuh tinggi kartu yang belum diketahui saat build.
/// ============================================================================
class ClayHeroScaffold extends StatelessWidget {
  const ClayHeroScaffold({
    super.key,
    required this.header,
    required this.body,
    this.overlap,
  });

  final ClayHeroHeader header;

  /// Isi layar. Kalau bisa panjang, bungkus scroll SENDIRI di pemanggil —
  /// kerangka ini sengaja tidak memaksakan scroll supaya layar daftar bisa
  /// memakai ClayRefresh miliknya.
  final Widget body;

  /// Kartu yang menumpang di tepi bawah hero (naik setengah tingginya) —
  /// tempat nominal penting: saldo, ringkasan order.
  final Widget? overlap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,

          if (overlap != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ClayTokens.space6,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 0.5,
                child: overlap!,
              ),
            ),

          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Lingkaran samar tekstur hero. Putih transparan supaya ikut aksen apa pun.
class _Lingkaran extends StatelessWidget {
  const _Lingkaran({required this.diameter, required this.alpha});

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
