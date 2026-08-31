import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/clay_shadows.dart';
import '../theme/clay_tokens.dart';
import 'clay_surface.dart';

/// Kolom input clay: permukaan yang TENGGELAM.
///
/// ============================================================================
///  INPUT TENGGELAM, TOMBOL TERANGKAT
/// ============================================================================
///  Aturan yang berlaku di seluruh aplikasi ini, dan yang membuat antarmukanya
///  bisa dipahami tanpa label:
///
///    Sesuatu yang MENERIMA masukan tenggelam ke dalam.
///    Sesuatu yang MENERIMA sentuhan terangkat keluar.
///
///  Konsistensi itu yang membuat orang tahu di mana harus mengetik dan di mana
///  harus menekan, bahkan sebelum membaca apa pun. Membalikkannya di satu tempat
///  saja sudah cukup untuk membuat layar itu terasa membingungkan.
/// ============================================================================
class ClayInput extends StatelessWidget {
  const ClayInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.autofocus = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.letterSpacing,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final int? maxLength;
  final int maxLines;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final bool adaGalat = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(
            label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: gelap
                  ? ClayTokens.textSecondaryDark
                  : ClayTokens.textSecondary,
              fontFamily: ClayTokens.fontFamily,
            ),
          ),
          const SizedBox(height: ClayTokens.space2),
        ],

        ClaySurface(
          depth: ClayDepthInput.forState(enabled: enabled),
          radius: ClayTokens.radiusMedium,
          padding: EdgeInsets.symmetric(
            horizontal: ClayTokens.space4,
            vertical: maxLines > 1 ? ClayTokens.space3 : 0,
          ),

          // Garis merah dipakai untuk galat, BUKAN mengubah warna latarnya.
          //
          // Latar merah pada permukaan tenggelam menghilangkan efek clay-nya dan
          // membuat kolomnya terlihat rusak, bukan salah isi.
          borderColor: adaGalat ? ClayTokens.danger : null,

          child: Row(
            children: <Widget>[
              if (prefixIcon != null) ...<Widget>[
                Icon(
                  prefixIcon,
                  size: 20,
                  color: gelap
                      ? ClayTokens.textTertiaryDark
                      : ClayTokens.textTertiary,
                ),
                const SizedBox(width: ClayTokens.space3),
              ],

              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  obscureText: obscureText,
                  enabled: enabled,
                  maxLength: maxLength,
                  maxLines: maxLines,
                  minLines: maxLines > 1 ? maxLines : null,
                  autofocus: autofocus,
                  textInputAction: textInputAction,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  textAlign: textAlign,

                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: gelap
                        ? ClayTokens.textPrimaryDark
                        : ClayTokens.textPrimary,
                    fontFamily: ClayTokens.fontFamily,
                    letterSpacing: letterSpacing,
                  ),

                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: gelap
                          ? ClayTokens.textTertiaryDark
                          : ClayTokens.textTertiary,
                      fontFamily: ClayTokens.fontFamily,
                      letterSpacing: letterSpacing,
                    ),

                    /*
                     * Seluruh dekorasi bawaan DIMATIKAN.
                     *
                     * Latar, garis, dan padding-nya sudah disediakan ClaySurface
                     * di luar. Membiarkan dekorasi bawaan aktif menghasilkan dua
                     * latar yang saling menimpa, dan yang terlihat adalah kotak
                     * di dalam kotak.
                     */
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: maxLines > 1 ? 0 : ClayTokens.space4,
                    ),

                    // Penghitung karakter bawaan disembunyikan; kalau perlu, dia
                    // ditampilkan lewat helperText yang bisa diatur pemanggil.
                    counterText: '',
                  ),
                ),
              ),

              if (suffix != null) ...<Widget>[
                const SizedBox(width: ClayTokens.space2),
                suffix!,
              ],
            ],
          ),
        ),

        if (adaGalat || helperText != null)
          Padding(
            padding: const EdgeInsets.only(
              top: ClayTokens.space2,
              left: ClayTokens.space1,
            ),
            child: Text(
              adaGalat ? errorText! : helperText!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: adaGalat
                    ? ClayTokens.danger
                    : (gelap
                          ? ClayTokens.textTertiaryDark
                          : ClayTokens.textTertiary),
                fontFamily: ClayTokens.fontFamily,
              ),
            ),
          ),
      ],
    );
  }
}

/// Pembantu kecil supaya aturan "input selalu tenggelam" tidak bisa dilanggar
/// tanpa sengaja.
class ClayDepthInput {
  const ClayDepthInput._();

  static ClayDepth forState({required bool enabled}) {
    // Kolom nonaktif dibuat RATA, bukan tenggelam.
    //
    // Permukaan tenggelam berarti "di sini bisa diisi". Kolom nonaktif yang
    // tetap tenggelam mengundang orang mengetik dan tidak merespons, dan yang
    // dia simpulkan adalah aplikasinya rusak — bukan bahwa kolomnya memang
    // sedang tidak bisa diisi.
    return enabled ? ClayDepth.pressed : ClayDepth.flat;
  }
}
