import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'edit_profile_screen.dart';

/// Profil dan pengaturan akun.
///
/// ============================================================================
///  KENAPA TANPA HERO GRADIEN, PADAHAL INI BAHASA V2
/// ============================================================================
///  Halaman ini hidup DI BAWAH AppBar milik shell (bukan halaman full-bleed),
///  jadi hero yang menembus status bar akan bertumpuk dengan bilah shell dan
///  terbaca sebagai dua kepala halaman. Bahasa v2 masuk lewat isi halaman:
///  avatar inisial dalam lingkaran bergradien aksen, chip ikon bergradien di
///  tiap baris menu, dan label seksi yang memisahkan Akun / Sesi / zona
///  bahaya — penghapusan akun sengaja dipisah paling jauh dan diberi bingkai
///  merah supaya tidak pernah tertekan karena dikira baris menu biasa.
/// ============================================================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _keluar(BuildContext context, {required bool semua}) async {
    // Wadahnya ClayConfirmDialog bersama, bukan AlertDialog per layar:
    // dialog "Keluar?" yang sama pernah punya dua rupa di aplikasi ini.
    // Kontraknya tetap bool — batal maupun tutup di luar mengembalikan false.
    final bool yakin = await ClayConfirmDialog.tampilkan(
      context,
      icon: semua ? Icons.phonelink_erase_rounded : Icons.logout_rounded,
      title: semua ? 'Keluar dari semua perangkat?' : 'Keluar?',
      message: semua
          // Menyebutkan konsekuensinya secara konkret. "Anda akan keluar
          // dari semua sesi" tidak memberitahu bahwa HP lain ikut terkena —
          // dan itu justru yang perlu diketahui.
          ? 'Semua perangkat yang masuk dengan akun ini akan dikeluarkan, '
                'termasuk perangkat ini. Pakai ini kalau HP Anda hilang.'
          : 'Anda perlu memasukkan kode OTP lagi untuk masuk.',
      confirmLabel: 'Keluar',
    );

    if (!yakin || !context.mounted) {
      return;
    }

    // Tidak ada navigasi setelah ini. Gerbang di akar aplikasi mengamati
    // `SessionStage`, dan begitu tahapnya `signedOut` seluruh tumpukan diganti
    // layar masuk.
    await context.read<SessionController>().signOut(allDevices: semua);
  }

  Future<void> _hapusAkun(BuildContext context) async {
    final bool yakin = await ClayConfirmDialog.tampilkan(
      context,
      icon: Icons.delete_forever_rounded,
      title: 'Hapus akun?',
      message:
          'Akun Anda akan dihapus setelah masa tenggang. Masuk kembali sebelum '
          'tenggangnya habis untuk membatalkan penghapusan.',
      confirmLabel: 'Ajukan penghapusan',
    );

    if (!yakin || !context.mounted) {
      return;
    }

    final AntarideServices services = context.read<AntarideServices>();

    final Result<AccountDeletion> hasil = await services.auth.requestDeletion();

    if (!context.mounted) {
      return;
    }

    switch (hasil) {
      case Ok<AccountDeletion>(value: final AccountDeletion d):
        // Pesannya dari BACKEND, sudah memuat jumlah harinya. Menulis angkanya
        // di aplikasi berarti menjanjikan tenggang yang bisa berbeda dari
        // kebijakan yang berlaku.
        await ClayConfirmDialog.beritahu(
          context,
          icon: Icons.schedule_rounded,
          title: 'Penghapusan diajukan',
          message: d.message,
        );

      case Err<AccountDeletion>(failure: final ApiFailure f):
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
    final SessionController sesi = context.watch<SessionController>();
    final AuthUser? user = sesi.user;
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: user == null
          ? ClayErrorState(
              message: sesi.lastFailure?.message ?? 'Profil tidak bisa dimuat.',
              onRetry: sesi.refreshProfile,
            )
          : ListView(
              padding: const EdgeInsets.all(ClayTokens.space5),
              children: <Widget>[
                /*
                 * Animasi masuk bergiliran per SEKSI, bukan per baris: halaman
                 * ini pendek dan seluruh seksinya terlihat sekaligus, jadi lima
                 * giliran cukup terbaca sebagai urutan tanpa membuat pengguna
                 * menunggu barisan kartu satu per satu. Halaman hidup di
                 * IndexedStack shell, jadi giliran hanya diputar sekali —
                 * saat tab pertama kali dibuka.
                 */
                ClayEntrance(index: 0, child: _Kepala(user: user)),

                if (!user.profileComplete) ...<Widget>[
                  const SizedBox(height: ClayTokens.space4),
                  ClayEntrance(
                    index: 1,
                    child: _AjakanLengkapi(onTap: () => _bukaEdit(context)),
                  ),
                ],

                const SizedBox(height: ClayTokens.space6),

                ClayEntrance(
                  index: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _LabelSeksi('Akun'),

                      _Baris(
                        icon: Icons.person_outline_rounded,
                        label: 'Ubah profil',
                        onTap: () => _bukaEdit(context),
                      ),

                      _Baris(
                        icon: Icons.card_giftcard_rounded,
                        label: 'Kode referral',
                        nilai: user.referralCode,
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: user.referralCode),
                          );

                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kode referral disalin.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),

                      _Baris(
                        icon: Icons.phone_rounded,
                        label: 'Nomor HP',
                        nilai: user.phone,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: ClayTokens.space4),

                ClayEntrance(
                  index: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _LabelSeksi('Sesi'),

                      _Baris(
                        icon: Icons.logout_rounded,
                        label: 'Keluar',
                        onTap: () => _keluar(context, semua: false),
                      ),

                      _Baris(
                        icon: Icons.phonelink_erase_rounded,
                        label: 'Keluar dari semua perangkat',
                        onTap: () => _keluar(context, semua: true),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: ClayTokens.space4),

                ClayEntrance(
                  index: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _LabelSeksi('Zona bahaya'),
                      _ZonaBahaya(onTap: () => _hapusAkun(context)),
                    ],
                  ),
                ),

                const SizedBox(height: ClayTokens.space8),

                Center(
                  child: Text(
                    'Antaride ${AppConfig.environment == 'production' ? '' : '· ${AppConfig.environment}'}',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: gelap
                          ? ClayTokens.textTertiaryDark
                          : ClayTokens.textTertiary,
                    ),
                  ),
                ),

                const SizedBox(height: ClayTokens.space8),
              ],
            ),
    );
  }

  void _bukaEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => const EditProfileScreen(),
      ),
    );
  }
}

