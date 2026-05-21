class Track {
  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArt,
    required this.duration,
    required this.filePath,
    required this.format,
    this.sampleRate,
    this.bitDepth,
    this.isFavorite = false,
    required this.addedDate,
  });

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      album: map['album'] ?? '',
      albumArt: map['albumArt'],
      duration: Duration(milliseconds: map['duration'] ?? 0),
      filePath: map['filePath'] ?? '',
      format: map['format'] ?? '',
      sampleRate: map['sampleRate'],
      bitDepth: map['bitDepth'],
      isFavorite: map['isFavorite'] ?? false,
      addedDate: DateTime.fromMillisecondsSinceEpoch(map['addedDate'] ?? 0),
    );
  }
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumArt;
  final Duration duration;
  final String filePath;
  final String format;
  final int? sampleRate;
  final int? bitDepth;
  final bool isFavorite;
  final DateTime addedDate;

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumArt,
    Duration? duration,
    String? filePath,
    String? format,
    int? sampleRate,
    int? bitDepth,
    bool? isFavorite,
    DateTime? addedDate,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArt: albumArt ?? this.albumArt,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      isFavorite: isFavorite ?? this.isFavorite,
      addedDate: addedDate ?? this.addedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArt': albumArt,
      'duration': duration.inMilliseconds,
      'filePath': filePath,
      'format': format,
      'sampleRate': sampleRate,
      'bitDepth': bitDepth,
      'isFavorite': isFavorite,
      'addedDate': addedDate.millisecondsSinceEpoch,
    };
  }
}
