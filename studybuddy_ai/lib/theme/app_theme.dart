import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand & Violet Accents
  static const Color primary = Color(0xFF630ED4);
  static const Color primaryContainer = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFF8B5CF6);
  static const Color primaryFixed = Color(0xFFEADDFF);
  static const Color onPrimaryFixed = Color(0xFF25005A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFEDE0FF);

  // Secondary Indigo
  static const Color secondary = Color(0xFF4648D4);
  static const Color secondaryContainer = Color(0xFF6063EE);
  static const Color secondaryFixed = Color(0xFFE1E0FF);
  static const Color onSecondaryFixed = Color(0xFF07006C);
  static const Color onSecondaryFixedVariant = Color(0xFF2F2EBE);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Tertiary Emerald / Mastery
  static const Color tertiary = Color(0xFF005B3D);
  static const Color tertiaryContainer = Color(0xFF007650);
  static const Color tertiaryFixed = Color(0xFF6FFBBE);
  static const Color tertiaryFixedDim = Color(0xFF4EDEA3);
  static const Color onTertiaryFixed = Color(0xFF002113);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldBg = Color(0xFFECFDF5);

  // Error / Warning
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color crimson = Color(0xFFEF4444);
  static const Color crimsonBg = Color(0xFFFEF2F2);
  static const Color amber = Color(0xFFF59E0B);

  // Surfaces & Backgrounds
  static const Color surface = Color(0xFFFAF8FF);
  static const Color background = Color(0xFFFAF8FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F3FF);
  static const Color surfaceContainer = Color(0xFFEAEDFF);
  static const Color surfaceContainerHigh = Color(0xFFE2E7FF);
  static const Color surfaceContainerHighest = Color(0xFFDAE2FD);

  // Typography Neutrals
  static const Color onSurface = Color(0xFF131B2E);
  static const Color onSurfaceVariant = Color(0xFF4A4455);
  static const Color outline = Color(0xFF7B7487);
  static const Color outlineVariant = Color(0xFFCCC3D8);
  static const Color inverseSurface = Color(0xFF283044);
  static const Color inverseOnSurface = Color(0xFFEEF0FF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryContainer, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [primary, secondaryContainer],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient progressBarGradient = LinearGradient(
    colors: [primary, emerald],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    const textTheme = TextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: Color(0xFFFBFFFB),
        tertiary: AppColors.tertiary,
        onTertiary: Colors.white,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.02 * 28,
          color: AppColors.onSurface,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.015 * 24,
          color: AppColors.onSurface,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01 * 20,
          color: AppColors.onSurface,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurface,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurface,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.01 * 13,
          color: AppColors.onSurface,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.02 * 12,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outlineVariant, width: 0.5),
        ),
      ),
    );
  }
}
