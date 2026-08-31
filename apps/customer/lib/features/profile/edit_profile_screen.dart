import 'package:antaride_api/antaride_api.dart';
import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_core/antaride_core.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Ubah nama, email, dan tanggal lahir.
///
/// ============================================================================
///  HANYA FIELD YANG BENAR-BENAR DIUBAH YANG DIKIRIM
/// ============================================================================
///  Backend memakai `PATCH`, dan null yang terkirim MENGOSONGKAN field itu.
///
///  Layar yang mengirim seluruh isi form akan menghapus email pengguna hanya
///  karena kolomnya kosong di layar ini — dan pengguna tidak akan tahu sampai
///  dia mencari emailnya di profil dan tidak menemukannya.
///
///  Yang dilakukan di sini: bandingkan dengan nilai awal, kirim yang berbeda.
/// ============================================================================
///
/// ============================================================================
///  BENTUK LAYAR: HERO COMPACT, BUKAN AppBar
/// ============================================================================
///  Layar ini route sendiri (bukan tab shell), jadi dia yang memasang kepala
///  halamannya: [ClayHeroHeader] compact dengan [ClayBackButton] — pola layar
///  form di brief v2. Compact, bukan hero penuh: form dibuka berulang kali
///  dalam satu sesi, dan hero setinggi beranda memakan ruang milik kolomnya.
/// ============================================================================
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nama;
  late final TextEditingController _email;

  String? _gender;
  String? _awalNama;
  String? _awalEmail;
  String? _awalGender;

  Map<String, String> _galatKolom = const <String, String>{};

  @override
  void initState() {
    super.initState();

    final AuthUser? user = context.read<SessionController>().user;

    _awalNama = user?.name;
    _awalEmail = user?.email;
    _awalGender = user?.gender;

    _nama = TextEditingController(text: _awalNama ?? '');
    _email = TextEditingController(text: _awalEmail ?? '');
    _gender = _awalGender;
  }

  @override
  void dispose() {
    _nama.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final SessionController sesi = context.read<SessionController>();

    final String nama = _nama.text.trim();
    final String email = _email.text.trim();

    final bool berhasil = await sesi.updateProfile(
      name: nama != _awalNama && nama.isNotEmpty ? nama : null,
      email: email != _awalEmail && email.isNotEmpty ? email : null,
      gender: _gender != _awalGender ? _gender : null,
    );

    if (!mounted) {
      return;
    }

    if (!berhasil) {
      final ApiFailure? galat = sesi.lastFailure;

      if (galat != null && galat.isValidation) {
        setState(() {
          _galatKolom = galat.fieldErrors;
        });

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(galat?.message ?? 'Tidak bisa menyimpan profil.'),
          backgroundColor: ClayTokens.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool sibuk = context.select<SessionController, bool>(
      (SessionController s) => s.isBusy,
    );

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ClayEntrance(
            index: 0,
            child: ClayHeroHeader(
              accent: ClayTokens.primary,
              title: 'Ubah profil',
              subtitle: 'Perbarui nama, email, dan jenis kelamin.',
              compact: true,
              leading: ClayBackButton(),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(ClayTokens.space5),
              children: <Widget>[
                ClayEntrance(
                  index: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _LabelSeksi('Identitas'),

                      ClayInput(
                        controller: _nama,
                        label: 'Nama lengkap',
                        hint: 'Nama yang dilihat driver',
                        prefixIcon: Icons.person_outline_rounded,
                        enabled: !sibuk,
                        maxLength: 80,
                        errorText: _galatKolom['name'],
                      ),

                      const SizedBox(height: ClayTokens.space4),

                      ClayInput(
                        controller: _email,
                        label: 'Email',
                        hint: 'nama@email.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !sibuk,
                        errorText: _galatKolom['email'],
                        helperText: 'Dipakai untuk struk dan pemulihan akun.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: ClayTokens.space6),

                ClayEntrance(
                  index: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _LabelSeksi('Jenis kelamin'),

                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _PilihanGender(
                              label: 'Laki-laki',
                              nilai: 'male',
                              terpilih: _gender == 'male',
                              onTap: (String v) => setState(() => _gender = v),
                            ),
                          ),
                          const SizedBox(width: ClayTokens.space3),
                          Expanded(
                            child: _PilihanGender(
                              label: 'Perempuan',
                              nilai: 'female',
                              terpilih: _gender == 'female',
                              onTap: (String v) => setState(() => _gender = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: ClayTokens.space8),

                ClayEntrance(
                  index: 3,
                  child: ClayButton(
                    label: 'Simpan',
                    icon: Icons.check_rounded,
                    isLoading: sibuk,
                    onPressed: sibuk ? null : _simpan,
                  ),
                ),

                const SizedBox(height: ClayTokens.space6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Label seksi dengan jarak bawaannya — sama dengan pola di ProfileScreen.
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

/// Satu pil pilihan jenis kelamin.
///
/// KENAPA yang terpilih diisi gradien aksen, bukan sekadar border: pada form
/// yang hanya punya dua pilihan berdampingan, keadaan terpilih harus terbaca
/// sekali lirik — border tipis di atas permukaan pucat tidak cukup. Gradiennya
/// [ClayGradients.chip], gradien yang sama dengan chip ikon, supaya seluruh
/// bidang beraksen di aplikasi berasal dari satu resep.
class _PilihanGender extends StatelessWidget {
  const _PilihanGender({
    required this.label,
    required this.nilai,
    required this.terpilih,
    required this.onTap,
  });

  final String label;
  final String nilai;
  final bool terpilih;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    if (!terpilih) {
      return ClaySurface(
        depth: ClayDepth.low,
        padding: const EdgeInsets.symmetric(vertical: ClayTokens.space4),
        onTap: () => onTap(nilai),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: ClayTokens.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: gelap
                  ? ClayTokens.textSecondaryDark
                  : ClayTokens.textSecondary,
            ),
          ),
        ),
      );
    }

    // `Ink` (bukan Container) supaya riak InkWell tergambar DI ATAS gradien —
    // riak di bawah bidang pejal tidak pernah terlihat.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
      child: Ink(
        decoration: BoxDecoration(
          gradient: ClayGradients.chip(ClayTokens.primary),
          borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
        ),
        child: InkWell(
          onTap: () => onTap(nilai),
          borderRadius: BorderRadius.circular(ClayTokens.radiusMedium),
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ClayTokens.space4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: ClayTokens.space2),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: ClayTokens.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
