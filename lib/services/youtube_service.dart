import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/search_result.dart';
import 'cache_service.dart';

class YouTubeService {
  static const String _invidousInstance = 'https://invidious.io';
  static const String _alternativeInstance = 'https://vid.puffyan.us';

  // Static so the JS runtime check runs only once across all instances
  static List<String>? _cachedJsRuntimeArgs;
  static bool _checkedJsRuntime = false;
  static bool _warnedAboutJsRuntime = false;

  Future<bool> _isCommandAvailable(String command, List<String> args) async {
    try {
      final result = await Process.run(command, args, runInShell: true);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _getJsRuntimeArgs() async {
    if (_checkedJsRuntime) {
      return _cachedJsRuntimeArgs ?? const [];
    }

    _checkedJsRuntime = true;

    if (await _isCommandAvailable('node', ['--version'])) {
      _cachedJsRuntimeArgs = const ['--js-runtimes', 'node'];
      print('yt-dlp: using Node.js JS runtime');
      return _cachedJsRuntimeArgs!;
    }

    if (await _isCommandAvailable('deno', ['--version'])) {
      _cachedJsRuntimeArgs = const ['--js-runtimes', 'deno'];
      print('yt-dlp: using Deno JS runtime');
      return _cachedJsRuntimeArgs!;
    }

    _cachedJsRuntimeArgs = const [];
    _warnMissingJsRuntime();
    return _cachedJsRuntimeArgs!;
  }

  void _warnMissingJsRuntime() {
    if (_warnedAboutJsRuntime) return;
    _warnedAboutJsRuntime = true;
    print(
        'Warning: No supported JavaScript runtime found for yt-dlp. Install Node.js or Deno for better compatibility.');
  }

  Future<List<String>> _buildYtDlpArgs(List<String> args) async {
    final runtimeArgs = await _getJsRuntimeArgs();
    return [...runtimeArgs, ...args];
  }

  Future<ProcessResult> _runYtDlp(List<String> args) async {
    final fullArgs = await _buildYtDlpArgs(args);
    return Process.run('yt-dlp', fullArgs, runInShell: true);
  }

  int _currentYear() {
    return DateTime.now().year;
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    if (month < 1 || month > 12) {
      return '';
    }

    return names[month - 1];
  }

  String _normalizeThumbnailUrl(String url,
      {String? baseUrl, String? videoId}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      if (videoId != null && videoId.isNotEmpty) {
        return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      }
      return '';
    }

    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return trimmed;
    }

    if (baseUrl != null && baseUrl.isNotEmpty) {
      try {
        return Uri.parse(baseUrl).resolve(trimmed).toString();
      } catch (_) {
        return trimmed;
      }
    }

    return trimmed;
  }

  // Check if yt-dlp is installed
  Future<bool> isYtDlpInstalled() async {
    try {
      final result =
          await Process.run('yt-dlp', ['--version'], runInShell: true);
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } catch (e) {
      print('yt-dlp not found: $e');
      return false;
    }
  }

  // Install yt-dlp if not present
  Future<bool> installYtDlp() async {
    try {
      print('Installing yt-dlp...');
      // On Windows, try to install via pip
      final result =
          await Process.run('pip', ['install', 'yt-dlp'], runInShell: true);
      if (result.exitCode != 0) {
        print('pip install yt-dlp failed: ${result.stderr}');
        return false;
      }

      return await isYtDlpInstalled();
    } catch (e) {
      print('Failed to install yt-dlp: $e');
      return false;
    }
  }

