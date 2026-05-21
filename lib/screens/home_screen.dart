import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/search_result.dart';
import '../models/youtube_artist.dart';
import '../models/youtube_playlist.dart';
import '../providers/audio_player_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/youtube_service.dart';
import 'artist_detail_screen.dart';
import 'playlist_detail_screen.dart';

// ── Suggestion keywords (static, instant filtering) ──────────────────────────
const List<String> _kSuggestionPool = [
  'lofi hip hop',
  'chill beats 2025',
  'top hits 2025',
  'pop music',
  'rock classics',
  'hip hop',
  'jazz relaxing',
  'electronic dance',
  'acoustic guitar',
  'workout music',
  'r&b soul',
  'indie folk',
  'classical piano',
  'rap 2025',
  'kpop hits',
  'bollywood songs',
  'study music',
  'night drive music',
  'sleep music',
  'trending songs',
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final YouTubeService _youtubeService = YouTubeService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<SearchResult> _trendingTracks = [];
  List<YouTubePlaylist> _trendingPlaylists = [];
  List<YouTubeArtist> _trendingArtists = [];

  bool _isLoading = true;
  String? _error;

  bool _showSuggestions = false;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadData();

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _searchFocusNode.hasFocus &&
            _suggestions.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    // Filter & rank suggestions — show up to 5
    final matches = _kSuggestionPool
        .where((s) => s.contains(query))
        .toList();

    // Also add the raw query as a suggestion if it isn't already there
    if (!matches.contains(query)) {
      matches.insert(0, query);
    }

    setState(() {
      _suggestions = matches.take(5).toList();
      _showSuggestions = _searchFocusNode.hasFocus && _suggestions.isNotEmpty;
    });
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _searchFocusNode.unfocus();
    setState(() => _showSuggestions = false);
    // Pre-populate search query and navigate to search screen
    ref.read(searchQueryProvider.notifier).state = trimmed;
    ref.read(activeScreenProvider.notifier).state = 1;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final futures = await Future.wait([
        _youtubeService.getTrendingMusic(maxResults: 10),
        _youtubeService.getTrendingPlaylists(maxResults: 10),
        _youtubeService.getTrendingArtists(maxResults: 15),
      ]);

      if (mounted) {
        setState(() {
          _trendingTracks = futures[0] as List<SearchResult>;
          _trendingPlaylists = (futures[1] as List<dynamic>)
              .map((data) => YouTubePlaylist.fromJson(data))
              .toList();
          _trendingArtists = (futures[2] as List<dynamic>)
              .map((data) => YouTubeArtist.fromJson(data))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load content',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      // Dismiss suggestions when tapping outside the search bar
      onTap: () {
        _searchFocusNode.unfocus();
        setState(() => _showSuggestions = false);
      },
      behavior: HitTestBehavior.translucent,
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Inline Search Bar ──────────────────────────────────
                  _buildSearchBar(context),
                  const SizedBox(height: 28),

                  // ── Hero Section ───────────────────────────────────────
                  if (_trendingArtists.isNotEmpty) _buildHeroSection(context),

                  if (_trendingArtists.isNotEmpty) const SizedBox(height: 32),

                  // ── Featured Playlists ─────────────────────────────────
                  if (_trendingPlaylists.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      'Featured Playlists',
                      Icons.playlist_play_rounded,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _trendingPlaylists.length,
                        itemBuilder: (context, index) {
                          final playlist = _trendingPlaylists[index];
                          return _buildPlaylistCard(context, playlist);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ── Trending Tracks ────────────────────────────────────
                  if (_trendingTracks.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      'Trending Tracks',
                      Icons.trending_up_rounded,
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(_trendingTracks.length, (index) {
                      final track = _trendingTracks[index];
                      return _buildTrackRow(context, track, index);
                    }),
                  ],
                ],
              ),
            ),

            // ── Autocomplete suggestions overlay ──────────────────────────
            if (_showSuggestions)
              Positioned(
                top: 24 + 56, // search bar top padding + bar height
                left: 24,
                right: 24,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _suggestions.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      return InkWell(
                        borderRadius: BorderRadius.only(
                          topLeft: i == 0
                              ? const Radius.circular(12)
                              : Radius.zero,
                          topRight: i == 0
                              ? const Radius.circular(12)
                              : Radius.zero,
                          bottomLeft: i == _suggestions.length - 1
                              ? const Radius.circular(12)
                              : Radius.zero,
                          bottomRight: i == _suggestions.length - 1
                              ? const Radius.circular(12)
                              : Radius.zero,
                        ),
                        onTap: () {
                          _searchController.text = s;
                          _submitSearch(s);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Icon(Icons.north_west_rounded,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _searchFocusNode.unfocus();
          setState(() => _showSuggestions = false);
        }
      },
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onSubmitted: _submitSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search music, artists, albums…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _showSuggestions = false);
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
        ),
      ),
    );
  }

  // ── Section header with icon ───────────────────────────────────────────────

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon,
            color: Theme.of(context).colorScheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ── Hero Section ───────────────────────────────────────────────────────────

  Widget _buildHeroSection(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Discover Music hero card — taps to go to search
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () =>
                  ref.read(activeScreenProvider.notifier).state = 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.headphones_rounded,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(height: 12),
                    Text(
                      'Discover Music',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to search →',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Trending Artists grid
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trending Artists',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _trendingArtists.length.clamp(0, 10),
                      itemBuilder: (context, index) {
                        final artist = _trendingArtists[index];
                        return _buildArtistAvatar(context, artist);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Artist Avatar (clickable) ──────────────────────────────────────────────

  Widget _buildArtistAvatar(BuildContext context, YouTubeArtist artist) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArtistDetailScreen(artist: artist),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: artist.avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        artist.avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          size: 24,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person_rounded,
                      size: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            artist.name,
            style: const TextStyle(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Playlist Card (clickable) ──────────────────────────────────────────────

  Widget _buildPlaylistCard(BuildContext context, YouTubePlaylist playlist) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlist: playlist),
        ),
      ),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                    child: playlist.thumbnailUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              playlist.thumbnailUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(Icons.playlist_play_rounded,
                                    size: 40,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(Icons.playlist_play_rounded,
                                size: 40,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                  ),
                  // Hover overlay with play icon
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${playlist.trackCount} tracks',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Trending Track Row ─────────────────────────────────────────────────────

  Widget _buildTrackRow(BuildContext context, SearchResult track, int index) {
    return InkWell(
      onTap: () async {
        final audioController =
            ref.read(audioPlayerControllerProvider.notifier);
        final trackList =
            _trendingTracks.map((result) => result.toTrack()).toList();
        ref.read(queueProvider.notifier).state = trackList;
        ref.read(currentTrackIndexProvider.notifier).state = index;
        await audioController.playFromSearchResult(track);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              child: track.thumbnailUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        track.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.music_note_rounded, size: 24),
                      ),
                    )
                  : const Icon(Icons.music_note_rounded, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artist,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '${track.duration.inMinutes}:${(track.duration.inSeconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
