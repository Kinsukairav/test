import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_player_provider.dart';

class SeekBar extends ConsumerWidget {
  const SeekBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPosition = ref.watch(currentPositionProvider);
    final totalDuration = ref.watch(totalDurationProvider);
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    
    return Column(
      children: [
        // Progress bar
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Theme.of(context).colorScheme.surfaceVariant,
            thumbColor: Theme.of(context).colorScheme.primary,
          ),
          child: Slider(
            value: _getSliderValue(currentPosition, totalDuration),
            min: 0.0,
            max: 1.0,
            onChanged: totalDuration.inMilliseconds > 0 ? (value) {
              final newPosition = Duration(
                milliseconds: (value * totalDuration.inMilliseconds).round(),
              );
              controller.seek(newPosition);
            } : null,
          ),
        ),
        
        // Time indicators
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(currentPosition),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _formatDuration(totalDuration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _getSliderValue(Duration currentPosition, Duration totalDuration) {
    if (totalDuration.inMilliseconds <= 0) return 0.0;
    
    final value = currentPosition.inMilliseconds / totalDuration.inMilliseconds;
    // Clamp value between 0.0 and 1.0 to prevent slider assertion errors
    return value.clamp(0.0, 1.0);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
