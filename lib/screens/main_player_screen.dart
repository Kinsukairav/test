import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/player_controls.dart';
import '../widgets/track_metadata_display.dart';
import '../widgets/playlist_panel.dart';
import '../widgets/top_bar.dart';
import '../widgets/seek_bar.dart';
import '../widgets/left_side_panel.dart';
import '../providers/audio_player_provider.dart';
import '../providers/playlist_provider.dart';
import '../models/playlist.dart';
import '../screens/queue_screen.dart';

class MainPlayerScreen extends ConsumerStatefulWidget {
  const MainPlayerScreen({super.key});

  @override
  ConsumerState<MainPlayerScreen> createState() => _MainPlayerScreenState();
}

class _MainPlayerScreenState extends ConsumerState<MainPlayerScreen> {
  bool _isLeftPanelExpanded = true;
  bool _isPlaylistVisible = false;

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(currentTrackProvider);
    final playlist = ref.watch(playlistProvider);
    final audioPlayerState = ref.watch(audioPlayerControllerProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final error = ref.watch(errorProvider);
    
    // Initialize stream watchers to sync real audio player with providers
    ref.watch(positionWatcherProvider);
    ref.watch(durationWatcherProvider);
    ref.watch(playingWatcherProvider);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Column(
        children: [
          // Top Bar with search, download, volume, etc.
          const TopBar(),
          
          // Error Banner (if any)
          if (error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red.shade700),
                    onPressed: () {
                      ref.read(audioPlayerControllerProvider.notifier).clearError();
                    },
                  ),
                ],
              ),
            ),
          
          // Loading Banner (if loading)
          if (isLoading || audioPlayerState.isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      audioPlayerState.currentTrack != null
                          ? 'Loading: ${audioPlayerState.currentTrack!.title}'
                          : 'Loading...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Main Content Area
          Expanded(
            child: Row(
              children: [
                // Left Side Panel
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isLeftPanelExpanded ? 250 : 60,
                  child: LeftSidePanel(
                    isExpanded: _isLeftPanelExpanded,
                    onToggleExpanded: () {
                      setState(() {
                        _isLeftPanelExpanded = !_isLeftPanelExpanded;
                      });
                    },
                  ),
                ),
                
                // Main Player Area
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Track Metadata Display
                        Expanded(
                          flex: 3,
                          child: TrackMetadataDisplay(track: currentTrack),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Seek Bar
                        const SeekBar(),
                        
                        const SizedBox(height: 20),
                        
                        // Player Controls
                        const PlayerControls(),
                        
                        const SizedBox(height: 20),
                        
                        // Additional Controls Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Shuffle Button
                            IconButton(
                              onPressed: () => ref.read(audioPlayerControllerProvider.notifier).toggleShuffle(),
                              icon: Icon(
                                Icons.shuffle,
                                color: ref.watch(isShuffleProvider) 
                                  ? Theme.of(context).colorScheme.primary 
                                  : Theme.of(context).colorScheme.onSurface,
                              ),
                              tooltip: 'Shuffle',
                            ),
                            
                            // Repeat Button
                            IconButton(
                              onPressed: () => ref.read(audioPlayerControllerProvider.notifier).toggleRepeat(),
                              icon: Icon(
                                ref.watch(repeatModeProvider) == RepeatMode.one
                                  ? Icons.repeat_one
                                  : Icons.repeat,
                                color: ref.watch(repeatModeProvider) != RepeatMode.off
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                              ),
                              tooltip: 'Repeat',
                            ),
                            
                            // Queue Button
                            IconButton(
                              onPressed: () => _navigateToQueue(context),
                              icon: Icon(
                                Icons.queue_music,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              tooltip: 'View Queue',
                            ),
                            
                            // Lyrics Button
                            IconButton(
                              onPressed: _showLyricsDialog,
                              icon: Icon(
                                Icons.music_note,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              tooltip: 'Lyrics',
                            ),
                            
                            // Equalizer Button
                            IconButton(
                              onPressed: _showEqualizerDialog,
                              icon: Icon(
                                Icons.equalizer,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              tooltip: 'Equalizer',
                            ),
                            
                            // Favorite Button
                            IconButton(
                              onPressed: _toggleFavorite,
                              icon: Icon(
                                currentTrack?.isFavorite == true 
                                  ? Icons.favorite 
                                  : Icons.favorite_border,
                                color: currentTrack?.isFavorite == true
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.onSurface,
                              ),
                              tooltip: 'Favorite',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Right Playlist Panel
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isPlaylistVisible ? 300 : 0,
                  child: _isPlaylistVisible
                    ? PlaylistPanel(
                        playlist: playlist,
                        onClose: () {
                          setState(() {
                            _isPlaylistVisible = false;
                          });
                        },
                      )
                    : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLyricsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lyrics'),
        content: Container(
          width: 400,
          height: 500,
          child: const Center(
            child: Text('Lyrics will be displayed here'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEqualizerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Equalizer'),
        content: Container(
          width: 400,
          height: 300,
          child: const Center(
            child: Text('Equalizer controls will be here'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite() {
    final currentTrack = ref.read(currentTrackProvider);
    if (currentTrack != null) {
      ref.read(playlistProvider.notifier).toggleFavorite(currentTrack.id);
    }
  }

  void _navigateToQueue(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QueueScreen(),
      ),
    );
  }
}
