import 'package:flutter/material.dart';

/// Callbreak color palette
class AppColors {
  AppColors._();

  // Table / game surface
  static const tableGreen = Color(0xFF1B5E20);       // deep green felt
  static const tableGreenLight = Color(0xFF2E7D32);
  static const tableRed = Color(0xFFB71C1C);         // Casino Red
  static const tableRedLight = Color(0xFFD32F2F);
  static const tableBlue = Color(0xFF0D47A1);        // Midnight Blue
  static const tableBlueLight = Color(0xFF1565C0);
  static const tableEdge = Color(0xFF4E342E);         // dark wood edge

  // Card colors
  static const cardWhite = Color(0xFFFAFAFA);
  static const cardShadow = Color(0x66000000);
  static const rankRed = Color(0xFFD32F2F);
  static const rankBlack = Color(0xFF212121);

  // UI surfaces
  static const background = Color(0xFF121212);
  static const surface = Color(0xFF1E1E1E);
  static const surfaceElevated = Color(0xFF2C2C2C);

  // Accents
  static const gold = Color(0xFFFFC107);
  static const goldDark = Color(0xFFFF8F00);
  static const spadeBlue = Color(0xFF1565C0);
  static const highlight = Color(0xFF00E5FF);
  static const errorRed = Color(0xFFEF5350);
  static const successGreen = Color(0xFF66BB6A);

  // Text
  static const textPrimary = Color(0xFFEEEEEE);
  static const textSecondary = Color(0xFF9E9E9E);
  static const textOnCard = Color(0xFF212121);
}

/// Application-wide ThemeData
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      secondary: AppColors.highlight,
      surface: AppColors.surface,
      error: AppColors.errorRed,
    ),
    fontFamily: 'Roboto',
    fontFamilyFallback: const ['NotoSansSymbols'],
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.rankBlack,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
    ),
  );
}
