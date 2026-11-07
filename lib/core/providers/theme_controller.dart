import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton ValueNotifier untuk mengontrol ThemeMode secara global.
/// Gunakan [ThemeController.instance] di mana saja.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);
  static final ThemeController instance = ThemeController._();

  static const _key = 'theme_mode';

  /// Muat preferensi dari penyimpanan lokal.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    value = switch (stored) {
      'dark'  => ThemeMode.dark,
      'light' => ThemeMode.light,
      _       => ThemeMode.system,
    };
  }

  /// Ubah tema dan simpan.
  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      switch (mode) {
        ThemeMode.dark   => 'dark',
        ThemeMode.light  => 'light',
        ThemeMode.system => 'system',
      },
    );
  }

  bool get isDark => value == ThemeMode.dark;
  bool get isLight => value == ThemeMode.light;
  bool get isSystem => value == ThemeMode.system;
}
