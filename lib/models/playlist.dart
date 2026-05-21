import 'track.dart';

class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required this.tracks,
    required this.createdDate,
    required this.lastModified,
  });

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      tracks: List<Track>.from(
        map['tracks']?.map((track) => Track.fromMap(track)) ?? [],
      ),
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate'] ?? 0),
      lastModified:
          DateTime.fromMillisecondsSinceEpoch(map['lastModified'] ?? 0),
    );
  }
  final String id;
  final String name;
  final List<Track> tracks;
  final DateTime createdDate;
  final DateTime lastModified;

  Playlist copyWith({
    String? id,
    String? name,
    List<Track>? tracks,
    DateTime? createdDate,
    DateTime? lastModified,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
      createdDate: createdDate ?? this.createdDate,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tracks': tracks.map((track) => track.toMap()).toList(),
      'createdDate': createdDate.millisecondsSinceEpoch,
      'lastModified': lastModified.millisecondsSinceEpoch,
    };
  }
}

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.artist,
    required this.status,
    this.progress = 0.0,
    this.filePath,
    this.error,
    required this.createdDate,
  });
  final String id;
  final String url;
  final String title;
  final String artist;
  final DownloadStatus status;
  final double progress;
  final String? filePath;
  final String? error;
  final DateTime createdDate;

  DownloadTask copyWith({
    String? id,
    String? url,
    String? title,
    String? artist,
    DownloadStatus? status,
    double? progress,
    String? filePath,
    String? error,
    DateTime? createdDate,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
}

// RepeatMode is defined in audio_player_provider.dart
