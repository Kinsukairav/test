import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_player_provider.dart';

class VolumeControl extends ConsumerWidget {
  const VolumeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(volumeProvider);
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          volume == 0 
            ? Icons.volume_off 
            : volume < 0.5 
              ? Icons.volume_down 
              : Icons.volume_up,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Slider(
            value: volume,
            onChanged: (value) => controller.setVolume(value),
            activeColor: Theme.of(context).colorScheme.primary,
            inactiveColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
        ),
      ],
    );
  }
}
