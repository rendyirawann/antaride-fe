import 'package:flutter/material.dart';

import 'clay_glass_button.dart';

/// Tombol kembali untuk DI DALAM hero gradien: lingkaran kaca buram berisi
/// panah putih.
///
/// ============================================================================
///  KENAPA BUKAN BackButton BAWAAN, DAN KENAPA KACA BURAM
/// ============================================================================
///  BackButton Material mengambil warna dari tema — di atas gradien aksen dia
///  jadi panah gelap tanpa latar, yang tenggelam di area paling ramai layar
///  (berdampingan dengan jam dan sinyal). Lingkaran putih transparan memberi
///  bidang sentuh yang TERLIHAT, dan karena warnanya putih-alpha (bukan warna
///  pejal) dia ikut aksen apa pun — sama seperti lingkaran tekstur hero.
///
///  Di luar hero jangan pakai ini: kaca buram butuh latar pekat di belakangnya;
///  di atas permukaan clay yang pucat dia nyaris tak terlihat.
/// ============================================================================
///
/// Bentuknya sendiri hidup di [ClayGlassButton], yang juga dipakai hamburger
/// dan lonceng notifikasi di hero beranda. Kelas ini tinggal namanya dan
/// perilaku bawaannya — dan itu berguna: `ClayBackButton()` tanpa argumen
/// terbaca lebih jelas di layar form daripada glass button dengan tiga
/// parameter yang selalu sama.
class ClayBackButton extends StatelessWidget {
  const ClayBackButton({super.key, this.onPressed});

  /// Bawaannya `Navigator.maybePop` — maybePop, bukan pop, supaya tombol yang
  /// terpasang di route pertama (mis. saat layar dipakai sebagai home waktu
  /// pengembangan) tidak melempar karena tumpukannya kosong.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClayGlassButton(
      icon: Icons.arrow_back_rounded,
      semanticLabel: 'Kembali',
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}
