// lib/core/theme/app_theme.dart
// SHATTERFORGE design system — inspired by Valorant dark UI + ancient sci-fi aesthetic.
// All colors, typography, and component themes defined here.
// Never hardcode colors or text styles in widgets.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color Palette ───────────────────────────────────────────────────────────
class SFColors {
  SFColors._();

  // Backgrounds (matches concept art dark atmosphere)
  static const Color bg0 = Color(0xFF0A0A0E);        // Deepest bg
  static const Color bg1 = Color(0xFF12121A);        // Card bg
  static const Color bg2 = Color(0xFF1A1A26);        // Elevated surface
  static const Color bg3 = Color(0xFF22223A);        // Highest surface (modals)

  // Primary energy color — orange glow from concept art
  static const Color energyOrange = Color(0xFFFF6B1A);
  static const Color energyOrangeDim = Color(0x66FF6B1A);
  static const Color energyOrangeGlow = Color(0x33FF6B1A);

  // Secondary accent — blue Core energy
  static const Color coreBlue = Color(0xFF2196F3);
  static const Color coreBlueDim = Color(0x662196F3);

  // Lava/volcanic cracks
  static const Color lavaRed = Color(0xFFE53935);
  static const Color lavaDim = Color(0x44E53935);

  // Crystal / energy shield
  static const Color crystalCyan = Color(0xFF00E5FF);
  static const Color crystalCyanDim = Color(0x4400E5FF);

  // Text hierarchy
  static const Color textPrimary = Color(0xFFE8E6F0);
  static const Color textSecondary = Color(0xFF9896A8);
  static const Color textMuted = Color(0xFF5C5A6E);
  static const Color textOnEnergy = Color(0xFF0A0A0E);

  // Borders
  static const Color border = Color(0xFF2A2A3E);
  static const Color borderStrong = Color(0xFF3C3A56);
  static const Color borderEnergy = Color(0x66FF6B1A);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFF44336);

  // Stone / wall material colors
  static const Color stoneBase = Color(0xFF3A3840);
  static const Color stoneDark = Color(0xFF25232B);
  static const Color stoneLight = Color(0xFF5A576A);

  // Grade ramp for damage states
  static const Color damageNone = Color(0xFF4CAF50);
  static const Color damageLow = Color(0xFFCDDC39);
  static const Color damageMed = Color(0xFFFF9800);
  static const Color damageHigh = Color(0xFFF44336);
  static const Color damageDestroyed = Color(0xFF424242);
}

// ─── Typography ──────────────────────────────────────────────────────────────
class SFTextStyles {
  SFTextStyles._();

  // Display — Orbitron for numbers, timers, scores
  static TextStyle display(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.orbitron(
        fontSize: size,
        color: color ?? SFColors.textPrimary,
        fontWeight: weight ?? FontWeight.w700,
        letterSpacing: 0.05 * size,
      );

  // UI text — Rajdhani for all labels, buttons, HUD
  static TextStyle ui(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.rajdhani(
        fontSize: size,
        color: color ?? SFColors.textPrimary,
        fontWeight: weight ?? FontWeight.w500,
        letterSpacing: 0.02 * size,
      );

  // Body text — system sans for readable prose
  static TextStyle body(double size, {Color? color, FontWeight? weight}) =>
      TextStyle(
        fontFamily: 'Rajdhani',
        fontSize: size,
        color: color ?? SFColors.textSecondary,
        fontWeight: weight ?? FontWeight.w400,
        height: 1.5,
      );

  // Named convenience styles
  static TextStyle get headlineLarge =>
      ui(32, weight: FontWeight.w700, color: SFColors.textPrimary);
  static TextStyle get headlineMedium =>
      ui(24, weight: FontWeight.w600, color: SFColors.textPrimary);
  static TextStyle get headlineSmall =>
      ui(20, weight: FontWeight.w600, color: SFColors.textPrimary);
  static TextStyle get titleLarge =>
      ui(18, weight: FontWeight.w600, color: SFColors.textPrimary);
  static TextStyle get titleMedium =>
      ui(16, weight: FontWeight.w500, color: SFColors.textPrimary);
  static TextStyle get labelLarge =>
      ui(14, weight: FontWeight.w600, color: SFColors.textPrimary);
  static TextStyle get labelSmall =>
      ui(12, weight: FontWeight.w500, color: SFColors.textSecondary);
  static TextStyle get bodyMedium =>
      body(15, color: SFColors.textSecondary);
  static TextStyle get bodySmall =>
      body(13, color: SFColors.textMuted);

  // HUD specific
  static TextStyle get hudTimer =>
      display(28, color: SFColors.energyOrange);
  static TextStyle get hudStat =>
      display(20, color: SFColors.textPrimary);
  static TextStyle get hudLabel =>
      ui(12, weight: FontWeight.w500, color: SFColors.textMuted);
}

// ─── Component Theme ─────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SFColors.bg0,
      colorScheme: const ColorScheme.dark(
        primary: SFColors.energyOrange,
        secondary: SFColors.coreBlue,
        surface: SFColors.bg1,
        error: SFColors.danger,
        onPrimary: SFColors.textOnEnergy,
        onSecondary: Colors.white,
        onSurface: SFColors.textPrimary,
        onError: Colors.white,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: SFColors.bg1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SFColors.border, width: 0.5),
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SFColors.energyOrange,
          foregroundColor: SFColors.textOnEnergy,
          textStyle: SFTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SFColors.energyOrange,
          textStyle: SFTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: SFColors.energyOrange, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SFColors.energyOrange,
          textStyle: SFTextStyles.labelLarge,
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SFColors.bg2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SFColors.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SFColors.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SFColors.energyOrange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SFColors.danger, width: 1),
        ),
        hintStyle: SFTextStyles.bodySmall,
        labelStyle: SFTextStyles.labelSmall,
        errorStyle: SFTextStyles.body(12, color: SFColors.danger),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: SFColors.border,
        thickness: 0.5,
      ),

      // AppBar (used sparingly — game is mostly full-screen)
      appBarTheme: AppBarTheme(
        backgroundColor: SFColors.bg0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: SFTextStyles.titleLarge,
        iconTheme: const IconThemeData(color: SFColors.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),

      // Bottom nav
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SFColors.bg1,
        indicatorColor: SFColors.energyOrangeGlow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SFTextStyles.labelSmall.copyWith(color: SFColors.energyOrange);
          }
          return SFTextStyles.labelSmall;
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: SFColors.energyOrange, size: 22);
          }
          return const IconThemeData(color: SFColors.textMuted, size: 22);
        }),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SFColors.bg3,
        contentTextStyle: SFTextStyles.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: SFColors.borderStrong, width: 0.5),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
