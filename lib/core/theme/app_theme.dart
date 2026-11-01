import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  // ==========================================
  // Syupeo Design System Tokens — v2
  // Image ref: Syupeo POS Dashboard style guide
  // ==========================================
  static const Color primary = Color(0xFF0070FC); // Syupeo Blue
  static const Color primaryHover = Color(0xFF005ECC); // Syupeo Blue hover
  static const Color secondary = Color(0xFFBA8C02); // Amber / warning accent
  static const Color accent = Color(0xFF3B82F6); // Blue-500 highlight
  static const Color surface = Color(0xFFFFFFFF); // Pure White (card bg)
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // Canvas bg (#f1f5f9)
  static const Color surfaceLow = Color(0xFFF8FAFC); // Slight tint
  static const Color surfaceHighest = Color(0xFFE2E8F0); // Dividers / subtle
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF0F172A); // Near-black heading (#0f172a)
  static const Color textBody = Color(0xFF334155); // Body text (#334155)
  static const Color textMuted = Color(0xFF64748B); // Muted / subtitle
  static const Color border = Color(0x14000000); // rgba(0,0,0,0.08) no-color border
  static const Color success = Color(0xFF10B981); // Emerald-500 — status Ready
  static const Color successBg = Color(0xFFD1FAE5); // Emerald-100 badge bg
  static const Color warning = Color(0xFFF59E0B); // Amber-500 — status Waiting
  static const Color warningBg = Color(0xFFFEF3C7); // Amber-100 badge bg
  static const Color danger = Color(0xFFEF4444); // Red-500 — destructive / error
  static const Color dangerBg = Color(0xFFFEE2E2); // Red-100 badge bg
  static const Color info = Color(0xFF3B82F6); // Blue-500 — info banner
  static const Color shadowDiffused = Color(0x14000000); // rgba(0,0,0,0.08)

  // Layout Radii — matches image: cards 16px, buttons pill-style
  static const double radiusSm = 6.0;   // Small chips / badges
  static const double radiusMd = 12.0;  // Default: inputs, modals, small cards
  static const double radiusLg = 16.0;  // Cards, panels
  static const double radiusXl = 24.0;  // Drawer / bottom sheet
  static const double radiusFull = 9999.0; // Pill buttons, avatar, segmented tabs

  // Backward compatibility alias references for ConciergeThemeTokens
  static const Color _activeTable = warningBg;
  static const Color _validationTable = Color(0xFFFEF3C7);
  static const Color _availableTable = successBg;

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFEFF6FF),
        onPrimaryContainer: primaryHover,
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFFEF3C7),
        onSecondaryContainer: text,
        tertiary: accent,
        onTertiary: Colors.white,
        error: danger,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
        surfaceContainerLowest: surfaceLowest,
        surfaceContainerLow: surfaceLow,
        surfaceContainerHighest: surfaceHighest,
        outline: textMuted,
        outlineVariant: surfaceHighest,
      ),
      scaffoldBackgroundColor: surfaceSubtle, // #f1f5f9 canvas bg
    );

    // Typography scale strictly following Design System rules (All Inter)
    final interBase = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: text,
      displayColor: text,
      decoration: TextDecoration.none,
    );

    final textTheme = interBase.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.72,
        color: text,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.64,
        color: text,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.56,
        color: text,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.44,
        color: text,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.44,
        color: text,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.32,
        color: text,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.28,
        color: text,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.65,
        color: textBody, // #334155
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: textBody, // #334155
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.40,
        color: textMuted,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: text,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: textMuted,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: text,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: shadowDiffused,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg), // 16px — matches image
          side: BorderSide.none, // no border, shadow-only cards
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: const Color(0xFFEFF6FF),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? primary : textMuted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52), // 52px height — matches image CTA
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusFull), // pill button
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: border, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusFull), // pill
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textMuted,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd), // 12px
          borderSide: const BorderSide(
            color: border,
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(
            color: border,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(
            color: primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(
            color: danger,
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(
            color: danger,
            width: 1.5,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceLow,
        selectedColor: const Color(0xFFEFF6FF),
        side: const BorderSide(color: border, width: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusFull)), // pill chips
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return const Color(0xFFCBD5E1);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      dividerColor: border,
      extensions: const [
        ConciergeThemeTokens(
          baseSurface: surface,
          sectionSurface: surfaceLow,
          raisedSurface: surfaceLowest,
          activeTableSurface: _activeTable,
          validationSurface: _validationTable,
          availableAccent: _availableTable,
          tintedShadow: shadowDiffused,
          ctaGradient: LinearGradient(
            colors: [primary, primaryHover],
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