  // Search videos using Invidious API (YouTube alternative frontend)
  Future<List<SearchResult>> searchVideos(String query,
      {int maxResults = 20}) async {
    // ── Cache lookup ───────────────────────────────────────────────────────
    final cacheKey = 'search_${query.trim().toLowerCase()}_$maxResults';
    try {
      final cached = await CacheService.instance.get(cacheKey);
      if (cached != null && cached is List) {
        return (cached)
            .map((item) => SearchResult(
                  id: item['id'],
                  title: item['title'],
                  artist: item['artist'],
                  album: item['album'],
                  duration: Duration(seconds: item['durationSeconds'] ?? 0),
                  thumbnailUrl: item['thumbnailUrl'] ?? '',
                  videoId: item['videoId'],
                  viewCount: item['viewCount'] ?? 0,
                  uploadDate: DateTime.tryParse(item['uploadDate'] ?? '') ??
                      DateTime.now(),
                ))
            .toList();
      }
    } catch (_) {} // Cache miss — continue to network

    try {
      final encodedQuery = Uri.encodeComponent(query);

      // Try primary Invidious instance
      final primaryUrl =
          '$_invidousInstance/api/v1/search?q=$encodedQuery&type=video&page=1';

      try {
        final response = await http.get(
          Uri.parse(primaryUrl),
          headers: {'User-Agent': 'MusicPlayer/1.0'},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final results = _parseSearchResults(data, maxResults,
              baseUrl: _invidousInstance);
          await _cacheSearchResults(cacheKey, results);
          return results;
        }
      } catch (e) {
        print('Primary Invidious instance failed: $e');
      }

      // Try alternative Invidious instance
      final altUrl =
          '$_alternativeInstance/api/v1/search?q=$encodedQuery&type=video&page=1';

      try {
        final response = await http.get(
          Uri.parse(altUrl),
          headers: {'User-Agent': 'MusicPlayer/1.0'},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final results = _parseSearchResults(data, maxResults,
              baseUrl: _alternativeInstance);
          await _cacheSearchResults(cacheKey, results);
          return results;
        }
      } catch (e) {
        print('Alternative Invidious instance failed: $e');
      }

      // If both Invidious instances fail, try yt-dlp search
      final results = await _searchWithYtDlp(query, maxResults);
      await _cacheSearchResults(cacheKey, results);
      return results;
    } catch (e) {
      print('Error searching YouTube: $e');
      throw Exception(
          'Failed to search YouTube: Network error or service unavailable');
    }
  }

  /// Serialises search results and stores them in cache.
  Future<void> _cacheSearchResults(
      String key, List<SearchResult> results) async {
    try {
      await CacheService.instance.put(
        key,
        results
            .map((r) => {
                  'id': r.id,
                  'title': r.title,
                  'artist': r.artist,
                  'album': r.album,
                  'durationSeconds': r.duration.inSeconds,
                  'thumbnailUrl': r.thumbnailUrl,
                  'videoId': r.videoId,
                  'viewCount': r.viewCount,
                  'uploadDate': r.uploadDate.toIso8601String(),
                })
            .toList(),
        ttl: CacheService.searchTtl,
      );
    } catch (_) {} // Ignore cache write failures
  }

  // Parse search results from Invidious API
  List<SearchResult> _parseSearchResults(List<dynamic> data, int maxResults,
      {required String baseUrl}) {
    final List<SearchResult> results = [];

    for (var item in data.take(maxResults)) {
      try {
        // Skip if no videoId
        if (item['videoId'] == null || item['videoId'].toString().isEmpty) {
          continue;
        }

        // Parse thumbnails
        String thumbnailUrl = '';
        if (item['videoThumbnails'] != null &&
            item['videoThumbnails'].isNotEmpty) {
          thumbnailUrl = item['videoThumbnails'][0]['url'] ?? '';
        }
        thumbnailUrl = _normalizeThumbnailUrl(thumbnailUrl,
            baseUrl: baseUrl, videoId: item['videoId']);

        // Parse upload date
        DateTime uploadDate = DateTime.now();
        if (item['published'] != null) {
          try {
            uploadDate =
                DateTime.fromMillisecondsSinceEpoch(item['published'] * 1000);
          } catch (e) {
            // Keep default date if parsing fails
          }
        }

        results.add(SearchResult(
          id: item['videoId'],
          title: item['title'] ?? 'Unknown Title',
          artist: item['author'] ?? 'Unknown Artist',
          album: 'YouTube',
          duration: Duration(seconds: item['lengthSeconds'] ?? 0),
          thumbnailUrl: thumbnailUrl,
          videoId: item['videoId'],
          viewCount: item['viewCount'] ?? 0,
          uploadDate: uploadDate,
        ));
      } catch (e) {
        print('Error parsing search result: $e');
        continue;
      }
    }

    return results;
  }

