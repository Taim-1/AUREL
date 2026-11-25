import 'package:flutter/material.dart';

class AurelColors {
  static const background = Color(0xFF090A0E);
  static const surface = Color(0xFF15161C);
  static const surfaceRaised = Color(0xFF202127);
  static const champagne = Color(0xFFD9BC91);
  static const champagneLight = Color(0xFFF1DEC1);
  static const muted = Color(0xFF96939A);
  static const divider = Color(0xFF2A292B);
  static const violet = Color(0xFF6450A5);
}

class AurelTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AurelColors.champagne,
      secondary: AurelColors.champagneLight,
      surface: AurelColors.surface,
      error: Color(0xFFE87979),
      onPrimary: AurelColors.background,
      onSecondary: AurelColors.background,
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AurelColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AurelColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: AurelColors.muted,
          fontSize: 13,
          height: 1.45,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AurelColors.surface,
        hintStyle: const TextStyle(color: AurelColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AurelColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AurelColors.champagne, width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AurelColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: AurelColors.divider,
    );
  }
}
