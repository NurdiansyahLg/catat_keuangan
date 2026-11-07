import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // === Seed / Primary ===
  static const Color seed = Color(0xFF1A7A68);
  static const Color primary = Color(0xFF1A7A68); // dark teal
  static const Color primaryDark = Color(0xFF145C4E);

  // === Semantic ===
  static const Color income = Color(0xFF1A7A68);
  static const Color expense = Color(0xFFD94040);
  static const Color savings = Color(0xFFC4A84A); // warm gold
  static const Color balance = Color(0xFF1A7A68);

  // === Tonal containers ===
  static const Color incomeContainer = Color(0xFFDEF2EC);
  static const Color expenseContainer = Color(0xFFFDECEB);
  static const Color savingsContainer = Color(0xFFC4A84A);

  // === Light theme ===
  static const Color lightBackground = Color(0xFFEBF2F1); // mint
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1C2B29);

  // === Dark theme ===
  static const Color darkBackground = Color(0xFF0E1A18);
  static const Color darkSurface = Color(0xFF1A2825);
  static const Color darkText = Color(0xFFE8F2F0);

  // ── Theme-adaptive helpers ─────────────────────────
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Scaffold / page background
  static Color bg(BuildContext context) =>
      _isDark(context) ? darkBackground : lightBackground;

  /// Card / container surface
  static Color surface(BuildContext context) =>
      _isDark(context) ? darkSurface : lightSurface;

  /// Primary body text
  static Color bodyText(BuildContext context) =>
      _isDark(context) ? darkText : lightText;

  /// Secondary / hint text
  static Color subText(BuildContext context) =>
      _isDark(context) ? const Color(0xFF9BA8A6) : const Color(0xFF6B7280);

  /// Toggle / chip background
  static Color chip(BuildContext context) =>
      _isDark(context) ? const Color(0xFF253533) : const Color(0xFFE5E7EB);

  /// Subtle divider/border
  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2C3E3C) : const Color(0xFFE5E7EB);
}

