import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_player_provider.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(isPlayingProvider);
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous Button
        IconButton(
          onPressed: () => controller.playPrevious(),
          icon: Icon(
            Icons.skip_previous,
            size: 32,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: 'Previous',
        ),
        
        const SizedBox(width: 16),
        
        // Play/Pause Button
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () async {
              if (isPlaying) {
                await controller.pause();
              } else {
                await controller.play();
              }
            },
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              size: 40,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            tooltip: isPlaying ? 'Pause' : 'Play',
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Next Button
        IconButton(
          onPressed: () => controller.playNext(),
          icon: Icon(
            Icons.skip_next,
            size: 32,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: 'Next',
        ),
        
        const SizedBox(width: 32),
        
        // Stop Button
        IconButton(
          onPressed: () => controller.stop(),
          icon: Icon(
            Icons.stop,
            size: 28,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: 'Stop',
        ),
      ],
    );
  }
}
