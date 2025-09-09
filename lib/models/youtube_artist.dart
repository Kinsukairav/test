class YouTubeArtist {
  final String id;
  final String name;
  final String description;
  final String avatarUrl;
  final String bannerUrl;
  final int subscriberCount;
  final int videoCount;
  final int viewCount;
  final DateTime joinedDate;
  final bool isVerified;
  final String country;

  YouTubeArtist({
    required this.id,
    required this.name,
    required this.description,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.subscriberCount,
    required this.videoCount,
    required this.viewCount,
    required this.joinedDate,
    this.isVerified = false,
    this.country = '',
  });

  // Create from YouTube API data
  factory YouTubeArtist.fromJson(Map<String, dynamic> json) {
    return YouTubeArtist(
      id: json['channelId'] ?? json['id'] ?? '',
      name: json['name'] ?? json['author'] ?? json['uploader'] ?? 'Unknown Artist',
      description: json['description'] ?? '',
      avatarUrl: _extractAvatar(json['avatar'] ?? json['thumbnails']),
      bannerUrl: _extractBanner(json['banner'] ?? json['bannerUrl']),
      subscriberCount: json['subscriberCount'] ?? json['subscribers'] ?? 0,
      videoCount: json['videoCount'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
      joinedDate: _parseDate(json['joinedDate']),
      isVerified: json['isVerified'] ?? json['verified'] ?? false,
      country: json['country'] ?? '',
    );
  }

  static String _extractAvatar(dynamic avatar) {
    if (avatar is List && avatar.isNotEmpty) {
      return avatar.last['url'] ?? '';
    } else if (avatar is Map) {
      return avatar['url'] ?? '';
    } else if (avatar is String) {
      return avatar;
    }
    return '';
  }

  static String _extractBanner(dynamic banner) {
    if (banner is List && banner.isNotEmpty) {
      return banner.last['url'] ?? '';
    } else if (banner is Map) {
      return banner['url'] ?? '';
    } else if (banner is String) {
      return banner;
    }
    return '';
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now().subtract(Duration(days: 365));
    
    try {
      if (date is String) {
        return DateTime.parse(date);
      }
      return DateTime.now().subtract(Duration(days: 365));
    } catch (e) {
      return DateTime.now().subtract(Duration(days: 365));
    }
  }

  // Format subscriber count for display
  String get formattedSubscriberCount {
    if (subscriberCount >= 1000000) {
      return '${(subscriberCount / 1000000).toStringAsFixed(1)}M subscribers';
    } else if (subscriberCount >= 1000) {
      return '${(subscriberCount / 1000).toStringAsFixed(1)}K subscribers';
    } else {
      return '$subscriberCount subscribers';
    }
  }

  // Format video count for display
  String get formattedVideoCount {
    if (videoCount >= 1000) {
      return '${(videoCount / 1000).toStringAsFixed(1)}K videos';
    } else {
      return '$videoCount videos';
    }
  }

  // Format view count for display
  String get formattedViewCount {
    if (viewCount >= 1000000000) {
      return '${(viewCount / 1000000000).toStringAsFixed(1)}B views';
    } else if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K views';
    } else {
      return '$viewCount views';
    }
  }

  // Format joined date for display
  String get formattedJoinedDate {
    final now = DateTime.now();
    final difference = now.difference(joinedDate);

    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return 'Joined ${years} year${years == 1 ? '' : 's'} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return 'Joined ${months} month${months == 1 ? '' : 's'} ago';
    } else {
      return 'Joined recently';
    }
  }
}
