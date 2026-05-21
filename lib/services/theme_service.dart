import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeService extends StateNotifier<ThemeMode> {
  // Default to dark mode as per user preference
  ThemeService() : super(ThemeMode.dark);

  void setTheme(ThemeMode themeMode) {
    state = themeMode;
  }

  void toggleTheme() {
    final newTheme =
        state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setTheme(newTheme);
  }
}

final themeProvider = StateNotifierProvider<ThemeService, ThemeMode>((ref) {
  return ThemeService();
});
