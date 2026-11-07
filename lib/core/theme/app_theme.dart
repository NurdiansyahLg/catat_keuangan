import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AppTheme {
  const AppTheme._();

  static TextTheme _textTheme(Brightness brightness) =>
      GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: brightness).textTheme,
      );

  // ── Light ──────────────────────────────────────────
  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
      surface: AppColors.lightSurface,
    );
    return _base(cs, _textTheme(Brightness.light)).copyWith(
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightText,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 24, fontWeight: FontWeight.w800,
          color: AppColors.lightText,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.incomeContainer,
        shadowColor: Colors.black12,
        elevation: 4,
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      cardTheme: _cardTheme(AppColors.lightSurface),
      inputDecorationTheme: _inputTheme(AppColors.lightSurface),
    );
  }

  // ── Dark ───────────────────────────────────────────
  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
    );
    return _base(cs, _textTheme(Brightness.dark)).copyWith(
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkText,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 24, fontWeight: FontWeight.w800,
          color: AppColors.darkText,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.25),
        shadowColor: Colors.black38,
        elevation: 4,
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : const Color(0xFF9BA8A6),
          ),
        ),
      ),
      cardTheme: _cardTheme(AppColors.darkSurface),
      inputDecorationTheme: _inputTheme(AppColors.darkSurface),
    );
  }

  // ── Shared base ────────────────────────────────────
  static ThemeData _base(ColorScheme cs, TextTheme textTheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }

  static CardThemeData _cardTheme(Color color) => CardThemeData(
    elevation: 0, color: color,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
  );

  static InputDecorationTheme _inputTheme(Color fill) => InputDecorationTheme(
    filled: true, fillColor: fill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}


