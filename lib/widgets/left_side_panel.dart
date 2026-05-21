import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_player_provider.dart';
import '../models/playlist.dart';

class LeftSidePanel extends ConsumerWidget {
  const LeftSidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final currentTrack = playerState.currentTrack;
    final savedPlaylists = ref.watch(savedPlaylistsProvider);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Music Player Card — uses flexible height to avoid overflow
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Cover Art — fills top of card, clipped to rounded corners
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: currentTrack?.albumArt != null
                                ? Image.network(
                                    currentTrack!.albumArt!,
                                    fit: BoxFit.cover,
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                    alignment: Alignment.center,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      child: Center(
                                        child: Icon(
                                          Icons.music_note_rounded,
                                          size: 64,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    child: Center(
                                      child: Icon(
                                        Icons.music_note_rounded,
                                        size: 64,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Track Info & Controls
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentTrack?.title ?? 'No Track Playing',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentTrack?.artist ?? 'Unknown Artist',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Progress Bar
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                          ),
                          child: Builder(
                            builder: (context) {
                              final double maxVal = playerState
                                          .totalDuration.inSeconds
                                          .toDouble() >
                                      0
                                  ? playerState.totalDuration.inSeconds
                                      .toDouble()
                                  : 1;
                              final double val = playerState
                                  .currentPosition.inSeconds
                                  .toDouble()
                                  .clamp(0, maxVal);

                              return Slider(
                                value: val,
                                max: maxVal,
                                onChanged: (value) {
                                  ref
                                      .read(audioPlayerControllerProvider
                                          .notifier)
                                      .seek(Duration(seconds: value.toInt()));
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(playerState.currentPosition),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                              Text(
                                _formatDuration(playerState.totalDuration),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.shuffle_rounded,
                                size: 20,
                                color: ref.watch(isShuffleProvider)
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              onPressed: () => ref
                                  .read(audioPlayerControllerProvider.notifier)
                                  .toggleShuffle(),
                              tooltip: 'Shuffle',
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded,
                                  size: 22),
                              onPressed: () => ref
                                  .read(audioPlayerControllerProvider.notifier)
                                  .playPrevious(),
                              tooltip: 'Previous',
                              visualDensity: VisualDensity.compact,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              child: playerState.isLoading
                                  ? Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      icon: Icon(
                                        playerState.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                      ),
                                      onPressed: () {
                                        if (playerState.isPlaying) {
                                          ref
                                              .read(
                                                  audioPlayerControllerProvider
                                                      .notifier)
                                              .pause();
                                        } else {
                                          ref
                                              .read(
                                                  audioPlayerControllerProvider
                                                      .notifier)
                                              .play();
                                        }
                                      },
                                      tooltip: playerState.isPlaying
                                          ? 'Pause'
                                          : 'Play',
                                    ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.skip_next_rounded, size: 22),
                              onPressed: () => ref
                                  .read(audioPlayerControllerProvider.notifier)
                                  .playNext(),
                              tooltip: 'Next',
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: Icon(
                                _repeatIcon(ref.watch(repeatModeProvider)),
                                size: 20,
                                color: ref.watch(repeatModeProvider) !=
                                        RepeatMode.off
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              onPressed: () => ref
                                  .read(audioPlayerControllerProvider.notifier)
                                  .toggleRepeat(),
                              tooltip: 'Repeat',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Playlists Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Saved Playlists',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () => _showCreatePlaylistDialog(context, ref),
                  tooltip: 'New Playlist',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Playlists List
          Expanded(
            flex: 1,
            child: savedPlaylists.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No saved playlists\nSearch & import from YouTube',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: savedPlaylists.length,
                    itemBuilder: (context, index) {
                      final playlist = savedPlaylists[index];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.playlist_play_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(
                          playlist.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${playlist.tracks.length} songs',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () {
                          if (playlist.tracks.isNotEmpty) {
                            ref
                                .read(audioPlayerControllerProvider.notifier)
                                .playPlaylist(playlist.tracks);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _repeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.one:
        return Icons.repeat_one_rounded;
      case RepeatMode.all:
      case RepeatMode.off:
        return Icons.repeat_rounded;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _showCreatePlaylistDialog(
      BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final playlistName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Playlist name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    final trimmedName = playlistName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final playlist = Playlist(
      id: now.millisecondsSinceEpoch.toString(),
      name: trimmedName,
      tracks: const [],
      createdDate: now,
      lastModified: now,
    );

    ref.read(savedPlaylistsProvider.notifier).addPlaylist(playlist);
  }
}
