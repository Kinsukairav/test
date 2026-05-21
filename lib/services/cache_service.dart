import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// A simple disk-backed LRU cache with a 2 GB total size limit.
///
/// Entries are stored as JSON files under [_cacheDir].
/// An index file ([_indexPath]) tracks every entry's key, size,
/// last-access time, and expiry time so we can do LRU eviction
/// without reading every cached file.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static const int _maxCacheSizeBytes = 2 * 1024 * 1024 * 1024; // 2 GB
  static const Duration _defaultTtl = Duration(hours: 1);
  static const Duration _trendingTtl = Duration(hours: 6);

  late String _cacheDir;
  late String _indexPath;
  bool _initialized = false;

  final Map<String, _CacheEntry> _index = {};

  // ── Public API ────────────────────────────────────────────────────────────

  static const Duration searchTtl = Duration(hours: 1);
  static const Duration trendingTtl = _trendingTtl;
  static const Duration streamUrlTtl = Duration(minutes: 30);
  static const Duration playlistTtl = Duration(hours: 3);

  Future<void> initialize() async {
    if (_initialized) return;
    _cacheDir = await _resolveCacheDir();
    _indexPath = path.join(_cacheDir, '_index.json');
    await Directory(_cacheDir).create(recursive: true);
    await _loadIndex();
    _initialized = true;
  }

  /// Returns cached data for [key], or null if missing / expired.
  Future<dynamic> get(String key) async {
    await initialize();
    final entry = _index[key];
    if (entry == null) return null;

    final now = DateTime.now();
    if (now.isAfter(entry.expiresAt)) {
      // Expired — remove it
      await _evictEntry(key);
      return null;
    }

    final file = File(path.join(_cacheDir, entry.filename));
    if (!await file.exists()) {
      _index.remove(key);
      return null;
    }

    try {
      final raw = await file.readAsString();
      // Update last access time for LRU
      _index[key] = entry.copyWith(lastAccessed: now);
      await _saveIndex();
      return json.decode(raw);
    } catch (e) {
      await _evictEntry(key);
      return null;
    }
  }

  /// Stores [data] under [key] with optional [ttl].
  Future<void> put(
    String key,
    dynamic data, {
    Duration? ttl,
  }) async {
    await initialize();

    final encoded = json.encode(data);
    final bytes = utf8.encode(encoded).length;
    final filename = '${_sanitizeKey(key)}.json';
    final filePath = path.join(_cacheDir, filename);
    final now = DateTime.now();

    // Evict old entry for this key if present
    await _evictEntry(key);

    // Ensure we are under 2 GB before writing
    await _ensureCapacity(bytes);

    await File(filePath).writeAsString(encoded, flush: true);

    _index[key] = _CacheEntry(
      key: key,
      filename: filename,
      sizeBytes: bytes,
      createdAt: now,
      lastAccessed: now,
      expiresAt: now.add(ttl ?? _defaultTtl),
    );
    await _saveIndex();
  }

  /// Clears all cached data and resets the index.
  Future<void> clearAll() async {
    await initialize();
    final dir = Directory(_cacheDir);
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File &&
            !entity.path.endsWith('_index.json')) {
          await entity.delete();
        }
      }
    }
    _index.clear();
    await _saveIndex();
  }

  /// Total bytes currently used by cached entries.
  int get totalSizeBytes =>
      _index.values.fold(0, (sum, e) => sum + e.sizeBytes);

  int get entryCount => _index.length;

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<String> _resolveCacheDir() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      return path.join(appData, 'music_app', 'cache');
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return path.join(
          home, 'Library', 'Caches', 'music_app');
    } else {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return path.join(home, '.cache', 'music_app');
    }
  }

  Future<void> _loadIndex() async {
    final file = File(_indexPath);
    if (!await file.exists()) return;
    try {
      final raw = await file.readAsString();
      final List<dynamic> list = json.decode(raw);
      for (final item in list) {
        final entry = _CacheEntry.fromJson(item as Map<String, dynamic>);
        _index[entry.key] = entry;
      }
      // Prune missing files from index
      final keysToRemove = <String>[];
      for (final entry in _index.values) {
        if (!await File(path.join(_cacheDir, entry.filename)).exists()) {
          keysToRemove.add(entry.key);
        }
      }
      keysToRemove.forEach(_index.remove);
    } catch (e) {
      // Corrupt index — start fresh
      _index.clear();
    }
  }

  Future<void> _saveIndex() async {
    final list = _index.values.map((e) => e.toJson()).toList();
    await File(_indexPath).writeAsString(json.encode(list), flush: true);
  }

  Future<void> _evictEntry(String key) async {
    final entry = _index.remove(key);
    if (entry == null) return;
    final file = File(path.join(_cacheDir, entry.filename));
    if (await file.exists()) await file.delete();
  }

  /// Remove LRU entries until [requiredBytes] fit within the cap.
  Future<void> _ensureCapacity(int requiredBytes) async {
    int currentSize = totalSizeBytes;
    if (currentSize + requiredBytes <= _maxCacheSizeBytes) return;

    // Sort by last accessed (oldest first)
    final sorted = _index.values.toList()
      ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

    for (final entry in sorted) {
      if (currentSize + requiredBytes <= _maxCacheSizeBytes) break;
      currentSize -= entry.sizeBytes;
      await _evictEntry(entry.key);
    }
    await _saveIndex();
  }

  String _sanitizeKey(String key) {
    return key
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        .substring(0, key.length.clamp(0, 200));
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _CacheEntry {
  final String key;
  final String filename;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime lastAccessed;
  final DateTime expiresAt;

  const _CacheEntry({
    required this.key,
    required this.filename,
    required this.sizeBytes,
    required this.createdAt,
    required this.lastAccessed,
    required this.expiresAt,
  });

  _CacheEntry copyWith({
    DateTime? lastAccessed,
    DateTime? expiresAt,
  }) {
    return _CacheEntry(
      key: key,
      filename: filename,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'filename': filename,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
        'lastAccessed': lastAccessed.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) => _CacheEntry(
        key: json['key'] as String,
        filename: json['filename'] as String,
        sizeBytes: json['sizeBytes'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastAccessed: DateTime.parse(json['lastAccessed'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}
