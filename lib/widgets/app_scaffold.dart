import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/queue_screen.dart';
import '../screens/download_manager_screen.dart';
import '../providers/navigation_provider.dart';
import 'left_side_panel.dart';
import 'right_side_panel.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = ref.watch(activeScreenProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Row(
        children: [
          // Left Sidebar (Music Player & Playlists)
          const LeftSidePanel(),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Navbar
                _buildTopNavbar(context, ref, activeIndex),
                // Active screen
                Expanded(child: _screenForIndex(activeIndex)),
              ],
            ),
          ),

          // Right Sidebar (Navigation & Volume)
          RightSidePanel(
            activeIndex: activeIndex,
            onNavigate: (index) {
              ref.read(activeScreenProvider.notifier).state = index;
            },
          ),
        ],
      ),
    );
  }

  Widget _screenForIndex(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const SearchScreen();
      case 2:
        return const QueueScreen();
      case 3:
        return const DownloadManagerScreen();
      default:
        return const HomeScreen();
    }
  }

  Widget _buildTopNavbar(BuildContext context, WidgetRef ref, int activeIndex) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Screen title
          Text(
            _titleForIndex(activeIndex),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          // Search bar — opens search screen when tapped
          if (activeIndex != 1)
            GestureDetector(
              onTap: () {
                ref.read(activeScreenProvider.notifier).state = 1;
              },
              child: Container(
                width: 260,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Search music...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Search';
      case 2:
        return 'Queue';
      case 3:
        return 'Downloads';
      default:
        return 'Home';
    }
  }
}
