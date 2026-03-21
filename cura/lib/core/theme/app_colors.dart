import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette — deep teal
  static const Color primary = Color(0xFF1E3E42);
  static const Color primaryLight = Color(0xFF4A8A88);
  static const Color primaryDark = Color(0xFF142C30);

  // Secondary palette — warm amber
  static const Color secondary = Color(0xFFE89C38);
  static const Color secondaryLight = Color(0xFFE8C060);

  // ── Light mode ──────────────────────────────────────────
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE5E5EA);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF6C6C70);
  static const Color textTertiary = Color(0xFFAEAEB2);
  static const Color divider = Color(0xFFE5E5EA);
  static const Color orbIdle = Color(0xFFD1D1D6);

  // ── Dark mode ────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF2C2C2E);
  static const Color surfaceVariantDark = Color(0xFF3A3A3C);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF8E8E93);
  static const Color textTertiaryDark = Color(0xFF636366);
  static const Color dividerDark = Color(0xFF3A3A3C);
  static const Color orbIdleDark = Color(0xFF3A3A3C);

  // Emergency
  static const Color emergency = Color(0xFFE53935);
  static const Color emergencyLight = Color(0xFFFFEBEE);
  static const Color emergencyDark = Color(0xFFFF453A);
  static const Color emergencyLightDark = Color(0xFF2C1418);

  // Status
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);

  // Orb states (active — same in both modes)
  static const Color orbListening = Color(0xFF4A8A88);
  static const Color orbSpeaking = Color(0xFFE89C38);

  // Accent tones
  static const Color accentMint = Color(0xFF7AAEAA);
  static const Color accentLightMint = Color(0xFFCAE6E2);
  static const Color accentGold = Color(0xFFE8BC50);
  static const Color accentCoral = Color(0xFFE87C5C);

  // ── Helpers ──────────────────────────────────────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? backgroundDark : background;
  static Color card(BuildContext context) =>
      isDark(context) ? surfaceDark : surface;
  static Color label(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimary;
  static Color hint(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondary;
  static Color muted(BuildContext context) =>
      isDark(context) ? textTertiaryDark : textTertiary;
  static Color border(BuildContext context) =>
      isDark(context) ? dividerDark : divider;
  static Color orbIdleColor(BuildContext context) =>
      isDark(context) ? orbIdleDark : orbIdle;
  static Color sos(BuildContext context) =>
      isDark(context) ? emergencyDark : emergency;
  static Color sosBg(BuildContext context) =>
      isDark(context) ? emergencyLightDark : emergencyLight;
  static Color glassFill(BuildContext context) => isDark(context)
      ? const Color(0xFF2A2C31).withValues(alpha: 0.58)
      : Colors.white.withValues(alpha: 0.72);
  static Color glassSecondaryFill(BuildContext context) => isDark(context)
      ? const Color(0xFF202228).withValues(alpha: 0.76)
      : Colors.white.withValues(alpha: 0.9);
  static Color glassBorder(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.18)
      : const Color(0xFFC9CCD3);
  static Color glassHighlight(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.white.withValues(alpha: 0.85);
  static Color glassShadow(BuildContext context) => isDark(context)
      ? Colors.black.withValues(alpha: 0.28)
      : const Color(0xFFB8BCC7).withValues(alpha: 0.3);
}
