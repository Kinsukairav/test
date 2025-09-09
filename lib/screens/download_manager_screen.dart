import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_manager_provider.dart';
import '../models/playlist.dart';

class DownloadManagerScreen extends ConsumerWidget {
  const DownloadManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              final downloadManager = ref.read(downloadManagerProvider.notifier);
              switch (value) {
                case 'clear_completed':
                  downloadManager.clearCompleted();
                  break;
                case 'clear_failed':
                  downloadManager.clearFailed();
                  break;
                case 'pause_all':
                  downloadManager.pauseAll();
                  break;
                case 'resume_all':
                  downloadManager.resumeAll();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_completed',
                child: Text('Clear Completed'),
              ),
              const PopupMenuItem(
                value: 'clear_failed',
                child: Text('Clear Failed'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'pause_all',
                child: Text('Pause All'),
              ),
              const PopupMenuItem(
                value: 'resume_all',
                child: Text('Resume All'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Download Stats
          _buildDownloadStats(context, downloadState),
          
          // Downloads List
          Expanded(
            child: _buildDownloadsList(context, ref, downloadState),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadStats(BuildContext context, DownloadManagerState state) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Expanded(
            child: _buildStatCard(
              context,
              'Active',
              state.activeDownloadCount.toString(),
              Icons.download,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              'Completed',
              state.completedDownloads.length.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              'Failed',
              state.failedDownloads.length.toString(),
              Icons.error,
              Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              'Total',
              state.downloads.length.toString(),
              Icons.queue,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList(BuildContext context, WidgetRef ref, DownloadManagerState state) {
    if (state.downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Downloads Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for music and start downloading',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.downloads.length,
      itemBuilder: (context, index) {
        final download = state.downloads[index];
        return DownloadTaskTile(
          task: download,
          onRetry: () {
            ref.read(downloadManagerProvider.notifier).retryDownload(download.id);
          },
          onCancel: () {
            ref.read(downloadManagerProvider.notifier).cancelDownload(download.id);
          },
          onRemove: () {
            ref.read(downloadManagerProvider.notifier).removeDownload(download.id);
          },
        );
      },
    );
  }
}

class DownloadTaskTile extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  const DownloadTaskTile({
    super.key,
    required this.task,
    required this.onRetry,
    required this.onCancel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.artist,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusIcon(context),
                const SizedBox(width: 8),
                _buildActionButton(context),
              ],
            ),
            
            if (task.status == DownloadStatus.downloading) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        '${(task.progress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
            
            if (task.status == DownloadStatus.failed && task.error != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${task.error}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            if (task.status == DownloadStatus.completed) ...[
              const SizedBox(height: 8),
              Text(
                'Downloaded • ${_formatFileSize(task.filePath)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    switch (task.status) {
      case DownloadStatus.pending:
        return Icon(Icons.schedule, color: Colors.orange, size: 20);
      case DownloadStatus.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: task.progress,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      case DownloadStatus.completed:
        return Icon(Icons.check_circle, color: Colors.green, size: 20);
      case DownloadStatus.failed:
        return Icon(Icons.error, color: Colors.red, size: 20);
      case DownloadStatus.cancelled:
        return Icon(Icons.cancel, color: Colors.grey, size: 20);
    }
  }

  Widget _buildActionButton(BuildContext context) {
    switch (task.status) {
      case DownloadStatus.pending:
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.cancel),
          onPressed: onCancel,
          tooltip: 'Cancel',
          iconSize: 20,
        );
      case DownloadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRetry,
              tooltip: 'Retry',
              iconSize: 20,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onRemove,
              tooltip: 'Remove',
              iconSize: 20,
            ),
          ],
        );
      case DownloadStatus.completed:
      case DownloadStatus.cancelled:
        return IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onRemove,
          tooltip: 'Remove',
          iconSize: 20,
        );
    }
  }

  String _formatFileSize(String? filePath) {
    // TODO: Implement actual file size calculation
    return 'Unknown size';
  }
}
