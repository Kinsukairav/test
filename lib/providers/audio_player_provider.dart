import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/search_result.dart';
import '../services/audio_service.dart';
import '../services/youtube_service.dart';

// Current track provider
final currentTrackProvider = StateProvider<Track?>((ref) => null);

// Playing state provider
final isPlayingProvider = StateProvider<bool>((ref) => false);

// Loading state provider
final isLoadingProvider = StateProvider<bool>((ref) => false);

// Error provider
final errorProvider = StateProvider<String?>((ref) => null);

// Shuffle state provider
final isShuffleProvider = StateProvider<bool>((ref) => false);

// Repeat mode provider
final repeatModeProvider = StateProvider<RepeatMode>((ref) => RepeatMode.off);

// Current position provider
final currentPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

// Total duration provider
final totalDurationProvider = StateProvider<Duration>((ref) => Duration.zero);

// Volume provider
final volumeProvider = StateProvider<double>((ref) => 1.0);

// Playlist provider
final currentPlaylistProvider = StateProvider<List<Track>>((ref) => []);

// Current track index provider
final currentTrackIndexProvider = StateProvider<int>((ref) => -1);

// Queue provider
final queueProvider = StateProvider<List<Track>>((ref) => []);

// Saved playlists provider
final savedPlaylistsProvider = StateNotifierProvider<SavedPlaylistsNotifier, List<Playlist>>((ref) {
  return SavedPlaylistsNotifier();
});

// YouTube service provider
final youtubeServiceProvider = Provider<YouTubeService>((ref) {
  return YouTubeService();
});

// Audio player stream providers that sync with real audio player
final positionStreamProvider = StreamProvider<Duration>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.positionStream;
});

final durationStreamProvider = StreamProvider<Duration?>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.durationStream;
});

final playingStreamProvider = StreamProvider<bool>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.playingStream;
});

// Watch the real streams and update providers accordingly
final positionWatcherProvider = Provider<void>((ref) {
  ref.listen(positionStreamProvider, (previous, next) {
    next.whenData((position) {
      ref.read(currentPositionProvider.notifier).state = position;
    });
  });
});

final durationWatcherProvider = Provider<void>((ref) {
  ref.listen(durationStreamProvider, (previous, next) {
    next.whenData((duration) {
      if (duration != null) {
        ref.read(totalDurationProvider.notifier).state = duration;
      }
    });
  });
});

final playingWatcherProvider = Provider<void>((ref) {
  ref.listen(playingStreamProvider, (previous, next) {
    next.whenData((isPlaying) {
      ref.read(isPlayingProvider.notifier).state = isPlaying;
    });
  });
});

// Audio player controller
final audioPlayerControllerProvider = StateNotifierProvider<AudioPlayerController, AudioPlayerState>((ref) {
  return AudioPlayerController(ref);
});

// Audio player state
class AudioPlayerState {
  final Track? currentTrack;
  final bool isPlaying;
  final bool isLoading;
  final Duration currentPosition;
  final Duration totalDuration;
  final double volume;
  final String? error;
  final List<Track> playlist;
  final int currentIndex;

