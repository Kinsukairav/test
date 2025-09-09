class YouTubePlaylist {
  final String id;
  final String title;
  final String author;
  final String description;
  final String thumbnailUrl;
  final int trackCount;
  final Duration totalDuration;
  final DateTime createdDate;
  final int viewCount;
  final bool isPublic;

  YouTubePlaylist({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.thumbnailUrl,
    required this.trackCount,
    required this.totalDuration,
    required this.createdDate,
    required this.viewCount,
    this.isPublic = true,
  });

  // Create from YouTube API data
  factory YouTubePlaylist.fromJson(Map<String, dynamic> json) {
    return YouTubePlaylist(
      id: json['playlistId'] ?? json['id'] ?? '',
      title: json['title'] ?? 'Unknown Playlist',
      author: json['author'] ?? json['uploader'] ?? 'Unknown Creator',
      description: json['description'] ?? '',
      thumbnailUrl: _extractThumbnail(json['thumbnails']),
      trackCount: json['trackCount'] ?? json['videoCount'] ?? 0,
      totalDuration: Duration(seconds: json['duration'] ?? 0),
      createdDate: _parseDate(json['published'] ?? json['uploadDate']),
      viewCount: json['viewCount'] ?? 0,
      isPublic: json['isPublic'] ?? true,
    );
  }

  static String _extractThumbnail(dynamic thumbnails) {
    if (thumbnails is List && thumbnails.isNotEmpty) {
      // Get highest quality thumbnail
      final thumb = thumbnails.last;
      return thumb['url'] ?? '';
    } else if (thumbnails is Map) {
      return thumbnails['url'] ?? '';
    }
    return '';
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    
    try {
      if (date is String) {
        // Handle various date formats
        if (date.contains('T')) {
          return DateTime.parse(date);
        } else if (date.length == 8) {
          // YYYYMMDD format
          return DateTime.parse('${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}');
        }
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
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

  // Format track count for display
  String get formattedTrackCount {
    return '$trackCount track${trackCount != 1 ? 's' : ''}';
  }

  // Format creation date for display
  String get formattedCreatedDate {
    final now = DateTime.now();
    final difference = now.difference(createdDate);

    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return '${years} year${years == 1 ? '' : 's'} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '${months} month${months == 1 ? '' : 's'} ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return 'Today';
    }
  }

  // Format total duration for display
  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
