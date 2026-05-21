import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/youtube_playlist.dart';
import '../models/search_result.dart';
import '../providers/audio_player_provider.dart';
import '../providers/download_manager_provider.dart';
import '../services/youtube_service.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final YouTubePlaylist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final YouTubeService _youtubeService = YouTubeService();
  List<SearchResult> _tracks = [];
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
      // No maxResults limit — fetch every track in the playlist
      final results =
          await _youtubeService.getPlaylistContents(widget.playlist.id);
      if (mounted) {
        setState(() {
          _tracks = results;
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
    final trackList = _tracks.map((r) => r.toTrack()).toList();
    ref.read(queueProvider.notifier).state = trackList;
    ref.read(currentTrackIndexProvider.notifier).state = index;
    await ref
        .read(audioPlayerControllerProvider.notifier)
        .playFromSearchResult(result);
  }

  Future<void> _playAll() async {
    if (_tracks.isEmpty) return;
    final trackList = _tracks.map((r) => r.toTrack()).toList();
    await ref
        .read(audioPlayerControllerProvider.notifier)
        .playPlaylist(trackList);
  }

  void _downloadTrack(SearchResult result) {
    final mgr = ref.read(downloadManagerProvider.notifier);
    if (mgr.isVideoDownloaded(result.videoId)) return;
    mgr.addDownload(result);
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Hero AppBar ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
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
                  // Thumbnail / gradient
                  playlist.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          playlist.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _gradientBackground(colors),
                        )
                      : _gradientBackground(colors),
                  // Overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                  // Playlist info
                  Positioned(
                    bottom: 20,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PLAYLIST',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          playlist.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.author}  •  ${playlist.trackCount} tracks',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
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
                    onPressed: _tracks.isNotEmpty ? _playAll : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play All'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _tracks.isEmpty
                        ? null
                        : () {
                            for (final t in _tracks) {
                              _downloadTrack(t);
                            }
                          },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download All'),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading / error / list ─────────────────────────────────────────
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading all tracks…',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Large playlists may take a moment',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: colors.error),
                    const SizedBox(height: 12),
                    const Text('Failed to load playlist'),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _loadTracks, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (_tracks.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No tracks in this playlist')),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  '${_tracks.length} tracks loaded',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildTrackTile(context, _tracks[index], index),
                childCount: _tracks.length,
              ),
            ),
          ],

          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  Widget _gradientBackground(ColorScheme colors) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.secondaryContainer, colors.tertiaryContainer],
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
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
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
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.music_note_rounded,
                            size: 24,
                            color: colors.onSurfaceVariant),
                      )
                    : Icon(Icons.music_note_rounded,
                        size: 24, color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 12, color: colors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '${track.duration.inMinutes}:${(track.duration.inSeconds % 60).toString().padLeft(2, '0')}',
              style:
                  TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _downloadTrack(track),
              tooltip: 'Download',
              iconSize: 22,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
