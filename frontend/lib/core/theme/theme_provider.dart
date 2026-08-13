import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appThemeModeProvider = StateNotifierProvider<AppThemeModeNotifier, ThemeMode>((ref) {
  return AppThemeModeNotifier();
});

class AppThemeModeNotifier extends StateNotifier<ThemeMode> {
  AppThemeModeNotifier() : super(ThemeMode.dark); // Default to Dark Obsidian theme

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}
