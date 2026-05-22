import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors from DESIGN.md
  static const Color primary = Color(0xFF11364e);
  static const Color primaryContainer = Color(0xFF2b4d66);
  static const Color onPrimary = Color(0xFFffffff);
  
  static const Color secondary = Color(0xFF32647f);
  static const Color secondaryContainer = Color(0xFFaddefd);
  
  static const Color surface = Color(0xFFf8f9fa);
  static const Color surfaceContainer = Color(0xFFedeeef);
  static const Color onSurface = Color(0xFF191c1d);
  
  static const Color tertiary = Color(0xFFE8F1F5);
  static const Color error = Color(0xFFba1a1a);
  
  static ThemeData get theme {
    final baseTextTheme = GoogleFonts.interTextTheme();
    final titleTextTheme = GoogleFonts.poppinsTextTheme();

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryContainer,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        secondary: secondary,
        secondaryContainer: secondaryContainer,
        surface: surface,
        onSurface: onSurface,
        error: error,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      textTheme: baseTextTheme.copyWith(
        displayLarge: titleTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.02),
        headlineLarge: titleTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: titleTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: titleTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400, fontSize: 18),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400, fontSize: 16),
        labelMedium: baseTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.05),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primaryContainer,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: titleTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: primaryContainer),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryContainer,
          side: const BorderSide(color: primaryContainer, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFc2c7cd), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFc2c7cd), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryContainer, width: 1.5),
        ),
        labelStyle: baseTextTheme.labelMedium?.copyWith(color: const Color(0xFF42474d)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFe1e3e4), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
