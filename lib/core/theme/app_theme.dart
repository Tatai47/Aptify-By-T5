import 'package:flutter/material.dart';

/// App theme definition with premium Material 3 dark/light modes
/// optimized for desktop programming environments.
class AppTheme {
  // Brand & Accent Colors
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondaryColor = Color(0xFF06B6D4); // Cyan
  static const Color accentPurple = Color(0xFF8B5CF6);
  
  // Status Colors
  static const Color successGreen = Color(0xFF10B981); // Emerald
  static const Color warningOrange = Color(0xFFF59E0B); // Amber
  static const Color errorRed = Color(0xFFEF4444); // Crimson
  
  // Dark Surface Tones
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceElevated = Color(0xFF1F2937);
  static const Color darkBorder = Color(0xFF374151);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkCodeBackground = Color(0xFF0D1117);

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF312E81),
      onPrimaryContainer: const Color(0xFFE0E7FF),
      secondary: secondaryColor,
      onSecondary: Colors.black,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      error: errorRed,
      onError: Colors.white,
      outline: darkBorder,
      outlineVariant: const Color(0xFF4B5563),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: 'Segoe UI', // Clean native desktop font
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          side: const BorderSide(color: primaryColor, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: darkTextSecondary),
        hintStyle: TextStyle(color: darkTextSecondary.withAlpha(153)),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryLight,
        unselectedLabelColor: darkTextSecondary,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: darkBorder),
        ),
        textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }
}
