import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/youtube_artist.dart';
import '../models/search_result.dart';
import '../providers/audio_player_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/youtube_service.dart';

class ArtistDetailScreen extends ConsumerStatefulWidget {
  final YouTubeArtist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  final YouTubeService _youtubeService = YouTubeService();
  List<SearchResult> _topTracks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _youtubeService.searchVideos(
        '${widget.artist.name} music official',
        maxResults: 15,
      );
      if (mounted) {
        setState(() {
          _topTracks = results;
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

  Future<void> _playTrack(SearchResult result, int index) async {
    final trackList = _topTracks.map((r) => r.toTrack()).toList();
    ref.read(queueProvider.notifier).state = trackList;
    ref.read(currentTrackIndexProvider.notifier).state = index;
    await ref
        .read(audioPlayerControllerProvider.notifier)
        .playFromSearchResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Hero AppBar ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: colors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner / gradient background
                  artist.bannerUrl.isNotEmpty
                      ? Image.network(
                          artist.bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _gradientBackground(colors),
                        )
                      : _gradientBackground(colors),
                  // Dark overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  // Artist info
                  Positioned(
                    bottom: 20,
                    left: 24,
                    right: 24,
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            color: colors.primaryContainer,
                          ),
                          child: artist.avatarUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    artist.avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.person_rounded,
                                      size: 40,
                                      color: colors.onPrimaryContainer,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.person_rounded,
                                  size: 40,
                                  color: colors.onPrimaryContainer,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      artist.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (artist.isVerified) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: Colors.blueAccent,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                artist.formattedSubscriberCount,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                              if (artist.description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    artist.description,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Action row ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: _topTracks.isNotEmpty
                        ? () => _playTrack(_topTracks.first, 0)
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to search screen with artist name
                      ref.read(activeScreenProvider.notifier).state = 1;
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search songs'),
                  ),
                ],
              ),
            ),
          ),

          // ── Section header ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(
                'Top Tracks',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // ── Tracks ────────────────────────────────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: colors.error),
                    const SizedBox(height: 12),
                    Text('Failed to load tracks'),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _loadTracks, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (_topTracks.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No tracks found')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = _topTracks[index];
                  return _buildTrackTile(context, track, index);
                },
                childCount: _topTracks.length,
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  Widget _gradientBackground(ColorScheme colors) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildTrackTile(BuildContext context, SearchResult track, int index) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _playTrack(track, index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          children: [
            // Index
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 48,
                height: 48,
                color: colors.surfaceContainerHighest,
                child: track.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        track.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.music_note_rounded, size: 24, color: colors.onSurfaceVariant),
                      )
                    : Icon(Icons.music_note_rounded, size: 24, color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.formattedViewCount,
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              '${track.duration.inMinutes}:${(track.duration.inSeconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded),
              onPressed: () => _playTrack(track, index),
              tooltip: 'Play',
              iconSize: 28,
              color: colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
