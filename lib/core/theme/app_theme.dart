import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color _surface = Color(0xFFFBFBFB);
  static const Color _surfaceLow = Color(0xFFF4F4F5);
  static const Color _surfaceHighest = Color(0xFFE4E4E7);
  static const Color _surfaceLowest = Color(0xFFFFFFFF);
  static const Color _leafGreen = Color(0xFF15803D); // Daun Mangga Segar Indramayu
  static const Color _deepInk = Color(0xFF18181B); // Crisp Modern Charcoal
  static const Color _warmDepth = Color(0xFF431407); // Rich Mango Bark
  static const Color _orange = Color(0xFFFF7A00); // Mangga Gedong Gincu Vibrant Orange
  static const Color _orangeDark = Color(0xFFC2410C); // Deep Mango Sunset
  static const Color _activeTable = Color(0xFFFEF3C7); // Mango Nectar Soft Cream
  static const Color _validationTable = Color(0xFFFFEDD5); // Soft Apricot
  static const Color _availableTable = Color(0xFFDCFCE7); // Fresh Mint Green
  static const Color _outlineSoft = Color(0xFFA1A1AA);
  static const Color _shadowNavy = Color(0x1418181B);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: _orange,
        onPrimary: Colors.white,
        primaryContainer: _warmDepth,
        onPrimaryContainer: _orangeDark,
        secondary: _leafGreen,
        onSecondary: Colors.white,
        secondaryContainer: _activeTable,
        onSecondaryContainer: _deepInk,
        tertiary: _availableTable,
        onTertiary: _deepInk,
        surface: _surface,
        onSurface: _deepInk,
        surfaceContainerLowest: _surfaceLowest,
        surfaceContainerLow: _surfaceLow,
        surfaceContainerHighest: _surfaceHighest,
        outline: _outlineSoft,
        outlineVariant: _outlineSoft,
      ),
      scaffoldBackgroundColor: _surface,
    );

    final manrope = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.manrope(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.12,
        height: 1.0,
        color: _deepInk,
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.88,
        height: 1.05,
        color: _deepInk,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.48,
        height: 1.15,
        color: _deepInk,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.44,
        color: _deepInk,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.36,
        color: _deepInk,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.28,
        color: _deepInk,
      ),
    );

    final textTheme = GoogleFonts.interTextTheme(manrope).apply(
      bodyColor: _deepInk,
      displayColor: _deepInk,
      decoration: TextDecoration.none,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: _deepInk,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: _deepInk,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: _deepInk.withValues(alpha: 0.70),
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: _deepInk,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: _deepInk.withValues(alpha: 0.72),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _deepInk,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.44,
          color: _deepInk,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surfaceLowest,
        elevation: 0,
        shadowColor: _shadowNavy,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceLowest,
        elevation: 0,
        indicatorColor: _activeTable,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: _deepInk,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _leafGreen,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: _outlineSoft.withValues(alpha: 0.20)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF94A3B8),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF0F172A),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFEF4444),
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFEF4444),
            width: 1.5,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _surfaceLow,
        selectedColor: _activeTable,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _deepInk,
        ),
      ),
      dividerColor: Colors.transparent,
      extensions: const [
        ConciergeThemeTokens(
          baseSurface: _surface,
          sectionSurface: _surfaceLow,
          raisedSurface: _surfaceLowest,
          activeTableSurface: _activeTable,
          validationSurface: _validationTable,
          availableAccent: _availableTable,
          tintedShadow: _shadowNavy,
          ctaGradient: LinearGradient(
            colors: [_deepInk, _warmDepth],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ],
    );
  }
}

@immutable
class ConciergeThemeTokens extends ThemeExtension<ConciergeThemeTokens> {
  const ConciergeThemeTokens({
    required this.baseSurface,
    required this.sectionSurface,
    required this.raisedSurface,
    required this.activeTableSurface,
    required this.validationSurface,
    required this.availableAccent,
    required this.tintedShadow,
    required this.ctaGradient,
  });

  final Color baseSurface;
  final Color sectionSurface;
  final Color raisedSurface;
  final Color activeTableSurface;
  final Color validationSurface;
  final Color availableAccent;
  final Color tintedShadow;
  final Gradient ctaGradient;

  @override
  ConciergeThemeTokens copyWith({
    Color? baseSurface,
    Color? sectionSurface,
    Color? raisedSurface,
    Color? activeTableSurface,
    Color? validationSurface,
    Color? availableAccent,
    Color? tintedShadow,
    Gradient? ctaGradient,
  }) {
    return ConciergeThemeTokens(
      baseSurface: baseSurface ?? this.baseSurface,
      sectionSurface: sectionSurface ?? this.sectionSurface,
      raisedSurface: raisedSurface ?? this.raisedSurface,
      activeTableSurface: activeTableSurface ?? this.activeTableSurface,
      validationSurface: validationSurface ?? this.validationSurface,
      availableAccent: availableAccent ?? this.availableAccent,
      tintedShadow: tintedShadow ?? this.tintedShadow,
      ctaGradient: ctaGradient ?? this.ctaGradient,
    );
  }

  @override
  ConciergeThemeTokens lerp(
    covariant ThemeExtension<ConciergeThemeTokens>? other,
    double t,
  ) {
    if (other is! ConciergeThemeTokens) {
      return this;
    }

    return ConciergeThemeTokens(
      baseSurface: Color.lerp(baseSurface, other.baseSurface, t) ?? baseSurface,
      sectionSurface:
          Color.lerp(sectionSurface, other.sectionSurface, t) ?? sectionSurface,
      raisedSurface:
          Color.lerp(raisedSurface, other.raisedSurface, t) ?? raisedSurface,
      activeTableSurface:
          Color.lerp(activeTableSurface, other.activeTableSurface, t) ??
          activeTableSurface,
      validationSurface:
          Color.lerp(validationSurface, other.validationSurface, t) ??
          validationSurface,
      availableAccent:
          Color.lerp(availableAccent, other.availableAccent, t) ??
          availableAccent,
      tintedShadow:
          Color.lerp(tintedShadow, other.tintedShadow, t) ?? tintedShadow,
      ctaGradient: t < 0.5 ? ctaGradient : other.ctaGradient,
    );
  }
}
