import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF4A6741);
  static const Color textDark = Color(0xFF2D4228);
  static const Color muted = Color(0xFF7A9472);
  static const Color bg = Color(0xFFF8F6F1);
  static const Color card = Color(0xFFFFFFFF);
  static const Color borderSoft = Color(0xFFD8D2C0);
  static const Color borderInput = Color(0xFFC5BFA8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: Color(0xFFA8C9A0),
        surface: card,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textDark,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Color(0xFFE8F0E4),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderSoft, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderInput, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderInput, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: const Color(0xFFE8F0E4),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: borderSoft, thickness: 0.5),
    );
  }
}
