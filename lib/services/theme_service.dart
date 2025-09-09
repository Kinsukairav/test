import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeService extends StateNotifier<ThemeMode> {
  ThemeService() : super(ThemeMode.system);

  void setTheme(ThemeMode themeMode) {
    state = themeMode;
  }

  void toggleTheme() {
    final newTheme = state == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    setTheme(newTheme);
  }
}

final themeProvider = StateNotifierProvider<ThemeService, ThemeMode>((ref) {
  return ThemeService();
});
