import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/youtube_playlist.dart';
import '../models/search_result.dart';
import '../services/youtube_service.dart';
import '../providers/audio_player_provider.dart';
import '../widgets/track_tile.dart';

class PlaylistDetailsScreen extends ConsumerStatefulWidget {
  final YouTubePlaylist playlist;

  const PlaylistDetailsScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends ConsumerState<PlaylistDetailsScreen> {
  final YouTubeService _youtubeService = YouTubeService();
  List<SearchResult> _tracks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  static const int _tracksPerPage = 50;
  bool _hasMoreTracks = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPlaylistTracks();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore && _hasMoreTracks) {
      _loadMoreTracks();
    }
  }

  Future<void> _loadPlaylistTracks() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _tracks.clear();
    });

    try {
      final tracks = await _youtubeService.getPlaylistTracks(
        widget.playlist.id, 
        maxResults: _tracksPerPage,
      );
      
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
          _hasMoreTracks = tracks.length == _tracksPerPage;
        });
      }
    } catch (e) {
      print('Error loading playlist tracks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading playlist: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreTracks() async {
    if (_isLoadingMore || !_hasMoreTracks) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newTracks = await _youtubeService.getPlaylistTracks(
        widget.playlist.id,
        maxResults: _tracksPerPage,
        offset: _currentPage * _tracksPerPage,
      );

      if (mounted) {
        setState(() {
          _tracks.addAll(newTracks);
          _currentPage++;
          _isLoadingMore = false;
          _hasMoreTracks = newTracks.length == _tracksPerPage;
        });
      }
    } catch (e) {
      print('Error loading more tracks: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _playAllTracks() async {
    if (_tracks.isEmpty) return;

    try {
      final audioController = ref.read(audioPlayerControllerProvider.notifier);
      
      // Convert SearchResult to Track
      final trackList = _tracks.map((result) => result.toTrack()).toList();
      
      // Play playlist (sets queue and starts playing)
      await audioController.playPlaylist(trackList);
      
      if (mounted) {
        Navigator.of(context).pop(); // Go back to previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing ${_tracks.length} tracks from ${widget.playlist.title}'),
            action: SnackBarAction(
              label: 'Go to Player',
              onPressed: () {
                DefaultTabController.of(context).animateTo(0);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play playlist: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _playTrack(SearchResult track, int index) async {
    try {
      final audioController = ref.read(audioPlayerControllerProvider.notifier);
      
      // Convert all tracks and start from selected index
      final trackList = _tracks.map((result) => result.toTrack()).toList();
      await audioController.playPlaylist(trackList, startIndex: index);
      
      if (mounted) {
        Navigator.of(context).pop(); // Go back to previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now playing: ${track.title}'),
            action: SnackBarAction(
              label: 'Go to Player',
              onPressed: () {
                DefaultTabController.of(context).animateTo(0);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing track: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.playlist.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          if (_tracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.shuffle),
              onPressed: () {
                // TODO: Implement shuffle play
                _playAllTracks();
              },
              tooltip: 'Shuffle Play',
            ),
        ],
      ),
      body: Column(
        children: [
          // Playlist Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Playlist Thumbnail
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: widget.playlist.thumbnailUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.playlist.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.playlist_play,
                                size: 50,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.playlist_play,
                          size: 50,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                ),
                
                const SizedBox(width: 16),
                
                // Playlist Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playlist.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'By ${widget.playlist.author}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tracks.length} tracks loaded',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Play All Button
          if (_tracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _playAllTracks,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Tracks List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tracks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tracks found',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _tracks.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _tracks.length) {
                            // Loading more indicator
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          
                          final track = _tracks[index];
                          return TrackTile(
                            track: track,
                            onTap: () => _playTrack(track, index),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'play_next':
                                    // TODO: Add to queue next
                                    break;
                                  case 'add_queue':
                                    // TODO: Add to end of queue
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'play_next',
                                  child: Row(
                                    children: [
                                      Icon(Icons.queue_play_next),
                                      SizedBox(width: 8),
                                      Text('Play Next'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'add_queue',
                                  child: Row(
                                    children: [
                                      Icon(Icons.queue),
                                      SizedBox(width: 8),
                                      Text('Add to Queue'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
