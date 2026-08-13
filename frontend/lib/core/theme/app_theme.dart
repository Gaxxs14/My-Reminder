import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Ultra-Premium Obsidian Glassmorphism Palette
  static const Color primaryDark = Color(0xFF38BDF8); // Vibrant Ice Blue
  static const Color primaryLight = Color(0xFF1E3A8A); // Deep Navy Blue
  static const Color primaryGlow = Color(0x4038BDF8); // Soft glow tint
  static const Color accentTeal = Color(0xFF2DD4BF);  // Teal Cyan
  static const Color accentIndigo = Color(0xFF818CF8); // Electric Indigo
  static const Color accentPurple = Color(0xFFA78BFA); // Soft Lavender

  static const Color backgroundDark = Color(0xFF07090E); // Deep Space Obsidian
  static const Color surfaceDark = Color(0xFF111722);    // Rich Slate Card
  static const Color surfaceDarkElevated = Color(0xFF18202F);
  static const Color glassBorder = Color(0x1F38BDF8);    // Ice Blue Tint Border

  static const Color textPrimaryDark = Color(0xFFF8FAFC);  // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textMutedDark = Color(0xFF64748B);     // Slate 500

  // Light Theme Palette
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);

  // Dark Theme Definition
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.outfitTextTheme(const TextTheme(
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimaryDark, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimaryDark, letterSpacing: -0.3),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryDark),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimaryDark),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimaryDark),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textSecondaryDark),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimaryDark),
    ));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        secondary: accentTeal,
        surface: surfaceDark,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimaryDark,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: glassBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDarkElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: glassBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryDark, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMutedDark, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
        modalBackgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  // Light Theme Definition
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.outfitTextTheme(const TextTheme(
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimaryLight, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimaryLight, letterSpacing: -0.3),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryLight),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimaryLight),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimaryLight),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textSecondaryLight),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimaryLight),
    ));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryDark,
        secondary: accentTeal,
        surface: surfaceLight,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryDark, width: 1.5),
        ),
        hintStyle: TextStyle(color: textSecondaryLight.withValues(alpha: 0.6), fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
