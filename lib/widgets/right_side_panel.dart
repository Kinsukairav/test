import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_player_provider.dart';

class RightSidePanel extends ConsumerWidget {
  const RightSidePanel({
    super.key,
    required this.activeIndex,
    required this.onNavigate,
  });

  final int activeIndex;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildNavItem(context,
              icon: Icons.home_rounded, tooltip: 'Home', index: 0),
          _buildNavItem(context,
              icon: Icons.search_rounded, tooltip: 'Search', index: 1),
          _buildNavItem(context,
              icon: Icons.queue_music_rounded, tooltip: 'Queue', index: 2),
          _buildNavItem(context,
              icon: Icons.download_rounded, tooltip: 'Downloads', index: 3),

          const Spacer(),

          // Volume Control (Vertical Slider)
          Container(
            height: 150,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Consumer(
              builder: (context, ref, _) {
                final volume = ref.watch(volumeProvider);
                return RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: volume,
                      onChanged: (val) {
                        ref
                            .read(audioPlayerControllerProvider.notifier)
                            .setVolume(val);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Icon(
            Icons.volume_up,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required int index,
  }) {
    final isSelected = activeIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onNavigate(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
