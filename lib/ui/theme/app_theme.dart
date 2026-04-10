import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: 'BBHBogle',
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.textPrimary,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
      thumbColor: AppColors.primaryBright,
      overlayColor: AppColors.primary.withValues(alpha: 0.16),
      valueIndicatorColor: AppColors.primary,
    ),
    cardColor: AppColors.surfaceRaised,
    dividerColor: Colors.white.withValues(alpha: 0.06),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
