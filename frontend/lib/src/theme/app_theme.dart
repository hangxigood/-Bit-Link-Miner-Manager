import 'package:flutter/material.dart';

/// Custom color scheme using HSL values from the spec
class AppTheme {
  // Light theme colors (HSL converted to RGB)
  static const _lightBackground = Color(0xFFFAFAFA); // hsl(0,0%,98%)
  static const _lightCard = Color(0xFFFFFFFF); // hsl(0,0%,100%)
  static const _lightText = Color(0xFF1A1D23); // hsl(220,16%,12%)
  static const _lightMutedText = Color(0xFF64748B); // hsl(215,12%,45%)
  static const _lightBorder = Color(0xFFE2E4E9); // hsl(220,14%,88%)
  static const _lightSecondary = Color(0xFFEDEFF2); // hsl(220,14%,93%)
  static const _lightPrimary = Color(0xFFD97706); // hsl(36,100%,46%)

  // Dark theme colors (HSL converted to RGB)
  static const _darkBackground = Color(0xFF0F1419); // hsl(220,16%,6%)
  static const _darkCard = Color(0xFF13181F); // hsl(220,16%,8%)
  static const _darkText = Color(0xFFEFF1F5); // hsl(210,20%,95%)
  static const _darkMutedText = Color(0xFF8B92A1); // hsl(215,12%,55%)
  static const _darkBorder = Color(0xFF252A31); // hsl(220,14%,16%)
  static const _darkSecondary = Color(0xFF1F2329); // hsl(220,14%,14%)
  static const _darkPrimary = Color(0xFFFF9800); // hsl(36,100%,50%)

  // Status colors (same for both themes)
  static const success = Color(0xFF22C55E); // hsl(142,71%,45%)
  static const warning = Color(0xFFFF9800); // hsl(36,100%,50%)
  static const error = Color(0xFFEF4444); // hsl(0,72%,51%)

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBackground,
      colorScheme: ColorScheme.light(
        primary: _lightPrimary,
        surface: _lightCard,
        onSurface: _lightText,
        outline: _lightBorder,
        surfaceContainerHighest: _lightSecondary,
      ),
      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: _lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: _lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: _lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: _lightPrimary, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(0, 32),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, 32),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(0, 32),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(fontSize: 12, color: _lightText),
        bodySmall: TextStyle(fontSize: 10, color: _lightMutedText),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: _lightText,
        ),
      ),
      dividerColor: _lightBorder,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      colorScheme: ColorScheme.dark(
        primary: _darkPrimary,
        surface: _darkCard,
        onSurface: _darkText,
        outline: _darkBorder,
        surfaceContainerHighest: _darkSecondary,
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: _darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: _darkPrimary, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(0, 32),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, 32),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(0, 32),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(fontSize: 12, color: _darkText),
        bodySmall: TextStyle(fontSize: 10, color: _darkMutedText),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: _darkText,
        ),
      ),
      dividerColor: _darkBorder,
    );
  }
}

/// Extension for convenient access to custom colors
extension AppColors on BuildContext {
  Color get mutedText => Theme.of(this).brightness == Brightness.light
      ? Color(0xFF64748B)
      : Color(0xFF8B92A1);

  Color get border => Theme.of(this).brightness == Brightness.light
      ? Color(0xFFE2E4E9)
      : Color(0xFF252A31);

  Color get secondarySurface => Theme.of(this).brightness == Brightness.light
      ? Color(0xFFEDEFF2)
      : Color(0xFF1F2329);

  Color get success => AppTheme.success;
  Color get warning => AppTheme.warning;
  Color get error => AppTheme.error;
}
