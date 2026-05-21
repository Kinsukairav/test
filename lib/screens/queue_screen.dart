import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);
    final currentTrackIndex = ref.watch(currentTrackIndexProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          if (queue.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => _showClearQueueDialog(context, ref),
              tooltip: 'Clear Queue',
            ),
        ],
      ),
      body: queue.isEmpty
          ? _buildEmptyQueue(context)
          : _buildQueueList(context, ref, queue, currentTrackIndex, isPlaying),
    );
  }

  Widget _buildEmptyQueue(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music,
            size: 64,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No songs in queue',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add songs to your queue to see them here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(BuildContext context, WidgetRef ref, List<Track> queue,
      int currentIndex, bool isPlaying) {
    return Column(
      children: [
        // Queue stats
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.queue_music,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${queue.length} song${queue.length != 1 ? 's' : ''} in queue',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                    ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Queue list
        Expanded(
          child: ReorderableListView.builder(
            itemCount: queue.length,
            onReorder: (oldIndex, newIndex) =>
                _reorderQueue(ref, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final track = queue[index];
              final isCurrent = index == currentIndex;

              return Card(
                key: ValueKey(track.id),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                elevation: isCurrent ? 4 : 1,
                color: isCurrent
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_handle,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Track number or play indicator
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.3),
                        ),
                        child: Center(
                          child: isCurrent && isPlaying
                              ? Icon(
                                  Icons.play_arrow,
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    track.title,
                    style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    track.artist,
                    style: TextStyle(
                      color: isCurrent
                          ? Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withValues(alpha: 0.8)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDuration(track.duration),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) => _handleTrackAction(
                            context, ref, track, index, value),
                        itemBuilder: (context) => [
                          if (!isCurrent)
                            const PopupMenuItem(
                              value: 'play',
                              child: Row(
                                children: [
                                  Icon(Icons.play_arrow),
                                  SizedBox(width: 8),
                                  Text('Play Now'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.remove_circle_outline),
                                SizedBox(width: 8),
                                Text('Remove from Queue'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _playTrackFromQueue(ref, index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _reorderQueue(WidgetRef ref, int oldIndex, int newIndex) {
    final queue = ref.read(queueProvider);
    final currentIndex = ref.read(currentTrackIndexProvider);

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final updatedQueue = List<Track>.from(queue);
    final track = updatedQueue.removeAt(oldIndex);
    updatedQueue.insert(newIndex, track);

    // Update current track index to follow the track that was moved.
    int updatedCurrentIndex = currentIndex;
    if (oldIndex == currentIndex) {
      // The currently-playing track itself was moved.
      updatedCurrentIndex = newIndex;
    } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
      // A track from before the current one was moved to after it — shift back.
      updatedCurrentIndex = currentIndex - 1;
    } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
      // A track from after the current one was moved to before it — shift forward.
      updatedCurrentIndex = currentIndex + 1;
    }

    ref.read(queueProvider.notifier).state = updatedQueue;
    ref.read(currentTrackIndexProvider.notifier).state = updatedCurrentIndex;
  }

  void _playTrackFromQueue(WidgetRef ref, int index) {
    final audioController = ref.read(audioPlayerControllerProvider.notifier);
    audioController.playFromQueue(index);
  }

  void _handleTrackAction(BuildContext context, WidgetRef ref, Track track,
      int index, String action) {
    switch (action) {
      case 'play':
        _playTrackFromQueue(ref, index);
        break;
      case 'remove':
        _removeFromQueue(ref, index);
        break;
    }
  }

  void _removeFromQueue(WidgetRef ref, int index) {
    final queue = ref.read(queueProvider);
    final currentIndex = ref.read(currentTrackIndexProvider);

    final updatedQueue = List<Track>.from(queue);
    updatedQueue.removeAt(index);

    // Determine new current-track index.
    int updatedCurrentIndex;
    if (updatedQueue.isEmpty) {
      // Queue is now empty — no valid current track.
      updatedCurrentIndex = -1;
    } else if (index < currentIndex) {
      // A track before the current one was removed — shift back.
      updatedCurrentIndex = currentIndex - 1;
    } else if (index == currentIndex) {
      // The currently-playing track was removed. Keep the same index but
      // clamp it to the new queue length so it stays valid.
      updatedCurrentIndex = currentIndex.clamp(0, updatedQueue.length - 1);
    } else {
      // A track after the current one was removed — index unchanged.
      updatedCurrentIndex = currentIndex;
    }

    ref.read(queueProvider.notifier).state = updatedQueue;
    ref.read(currentTrackIndexProvider.notifier).state = updatedCurrentIndex;
  }



  void _showClearQueueDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Queue'),
        content: const Text('Are you sure you want to clear the entire queue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(audioPlayerControllerProvider.notifier).clearQueue();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