  const AudioPlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.isLoading = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.volume = 1.0,
    this.error,
    this.playlist = const [],
    this.currentIndex = -1,
  });

  AudioPlayerState copyWith({
    Track? currentTrack,
    bool? isPlaying,
    bool? isLoading,
    Duration? currentPosition,
    Duration? totalDuration,
    double? volume,
    String? error,
    List<Track>? playlist,
    int? currentIndex,
  }) {
    return AudioPlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      volume: volume ?? this.volume,
      error: error ?? this.error,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

// Audio player controller with streaming support
class AudioPlayerController extends StateNotifier<AudioPlayerState> {
  
  AudioPlayerController(this._ref) : super(const AudioPlayerState()) {
    _audioService = _ref.read(audioPlayerServiceProvider);
    _youtubeService = _ref.read(youtubeServiceProvider);
    _initializeAudioHandlers();
  }
  
  final Ref _ref;
  late final AudioPlayerService _audioService;
  late final YouTubeService _youtubeService;

  void _initializeAudioHandlers() {
    // Listen for audio completion to automatically play next track
    _audioService.audioPlayer.onPlayerStateChanged.listen((PlayerState playerState) {
      if (playerState == PlayerState.completed) {
        print('🎵 Track completed, checking for next track...');
        _handleTrackCompletion();
      }
    });
    
    // Listen for position updates
    _audioService.positionStream.listen((position) {
      state = state.copyWith(currentPosition: position);
      _ref.read(currentPositionProvider.notifier).state = position;
    });
    
    // Listen for duration updates
    _audioService.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(totalDuration: duration);
        _ref.read(totalDurationProvider.notifier).state = duration;
      }
    });
  }

  void _handleTrackCompletion() {
    final repeatMode = _ref.read(repeatModeProvider);
    final queue = _ref.read(queueProvider);
    final currentIndex = _ref.read(currentTrackIndexProvider);
    
    print('🏁 Track completion handler - Repeat: $repeatMode, Index: $currentIndex, Queue: ${queue.length}');
    
    switch (repeatMode) {
      case RepeatMode.one:
        // Repeat current track
        if (state.currentTrack != null) {
          print('🔁 Repeating current track: ${state.currentTrack!.title}');
          _playTrackFromQueue(state.currentTrack!);
        }
        break;
        
      case RepeatMode.all:
        // Play next track or loop to beginning
        if (queue.isNotEmpty) {
          if (currentIndex < queue.length - 1) {
            print('🎵 Auto-playing next track in queue');
            playNext();
          } else {
            // Loop back to first track
            print('🔁 Queue completed, looping back to first track');
            _ref.read(currentTrackIndexProvider.notifier).state = 0;
            _playTrackFromQueue(queue[0]);
          }
        }
        break;
        
      case RepeatMode.off:
        // Play next track if available
        if (queue.isNotEmpty && currentIndex < queue.length - 1) {
          print('🎵 Auto-playing next track in queue');
          playNext();
        } else {
          // End of queue, stop playback
          print('🛑 End of queue reached, stopping playback');
          state = state.copyWith(isPlaying: false);
          _ref.read(isPlayingProvider.notifier).state = false;
        }
        break;
    }
  }

  // Play from search result (streaming)
  Future<void> playFromSearchResult(SearchResult searchResult) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      print('🎵 Starting stream for: ${searchResult.title}');
      print('🔍 Video ID: ${searchResult.videoId}');
      
      // Validate video ID
      if (searchResult.videoId.isEmpty) {
        throw Exception('Invalid video ID for track: ${searchResult.title}');
      }
      
      // Get stream URL using yt-dlp with retry mechanism
      String? streamUrl;
      int retries = 3;
      
      for (int i = 0; i < retries; i++) {
        try {
          streamUrl = await _youtubeService.getStreamUrl(searchResult.videoId);
          if (streamUrl != null && streamUrl.isNotEmpty) {
            break; // Success
          }
        } catch (e) {
          print('Stream URL attempt ${i + 1} failed: $e');
          if (i == retries - 1) rethrow;
          await Future.delayed(Duration(seconds: 1)); // Wait before retry
        }
      }
      
      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('Failed to get stream URL after $retries attempts for: ${searchResult.title}');
      }
      
      // Validate URL format
      if (!streamUrl.startsWith('http')) {
        throw Exception('Invalid stream URL format: $streamUrl');
      }
      
      print('🔗 Stream URL obtained: ${streamUrl.substring(0, 100)}...');
      
      // Convert SearchResult to Track
      final track = Track(
        id: searchResult.videoId,
        title: searchResult.title,
        artist: searchResult.artist,
        album: searchResult.album ?? 'Unknown Album',
        albumArt: searchResult.thumbnailUrl.isNotEmpty ? searchResult.thumbnailUrl : null,
        duration: searchResult.duration,
        filePath: streamUrl, // Use stream URL as file path
        format: 'stream',
        addedDate: DateTime.now(),
      );
      
      // Play the stream using the real audio service
      print('🎧 Starting audio playback with URL: ${streamUrl.substring(0, 50)}...');
      await _audioService.playFromUrl(streamUrl);
      
      state = state.copyWith(
        currentTrack: track,
        isPlaying: true,
        isLoading: false,
        totalDuration: searchResult.duration,
        currentPosition: Duration.zero,
      );
      
      // Update legacy providers for backward compatibility
      _ref.read(currentTrackProvider.notifier).state = track;
      _ref.read(isPlayingProvider.notifier).state = true;
      _ref.read(isLoadingProvider.notifier).state = false;
      _ref.read(totalDurationProvider.notifier).state = searchResult.duration;
      
      print('✅ Successfully started streaming: ${track.title}');
      print('⏰ Duration: ${searchResult.duration.inMinutes}:${(searchResult.duration.inSeconds % 60).toString().padLeft(2, '0')}');
      
    } catch (e) {
      print('❌ Streaming error: $e');
      
      final errorMessage = e.toString().contains('Exception: ')
          ? e.toString().replaceFirst('Exception: ', '')
          : 'Failed to stream: ${e.toString()}';
      
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        error: errorMessage,
      );
      
      // Update legacy providers
      _ref.read(isLoadingProvider.notifier).state = false;
      _ref.read(isPlayingProvider.notifier).state = false;
      _ref.read(errorProvider.notifier).state = errorMessage;
    }
  }

  Future<void> playTrack(Track track) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      await _audioService.playTrack(track);
      
      state = state.copyWith(
        currentTrack: track,
        isPlaying: true,
        isLoading: false,
        totalDuration: track.duration,
        currentPosition: Duration.zero,
      );
      
      // Update legacy providers
      _ref.read(currentTrackProvider.notifier).state = track;
      _ref.read(isPlayingProvider.notifier).state = true;
      _ref.read(isLoadingProvider.notifier).state = false;
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        error: 'Failed to play track: ${e.toString()}',
      );
      
      _ref.read(isLoadingProvider.notifier).state = false;
      _ref.read(errorProvider.notifier).state = 'Failed to play track: ${e.toString()}';
    }
  }

  Future<void> play() async {
    try {
      await _audioService.play();
      state = state.copyWith(isPlaying: true);
      _ref.read(isPlayingProvider.notifier).state = true;
    } catch (e) {
      state = state.copyWith(error: 'Play failed: ${e.toString()}');
    }
  }

  Future<void> pause() async {
    try {
      await _audioService.pause();
      state = state.copyWith(isPlaying: false);
      _ref.read(isPlayingProvider.notifier).state = false;
    } catch (e) {
      state = state.copyWith(error: 'Pause failed: ${e.toString()}');
    }
  }

  Future<void> stop() async {
    try {
      await _audioService.stop();
      state = state.copyWith(
        isPlaying: false,
        currentPosition: Duration.zero,
      );
      _ref.read(isPlayingProvider.notifier).state = false;
      _ref.read(currentPositionProvider.notifier).state = Duration.zero;
    } catch (e) {
      state = state.copyWith(error: 'Stop failed: ${e.toString()}');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _audioService.seek(position);
      state = state.copyWith(currentPosition: position);
      _ref.read(currentPositionProvider.notifier).state = position;
    } catch (e) {
      state = state.copyWith(error: 'Seek failed: ${e.toString()}');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _audioService.setVolume(volume);
      state = state.copyWith(volume: volume);
      _ref.read(volumeProvider.notifier).state = volume;
    } catch (e) {
      state = state.copyWith(error: 'Volume control failed: ${e.toString()}');
    }
  }

  void toggleShuffle() {
    final currentShuffle = _ref.read(isShuffleProvider);
    _ref.read(isShuffleProvider.notifier).state = !currentShuffle;
  }

  void toggleRepeat() {
    final currentRepeat = _ref.read(repeatModeProvider);
    RepeatMode newMode;
    switch (currentRepeat) {
      case RepeatMode.off:
        newMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        newMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        newMode = RepeatMode.off;
        break;
    }
    _ref.read(repeatModeProvider.notifier).state = newMode;
  }

  Future<void> playPrevious() async {
    final queue = _ref.read(queueProvider);
    final currentIndex = _ref.read(currentTrackIndexProvider);
    
    print('🔀 Previous button pressed - Current index: $currentIndex, Queue length: ${queue.length}');
    
    if (queue.isNotEmpty && currentIndex > 0) {
      final previousIndex = currentIndex - 1;
      final previousTrack = queue[previousIndex];
      print('🎵 Playing previous track: ${previousTrack.title} (index: $previousIndex)');
      _ref.read(currentTrackIndexProvider.notifier).state = previousIndex;
      await _playTrackFromQueue(previousTrack);
    } else if (_ref.read(repeatModeProvider) == RepeatMode.all && queue.isNotEmpty) {
      // Loop back to last track
      final lastIndex = queue.length - 1;
      final lastTrack = queue[lastIndex];
      print('🔁 Looping back to last track: ${lastTrack.title} (index: $lastIndex)');
      _ref.read(currentTrackIndexProvider.notifier).state = lastIndex;
      await _playTrackFromQueue(lastTrack);
    } else {
      print('⚠️ Cannot play previous: Already at beginning of queue');
    }
  }

  Future<void> playNext() async {
    final queue = _ref.read(queueProvider);
    final currentIndex = _ref.read(currentTrackIndexProvider);
    
    print('🔀 Next button pressed - Current index: $currentIndex, Queue length: ${queue.length}');
    
    if (queue.isNotEmpty && currentIndex < queue.length - 1) {
      final nextIndex = currentIndex + 1;
      final nextTrack = queue[nextIndex];
      print('🎵 Playing next track: ${nextTrack.title} (index: $nextIndex)');
      _ref.read(currentTrackIndexProvider.notifier).state = nextIndex;
      await _playTrackFromQueue(nextTrack);
    } else if (_ref.read(repeatModeProvider) == RepeatMode.all && queue.isNotEmpty) {
      // Loop back to first track
      final firstTrack = queue[0];
      print('🔁 Looping back to first track: ${firstTrack.title}');
      _ref.read(currentTrackIndexProvider.notifier).state = 0;
      await _playTrackFromQueue(firstTrack);
    } else {
      print('⚠️ Cannot play next: No more tracks in queue');
    }
  }

  // Helper method to play track from queue with proper streaming
  Future<void> _playTrackFromQueue(Track track) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      print('🎵 Playing from queue: ${track.title}');
      print('🔍 Track ID: ${track.id}');
      print('📁 Original filePath: ${track.filePath}');
      
      // Validate track ID
      if (track.id.isEmpty) {
        throw Exception('Invalid track ID for: ${track.title}');
      }
      
      // Get stream URL using yt-dlp with retry mechanism
      String? streamUrl;
      int retries = 3;
      
      for (int i = 0; i < retries; i++) {
        try {
          print('🔄 Attempt ${i + 1}: Fetching stream URL for ${track.id}...');
          streamUrl = await _youtubeService.getStreamUrl(track.id);
          if (streamUrl != null && streamUrl.isNotEmpty && streamUrl.startsWith('http')) {
            print('✅ Valid stream URL obtained on attempt ${i + 1}');
            break;
          } else {
            print('⚠️ Invalid stream URL on attempt ${i + 1}: $streamUrl');
          }
        } catch (e) {
          print('❌ Queue stream URL attempt ${i + 1} failed: $e');
          if (i == retries - 1) rethrow;
          await Future.delayed(Duration(seconds: 2)); // Longer delay for retries
        }
      }
      
      if (streamUrl == null || streamUrl.isEmpty || !streamUrl.startsWith('http')) {
        throw Exception('Failed to get valid stream URL after $retries attempts for: ${track.title}');
      }

      print('🔗 Queue stream URL obtained: ${streamUrl.substring(0, 80)}...');
      
      // Create updated track with stream URL
      final updatedTrack = Track(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        albumArt: track.albumArt,
        duration: track.duration,
        filePath: streamUrl, // Set the fresh stream URL
        format: 'stream',
        addedDate: track.addedDate,
        isFavorite: track.isFavorite,
        sampleRate: track.sampleRate,
        bitDepth: track.bitDepth,
      );
      
      // Play the stream using the real audio service
      print('🎧 Starting audio playback...');
      await _audioService.playFromUrl(streamUrl);
      
      state = state.copyWith(
        currentTrack: updatedTrack,
        isPlaying: true,
        isLoading: false,
        totalDuration: track.duration,
        currentPosition: Duration.zero,
      );
      
      // Update legacy providers for backward compatibility
      _ref.read(currentTrackProvider.notifier).state = updatedTrack;
      _ref.read(isPlayingProvider.notifier).state = true;
      _ref.read(isLoadingProvider.notifier).state = false;
      _ref.read(totalDurationProvider.notifier).state = track.duration;
      
      print('✅ Successfully started streaming from queue: ${track.title}');
      
    } catch (e) {
      print('❌ Queue streaming error: $e');
      
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to play track from queue: ${e.toString()}',
      );
      
      _ref.read(isLoadingProvider.notifier).state = false;
      _ref.read(errorProvider.notifier).state = 'Failed to play track from queue: ${e.toString()}';
    }
  }

  Future<void> addToQueue(List<Track> tracks) async {
    final currentQueue = _ref.read(queueProvider);
    final updatedQueue = [...currentQueue, ...tracks];
    _ref.read(queueProvider.notifier).state = updatedQueue;
  }

  Future<void> clearQueue() async {
    _ref.read(queueProvider.notifier).state = [];
    _ref.read(currentTrackIndexProvider.notifier).state = -1;
  }

  Future<void> playFromQueue(int index) async {
    final queue = _ref.read(queueProvider);
    if (index >= 0 && index < queue.length) {
      _ref.read(currentTrackIndexProvider.notifier).state = index;
      await _playTrackFromQueue(queue[index]); // Use streaming method instead of playTrack
    }
  }

  Future<void> playPlaylist(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    
    // Clear and set new queue
    _ref.read(queueProvider.notifier).state = tracks;
    _ref.read(currentTrackIndexProvider.notifier).state = startIndex;
    
    // Play the selected track using streaming method
    await _playTrackFromQueue(tracks[startIndex]);
  }

  // Play track by index from queue (with fresh URL fetching)
  Future<void> playTrackFromQueueByIndex(int index) async {
    final queue = _ref.read(queueProvider);
    
    if (index < 0 || index >= queue.length) {
      print('❌ Invalid queue index: $index');
      return;
    }
    
    // Update current index
    _ref.read(currentTrackIndexProvider.notifier).state = index;
    
    // Play the track with fresh stream URL
    await _playTrackFromQueue(queue[index]);
  }

  void clearError() {
    state = state.copyWith(error: null);
    _ref.read(errorProvider.notifier).state = null;
  }

  // Enhanced method to sync and play track with fresh data
  Future<void> syncAndPlayTrack(Track track) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      print('🔄 Syncing track: ${track.title}');
      print('🆔 Track ID: ${track.id}');
      
      // Validate track ID
      if (track.id.isEmpty) {
        throw Exception('Invalid track ID for: ${track.title}');
      }
      
      // Re-fetch video information to get fresh stream URL
      String? streamUrl;
      int retries = 3;
      
      for (int i = 0; i < retries; i++) {
        try {
          print('🔍 Attempt ${i + 1}: Fetching fresh stream URL...');
          streamUrl = await _youtubeService.getStreamUrl(track.id);
          
          if (streamUrl != null && streamUrl.isNotEmpty && streamUrl.startsWith('http')) {
            print('✅ Fresh stream URL obtained on attempt ${i + 1}');
            break;
          } else {
            print('⚠️ Invalid stream URL on attempt ${i + 1}: $streamUrl');
          }
        } catch (e) {
          print('❌ Stream URL attempt ${i + 1} failed: $e');
          if (i == retries - 1) rethrow;
          await Future.delayed(Duration(seconds: 2)); // Longer delay for retries
        }
      }
      
      if (streamUrl == null || streamUrl.isEmpty || !streamUrl.startsWith('http')) {
        throw Exception('Failed to obtain valid stream URL after $retries attempts for: ${track.title}');
      }
      
      print('🎵 Starting playback with fresh URL: ${streamUrl.substring(0, 80)}...');
      
      // Update track with fresh stream URL
      final updatedTrack = Track(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        albumArt: track.albumArt,
        duration: track.duration,
        filePath: streamUrl, // Set fresh stream URL
        format: 'stream',
        addedDate: track.addedDate,
        isFavorite: track.isFavorite,
        sampleRate: track.sampleRate,
        bitDepth: track.bitDepth,
      );
      
      // Play using the audio service
      await _audioService.playFromUrl(streamUrl);
      
      // Update state
      state = state.copyWith(
        currentTrack: updatedTrack,
        isPlaying: true,
        isLoading: false,
        totalDuration: track.duration,
        currentPosition: Duration.zero,
        error: null,
      );
      
      // Update legacy providers
      _ref.read(currentTrackProvider.notifier).state = updatedTrack;
      _ref.read(isPlayingProvider.notifier).state = true;
      _ref.read(isLoadingProvider.notifier).state = false;
      _ref.read(totalDurationProvider.notifier).state = track.duration;
      
      print('🎉 Successfully synced and started playing: ${track.title}');
      
    } catch (e) {
      print('💥 Sync and play error: $e');
      
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to sync and play track: ${e.toString()}',
      );
      
      _ref.read(isLoadingProvider.notifier).state = false;
      _ref.read(errorProvider.notifier).state = 'Failed to sync and play track: ${e.toString()}';
    }
  }
}

// Saved Playlists Notifier
class SavedPlaylistsNotifier extends StateNotifier<List<Playlist>> {
  SavedPlaylistsNotifier() : super([]);

  void addPlaylist(Playlist playlist) {
    state = [...state, playlist];
  }

  void removePlaylist(String playlistId) {
    state = state.where((p) => p.id != playlistId).toList();
  }

  void updatePlaylist(Playlist updatedPlaylist) {
    state = state.map((p) => p.id == updatedPlaylist.id ? updatedPlaylist : p).toList();
  }

  Playlist? getPlaylist(String id) {
    try {
      return state.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
