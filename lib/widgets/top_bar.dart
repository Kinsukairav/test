import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/search_screen.dart';
import '../screens/download_manager_screen.dart';

class TopBar extends ConsumerStatefulWidget {
  const TopBar({super.key});

  @override
  ConsumerState<TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<TopBar> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // App Title
          Text(
            'Music Player',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // Search Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSearchExpanded ? 300 : 40,
            height: 40,
            child: _isSearchExpanded
                ? TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search music...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _isSearchExpanded = false;
                            _searchController.clear();
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (query) {
                      // Navigate to search screen
                      _navigateToSearch(query);
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      if (_searchController.text.trim().isNotEmpty) {
                        _navigateToSearch(_searchController.text.trim());
                      } else {
                        setState(() {
                          _isSearchExpanded = true;
                        });
                      }
                    },
                  ),
          ),
          
          const SizedBox(width: 8),
          
          // Voice Search Button
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Voice Search',
            onPressed: _startVoiceSearch,
          ),
          
          const SizedBox(width: 8),
          
          // Download Button
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download Manager',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DownloadManagerScreen(),
                ),
              );
            },
          ),
          
          const SizedBox(width: 8),
          
          // Volume Control (moved here)
          // VolumeControl(),
          
          const SizedBox(width: 8),
          
          // Feedback Button
          IconButton(
            icon: const Icon(Icons.message),
            tooltip: 'Feedback',
            onPressed: _showFeedbackDialog,
          ),
        ],
      ),
    );
  }

  void _navigateToSearch(String query) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SearchScreen(),
      ),
    );
  }

  void _startVoiceSearch() {
    // Implementation for voice search
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Search'),
        content: const Text('Voice search functionality will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feedback'),
        content: const Text('Feedback form will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
