import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:process_run/shell.dart';
import 'package:path/path.dart' as path;
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/search_result.dart';

class YouTubeService {
  static const String _invidousInstance = 'https://invidious.io';
  static const String _alternativeInstance = 'https://vid.puffyan.us';
  final Shell _shell = Shell();
  
  // Check if yt-dlp is installed
  Future<bool> isYtDlpInstalled() async {
    try {
      final result = await _shell.run('yt-dlp --version');
      return result.isNotEmpty;
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
      await _shell.run('pip install yt-dlp');
      return await isYtDlpInstalled();
    } catch (e) {
      print('Failed to install yt-dlp: $e');
      return false;
    }
  }
  
  // Search videos using Invidious API (YouTube alternative frontend)
  Future<List<SearchResult>> searchVideos(String query, {int maxResults = 20}) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      
      // Try primary Invidious instance
      final primaryUrl = '$_invidousInstance/api/v1/search?q=$encodedQuery&type=video&page=1';
      
      try {
        final response = await http.get(
          Uri.parse(primaryUrl),
          headers: {'User-Agent': 'MusicPlayer/1.0'},
        ).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return _parseSearchResults(data, maxResults);
        }
      } catch (e) {
        print('Primary Invidious instance failed: $e');
      }
      
      // Try alternative Invidious instance
      final altUrl = '$_alternativeInstance/api/v1/search?q=$encodedQuery&type=video&page=1';
      
      try {
        final response = await http.get(
          Uri.parse(altUrl),
          headers: {'User-Agent': 'MusicPlayer/1.0'},
        ).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return _parseSearchResults(data, maxResults);
        }
      } catch (e) {
        print('Alternative Invidious instance failed: $e');
      }
      
      // If both Invidious instances fail, try yt-dlp search
      return await _searchWithYtDlp(query, maxResults);
      
    } catch (e) {
      print('Error searching YouTube: $e');
      throw Exception('Failed to search YouTube: Network error or service unavailable');
    }
  }
  
  // Parse search results from Invidious API
  List<SearchResult> _parseSearchResults(List<dynamic> data, int maxResults) {
    final List<SearchResult> results = [];
    
    for (var item in data.take(maxResults)) {
      try {
        // Skip if no videoId
        if (item['videoId'] == null || item['videoId'].toString().isEmpty) {
          continue;
        }
        
        // Parse thumbnails
        String thumbnailUrl = '';
        if (item['videoThumbnails'] != null && item['videoThumbnails'].isNotEmpty) {
          thumbnailUrl = item['videoThumbnails'][0]['url'] ?? '';
        }
        
        // Parse upload date
        DateTime uploadDate = DateTime.now();
        if (item['published'] != null) {
          try {
            uploadDate = DateTime.fromMillisecondsSinceEpoch(item['published'] * 1000);
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
  Future<List<SearchResult>> _searchWithYtDlp(String query, int maxResults) async {
    try {
      if (!await isYtDlpInstalled()) {
        throw Exception('yt-dlp is not installed');
      }
      
      print('Searching with yt-dlp: $query');
      
      // Use yt-dlp to search YouTube
      final searchQuery = 'ytsearch$maxResults:$query';
      final result = await _shell.run('yt-dlp --dump-json --flat-playlist "$searchQuery"');
      
      if (result.isEmpty) {
        throw Exception('No search results from yt-dlp');
      }
      
      final List<SearchResult> results = [];
      final output = result.first.stdout.toString();
      
      // Parse JSON lines
      final lines = output.split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        try {
          final videoData = json.decode(line);
          
          if (videoData['id'] != null) {
            results.add(SearchResult(
              id: videoData['id'],
              title: videoData['title'] ?? 'Unknown Title',
              artist: videoData['uploader'] ?? 'Unknown Artist',
              album: 'YouTube',
              duration: Duration(seconds: videoData['duration']?.toInt() ?? 0),
              thumbnailUrl: videoData['thumbnail'] ?? '',
              videoId: videoData['id'],
              viewCount: videoData['view_count'] ?? 0,
              uploadDate: DateTime.tryParse(videoData['upload_date'] ?? '') ?? DateTime.now(),
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
      final result = await _shell.run('yt-dlp --dump-json --no-download "$url"');
      
      if (result.isNotEmpty) {
        final output = result.first.stdout.toString();
        return json.decode(output);
      }
      
      return null;
    } catch (e) {
      print('Error getting video info: $e');
      return null;
    }
  }
  
  // Download audio using yt-dlp
  Future<DownloadTask> downloadAudio(String videoId, String outputPath, {
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
      final finalTask = videoInfo != null ? updatedTask.copyWith(
        title: videoInfo['title'] ?? 'Unknown Title',
        artist: videoInfo['uploader'] ?? 'Unknown Artist',
      ) : updatedTask;

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
      final command = [
        'yt-dlp',
        '--extract-audio',
        '--audio-format', 'mp3',
        '--audio-quality', '0', // Best quality
        '--no-playlist',
        '--output', outputFile,
        '--newline',
        url,
      ];

      print('Running command: ${command.join(' ')}');

      // Run yt-dlp with progress tracking
      final process = await Process.start('yt-dlp', command.skip(1).toList());
      
      final outputBuffer = StringBuffer();
      double currentProgress = 0.0;

      process.stdout.transform(utf8.decoder).listen((data) {
        outputBuffer.write(data);
        print('yt-dlp output: $data');
        
        // Parse progress from yt-dlp output
        final progressMatch = RegExp(r'\[download\]\s+(\d+\.?\d*)%').firstMatch(data);
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
          (file) => file.path.contains(sanitizedTitle) && 
                   file.path.endsWith('.mp3'),
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
  Future<String?> getStreamUrl(String videoId, {String quality = 'best'}) async {
    try {
      if (!await isYtDlpInstalled()) {
        if (!await installYtDlp()) {
          return null;
        }
      }

      final url = 'https://www.youtube.com/watch?v=$videoId';
      final result = await _shell.run('yt-dlp --get-url --format "bestaudio/best" "$url"');
      
      if (result.isNotEmpty) {
        final streamUrl = result.first.stdout.toString().trim();
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
    if (downloadTask.status != DownloadStatus.completed || downloadTask.filePath == null) {
      return null;
    }

    return Track(
      id: downloadTask.id,
      title: downloadTask.title,
      artist: downloadTask.artist,
      album: 'YouTube Download',
      duration: const Duration(minutes: 3, seconds: 30), // TODO: Get actual duration
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
        return path.join(userProfile ?? 'C:\\Users\\Default', 'Music', 'YouTube Downloads');
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
      
      // Try Invidious API for trending
      final url = '$_invidousInstance/api/v1/trending?type=music';
      
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'MusicPlayer/1.0'},
        ).timeout(Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final results = _parseSearchResults(data, maxResults);
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
          final results = _parseSearchResults(data, maxResults);
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
  Future<List<SearchResult>> getPlaylistContents(String playlistId, {int maxResults = 50, int offset = 0}) async {
    try {
      print('Fetching playlist contents for: $playlistId (offset: $offset, max: $maxResults)');
      
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
          final results = _parseSearchResults(paginatedVideos, maxResults);
          print('Found ${results.length} tracks in playlist via Invidious (page: ${offset ~/ maxResults + 1})');
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
  Future<List<Map<String, dynamic>>> getTrendingArtists({int maxResults = 10}) async {
    try {
      print('Fetching trending artists...');
      
      // Use yt-dlp to search for popular artists
      final artistQueries = [
        'trending music artists 2024',
        'popular singers',
        'top music channels',
        'viral artists',
        'chart toppers'
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
  Future<List<Map<String, dynamic>>> getTrendingPlaylists({int maxResults = 10}) async {
    try {
      print('Fetching trending playlists...');
      
      // Search for popular playlists
      final playlistQueries = [
        'best music playlist 2024',
        'top hits playlist',
        'viral songs playlist',
        'trending music mix'
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
              'thumbnail': result.thumbnailUrl,
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
      
      final trendingQueries = [
        'trending music 2024',
        'viral songs',
        'top hits today',
        'popular music now'
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
  
  Future<List<SearchResult>> _getPlaylistWithYtDlp(String playlistId, int maxResults, [int offset = 0]) async {
    try {
      print('Fetching playlist with yt-dlp: $playlistId (offset: $offset)');
      
      final results = await _shell.run(
        'yt-dlp --dump-json --flat-playlist "https://www.youtube.com/playlist?list=$playlistId"'
      );
      
      final List<SearchResult> tracks = [];
      final output = results.isNotEmpty ? results.first.stdout : '';
      
      for (final line in output.split('\n')) {
        if (line.trim().isEmpty) continue;
        
        try {
          final data = json.decode(line.trim());
          final searchResult = SearchResult(
            id: data['id'] ?? '',
            title: data['title'] ?? 'Unknown Title',
            artist: data['uploader'] ?? 'Unknown Artist',
            album: null,
            duration: Duration(seconds: (data['duration'] ?? 0).toInt()),
            thumbnailUrl: (data['thumbnails'] as List?)?.isNotEmpty == true
                ? data['thumbnails'][0]['url'] ?? ''
                : '',
            videoId: data['id'] ?? '',
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
      print('Extracted ${paginatedTracks.length} tracks from playlist (total: ${tracks.length}, page: ${offset ~/ maxResults + 1})');
      return paginatedTracks;
      
    } catch (e) {
      print('Error getting playlist with yt-dlp: $e');
      return [];
    }
  }

  // Alias for getPlaylistContents with better naming
  Future<List<SearchResult>> getPlaylistTracks(String playlistId, {int maxResults = 50, int offset = 0}) async {
    return await getPlaylistContents(playlistId, maxResults: maxResults, offset: offset);
  }

  void dispose() {
    // Cleanup
  }
}
