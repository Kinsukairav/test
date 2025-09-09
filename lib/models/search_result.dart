import 'track.dart';

class SearchResult {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final Duration duration;
  final String thumbnailUrl;
  final String videoId;
  final int viewCount;
  final DateTime uploadDate;

  SearchResult({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.duration,
    required this.thumbnailUrl,
    required this.videoId,
    required this.viewCount,
    required this.uploadDate,
  });

  // Convert to Track for playback
  Track toTrack() {
    return Track(
      id: id,
      title: title,
      artist: artist,
      album: album ?? 'Unknown Album',
      albumArt: thumbnailUrl.isNotEmpty ? thumbnailUrl : null,
      duration: duration,
      filePath: '', // Will be set after download/streaming
      format: 'mp4', // YouTube video format
      addedDate: DateTime.now(),
    );
  }

  // Format view count for display
  String get formattedViewCount {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K views';
    } else {
      return '$viewCount views';
    }
  }

  // Format upload date for display
  String get formattedUploadDate {
    final now = DateTime.now();
    final difference = now.difference(uploadDate);

    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    }
  }
}
