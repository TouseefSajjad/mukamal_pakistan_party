import 'package:flutter/material.dart';

class AppTheme {
  // Primary colors
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFC8E6C9);

  // Accent colors
  static const Color accentPink = Color(0xFFFF4081);
  static const Color criticalRed = Color(0xFFD32F2F);

  // Background
  static const Color backgroundWhite = Colors.white;
  static const Color backgroundGray = Color(0xFFF5F5F5);

  // Text colors
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Colors.black87;
  static const Color textOnPrimary = Colors.white;

  // Buttons
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

  // Text styles
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

  // Input Decoration (GLOBAL FIX)
  static InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,

    contentPadding: const EdgeInsets.symmetric(
      vertical: 12,
      horizontal: 16,
    ),

    hintStyle: const TextStyle(
      color: Colors.black54,
      fontSize: 14,
    ),

    labelStyle: const TextStyle(
      color: Colors.black87,
      fontSize: 14,
    ),

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: primaryGreen),
    ),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.black26),
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: primaryGreen,
        width: 2,
      ),
    ),

    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: criticalRed),
    ),

    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: criticalRed,
        width: 2,
      ),
    ),
  );

  // FULL THEME DATA (IMPORTANT FIXES HERE)
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
      displayLarge: TextStyle(color: textPrimary),
      titleLarge: TextStyle(color: textPrimary),
      titleMedium: TextStyle(color: textPrimary),
      bodyLarge: TextStyle(
        color: Colors.black,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Colors.black,
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        color: Colors.black87,
        fontSize: 12,
      ),
    ),

    // FIX: prevents Material 3 weird light text issues in inputs
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: primaryGreen,
      selectionColor: Color(0x552E7D32),
      selectionHandleColor: primaryGreen,
    ),

    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: accentPink,
      error: criticalRed,
      background: backgroundWhite,
    ),
  );
}