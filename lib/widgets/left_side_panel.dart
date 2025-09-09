import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/search_screen.dart';
import '../screens/queue_screen.dart';
import '../providers/audio_player_provider.dart';
import '../models/playlist.dart';

class LeftSidePanel extends ConsumerWidget {
  const LeftSidePanel({
    super.key,
    required this.isExpanded,
    required this.onToggleExpanded,
  });
  
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Toggle Button
          Container(
            height: 60,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    isExpanded ? Icons.menu_open : Icons.menu,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Library',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(
                  context,
                  icon: Icons.home,
                  label: 'Home',
                  isSelected: true,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.search,
                  label: 'Search',
                  onTap: () => _navigateToSearch(context),
                ),
                _buildNavItem(
                  context,
                  icon: Icons.library_music,
                  label: 'Library',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.favorite,
                  label: 'Favorites',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.playlist_play,
                  label: 'Playlists',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.history,
                  label: 'Recently Played',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.queue_music,
                  label: 'Queue',
                  onTap: () => _navigateToQueue(context),
                ),
                _buildNavItem(
                  context,
                  icon: Icons.download,
                  label: 'Downloads',
                ),
                
                const Divider(),
                
                // Saved Playlists Section
                if (isExpanded) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Saved Playlists',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _showCreatePlaylistDialog(context),
                          icon: Icon(
                            Icons.add,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          tooltip: 'Create Playlist',
                        ),
                      ],
                    ),
                  ),
                  _buildSavedPlaylists(context, ref),
                ] else ...[
                  // Create Playlist (compact)
                  _buildNavItem(
                    context,
                    icon: Icons.add,
                    label: 'Create Playlist',
                    onTap: () => _showCreatePlaylistDialog(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
        title: isExpanded ? Text(
          label,
          style: TextStyle(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ) : null,
        onTap: onTap,
        selected: isSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: isExpanded 
            ? const EdgeInsets.symmetric(horizontal: 16)
            : const EdgeInsets.all(0),
        minLeadingWidth: isExpanded ? null : 0,
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Playlist Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                // Create playlist
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playlist "${controller.text}" created'),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _navigateToSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SearchScreen(),
      ),
    );
  }

  void _navigateToQueue(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QueueScreen(),
      ),
    );
  }

  Widget _buildSavedPlaylists(BuildContext context, WidgetRef ref) {
    final savedPlaylists = ref.watch(savedPlaylistsProvider);
    
    if (savedPlaylists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'No saved playlists',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return Column(
      children: savedPlaylists.map((playlist) => _buildPlaylistItem(context, ref, playlist)).toList(),
    );
  }

  Widget _buildPlaylistItem(BuildContext context, WidgetRef ref, Playlist playlist) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: ListTile(
        leading: Icon(
          Icons.playlist_play,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        title: Text(
          playlist.name,
          style: Theme.of(context).textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${playlist.tracks.length} songs',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handlePlaylistAction(context, ref, playlist, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'play',
              child: Row(
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text('Play'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'queue',
              child: Row(
                children: [
                  Icon(Icons.queue),
                  SizedBox(width: 8),
                  Text('Add to Queue'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _playPlaylist(context, ref, playlist),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _handlePlaylistAction(BuildContext context, WidgetRef ref, Playlist playlist, String action) {
    final audioController = ref.read(audioPlayerControllerProvider.notifier);
    
    switch (action) {
      case 'play':
        _playPlaylist(context, ref, playlist);
        break;
      case 'queue':
        audioController.addToQueue(playlist.tracks);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${playlist.name}" to queue'),
          ),
        );
        break;
      case 'delete':
        _showDeletePlaylistDialog(context, ref, playlist);
        break;
    }
  }

  void _playPlaylist(BuildContext context, WidgetRef ref, Playlist playlist) {
    if (playlist.tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist is empty')),
      );
      return;
    }
    
    final audioController = ref.read(audioPlayerControllerProvider.notifier);
    audioController.playPlaylist(playlist.tracks);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing "${playlist.name}"'),
        action: SnackBarAction(
          label: 'Queue',
          onPressed: () => _navigateToQueue(context),
        ),
      ),
    );
  }

  void _showDeletePlaylistDialog(BuildContext context, WidgetRef ref, Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(savedPlaylistsProvider.notifier).removePlaylist(playlist.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${playlist.name}"')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
