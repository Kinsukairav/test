import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

// ── State ────────────────────────────────────────────────────────────────────

class DownloadSettings {
  final String downloadPath;

  const DownloadSettings({required this.downloadPath});

  DownloadSettings copyWith({String? downloadPath}) =>
      DownloadSettings(downloadPath: downloadPath ?? this.downloadPath);
}

// ── Default path helper ───────────────────────────────────────────────────────

String getDefaultDownloadPath() {
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
    return path.join(userProfile, 'Music', 'music_app_downloads');
  } else {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return path.join(home, 'Music', 'music_app_downloads');
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class DownloadSettingsNotifier extends StateNotifier<DownloadSettings> {
  static const _prefKey = 'download_path';

  DownloadSettingsNotifier() : super(DownloadSettings(downloadPath: getDefaultDownloadPath())) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      state = state.copyWith(downloadPath: saved);
    }
  }

  Future<void> setDownloadPath(String newPath) async {
    state = state.copyWith(downloadPath: newPath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, newPath);
  }

  Future<void> resetToDefault() async {
    await setDownloadPath(getDefaultDownloadPath());
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final downloadSettingsProvider =
    StateNotifierProvider<DownloadSettingsNotifier, DownloadSettings>(
  (ref) => DownloadSettingsNotifier(),
);