/// Label seksi dengan jarak bawaannya — supaya semua seksi memakai jarak yang
/// sama tanpa mengulang Padding di tiap tempat.
class _LabelSeksi extends StatelessWidget {
  const _LabelSeksi(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: ClayTokens.space1,
        bottom: ClayTokens.space3,
      ),
      child: ClaySectionLabel(teks),
    );
  }
}

/// Kartu identitas: avatar inisial dalam lingkaran bergradien + nama/kontak.
class _Kepala extends StatelessWidget {
  const _Kepala({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.medium,
      radius: ClayTokens.radiusLarge,
      padding: const EdgeInsets.all(ClayTokens.space5),
      child: Row(
        children: <Widget>[
          /*
           * Avatar = lingkaran bergradien aksen dengan inisial putih — bidang
           * pekat satu-satunya di kartu, jadi mata langsung jatuh ke identitas.
           * Gradiennya ClayGradients.chip, bukan warna pejal, dengan alasan
           * yang sama seperti docblock ClayIconChip: warna pejal di tengah
           * permukaan clay terlihat seperti stiker yang ditempel.
           */
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ClayGradients.chip(ClayTokens.primary),
            ),
            alignment: Alignment.center,
            child: Text(
              user.initials,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: gelap
                        ? ClayTokens.textPrimaryDark
                        : ClayTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email ?? user.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    color: gelap
                        ? ClayTokens.textSecondaryDark
                        : ClayTokens.textSecondary,
                  ),
                ),
                if (user.isBlocked) ...<Widget>[
                  const SizedBox(height: ClayTokens.space2),
                  ClayStatusBadge(
                    status: 'cancelled',
                    label: user.status == 'banned'
                        ? 'Akun diblokir'
                        : 'Akun ditangguhkan',
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AjakanLengkapi extends StatelessWidget {
  const _AjakanLengkapi({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.low,
      borderColor: ClayTokens.primary,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const ClayIconChip(
            icon: Icons.edit_note_rounded,
            accent: ClayTokens.primary,
            size: 36,
          ),
          const SizedBox(width: ClayTokens.space3),
          Expanded(
            child: Text(
              'Lengkapi nama dan email Anda supaya driver dan bantuan lebih '
              'mudah mengenali.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                height: 1.45,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: gelap
                ? ClayTokens.textTertiaryDark
                : ClayTokens.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// Satu baris menu: chip ikon bergradien + label + nilai/chevron.
class _Baris extends StatelessWidget {
  const _Baris({
    required this.icon,
    required this.label,
    this.nilai,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? nilai;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClayCard(
      depth: ClayDepth.flat,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space4,
        vertical: ClayTokens.space3,
      ),
      child: Row(
        children: <Widget>[
          ClayIconChip(icon: icon, accent: ClayTokens.primary, size: 38),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: gelap
                    ? ClayTokens.textPrimaryDark
                    : ClayTokens.textPrimary,
              ),
            ),
          ),
          if (nilai != null)
            Text(
              nilai!,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: gelap
                    ? ClayTokens.textSecondaryDark
                    : ClayTokens.textSecondary,
              ),
            ),
          if (onTap != null && nilai == null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: gelap
                  ? ClayTokens.textTertiaryDark
                  : ClayTokens.textTertiary,
            ),
        ],
      ),
    );
  }
}

/// Kartu hapus akun: dipisah dari baris menu biasa dan diberi bingkai merah.
///
/// KENAPA bukan `_Baris` berwarna merah: baris menu dan tindakan penghancuran
/// akun tidak boleh punya bentuk yang sama — bentuk yang sama mengundang
/// refleks sentuh yang sama.
class _ZonaBahaya extends StatelessWidget {
  const _ZonaBahaya({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return ClaySurface(
      depth: ClayDepth.low,
      borderColor: ClayTokens.danger,
      onTap: onTap,
      padding: const EdgeInsets.all(ClayTokens.space4),
      child: Row(
        children: <Widget>[
          const ClayIconChip(
            icon: Icons.delete_outline_rounded,
            accent: ClayTokens.danger,
            size: 38,
          ),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Hapus akun',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Tanpa angka hari: tenggangnya kebijakan backend, dan pesan
                  // sukses penghapusan datang dari sana.
                  'Akun dihapus setelah masa tenggang.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    height: 1.4,
                    color: gelap
                        ? ClayTokens.textTertiaryDark
                        : ClayTokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: ClayTokens.danger,
          ),
        ],
      ),
    );
  }
}
