import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/clay_tokens.dart';

/// Kerangka bentuk yang berkilau selagi data dimuat.
///
/// ============================================================================
///  SKELETON, BUKAN SPINNER — DAN BEDANYA BUKAN SELERA
/// ============================================================================
///  Spinner memberitahu bahwa sesuatu sedang berjalan. Skeleton memberitahu
///  APA yang akan muncul dan DI MANA.
///
///  Bedanya terasa di dua hal:
///
///    Layar tidak melompat  Tinggi skeleton sama dengan tinggi isi
///                          sebenarnya, jadi tidak ada pergeseran tata letak
///                          saat datanya datang. Layar yang melompat membuat
///                          orang menekan tombol yang salah — dan di layar
///                          konfirmasi pesanan, tombol yang salah berarti
///                          pesanan yang salah.
///
///    Waktu terasa singkat  Bentuk yang sudah terlihat membuat orang mulai
///                          membaca tata letaknya sebelum datanya ada. Spinner
///                          tidak memberi apa pun untuk dilakukan selama
///                          menunggu.
///
///  Yang dipakai `shimmer` dari pub.dev, dibungkus di sini supaya warna
///  kilauannya mengikuti tema clay dan tidak diputuskan ulang di setiap layar.
/// ============================================================================
class ClaySkeleton extends StatelessWidget {
  const ClaySkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = ClayTokens.radiusSmall,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClaySkeletonGroup(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Membungkus beberapa skeleton supaya kilauannya BERGERAK BERSAMAAN.
///
/// ============================================================================
///  SATU KILAUAN UNTUK SATU KELOMPOK, BUKAN SATU PER BENTUK
/// ============================================================================
///  Setiap `Shimmer` punya animasinya sendiri. Enam skeleton yang
///  masing-masing dibungkus `Shimmer` menghasilkan enam kilauan yang tidak
///  sinkron — dan yang terlihat bukan "sedang memuat", tapi kedipan acak.
///
///  Pola yang benar: satu [ClaySkeletonGroup] di sekeliling seluruh kelompok,
///  dan bentuk-bentuk polos di dalamnya. [ClaySkeleton] sendirian tetap
///  membungkus dirinya untuk pemakaian tunggal.
/// ============================================================================
class ClaySkeletonGroup extends StatelessWidget {
  const ClaySkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      // Warnanya mengikuti permukaan clay, bukan abu-abu bawaan. Skeleton yang
      // lebih terang daripada latarnya terbaca sebagai kartu kosong, bukan
      // sebagai isi yang sedang dimuat.
      baseColor: gelap
          ? ClayTokens.surfaceSunkenDark
          : ClayTokens.surfaceSunken,
      highlightColor: gelap
          ? ClayTokens.surfaceRaisedDark
          : ClayTokens.surfaceRaised,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Bentuk polos untuk dipakai DI DALAM [ClaySkeletonGroup].
class ClaySkeletonBox extends StatelessWidget {
  const ClaySkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = ClayTokens.radiusSmall,
    this.margin,
  });

  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton berbentuk daftar kartu.
///
/// Dipakai riwayat pesanan dan mutasi dompet. Tingginya disamakan dengan kartu
/// sebenarnya supaya tidak ada pergeseran saat datanya datang.
class ClaySkeletonList extends StatelessWidget {
  const ClaySkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 88,
    this.padding = const EdgeInsets.all(ClayTokens.space5),
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClaySkeletonGroup(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < itemCount; i++)
              ClaySkeletonBox(
                height: itemHeight,
                radius: ClayTokens.radiusMedium,
                margin: const EdgeInsets.only(bottom: ClayTokens.space3),
              ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton berbentuk kisi ikon layanan.
class ClaySkeletonGrid extends StatelessWidget {
  const ClaySkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 3,
    this.aspectRatio = 0.92,
  });

  final int itemCount;
  final int crossAxisCount;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return ClaySkeletonGroup(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: ClayTokens.space3,
          crossAxisSpacing: ClayTokens.space3,
          childAspectRatio: aspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (BuildContext context, int index) => const ClaySkeletonBox(
          height: double.infinity,
          radius: ClayTokens.radiusMedium,
        ),
      ),
    );
  }
}
