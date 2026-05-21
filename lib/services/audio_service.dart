import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'dart:async';
import '../models/track.dart';

class AudioPlayerService {
  AudioPlayerService() {
    _audioPlayer = Player();
    _setupStreams();
  }

  late final Player _audioPlayer;

  // Getter to access the audio player for advanced features
  Player get audioPlayer => _audioPlayer;

  // Stream controllers for UI synchronization
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _completedController =
      StreamController<bool>.broadcast();

  Timer? _positionTimer;
  Duration _currentPosition = Duration.zero;
  Duration? _totalDuration;
  bool _isPlaying = false;
  double _currentVolume = 1.0;

  void _setupStreams() {
    // Listen to player state changes
    _audioPlayer.stream.playing.listen((bool isPlaying) {
      if (_isPlaying != isPlaying) {
        _isPlaying = isPlaying;
        _playingController.add(_isPlaying);
        print(
            'Player state changed: ${isPlaying ? "Playing" : "Paused/Stopped"}');

        if (isPlaying) {
          _startPositionTimer();
        } else {
          _stopPositionTimer();
        }
      }
    });

    // Listen to duration changes
    _audioPlayer.stream.duration.listen((Duration duration) {
      _totalDuration = duration;
      _durationController.add(duration);
      print(
          'Track duration: ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}');
    });

    // Listen to position changes
    _audioPlayer.stream.position.listen((Duration position) {
      _currentPosition = position;
      _positionController.add(position);
    });

    // Listen for playback completion
    _audioPlayer.stream.completed.listen((bool completed) {
      _completedController.add(completed);
      if (completed) {
        print('Playback completed');
      }
    });
  }

  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying) {
        // Position is already handled by positionStream
        // This is just for backup logging
        if (_currentPosition.inSeconds % 10 == 0) {
          print(
              'Current position: ${_currentPosition.inMinutes}:${(_currentPosition.inSeconds % 60).toString().padLeft(2, '0')}');
        }
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  // Streams for UI to listen to
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get completedStream => _completedController.stream;

  String _resolveMediaSource(String pathOrUrl) {
    final uri = Uri.tryParse(pathOrUrl);
    if (uri != null && uri.hasScheme) {
      return pathOrUrl;
    }

    return Uri.file(pathOrUrl).toString();
  }

  Future<void> playTrack(Track track) async {
    try {
      print('Loading track from file: ${track.filePath}');
      final source = _resolveMediaSource(track.filePath);
      await _audioPlayer.open(Media(source), play: true);
      print('Successfully started playing: ${track.title}');
    } catch (e) {
      print('Error playing track: $e');
      throw Exception('Failed to play track: $e');
    }
  }

  Future<void> playFromUrl(String url) async {
    try {
      print(
          'Loading audio from URL: ${url.substring(0, url.length < 100 ? url.length : 100)}...');

      // Stop any current playback
      await _audioPlayer.stop();

      // Set the URL and start playing
      final source = _resolveMediaSource(url);
      await _audioPlayer.open(Media(source), play: true);
      print('Audio source set and playback started successfully');
    } catch (e) {
      print('Error playing from URL: $e');
      throw Exception('Failed to stream audio: $e');
    }
  }

  Future<void> play() async {
    try {
      await _audioPlayer.play();
      print('Resumed playback');
    } catch (e) {
      print('Error resuming playback: $e');
      throw Exception('Failed to resume playback: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      print('Paused playback');
    } catch (e) {
      print('Error pausing playback: $e');
      throw Exception('Failed to pause playback: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _currentPosition = Duration.zero;
      _positionController.add(_currentPosition);
      print('Stopped playback');
    } catch (e) {
      print('Error stopping playback: $e');
      throw Exception('Failed to stop playback: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      _currentPosition = position;
      _positionController.add(_currentPosition);
      print(
          'Seeked to: ${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}');
    } catch (e) {
      print('Error seeking: $e');
      throw Exception('Failed to seek: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      // Clamp volume between 0.0 and 1.0
      final clampedVolume = volume.clamp(0.0, 1.0);
      _currentVolume = clampedVolume;
      await _audioPlayer.setVolume(clampedVolume * 100.0);
      print('Volume set to: ${(clampedVolume * 100).round()}%');
    } catch (e) {
      print('Error setting volume: $e');
      throw Exception('Failed to set volume: $e');
    }
  }

  // Get current state information
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration? get totalDuration => _totalDuration;
  double get currentVolume => _currentVolume;

  void dispose() {
    print('Disposing audio player');
    _stopPositionTimer();
    _positionController.close();
    _durationController.close();
    _playingController.close();
    _completedController.close();
    _audioPlayer.dispose();
  }
}

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(service.dispose);
  return service;
});
