import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/search_result.dart';
import '../models/youtube_playlist.dart';
import '../models/youtube_artist.dart';

class CacheService {
  static const String _cacheDir = 'music_cache';
  static const String _trendingTracksFile = 'trending_tracks.json';
  static const String _trendingPlaylistsFile = 'trending_playlists.json';
  static const String _trendingArtistsFile = 'trending_artists.json';
  static const Duration _cacheExpiry = Duration(hours: 2);

  static Future<Directory> get _cacheDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  // Cache trending tracks
  static Future<void> cacheTrendingTracks(List<SearchResult> tracks) async {
    try {
      final cacheDir = await _cacheDirectory;
      final file = File('${cacheDir.path}/$_trendingTracksFile');
      
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': tracks.map((track) => {
          'id': track.id,
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'duration': track.duration.inSeconds,
          'thumbnailUrl': track.thumbnailUrl,
          'videoId': track.videoId,
          'viewCount': track.viewCount,
          'uploadDate': track.uploadDate.millisecondsSinceEpoch,
        }).toList(),
      };
      
      await file.writeAsString(jsonEncode(cacheData));
    } catch (e) {
      print('Failed to cache trending tracks: $e');
    }
  }

  static Future<List<SearchResult>?> getCachedTrendingTracks() async {
    try {
      final cacheDir = await _cacheDirectory;
      final file = File('${cacheDir.path}/$_trendingTracksFile');
      
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      final cacheData = jsonDecode(content);
      
      final timestamp = DateTime.fromMillisecondsSinceEpoch(cacheData['timestamp']);
      if (DateTime.now().difference(timestamp) > _cacheExpiry) {
        await file.delete();
        return null;
      }
      
      final List<dynamic> tracksData = cacheData['data'];
      return tracksData.map((data) => SearchResult(
        id: data['id'],
        title: data['title'],
        artist: data['artist'],
        album: data['album'],
        duration: Duration(seconds: data['duration']),
        thumbnailUrl: data['thumbnailUrl'],
        videoId: data['videoId'],
        viewCount: data['viewCount'],
        uploadDate: DateTime.fromMillisecondsSinceEpoch(data['uploadDate']),
      )).toList();
    } catch (e) {
      print('Failed to get cached trending tracks: $e');
      return null;
    }
  }

  // Cache trending playlists
  static Future<void> cacheTrendingPlaylists(List<YouTubePlaylist> playlists) async {
    try {
      final cacheDir = await _cacheDirectory;
      final file = File('${cacheDir.path}/$_trendingPlaylistsFile');
      
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': playlists.map((playlist) => {
          'id': playlist.id,
          'title': playlist.title,
          'author': playlist.author,
          'description': playlist.description,
          'thumbnailUrl': playlist.thumbnailUrl,
          'trackCount': playlist.trackCount,
          'totalDuration': playlist.totalDuration.inSeconds,
          'viewCount': playlist.viewCount,
          'createdDate': playlist.createdDate.millisecondsSinceEpoch,
          'isPublic': playlist.isPublic,
        }).toList(),
      };
      
      await file.writeAsString(jsonEncode(cacheData));
    } catch (e) {
      print('Failed to cache trending playlists: $e');
    }
  }

  static Future<List<YouTubePlaylist>?> getCachedTrendingPlaylists() async {
    try {
      final cacheDir = await _cacheDirectory;
      final file = File('${cacheDir.path}/$_trendingPlaylistsFile');
      
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      final cacheData = jsonDecode(content);
      
      final timestamp = DateTime.fromMillisecondsSinceEpoch(cacheData['timestamp']);
      if (DateTime.now().difference(timestamp) > _cacheExpiry) {
        await file.delete();
        return null;
      }
      
      final List<dynamic> playlistsData = cacheData['data'];
      return playlistsData.map((data) => YouTubePlaylist(
        id: data['id'],
        title: data['title'],
        author: data['author'],
        description: data['description'],
        thumbnailUrl: data['thumbnailUrl'],
        trackCount: data['trackCount'],
        totalDuration: Duration(seconds: data['totalDuration']),
        viewCount: data['viewCount'],
        createdDate: DateTime.fromMillisecondsSinceEpoch(data['createdDate']),
        isPublic: data['isPublic'] ?? true,
      )).toList();
    } catch (e) {
      print('Failed to get cached trending playlists: $e');
      return null;
    }
  }

  // Cache trending artists
  static Future<void> cacheTrendingArtists(List<YouTubeArtist> artists) async {
    try {
      final cacheDir = await _cacheDirectory;
      final file = File('${cacheDir.path}/$_trendingArtistsFile');
      
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': artists.map((artist) => {
          'id': artist.id,
          'name': artist.name,
          'description': artist.description,
          'avatarUrl': artist.avatarUrl,
          'bannerUrl': artist.bannerUrl,
          'subscriberCount': artist.subscriberCount,
          'videoCount': artist.videoCount,
          'viewCount': artist.viewCount,
          'joinedDate': artist.joinedDate.millisecondsSinceEpoch,
          'isVerified': artist.isVerified,
          'country': artist.country,
        }).toList(),
      };
      
      await file.writeAsString(jsonEncode(cacheData));
    } catch (e) {
      print('Failed to cache trending artists: $e');
    }
  }

  static Future<List<YouTubeArtist>?> getCachedTrendingArtists() async {
    try {
      final cacheDir = await _cacheDirectory;
      final file = File('${cacheDir.path}/$_trendingArtistsFile');
      
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      final cacheData = jsonDecode(content);
      
      final timestamp = DateTime.fromMillisecondsSinceEpoch(cacheData['timestamp']);
      if (DateTime.now().difference(timestamp) > _cacheExpiry) {
        await file.delete();
        return null;
      }
      
      final List<dynamic> artistsData = cacheData['data'];
      return artistsData.map((data) => YouTubeArtist(
        id: data['id'],
        name: data['name'],
        description: data['description'],
        avatarUrl: data['avatarUrl'],
        bannerUrl: data['bannerUrl'],
        subscriberCount: data['subscriberCount'],
        videoCount: data['videoCount'],
        viewCount: data['viewCount'],
        joinedDate: DateTime.fromMillisecondsSinceEpoch(data['joinedDate']),
        isVerified: data['isVerified'],
        country: data['country'],
      )).toList();
    } catch (e) {
      print('Failed to get cached trending artists: $e');
      return null;
    }
  }

  // Clear all cache
  static Future<void> clearCache() async {
    try {
      final cacheDir = await _cacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      print('Failed to clear cache: $e');
    }
  }

  // Get cache size
  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await _cacheDirectory;
      if (!await cacheDir.exists()) return 0;
      
      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      return totalSize;
    } catch (e) {
      print('Failed to get cache size: $e');
      return 0;
    }
  }

  // Format cache size for display
  static String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
