import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // Using system font — SF Pro on iOS, Roboto on Android (Apple-esque)
  static const TextTheme textTheme = TextTheme(
    // Large greeting / hero text
    displayLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      letterSpacing: -0.3,
      height: 1.25,
    ),
    // Section headings
    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      letterSpacing: -0.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    // Body — minimum 18sp for accessibility
    bodyLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      height: 1.4,
    ),
    // Labels
    labelLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiary,
    ),
  );
}