  // Fallback search using yt-dlp
  Future<List<SearchResult>> _searchWithYtDlp(
      String query, int maxResults) async {
    try {
      if (!await isYtDlpInstalled()) {
        throw Exception('yt-dlp is not installed');
      }

      print('Searching with yt-dlp: $query');

      // Use yt-dlp to search YouTube
      final searchQuery = 'ytsearch$maxResults:$query';
      final result = await _runYtDlp(
        ['--dump-json', '--flat-playlist', searchQuery],
      );

      if (result.exitCode != 0 || result.stdout.toString().trim().isEmpty) {
        throw Exception('No search results from yt-dlp: ${result.stderr}');
      }

      final List<SearchResult> results = [];
      final output = result.stdout.toString();

      // Parse JSON lines
      final lines = output.split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        try {
          final videoData = json.decode(line);

          if (videoData['id'] != null) {
            final videoId = videoData['id'];
            final thumbnail = _normalizeThumbnailUrl(
              videoData['thumbnail'] ?? '',
              videoId: videoId,
            );
            results.add(SearchResult(
              id: videoId,
              title: videoData['title'] ?? 'Unknown Title',
              artist: videoData['uploader'] ?? 'Unknown Artist',
              album: 'YouTube',
              duration: Duration(seconds: videoData['duration']?.toInt() ?? 0),
              thumbnailUrl: thumbnail,
              videoId: videoId,
              viewCount: videoData['view_count'] ?? 0,
              uploadDate: DateTime.tryParse(videoData['upload_date'] ?? '') ??
                  DateTime.now(),
            ));
          }
        } catch (e) {
          print('Error parsing yt-dlp result line: $e');
          continue;
        }
      }

      return results;
    } catch (e) {
      print('yt-dlp search failed: $e');
      throw Exception('Search failed: ${e.toString()}');
    }
  }

  // Get detailed video information using yt-dlp
  Future<Map<String, dynamic>?> getVideoInfo(String videoId) async {
    try {
      if (!await isYtDlpInstalled()) {
        print('yt-dlp not installed, installing...');
        if (!await installYtDlp()) {
          throw Exception('Failed to install yt-dlp');
        }
      }

      final url = 'https://www.youtube.com/watch?v=$videoId';
      final result = await _runYtDlp(['--dump-json', '--no-download', url]);

      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final output = result.stdout.toString();
        return json.decode(output);
      }

      return null;
    } catch (e) {
      print('Error getting video info: $e');
      return null;
    }
  }

  // Download audio using yt-dlp
  Future<DownloadTask> downloadAudio(
    String videoId,
    String outputPath, {
    Function(double)? onProgress,
    String quality = 'best',
    // Original metadata from the search result — preserved throughout so the
    // UI never shows generic 'Downloading...' / 'Unknown Artist' strings.
    String? originalTitle,
    String? originalArtist,
  }) async {
    // Use the caller-supplied title/artist as the baseline. We'll try to
    // improve them via getVideoInfo, but we won't replace them with generic
    // fallbacks if that call fails.
    final baseTask = DownloadTask(
      id: videoId,
      url: 'https://www.youtube.com/watch?v=$videoId',
      title: originalTitle ?? 'Unknown Title',
      artist: originalArtist ?? 'Unknown Artist',
      status: DownloadStatus.downloading,
      progress: 0.0,
      createdDate: DateTime.now(),
    );

    try {
      if (!await isYtDlpInstalled()) {
        print('yt-dlp not installed, installing...');
        if (!await installYtDlp()) {
          throw Exception('Failed to install yt-dlp');
        }
      }

      // Try to enrich the title/artist from yt-dlp metadata.
      // If getVideoInfo fails or returns null, we keep the original values.
      final videoInfo = await getVideoInfo(videoId);
      final finalTask = (videoInfo != null)
          ? baseTask.copyWith(
              title: (videoInfo['title'] as String?)?.isNotEmpty == true
                  ? videoInfo['title'] as String
                  : baseTask.title,
              artist: (videoInfo['uploader'] as String?)?.isNotEmpty == true
                  ? videoInfo['uploader'] as String
                  : baseTask.artist,
            )
          : baseTask;

      // Ensure output directory exists
      final outputDir = Directory(outputPath);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Sanitize filename
      final sanitizedTitle = _sanitizeFilename(finalTask.title);
      final outputFile = path.join(outputPath, '$sanitizedTitle.%(ext)s');

      // ── yt-dlp command ────────────────────────────────────────────────────
      // --embed-thumbnail   : embeds the video thumbnail as MP3 cover art (APIC)
      // --convert-thumbnails: JPEG is required for ID3v2 APIC frames
      // --embed-metadata    : writes title, uploader, date, description, etc.
      // --parse-metadata    : remap YouTube-specific fields to standard ID3 names
      final url = 'https://www.youtube.com/watch?v=$videoId';
      final args = await _buildYtDlpArgs([
        '--extract-audio',
        '--audio-format', 'mp3',
        '--audio-quality', '0',
        '--no-playlist',
        // Embed cover art (thumbnail) and all available YouTube metadata
        '--embed-thumbnail',
        '--convert-thumbnails', 'jpg',
        '--embed-metadata',
        // Map YouTube channel fields to standard ID3 artist tags
        '--parse-metadata', r'%(uploader)s:%(artist)s',
        '--parse-metadata', r'%(channel)s:%(album_artist)s',
        // NOTE: %(upload_date>%Y)s is intentionally omitted — the > character
        // is a shell redirect operator and breaks yt-dlp when runInShell=true.
        // Year is already written by --embed-metadata from the video upload_date.
        '--output', outputFile,
        '--newline',
        url,
      ]);

      print('Running command: yt-dlp ${args.join(' ')}');

      // runInShell: false so shell operators (>, |, etc.) in track titles
      // or yt-dlp format strings cannot be misinterpreted by the shell.
      final process = await Process.start('yt-dlp', args, runInShell: false);

      final outputBuffer = StringBuffer();
      double currentProgress = 0.0;

      // allowMalformed: true prevents FormatException crashes when yt-dlp
      // outputs non-UTF-8 bytes (e.g. special characters in song titles).
      process.stdout
          .transform(const Utf8Codec(allowMalformed: true).decoder)
          .transform(const LineSplitter())
          .listen((line) {
        outputBuffer.writeln(line);
        print('yt-dlp: $line');

        // Parse progress percentage from yt-dlp output
        final progressMatch =
            RegExp(r'\[download\]\s+(\d+\.?\d*)%').firstMatch(line);
        if (progressMatch != null) {
          currentProgress = double.parse(progressMatch.group(1)!) / 100.0;
          onProgress?.call(currentProgress);
        }
      });

      process.stderr
          .transform(const Utf8Codec(allowMalformed: true).decoder)
          .listen((data) {
        print('yt-dlp stderr: $data');
      });

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        // Find the downloaded file
        final files = await outputDir.list().toList();
        String? downloadedFilePath;
        try {
          final matched = files.firstWhere(
            (f) => f.path.contains(sanitizedTitle) && f.path.endsWith('.mp3'),
          );
          downloadedFilePath = matched.path;
        } catch (_) {
          final mp3Files = files.where((f) => f.path.endsWith('.mp3')).toList();
          if (mp3Files.isNotEmpty) downloadedFilePath = mp3Files.last.path;
        }

        // MusicBrainz enrichment (best-effort, non-blocking).
        // Queries for genre, canonical artist, album, year.
        // Patches them into the MP3 via ffmpeg stream-copy (no re-encode).
        // Failures here are non-fatal — the download is still returned.
        if (downloadedFilePath != null) {
          print('Enriching ID3 tags from MusicBrainz...');
          final mbData = await _enrichMetadataFromMusicBrainz(
              finalTask.title, finalTask.artist);
          if (mbData.isNotEmpty) {
            await _patchId3TagsWithFfmpeg(downloadedFilePath, mbData);
          } else {
            print('No MusicBrainz match -- keeping yt-dlp tags only');
          }
        }

        return finalTask.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: downloadedFilePath,
        );
      } else {
        throw Exception('yt-dlp failed with exit code: $exitCode');
      }
    } catch (e) {
      print('Download error: $e');
      return baseTask.copyWith(
        status: DownloadStatus.failed,
        progress: 0.0,
      );
    }
  }

  // Get stream URL for direct playback (without downloading)
  Future<String?> getStreamUrl(String videoId,
      {String quality = 'best'}) async {
    // ── Cache lookup (stream URLs expire in 30 min) ───────────────────────
    final cacheKey = 'stream_url_$videoId';
    try {
      final cached = await CacheService.instance.get(cacheKey);
      if (cached != null && cached is String && cached.isNotEmpty) {
        return cached;
      }
    } catch (_) {}

    try {
      if (!await isYtDlpInstalled()) {
        if (!await installYtDlp()) {
          return null;
        }
      }

      final url = 'https://www.youtube.com/watch?v=$videoId';
      final result =
          await _runYtDlp(['--get-url', '--format', 'bestaudio/best', url]);

      if (result.exitCode == 0) {
        final streamUrl = result.stdout.toString().trim();
        if (streamUrl.isNotEmpty) {
          await CacheService.instance.put(
            cacheKey,
            streamUrl,
            ttl: CacheService.streamUrlTtl,
          );
          return streamUrl;
        }
      }

      return null;
    } catch (e) {
      print('Error getting stream URL: $e');
      return null;
    }
  }

  // Create track from download task
  Future<Track?> createTrackFromDownload(DownloadTask downloadTask) async {
    if (downloadTask.status != DownloadStatus.completed ||
        downloadTask.filePath == null) {
      return null;
    }

    return Track(
      id: downloadTask.id,
      title: downloadTask.title,
      artist: downloadTask.artist,
      album: 'YouTube Download',
      duration:
          const Duration(minutes: 3, seconds: 30), // TODO: Get actual duration
      filePath: downloadTask.filePath!,
      format: 'mp3',
      addedDate: DateTime.now(),
    );
  }

  // Get default download path — always uses music_app_downloads folder
  Future<String> getDefaultDownloadPath() async {
    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        return path.join(
            userProfile ?? 'C:\\Users\\Default', 'Music', 'music_app_downloads');
      } else {
        final home = Platform.environment['HOME'];
        return path.join(home ?? '/tmp', 'Music', 'music_app_downloads');
      }
    } catch (e) {
      print('Error getting download path: $e');
      return Platform.isWindows
          ? 'C:\\Users\\Music\\music_app_downloads'
          : '/tmp/music_app_downloads';
    }
  }

  // Sanitize filename for cross-platform compatibility
  String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Get YouTube trending music
  Future<List<SearchResult>> getTrendingMusic({int maxResults = 10}) async {
    // ── Cache lookup (6h TTL) ─────────────────────────────────────────────
    const cacheKey = 'trending_music';
    try {
      final cached = await CacheService.instance.get(cacheKey);
      if (cached != null && cached is List) {
        return (cached)
            .map((item) => SearchResult(
                  id: item['id'],
                  title: item['title'],
                  artist: item['artist'],
                  album: item['album'],
                  duration: Duration(seconds: item['durationSeconds'] ?? 0),
                  thumbnailUrl: item['thumbnailUrl'] ?? '',
                  videoId: item['videoId'],
                  viewCount: item['viewCount'] ?? 0,
                  uploadDate: DateTime.tryParse(item['uploadDate'] ?? '') ??
                      DateTime.now(),
                ))
            .toList();
      }
    } catch (_) {}

    try {
      print('Fetching trending music...');

      final now = DateTime.now();
      final year = _currentYear();
      final monthName = _monthName(now.month);
      final latestQueries = [
        'latest songs $year',
        'new songs $monthName $year',
        'top hits $year'
      ];

      final List<SearchResult> latestResults = [];
      for (final query in latestQueries) {
        try {
          final results = await searchVideos(query, maxResults: 4);
          latestResults.addAll(results);
        } catch (e) {
          print('Latest search failed for "$query": $e');
        }
      }

      if (latestResults.isNotEmpty) {
        final finalResults = latestResults.take(maxResults).toList();
        await _cacheSearchResults(cacheKey, finalResults);
        return finalResults;
      }

      // Try Invidious API for trending
      final url = '$_invidousInstance/api/v1/trending?type=music';

      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'MusicPlayer/1.0'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final results =
              _parseSearchResults(data, maxResults, baseUrl: _invidousInstance);
          print('Found ${results.length} trending tracks via Invidious');
          await _cacheSearchResults(cacheKey, results);
          return results;
        }
      } catch (e) {
        print('Primary Invidious trending failed: $e');
      }

      // Fallback to alternative instance
      try {
        final fallbackUrl = '$_alternativeInstance/api/v1/trending?type=music';
        final response = await http.get(
          Uri.parse(fallbackUrl),
          headers: {'User-Agent': 'MusicPlayer/1.0'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final results = _parseSearchResults(data, maxResults,
              baseUrl: _alternativeInstance);
          print('Found ${results.length} trending tracks via fallback');
          await _cacheSearchResults(cacheKey, results);
          return results;
        }
      } catch (e) {
        print('Fallback Invidious trending failed: $e');
      }

      // Fallback to yt-dlp search for popular music
      final results = await _getTrendingWithYtDlp(maxResults);
      await _cacheSearchResults(cacheKey, results);
      return results;
    } catch (e) {
      print('Error getting trending music: $e');
      return [];
    }
  }

  // Get ALL tracks in a YouTube playlist (no artificial page limit)
  Future<List<SearchResult>> getPlaylistContents(String playlistId,
      {int maxResults = 0, int offset = 0}) async {
    // ── Cache lookup ───────────────────────────────────────────────────────────
    // Key is per-playlist only so the full result is shared regardless of
    // how many results the caller requested.
    final cacheKey = 'playlist_all_$playlistId';
    try {
      final cached = await CacheService.instance.get(cacheKey);
      if (cached != null && cached is List) {
        final all = (cached)
            .map((item) => SearchResult(
                  id: item['id'],
                  title: item['title'],
                  artist: item['artist'],
                  album: item['album'],
                  duration: Duration(seconds: item['durationSeconds'] ?? 0),
                  thumbnailUrl: item['thumbnailUrl'] ?? '',
                  videoId: item['videoId'],
                  viewCount: item['viewCount'] ?? 0,
                  uploadDate: DateTime.tryParse(item['uploadDate'] ?? '') ??
                      DateTime.now(),
                ))
            .toList();
        print('Playlist cache hit: ${all.length} tracks for $playlistId');
        return all;
      }
    } catch (_) {}

    try {
      print('Fetching ALL playlist contents for: $playlistId');

      // ── Try Invidious API ──────────────────────────────────────────────
      // Invidious returns every video in the playlist inside a single JSON
      // response (the `videos` array). No pagination needed server-side.
      final url = '$_invidousInstance/api/v1/playlists/$playlistId';
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'MusicPlayer/1.0'},
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final List<dynamic> videos = data['videos'] ?? [];

          if (videos.isNotEmpty) {
            // Return ALL videos — no slicing
            final results =
                _parseSearchResults(videos, videos.length, baseUrl: _invidousInstance);
            print('Found ${results.length} tracks in playlist via Invidious');
            await _cacheSearchResults(cacheKey, results);
            return results;
          }
        }
      } catch (e) {
        print('Invidious playlist fetch failed: $e');
      }

      // ── Fallback to yt-dlp (fetches everything in one --flat-playlist call) ───
      final results = await _getPlaylistWithYtDlp(playlistId);
      await _cacheSearchResults(cacheKey, results);
      return results;
    } catch (e) {
      print('Error getting playlist contents: $e');
      return [];
    }
  }

  // Extract playlist ID from YouTube URL
  String? extractPlaylistId(String url) {
    final trimmed = url.trim();

    // Match various YouTube playlist URL formats
    final patterns = [
      r'[?&]list=([a-zA-Z0-9_-]+)',
      r'playlist\?list=([a-zA-Z0-9_-]+)',
      r'/playlist/([a-zA-Z0-9_-]+)',
    ];

    for (final pattern in patterns) {
      final match = RegExp(pattern).firstMatch(trimmed);
      if (match != null) {
        return match.group(1);
      }
    }

    // Fallback: if the input itself looks like a bare playlist ID
    // (e.g. PL..., OLAK..., RD..., FL..., or any 20+ char alphanumeric
    // string the user pasted directly), return it as-is.
    final bareIdPattern = RegExp(r'^[a-zA-Z0-9_-]{10,}$');
    if (bareIdPattern.hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  // Get trending artists/channels
  Future<List<Map<String, dynamic>>> getTrendingArtists(
      {int maxResults = 10}) async {
    try {
      print('Fetching trending artists...');

      final now = DateTime.now();
      final year = _currentYear();
      final monthName = _monthName(now.month);

      // Use yt-dlp to search for popular artists
      final artistQueries = [
        'trending music artists $year',
        'popular singers $year',
        'top music channels $year',
        'viral artists $year',
        'new artists $monthName $year'
      ];

      final List<Map<String, dynamic>> artists = [];

      for (final query in artistQueries.take(2)) {
        try {
          final results = await searchVideos(query, maxResults: 5);
          for (final result in results) {
            if (!artists.any((a) => a['name'] == result.artist)) {
              artists.add({
                'name': result.artist,
                'subscribers': result.viewCount,
                'avatar': result.thumbnailUrl,
                'channelId': result.videoId, // Placeholder
              });
            }
          }
        } catch (e) {
          print('Error searching for artists with query "$query": $e');
        }
      }

      return artists.take(maxResults).toList();
    } catch (e) {
      print('Error getting trending artists: $e');
      return [];
    }
  }

  // Get trending playlists
  Future<List<Map<String, dynamic>>> getTrendingPlaylists(
      {int maxResults = 10}) async {
    try {
      print('Fetching trending playlists...');

      final now = DateTime.now();
      final year = _currentYear();
      final monthName = _monthName(now.month);

      // Search for popular playlists
      final playlistQueries = [
        'best music playlist $year',
        'top hits $year playlist',
        'viral songs $year playlist',
        'trending music mix $monthName $year'
      ];

      final List<Map<String, dynamic>> playlists = [];

      for (final query in playlistQueries.take(2)) {
        try {
          final results = await searchVideos(query, maxResults: 3);
          for (final result in results) {
            playlists.add({
              'title': result.title,
              'author': result.artist,
              'trackCount': 25, // Placeholder
              'thumbnailUrl': result.thumbnailUrl,
              'playlistId': result.videoId, // Placeholder
              'description': 'Trending playlist featuring ${result.artist}',
            });
          }
        } catch (e) {
          print('Error searching playlists with query "$query": $e');
        }
      }

      return playlists.take(maxResults).toList();
    } catch (e) {
      print('Error getting trending playlists: $e');
      return [];
    }
  }

  // Private helper methods
  Future<List<SearchResult>> _getTrendingWithYtDlp(int maxResults) async {
    try {
      print('Fetching trending with yt-dlp fallback...');

      final now = DateTime.now();
      final year = _currentYear();
      final monthName = _monthName(now.month);

      final trendingQueries = [
        'trending music $year',
        'viral songs $year',
        'top hits $monthName $year',
        'popular music $year'
      ];

      final List<SearchResult> allResults = [];

      for (final query in trendingQueries) {
        try {
          final results = await searchVideos(query, maxResults: 3);
          allResults.addAll(results);
        } catch (e) {
          print('Error with trending query "$query": $e');
        }
      }

      return allResults.take(maxResults).toList();
    } catch (e) {
      print('Error getting trending with yt-dlp: $e');
      return [];
    }
  }

  // Fetches ALL tracks from a playlist using yt-dlp --flat-playlist.
  // Returns every track in one go — no artificial page limit.
  Future<List<SearchResult>> _getPlaylistWithYtDlp(String playlistId) async {
    try {
      print('Fetching ALL playlist tracks with yt-dlp: $playlistId');

      final result = await _runYtDlp([
        '--dump-json',
        '--flat-playlist',
        'https://www.youtube.com/playlist?list=$playlistId',
      ]);

      if (result.exitCode != 0) {
        print('yt-dlp playlist fetch failed: ${result.stderr}');
        return [];
      }

      final List<SearchResult> tracks = [];
      final output = result.stdout.toString();

      for (final line in output.split('\n')) {
        if (line.trim().isEmpty) continue;

        try {
          final data = json.decode(line.trim());
          final videoId = data['id'] ?? '';
          final rawThumbnail =
              (data['thumbnails'] as List?)?.isNotEmpty == true
                  ? data['thumbnails'][0]['url'] ?? ''
                  : '';
          tracks.add(SearchResult(
            id: videoId,
            title: data['title'] ?? 'Unknown Title',
            artist: data['uploader'] ?? 'Unknown Artist',
            album: null,
            duration:
                Duration(seconds: (data['duration'] ?? 0).toInt()),
            thumbnailUrl:
                _normalizeThumbnailUrl(rawThumbnail, videoId: videoId),
            videoId: videoId,
            viewCount: data['view_count'] ?? 0,
            uploadDate: DateTime.now(),
          ));
        } catch (e) {
          print('Error parsing playlist track data: $e');
          continue;
        }
      }

      print('Extracted ${tracks.length} tracks from playlist $playlistId');
      return tracks;
    } catch (e) {
      print('Error getting playlist with yt-dlp: $e');
      return [];
    }
  }

  // Alias for getPlaylistContents with better naming
  Future<List<SearchResult>> getPlaylistTracks(String playlistId,
      {int maxResults = 0, int offset = 0}) async {
    return getPlaylistContents(playlistId);
  }

  // ── MusicBrainz metadata enrichment ─────────────────────────────────────
  // Queries the free MusicBrainz API (no key needed) for genre, proper album
  // name, precise artist credit, and release year.
  Future<Map<String, String>> _enrichMetadataFromMusicBrainz(
      String title, String artist) async {
    try {
      // Strip featured artist suffixes and brackets for a cleaner search
      final cleanTitle = title
          .replaceAll(RegExp(r'\(feat\..*?\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      // Use only the primary artist (before any comma / ampersand)
      final cleanArtist =
          artist.split(RegExp(r'[,&]')).first.trim();

      final query = Uri.encodeQueryComponent(
          'recording:"$cleanTitle" AND artistname:"$cleanArtist"');
      final uri = Uri.parse(
          'https://musicbrainz.org/ws/2/recording?query=$query'
          '&fmt=json&limit=1&inc=tags+releases+artist-credits');

      final response = await http.get(uri, headers: {
        'User-Agent': 'MusicPlayerApp/1.0 (music-app-flutter)',
        'Accept':     'application/json',
      }).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return {};

      final data = json.decode(
          const Utf8Codec(allowMalformed: true).decode(response.bodyBytes));
      final recordings = data['recordings'] as List?;
      if (recordings == null || recordings.isEmpty) return {};

      final rec = recordings.first as Map<String, dynamic>;
      final enriched = <String, String>{};

      // ── Title (MusicBrainz canonical spelling) ───────────────────────────
      final mbTitle = rec['title'] as String?;
      if (mbTitle != null && mbTitle.isNotEmpty) enriched['title'] = mbTitle;

      // ── Artist credit (handles collaborations correctly) ─────────────────
      final credits = rec['artist-credit'] as List?;
      if (credits != null && credits.isNotEmpty) {
        final artistStr = credits.map<String>((c) {
          final a    = (c['artist'] as Map?)?['name'] as String? ?? '';
          final join = (c['joinphrase'] as String?) ?? '';
          return '$a$join';
        }).join().trim();
        if (artistStr.isNotEmpty) enriched['artist'] = artistStr;
      }

      // ── Album + year from the first listed release ───────────────────────
      final releases = rec['releases'] as List?;
      if (releases != null && releases.isNotEmpty) {
        final rel = releases.first as Map<String, dynamic>;

        final album = rel['title'] as String?;
        if (album != null && album.isNotEmpty) enriched['album'] = album;

        final releaseDate = rel['date'] as String?;
        if (releaseDate != null && releaseDate.length >= 4) {
          enriched['date'] = releaseDate.substring(0, 4); // Year only
        }

        // Release type badge stored as comment (Album / Single / EP)
        final rg = rel['release-group'] as Map?;
        final type = rg?['primary-type'] as String?;
        if (type != null && type.isNotEmpty) {
          enriched['comment'] = type;
        }
      }

      // ── Genre from crowd-sourced tags (highest vote count first) ─────────
      final tags = rec['tags'] as List?;
      if (tags != null && tags.isNotEmpty) {
        final sorted = List<Map<String, dynamic>>.from(
            tags.cast<Map<String, dynamic>>())
          ..sort((a, b) =>
              ((b['count'] ?? 0) as int).compareTo((a['count'] ?? 0) as int));
        final genre = sorted
            .take(3)
            .map((t) => (t['name'] as String? ?? '').trim())
            .where((t) => t.isNotEmpty)
            .map((t) => t[0].toUpperCase() + t.substring(1))
            .join('; ');
        if (genre.isNotEmpty) enriched['genre'] = genre;
      }

      if (enriched.isNotEmpty) {
        print('MusicBrainz enrichment: ${enriched.keys.join(', ')} for "$cleanTitle"');
      }
      return enriched;
    } catch (e) {
      print('MusicBrainz lookup failed (non-critical): $e');
      return {};
    }
  }

  // ── ffmpeg ID3 tag patcher ────────────────────────────────────────────────
  // Uses ffmpeg stream-copy to add/override specific ID3 tags without
  // re-encoding the audio. Existing tags (including cover art added by
  // yt-dlp's --embed-thumbnail) are preserved via -map_metadata 0.
  Future<void> _patchId3TagsWithFfmpeg(
      String mp3Path, Map<String, String> metadata) async {
    if (metadata.isEmpty) return;

    final dir      = path.dirname(mp3Path);
    final base     = path.basenameWithoutExtension(mp3Path);
    final tempPath = path.join(dir, '${base}_id3tmp.mp3');

    try {
      // Build -metadata key=value pairs for every non-empty field
      final metaArgs = metadata.entries
          .where((e) => e.value.isNotEmpty)
          .expand<String>((e) => ['-metadata', '${e.key}=${e.value}'])
          .toList();

      final ffmpegArgs = [
        '-i',          mp3Path,
        '-map',        '0',          // copy ALL streams (audio + embedded cover)
        '-map_metadata', '0',        // preserve all existing tags
        '-id3v2_version', '3',       // ID3v2.3 – broadest player compatibility
        ...metaArgs,
        '-codec',      'copy',       // no re-encode
        '-y',                        // overwrite temp
        tempPath,
      ];

      print('Patching ID3 tags via ffmpeg: ${metadata.keys.join(', ')}');
      final result =
          await Process.run('ffmpeg', ffmpegArgs, runInShell: true);

      if (result.exitCode == 0) {
        // Atomically replace original with enriched copy
        await File(mp3Path).delete();
        await File(tempPath).rename(mp3Path);
        print('ID3 tags patched successfully');
      } else {
        print('ffmpeg ID3 patch failed (non-critical): ${result.stderr}');
        final tmp = File(tempPath);
        if (await tmp.exists()) await tmp.delete();
      }
    } catch (e) {
      print('Error patching ID3 tags (non-critical): $e');
      final tmp = File(tempPath);
      if (await tmp.exists()) await tmp.delete();
    }
  }

  void dispose() {
    // Cleanup
  }
}
