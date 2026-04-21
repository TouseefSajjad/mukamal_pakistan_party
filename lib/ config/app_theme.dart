import 'package:flutter/material.dart';

class AppTheme {
  // Primary professional color
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFC8E6C9);

  // Accent colors
  static const Color accentPink = Color(0xFFFF4081);
  static const Color criticalRed = Color(0xFFD32F2F);

  // Background & surface
  static const Color backgroundWhite = Colors.white;
  static const Color backgroundGray = Color(0xFFF5F5F5);

  // Text colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textOnPrimary = Colors.white;

  // Button Styles
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: primaryGreen,
    foregroundColor: textOnPrimary,
    padding: const EdgeInsets.symmetric(vertical: 14),
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );

  static ButtonStyle accentButton = ElevatedButton.styleFrom(
    backgroundColor: accentPink,
    foregroundColor: textOnPrimary,
    padding: const EdgeInsets.symmetric(vertical: 14),
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );

  static ButtonStyle criticalButton = ElevatedButton.styleFrom(
    backgroundColor: criticalRed,
    foregroundColor: textOnPrimary,
    padding: const EdgeInsets.symmetric(vertical: 14),
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );

  // Text Styles
  static const TextStyle heading = TextStyle(
    color: textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subHeading = TextStyle(
    color: textSecondary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    color: textPrimary,
    fontSize: 16,
  );

  static const TextStyle bodySmall = TextStyle(
    color: textSecondary,
    fontSize: 14,
  );

  static const TextStyle accentText = TextStyle(
    color: accentPink,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  // Input Decoration Theme
  static InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: backgroundWhite,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: primaryGreen),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: primaryGreen, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: criticalRed),
    ),
  );

  // ThemeData for app
  static ThemeData themeData = ThemeData(
    useMaterial3: true,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: backgroundGray,

    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: textOnPrimary,
      elevation: 2,
      centerTitle: true,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primaryButton,
    ),

    inputDecorationTheme: inputDecorationTheme,

    textTheme: const TextTheme(
      titleLarge: heading,
      titleMedium: subHeading,
      bodyLarge: bodyLarge,
      bodyMedium: bodySmall,
    ),

    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: accentPink,
      error: criticalRed,
      background: backgroundWhite,
    ),
  );
}