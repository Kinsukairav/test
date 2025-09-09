import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/youtube_service.dart';
import '../services/cache_service.dart';
import '../models/search_result.dart';
import '../models/youtube_playlist.dart';
import '../models/youtube_artist.dart';
import '../providers/audio_player_provider.dart';
import '../widgets/track_tile.dart';
import 'playlist_details_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final YouTubeService _youtubeService = YouTubeService();
  
  List<SearchResult> _trendingTracks = [];
  List<YouTubePlaylist> _trendingPlaylists = [];
  List<YouTubeArtist> _trendingArtists = [];
  
  bool _isLoadingTracks = true;
  bool _isLoadingPlaylists = true;
  bool _isLoadingArtists = true;

  @override
  void initState() {
    super.initState();
    _loadTrendingContent();
  }

  Future<void> _loadTrendingContent() async {
    setState(() {
      _isLoadingTracks = true;
      _isLoadingPlaylists = true;
      _isLoadingArtists = true;
    });

    // Load trending tracks - try cache first
    try {
      final cachedTracks = await CacheService.getCachedTrendingTracks();
      if (cachedTracks != null && cachedTracks.isNotEmpty) {
        if (mounted) {
          setState(() {
            _trendingTracks = cachedTracks;
            _isLoadingTracks = false;
          });
        }
      } else {
        // Load from API and cache
        final tracks = await _youtubeService.getTrendingMusic(maxResults: 10);
        await CacheService.cacheTrendingTracks(tracks);
        if (mounted) {
          setState(() {
            _trendingTracks = tracks;
            _isLoadingTracks = false;
          });
        }
      }
    } catch (e) {
      print('Error loading trending tracks: $e');
      if (mounted) {
        setState(() => _isLoadingTracks = false);
      }
    }

    // Load trending playlists - try cache first
    try {
      final cachedPlaylists = await CacheService.getCachedTrendingPlaylists();
      if (cachedPlaylists != null && cachedPlaylists.isNotEmpty) {
        if (mounted) {
          setState(() {
            _trendingPlaylists = cachedPlaylists;
            _isLoadingPlaylists = false;
          });
        }
      } else {
        // Load from API and cache
        final playlistsData = await _youtubeService.getTrendingPlaylists(maxResults: 5);
        final playlists = playlistsData
            .map((data) => YouTubePlaylist.fromJson(data))
            .toList();
        await CacheService.cacheTrendingPlaylists(playlists);
        
        if (mounted) {
          setState(() {
            _trendingPlaylists = playlists;
            _isLoadingPlaylists = false;
          });
        }
      }
    } catch (e) {
      print('Error loading trending playlists: $e');
      if (mounted) {
        setState(() => _isLoadingPlaylists = false);
      }
    }

    // Load trending artists - try cache first
    try {
      final cachedArtists = await CacheService.getCachedTrendingArtists();
      if (cachedArtists != null && cachedArtists.isNotEmpty) {
        if (mounted) {
          setState(() {
            _trendingArtists = cachedArtists;
            _isLoadingArtists = false;
          });
        }
      } else {
        // Load from API and cache
        final artistsData = await _youtubeService.getTrendingArtists(maxResults: 5);
        final artists = artistsData
            .map((data) => YouTubeArtist.fromJson(data))
            .toList();
        await CacheService.cacheTrendingArtists(artists);
        
        if (mounted) {
          setState(() {
            _trendingArtists = artists;
            _isLoadingArtists = false;
          });
        }
      }
    } catch (e) {
      print('Error loading trending artists: $e');
      if (mounted) {
        setState(() => _isLoadingArtists = false);
      }
    }
  }

  Future<void> _refreshContent() async {
    // Clear all cache
    await CacheService.clearCache();
    // Reload fresh content
    await _loadTrendingContent();
  }

  Future<void> _playTrack(SearchResult track) async {
    try {
      final audioController = ref.read(audioPlayerControllerProvider.notifier);
      await audioController.playFromSearchResult(track);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now playing: ${track.title}'),
            action: SnackBarAction(
              label: 'Go to Player',
              onPressed: () {
                // Navigate to player screen
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

  void _showPlaylistDetails(YouTubePlaylist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlaylistDetailsScreen(playlist: playlist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshContent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.music_note,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome to Music Player',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discover trending music from around the world',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Trending Tracks
            _buildSectionHeader('Trending Tracks', Icons.trending_up),
            const SizedBox(height: 12),
            _buildTrendingTracks(),
            
            const SizedBox(height: 24),
            
            // Trending Playlists
            _buildSectionHeader('Trending Playlists', Icons.playlist_play),
            const SizedBox(height: 12),
            _buildTrendingPlaylists(),
            
            const SizedBox(height: 24),
            
            // Trending Artists
            _buildSectionHeader('Trending Artists', Icons.person),
            const SizedBox(height: 12),
            _buildTrendingArtists(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingTracks() {
    if (_isLoadingTracks) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_trendingTracks.isEmpty) {
      return const Center(child: Text('No trending tracks available'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _trendingTracks.length,
      itemBuilder: (context, index) {
        final track = _trendingTracks[index];
        return TrackTile(
          track: track,
          onTap: () => _playTrack(track),
        );
      },
    );
  }

  Widget _buildTrendingPlaylists() {
    if (_isLoadingPlaylists) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_trendingPlaylists.isEmpty) {
      return const Center(child: Text('No trending playlists available'));
    }

    return SizedBox(
      height: 220, // Increased height to prevent overflow
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _trendingPlaylists.length,
        itemBuilder: (context, index) {
          final playlist = _trendingPlaylists[index];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _showPlaylistDetails(playlist);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Playlist thumbnail
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        color: Theme.of(context).colorScheme.surfaceVariant,
                      ),
                      child: playlist.thumbnailUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Image.network(
                                playlist.thumbnailUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.playlist_play,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.playlist_play,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                    ),
                    
                    // Playlist info
                    Container(
                      height: 80, // Fixed height to prevent overflow
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            playlist.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${playlist.trackCount} tracks',
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingArtists() {
    if (_isLoadingArtists) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_trendingArtists.isEmpty) {
      return const Center(child: Text('No trending artists available'));
    }

    return SizedBox(
      height: 180, // Increased height to prevent overflow
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _trendingArtists.length,
        itemBuilder: (context, index) {
          final artist = _trendingArtists[index];
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // TODO: Navigate to artist details
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Artist avatar
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surfaceVariant,
                        ),
                        child: artist.avatarUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  artist.avatarUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 30,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Artist name
                      Text(
                        artist.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 2),
                      
                      // Subscriber count
                      Text(
                        '${artist.subscriberCount} subs',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}