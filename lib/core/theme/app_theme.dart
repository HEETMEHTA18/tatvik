import 'package:flutter/material.dart';

class AppTheme {
  static bool isDark = false;

  static Color get background =>
      isDark ? const Color(0xFF09090B) : const Color(0xFFF1F5F9);
  static Color get surface =>
      isDark ? const Color(0xFF18181B) : const Color(0xFFFFFFFF);
  static Color get accent =>
      isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
  static Color get secondaryAccent =>
      isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED);
  static Color get textMain =>
      isDark ? const Color(0xFFFAFAFA) : const Color(0xFF0F172A);
  static Color get textSecondary =>
      isDark ? const Color(0xFFD4D4D8) : const Color(0xFF3F3F46);
  static Color get success => const Color(0xFF10B981);
  static Color get warning => const Color(0xFFF59E0B);
  static Color get destructive => const Color(0xFFEF4444);
  static Color get border =>
      isDark ? const Color(0x33FFFFFF) : const Color(0x66FFFFFF);

  static const Color peach = Color(0xFFF4C7AB);
  static const Color blue = Color(0xFFB8C9E8);
  static const Color teal = Color(0xFFA8C8C6);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFF8FAFC),
        secondary: Color(0xFF94A3B8),
        surface: Color(0xFF09090B),
        onSurface: Color(0xFFF8FAFC),
        error: Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
          letterSpacing: -2,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xB3FFFFFF),
          letterSpacing: 1.2,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFFFFFFF)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xB3FFFFFF)),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFFFFFF),
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFFFFFF),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(
          0x661E1E24,
        ), // Increased translucency for Liquid Glass
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32), // Rounder forms
          side: const BorderSide(color: Color(0x33FFFFFF), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: const Color(0x33F8FAFC), // Glass-like background
              foregroundColor: const Color(0xFFFFFFFF),
              minimumSize: const Size(
                double.infinity,
                60,
              ), // Extra-large size option
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32), // Rounder forms
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ).copyWith(
              overlayColor: WidgetStateProperty.all(const Color(0x33FFFFFF)),
            ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4F46E5),
        secondary: Color(0xFF7C3AED),
        surface: Color(0xFFF8FAFC),
        onSurface: Color(0xFF0F172A),
        error: Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
          letterSpacing: -2,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF475569),
          letterSpacing: 1.2,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(
          0x99FFFFFF,
        ), // Increased translucency for light mode glass card
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32), // Rounder forms
          side: const BorderSide(color: Color(0x4DFFFFFF), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: const Color(0x1A4F46E5), // Glass-like background
              foregroundColor: const Color(0xFF4F46E5),
              minimumSize: const Size(
                double.infinity,
                60,
              ), // Extra-large size option
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32), // Rounder forms
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ).copyWith(
              overlayColor: WidgetStateProperty.all(const Color(0x1A4F46E5)),
            ),
      ),
    );
  }
}
