import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/search_result.dart';

class YouTubeService {
  static const String _invidousInstance = 'https://invidious.io';
  static const String _alternativeInstance = 'https://vid.puffyan.us';
  List<String>? _cachedJsRuntimeArgs;
  bool _checkedJsRuntime = false;
  bool _warnedAboutJsRuntime = false;

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
      return _cachedJsRuntimeArgs!;
    }

    if (await _isCommandAvailable('deno', ['--version'])) {
      _cachedJsRuntimeArgs = const ['--js-runtimes', 'deno'];
      return _cachedJsRuntimeArgs!;
    }

    _cachedJsRuntimeArgs = const [];
    _warnMissingJsRuntime();
    return _cachedJsRuntimeArgs!;
  }

  void _warnMissingJsRuntime() {
    if (_warnedAboutJsRuntime) {
      return;
    }

    _warnedAboutJsRuntime = true;
    print(
        'Warning: No supported JavaScript runtime found for yt-dlp. Install Node.js or Deno and set --js-runtimes to avoid missing formats.');
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
          return _parseSearchResults(data, maxResults,
              baseUrl: _invidousInstance);
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
          return _parseSearchResults(data, maxResults,
              baseUrl: _alternativeInstance);
        }
      } catch (e) {
        print('Alternative Invidious instance failed: $e');
      }

      // If both Invidious instances fail, try yt-dlp search
      return await _searchWithYtDlp(query, maxResults);
    } catch (e) {
      print('Error searching YouTube: $e');
      throw Exception(
          'Failed to search YouTube: Network error or service unavailable');
    }
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
  }) async {
    final downloadTask = DownloadTask(
      id: videoId,
      url: 'https://www.youtube.com/watch?v=$videoId',
      title: 'Downloading...',
      artist: 'Unknown Artist',
      status: DownloadStatus.pending,
      createdDate: DateTime.now(),
    );

    try {
      if (!await isYtDlpInstalled()) {
        print('yt-dlp not installed, installing...');
        if (!await installYtDlp()) {
          throw Exception('Failed to install yt-dlp');
        }
      }

      // Update status to downloading
      final updatedTask = downloadTask.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.0,
      );

      // Get video info first
      final videoInfo = await getVideoInfo(videoId);
      final finalTask = videoInfo != null
          ? updatedTask.copyWith(
              title: videoInfo['title'] ?? 'Unknown Title',
              artist: videoInfo['uploader'] ?? 'Unknown Artist',
            )
          : updatedTask;

      // Ensure output directory exists
      final outputDir = Directory(outputPath);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Sanitize filename
      final sanitizedTitle = _sanitizeFilename(finalTask.title);
      final outputFile = path.join(outputPath, '$sanitizedTitle.%(ext)s');

      // Prepare yt-dlp command
      final url = 'https://www.youtube.com/watch?v=$videoId';
      final args = await _buildYtDlpArgs([
        '--extract-audio',
        '--audio-format',
        'mp3',
        '--audio-quality',
        '0', // Best quality
        '--no-playlist',
        '--output',
        outputFile,
        '--newline',
        url,
      ]);

      print('Running command: yt-dlp ${args.join(' ')}');

      // Run yt-dlp with progress tracking
      final process = await Process.start('yt-dlp', args, runInShell: true);

      final outputBuffer = StringBuffer();
      double currentProgress = 0.0;

      process.stdout.transform(utf8.decoder).listen((data) {
        outputBuffer.write(data);
        print('yt-dlp output: $data');

        // Parse progress from yt-dlp output
        final progressMatch =
            RegExp(r'\[download\]\s+(\d+\.?\d*)%').firstMatch(data);
        if (progressMatch != null) {
          currentProgress = double.parse(progressMatch.group(1)!) / 100.0;
          onProgress?.call(currentProgress);
        }
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        print('yt-dlp error: $data');
      });

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        // Find the downloaded file
        final files = await outputDir.list().toList();
        final downloadedFile = files.firstWhere(
          (file) =>
              file.path.contains(sanitizedTitle) && file.path.endsWith('.mp3'),
          orElse: () => files.first,
        );

        return downloadTask.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: downloadedFile.path,
        );
      } else {
        throw Exception('yt-dlp failed with exit code: $exitCode');
      }
    } catch (e) {
      print('Download error: $e');
      return downloadTask.copyWith(
        status: DownloadStatus.failed,
        progress: 0.0,
      );
    }
  }

  // Get stream URL for direct playback (without downloading)
  Future<String?> getStreamUrl(String videoId,
      {String quality = 'best'}) async {
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
        return streamUrl.isNotEmpty ? streamUrl : null;
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

  // Get default download path
  Future<String> getDefaultDownloadPath() async {
    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        return path.join(
            userProfile ?? 'C:\\Users\\Default', 'Music', 'YouTube Downloads');
      } else {
        final home = Platform.environment['HOME'];
        return path.join(home ?? '/tmp', 'Music', 'YouTube Downloads');
      }
    } catch (e) {
      print('Error getting download path: $e');
      return Platform.isWindows
          ? 'C:\\Users\\Music\\YouTube Downloads'
          : '/tmp/music_downloads';
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
        return latestResults.take(maxResults).toList();
      }

      // Try Invidious API for trending
      final url = '$_invidousInstance/api/v1/trending?type=music';

      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'MusicPlayer/1.0'},
        ).timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final results =
              _parseSearchResults(data, maxResults, baseUrl: _invidousInstance);
          print('Found ${results.length} trending tracks via Invidious');
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
        ).timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final results = _parseSearchResults(data, maxResults,
              baseUrl: _alternativeInstance);
          print('Found ${results.length} trending tracks via fallback');
          return results;
        }
      } catch (e) {
        print('Fallback Invidious trending failed: $e');
      }

      // Fallback to yt-dlp search for popular music
      return await _getTrendingWithYtDlp(maxResults);
    } catch (e) {
      print('Error getting trending music: $e');
      return [];
    }
  }

  // Get YouTube playlist contents with pagination support
  Future<List<SearchResult>> getPlaylistContents(String playlistId,
      {int maxResults = 50, int offset = 0}) async {
    try {
      print(
          'Fetching playlist contents for: $playlistId (offset: $offset, max: $maxResults)');

      // Try Invidious API for playlist
      final url = '$_invidousInstance/api/v1/playlists/$playlistId';

      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'MusicPlayer/1.0'},
        ).timeout(Duration(seconds: 15));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final List<dynamic> videos = data['videos'] ?? [];

          // Apply offset and maxResults for pagination
          final startIndex = offset;
          final endIndex = (startIndex + maxResults).clamp(0, videos.length);

          if (startIndex >= videos.length) {
            return []; // No more results
          }

          final paginatedVideos = videos.sublist(startIndex, endIndex);
          final results = _parseSearchResults(paginatedVideos, maxResults,
              baseUrl: _invidousInstance);
          print(
              'Found ${results.length} tracks in playlist via Invidious (page: ${offset ~/ maxResults + 1})');
          return results;
        }
      } catch (e) {
        print('Invidious playlist fetch failed: $e');
      }

      // Fallback to yt-dlp for playlist
      return await _getPlaylistWithYtDlp(playlistId, maxResults, offset);
    } catch (e) {
      print('Error getting playlist contents: $e');
      return [];
    }
  }

  // Extract playlist ID from YouTube URL
  String? extractPlaylistId(String url) {
    // Match various YouTube playlist URL formats
    final patterns = [
      r'[?&]list=([a-zA-Z0-9_-]+)',
      r'playlist\?list=([a-zA-Z0-9_-]+)',
      r'/playlist/([a-zA-Z0-9_-]+)',
    ];

    for (final pattern in patterns) {
      final match = RegExp(pattern).firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
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

  Future<List<SearchResult>> _getPlaylistWithYtDlp(
      String playlistId, int maxResults,
      [int offset = 0]) async {
    try {
      print('Fetching playlist with yt-dlp: $playlistId (offset: $offset)');

      final result = await _runYtDlp([
        '--dump-json',
        '--flat-playlist',
        'https://www.youtube.com/playlist?list=$playlistId',
      ]);

      final List<SearchResult> tracks = [];
      if (result.exitCode != 0) {
        print('yt-dlp playlist fetch failed: ${result.stderr}');
        return [];
      }

      final output = result.stdout.toString();

      for (final line in output.split('\n')) {
        if (line.trim().isEmpty) continue;

        try {
          final data = json.decode(line.trim());
          final videoId = data['id'] ?? '';
          final rawThumbnail = (data['thumbnails'] as List?)?.isNotEmpty == true
              ? data['thumbnails'][0]['url'] ?? ''
              : '';
          final searchResult = SearchResult(
            id: videoId,
            title: data['title'] ?? 'Unknown Title',
            artist: data['uploader'] ?? 'Unknown Artist',
            album: null,
            duration: Duration(seconds: (data['duration'] ?? 0).toInt()),
            thumbnailUrl:
                _normalizeThumbnailUrl(rawThumbnail, videoId: videoId),
            videoId: videoId,
            viewCount: data['view_count'] ?? 0,
            uploadDate: DateTime.now(),
          );

          tracks.add(searchResult);
        } catch (e) {
          print('Error parsing playlist track data: $e');
          continue;
        }
      }

      // Apply pagination
      final startIndex = offset;
      final endIndex = (startIndex + maxResults).clamp(0, tracks.length);

      if (startIndex >= tracks.length) {
        return []; // No more results
      }

      final paginatedTracks = tracks.sublist(startIndex, endIndex);
      print(
          'Extracted ${paginatedTracks.length} tracks from playlist (total: ${tracks.length}, page: ${offset ~/ maxResults + 1})');
      return paginatedTracks;
    } catch (e) {
      print('Error getting playlist with yt-dlp: $e');
      return [];
    }
  }

  // Alias for getPlaylistContents with better naming
  Future<List<SearchResult>> getPlaylistTracks(String playlistId,
      {int maxResults = 50, int offset = 0}) async {
    return await getPlaylistContents(playlistId,
        maxResults: maxResults, offset: offset);
  }

  void dispose() {
    // Cleanup
  }
}
