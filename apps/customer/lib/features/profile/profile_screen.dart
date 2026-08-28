import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'edit_profile_screen.dart';

/// Profil dan pengaturan akun.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _keluar(BuildContext context, {required bool semua}) async {
    final bool? yakin = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(semua ? 'Keluar dari semua perangkat?' : 'Keluar?'),
        content: Text(
          semua
              // Menyebutkan konsekuensinya secara konkret. "Anda akan keluar
              // dari semua sesi" tidak memberitahu bahwa HP lain ikut terkena —
              // dan itu justru yang perlu diketahui.
              ? 'Semua perangkat yang masuk dengan akun ini akan dikeluarkan, '
                    'termasuk perangkat ini. Pakai ini kalau HP Anda hilang.'
              : 'Anda perlu memasukkan kode OTP lagi untuk masuk.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: ClayTokens.danger),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (yakin != true || !context.mounted) {
      return;
    }

    // Tidak ada navigasi setelah ini. Gerbang di akar aplikasi mengamati
    // `SessionStage`, dan begitu tahapnya `signedOut` seluruh tumpukan diganti
    // layar masuk.
    await context.read<SessionController>().signOut(allDevices: semua);
  }

  Future<void> _hapusAkun(BuildContext context) async {
    final bool? yakin = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Hapus akun?'),
        content: const Text(
          'Akun Anda akan dihapus setelah masa tenggang. Masuk kembali sebelum '
          'tenggangnya habis untuk membatalkan penghapusan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: ClayTokens.danger),
            child: const Text('Ajukan penghapusan'),
          ),
        ],
      ),
    );

    if (yakin != true || !context.mounted) {
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
        await showDialog<void>(
          context: context,
          builder: (BuildContext dialog) => AlertDialog(
            title: const Text('Penghapusan diajukan'),
            content: Text(d.message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(),
                child: const Text('Mengerti'),
              ),
            ],
          ),
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

    return Scaffold(
      body: user == null
          ? ClayErrorState(
              message: sesi.lastFailure?.message ?? 'Profil tidak bisa dimuat.',
              onRetry: sesi.refreshProfile,
            )
          : ListView(
              padding: const EdgeInsets.all(ClayTokens.space5),
              children: <Widget>[
                _Kepala(user: user),

                if (!user.profileComplete) ...<Widget>[
                  const SizedBox(height: ClayTokens.space4),
                  _AjakanLengkapi(onTap: () => _bukaEdit(context)),
                ],

                const SizedBox(height: ClayTokens.space6),

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

                const SizedBox(height: ClayTokens.space6),

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

                const SizedBox(height: ClayTokens.space6),

                _Baris(
                  icon: Icons.delete_outline_rounded,
                  label: 'Hapus akun',
                  warna: ClayTokens.danger,
                  onTap: () => _hapusAkun(context),
                ),

                const SizedBox(height: ClayTokens.space8),

                Center(
                  child: Text(
                    'Antaride ${AppConfig.environment == 'production' ? '' : '· ${AppConfig.environment}'}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: ClayTokens.textTertiary,
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

class _Kepala extends StatelessWidget {
  const _Kepala({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      depth: ClayDepth.medium,
      radius: ClayTokens.radiusLarge,
      padding: const EdgeInsets.all(ClayTokens.space5),
      child: Row(
        children: <Widget>[
          ClaySurface(
            depth: ClayDepth.pressed,
            radius: ClayTokens.radiusPill,
            padding: const EdgeInsets.all(ClayTokens.space4),
            child: Text(
              user.initials,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ClayTokens.primary,
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
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email ?? user.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    color: ClayTokens.textSecondary,
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
    return ClaySurface(
      depth: ClayDepth.low,
      borderColor: ClayTokens.primary,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.edit_note_rounded,
            size: 20,
            color: ClayTokens.primary,
          ),
          const SizedBox(width: ClayTokens.space3),
          const Expanded(
            child: Text(
              'Lengkapi nama dan email Anda supaya driver dan bantuan lebih '
              'mudah mengenali.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.icon,
    required this.label,
    this.nilai,
    this.onTap,
    this.warna,
  });

  final IconData icon;
  final String label;
  final String? nilai;
  final VoidCallback? onTap;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      depth: ClayDepth.flat,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: ClayTokens.space4,
        vertical: ClayTokens.space4,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: warna ?? ClayTokens.textSecondary),
          const SizedBox(width: ClayTokens.space4),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: warna,
              ),
            ),
          ),
          if (nilai != null)
            Text(
              nilai!,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ClayTokens.textSecondary,
              ),
            ),
          if (onTap != null && nilai == null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: ClayTokens.textTertiary,
            ),
        ],
      ),
    );
  }
}
