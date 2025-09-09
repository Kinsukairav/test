import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../models/search_result.dart';
import '../models/playlist.dart';
import '../services/youtube_service.dart';
import '../providers/download_manager_provider.dart';
import '../providers/audio_player_provider.dart';
import 'download_manager_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final YouTubeService _youtubeService = YouTubeService();
  bool _isLoading = false;
  bool _isImportingPlaylist = false;
  List<SearchResult> _searchResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Music'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for songs, artists, albums...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults.clear();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                    onSubmitted: (query) {
                      if (query.trim().isNotEmpty) {
                        _performSearch(query.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _searchController.text.trim().isNotEmpty && !_isLoading
                      ? () => _performSearch(_searchController.text.trim())
                      : null,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isLoading ? 'Searching...' : 'Search'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Link Paste Button
                ElevatedButton.icon(
                  onPressed: _isImportingPlaylist ? null : _showPlaylistLinkDialog,
                  icon: _isImportingPlaylist
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(_isImportingPlaylist ? 'Loading...' : 'Paste Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Results Section
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching for music...'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.trim().isNotEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for Music',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find your favorite songs, artists, and albums',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return SearchResultTile(
          result: result,
          onTap: () => _playTrack(result),
          onDownload: () => _downloadTrack(result),
        );
      },
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _searchResults.clear();
    });

    try {
      print('Searching for: $query');
      
      // Use the real YouTube service
      final results = await _youtubeService.searchVideos(query, maxResults: 15);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
        
        // Show success message if results found
        if (results.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${results.length} results for "$query"'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Search error: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Show detailed error message
        final errorMessage = e.toString().contains('Exception: ')
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Search failed: ${e.toString()}';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Failed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(errorMessage),
                const SizedBox(height: 8),
                const Text(
                  'Please check your internet connection or try again later.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _performSearch(query),
            ),
          ),
        );
      }
    }
  }

  void _playTrack(SearchResult result) async {
    try {
      final audioController = ref.read(audioPlayerControllerProvider.notifier);
      
      // Show loading notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Loading: ${result.title}'),
            ],
          ),
        ),
      );
      
      // Start streaming the track
      await audioController.playFromSearchResult(result);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now playing: ${result.title} by ${result.artist}'),
            action: SnackBarAction(
              label: 'Go to Player',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
      
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _playTrack(result),
            ),
          ),
        );
      }
    }
  }

  void _downloadTrack(SearchResult result) {
    final downloadManager = ref.read(downloadManagerProvider.notifier);
    
    // Check if already downloaded or downloading
    if (downloadManager.isVideoDownloaded(result.videoId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This track is already downloaded or downloading'),
        ),
      );
      return;
    }
    
    // Add to download queue
    downloadManager.addDownload(result);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${result.title}" to download queue'),
        action: SnackBarAction(
          label: 'View Downloads',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const DownloadManagerScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showPlaylistLinkDialog() async {
    final TextEditingController linkController = TextEditingController();
    
    // Try to get text from clipboard
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && 
          (clipboardData!.text!.contains('youtube.com/playlist') || 
           clipboardData.text!.contains('youtu.be/playlist') ||
           clipboardData.text!.startsWith('PL'))) {
        linkController.text = clipboardData.text!;
      }
    } catch (e) {
      // Clipboard access might fail, ignore
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.playlist_play),
              SizedBox(width: 8),
              Text('Import YouTube Playlist'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste a YouTube playlist URL or ID to import and view its contents:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: linkController,
                decoration: const InputDecoration(
                  hintText: 'https://youtube.com/playlist?list=... or PLrAl...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                  labelText: 'Playlist URL or ID',
                ),
                autofocus: true,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supported formats:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Full URL: https://youtube.com/playlist?list=PLrA...\n'
                      '• Short URL: https://youtu.be/playlist?list=PLrA...\n'
                      '• Playlist ID: PLrA...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _importPlaylistFromLink(linkController.text.trim());
              },
              icon: const Icon(Icons.download),
              label: const Text('Import'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importPlaylistFromLink(String input) async {
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a playlist URL or ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isImportingPlaylist = true);

    try {
      // Extract playlist ID from URL or use as-is if it's already an ID
      final playlistId = _youtubeService.extractPlaylistId(input);
      if (playlistId == null) {
        throw Exception('Invalid playlist URL or ID format');
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Fetching playlist contents...'),
              const SizedBox(height: 8),
              Text(
                'Playlist ID: $playlistId',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // Get playlist contents
      final tracks = await _youtubeService.getPlaylistContents(playlistId);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (tracks.isEmpty) {
        throw Exception('No tracks found in playlist or playlist is private');
      }

      // Show playlist contents in a bottom sheet
      if (mounted) {
        _showPlaylistContents(tracks, playlistId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${tracks.length} tracks in playlist!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error importing playlist: $e');
      
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import playlist: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _importPlaylistFromLink(input),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingPlaylist = false);
      }
    }
  }

  void _showPlaylistContents(List<SearchResult> tracks, String playlistId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Playlist header
                Row(
                  children: [
                    Icon(
                      Icons.playlist_play,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YouTube Playlist',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${tracks.length} tracks • ID: $playlistId',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _playAllTracks(tracks),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, size: 18),
                          SizedBox(width: 4),
                          Text('Play All'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _savePlaylist(tracks, playlistId),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save, size: 18),
                          SizedBox(width: 4),
                          Text('Save'),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                
                // Track list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return SearchResultTile(
                        result: track,
                        onTap: () => _playTrack(track),
                        onDownload: () => _downloadTrack(track),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _playAllTracks(List<SearchResult> tracks) async {
    if (tracks.isEmpty) return;
    
    try {
      final audioController = ref.read(audioPlayerControllerProvider.notifier);
      
      // Convert SearchResult to Track
      final trackList = tracks.map((result) => result.toTrack()).toList();
      
      // Play playlist (sets queue and starts playing)
      await audioController.playPlaylist(trackList);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing ${tracks.length} tracks from playlist'),
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

  Future<void> _savePlaylist(List<SearchResult> tracks, String playlistId) async {
    if (tracks.isEmpty) return;
    
    try {
      // Show name input dialog
      final playlistName = await _showPlaylistNameDialog(playlistId);
      if (playlistName == null || playlistName.trim().isEmpty) return;
      
      // Convert SearchResult to Track
      final trackList = tracks.map((result) => result.toTrack()).toList();
      
      // Create playlist
      final playlist = Playlist(
        id: playlistId,
        name: playlistName.trim(),
        tracks: trackList,
        createdDate: DateTime.now(),
        lastModified: DateTime.now(),
      );
      
      // Save to provider
      ref.read(savedPlaylistsProvider.notifier).addPlaylist(playlist);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playlist "$playlistName" saved with ${tracks.length} tracks'),
            action: SnackBarAction(
              label: 'View Playlists',
              onPressed: () {
                // TODO: Navigate to playlists view
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save playlist: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showPlaylistNameDialog(String defaultId) async {
    final controller = TextEditingController(text: 'YouTube Playlist $defaultId');
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for this playlist:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Playlist Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const SearchResultTile({
    super.key,
    required this.result,
    required this.onTap,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.music_note,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          result.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.artist,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${result.duration.inMinutes}:${(result.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  result.formattedViewCount,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: onTap,
              tooltip: 'Play',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: onDownload,
              tooltip: 'Download',
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
