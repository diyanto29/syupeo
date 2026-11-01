import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';

/// Standardized Form Field Wrapper based on Syupeo Modern Design System.
/// Provides a consistent label row (label + optional topTrailing badge/counter),
/// the input field, and bottom helper text.
class AppFormField extends StatelessWidget {
  const AppFormField({
    super.key,
    this.label,
    this.isRequired = false,
    this.topTrailing,
    this.helperText,
    this.errorText,
    required this.child,
  });

  final String? label;
  final bool isRequired;
  final Widget? topTrailing;
  final String? helperText;
  final String? errorText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || topTrailing != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (label != null)
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                      children: [
                        if (isRequired)
                          const TextSpan(
                            text: ' *',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                const Spacer(),
              if (topTrailing != null) topTrailing!,
            ],
          ),
          const SizedBox(height: 7),
        ],
        child,
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            errorText!,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFEF4444),
            ),
          ),
        ] else if (helperText != null && helperText!.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            helperText!,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

/// Standardized Text Input Field with clean border, optional prefix badge (e.g. IDR, Rp, %),
/// suffix action, and typography aligned with the Atelier design standard.
class AppTextInput extends StatelessWidget {
  const AppTextInput({
    super.key,
    this.label,
    this.isRequired = false,
    this.topTrailing,
    this.helperText,
    this.hintText,
    this.controller,
    this.initialValue,
    this.prefixBadge,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
    this.autofocus = false,
  });

  final String? label;
  final bool isRequired;
  final Widget? topTrailing;
  final String? helperText;
  final String? hintText;
  final TextEditingController? controller;
  final String? initialValue;
  final String? prefixBadge;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final effectivePrefix = prefixBadge != null
        ? Container(
            margin: const EdgeInsets.only(left: 12, right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              prefixBadge!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF475569),
                letterSpacing: 0.5,
              ),
            ),
          )
        : (prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: IconTheme(
                  data: const IconThemeData(
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                  child: prefixIcon!,
                ),
              )
            : null);

    return AppFormField(
      label: label,
      isRequired: isRequired,
      topTrailing: topTrailing,
      helperText: helperText,
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        onChanged: onChanged,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        readOnly: readOnly,
        enabled: enabled,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        focusNode: focusNode,
        autofocus: autofocus,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          counterText: '',
          prefixIcon: effectivePrefix,
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

/// Helper badge chip for top trailing label area (e.g. 'INTERNAL ONLY', 'WAJIB DIISI', 'MARGIN CUKUP')
class AppBadgeText extends StatelessWidget {
  const AppBadgeText(
    this.text, {
    super.key,
    this.backgroundColor = const Color(0xFFF1F5F9),
    this.textColor = const Color(0xFF64748B),
    this.borderColor = const Color(0xFFE2E8F0),
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Selector card field for interactive choices (e.g. Kategori Toko, Outlet, Supplier)
class AppSelectorField extends StatelessWidget {
  const AppSelectorField({
    super.key,
    this.label,
    this.isRequired = false,
    this.topTrailing,
    this.helperText,
    required this.valueText,
    this.placeholder = 'Pilih...',
    this.leadingIcon,
    required this.onTap,
  });

  final String? label;
  final bool isRequired;
  final Widget? topTrailing;
  final String? helperText;
  final String? valueText;
  final String placeholder;
  final Widget? leadingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueText != null && valueText!.isNotEmpty;

    return AppFormField(
      label: label,
      isRequired: isRequired,
      topTrailing: topTrailing,
      helperText: helperText,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                leadingIcon!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  hasValue ? valueText! : placeholder,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standardized Currency Input Field with prefix badge ('IDR' or 'Rp')
/// and automatic thousands separation formatting.
class AppCurrencyInput extends StatelessWidget {
  const AppCurrencyInput({
    super.key,
    this.label,
    this.isRequired = false,
    this.topTrailing,
    this.helperText,
    this.hintText = '0',
    this.controller,
    this.initialValue,
    this.prefixBadge = 'IDR',
    this.validator,
    this.onChanged,
    this.readOnly = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.focusNode,
  });

  final String? label;
  final bool isRequired;
  final Widget? topTrailing;
  final String? helperText;
  final String? hintText;
  final TextEditingController? controller;
  final String? initialValue;
  final String? prefixBadge;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return AppTextInput(
      label: label,
      isRequired: isRequired,
      topTrailing: topTrailing,
      helperText: helperText,
      hintText: hintText,
      controller: controller,
      initialValue: initialValue,
      prefixBadge: prefixBadge,
      keyboardType: TextInputType.number,
      inputFormatters: const [RupiahTextInputFormatter(allowEmpty: true)],
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      enabled: enabled,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      focusNode: focusNode,
    );
  }
}

/// Standardized Dropdown Field wrapped with AppFormField styling.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    this.label,
    this.isRequired = false,
    this.topTrailing,
    this.helperText,
    this.hintText = 'Pilih...',
    this.value,
    required this.items,
    this.onChanged,
    this.validator,
    this.prefixIcon,
  });

  final String? label;
  final bool isRequired;
  final Widget? topTrailing;
  final String? helperText;
  final String? hintText;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final Widget? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return AppFormField(
      label: label,
      isRequired: isRequired,
      topTrailing: topTrailing,
      helperText: helperText,
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF94A3B8),
        ),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: IconTheme(
                    data: const IconThemeData(
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    child: prefixIcon!,
                  ),
                )
              : null,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      ),
    );
  }
}

