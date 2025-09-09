import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../models/track.dart';

class AudioPlayerService {
  AudioPlayerService() {
    _audioPlayer = AudioPlayer();
    _setupStreams();
  }

  late final AudioPlayer _audioPlayer;
  
  // Getter to access the audio player for advanced features
  AudioPlayer get audioPlayer => _audioPlayer;
  
  // Stream controllers for UI synchronization
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  
  Timer? _positionTimer;
  Duration _currentPosition = Duration.zero;
  Duration? _totalDuration;
  bool _isPlaying = false;
  
  void _setupStreams() {
    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      final isPlaying = state == PlayerState.playing;
      if (_isPlaying != isPlaying) {
        _isPlaying = isPlaying;
        _playingController.add(_isPlaying);
        print('Player state changed: ${isPlaying ? "Playing" : "Paused/Stopped"}');
        
        if (isPlaying) {
          _startPositionTimer();
        } else {
          _stopPositionTimer();
        }
      }
    });
    
    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      _totalDuration = duration;
      _durationController.add(duration);
      print('Track duration: ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}');
    });
    
    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((Duration position) {
      _currentPosition = position;
      _positionController.add(position);
    });
  }
  
  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isPlaying) {
        // Position is already handled by onPositionChanged
        // This is just for backup logging
        if (_currentPosition.inSeconds % 10 == 0) {
          print('Current position: ${_currentPosition.inMinutes}:${(_currentPosition.inSeconds % 60).toString().padLeft(2, '0')}');
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
  
  Future<void> playTrack(Track track) async {
    try {
      print('Loading track from file: ${track.filePath}');
      
      if (track.filePath.startsWith('http')) {
        await _audioPlayer.play(UrlSource(track.filePath));
      } else {
        await _audioPlayer.play(DeviceFileSource(track.filePath));
      }
      
      print('Successfully started playing: ${track.title}');
    } catch (e) {
      print('Error playing track: $e');
      throw Exception('Failed to play track: $e');
    }
  }

  Future<void> playFromUrl(String url) async {
    try {
      print('Loading audio from URL: ${url.substring(0, 100)}...');
      
      // Stop any current playback
      await _audioPlayer.stop();
      
      // Set the URL and start playing
      await _audioPlayer.play(UrlSource(url));
      print('Audio source set and playback started successfully');
      
    } catch (e) {
      print('Error playing from URL: $e');
      throw Exception('Failed to stream audio: $e');
    }
  }

  Future<void> play() async {
    try {
      await _audioPlayer.resume();
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
      print('Seeked to: ${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}');
    } catch (e) {
      print('Error seeking: $e');
      throw Exception('Failed to seek: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      // Clamp volume between 0.0 and 1.0
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(clampedVolume);
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
  double get currentVolume => 1.0; // audioplayers doesn't provide current volume

  void dispose() {
    print('Disposing audio player');
    _stopPositionTimer();
    _positionController.close();
    _durationController.close();
    _playingController.close();
    _audioPlayer.dispose();
  }
}

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(service.dispose);
  return service;
});
