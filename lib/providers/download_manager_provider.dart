import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playlist.dart';
import '../models/search_result.dart';
import '../services/youtube_service.dart';

// Provider for download manager
final downloadManagerProvider = StateNotifierProvider<DownloadManager, DownloadManagerState>(
  (ref) => DownloadManager(),
);

class DownloadManagerState {
  final List<DownloadTask> downloads;
  final bool isDownloading;
  final int activeDownloadCount;

  const DownloadManagerState({
    this.downloads = const [],
    this.isDownloading = false,
    this.activeDownloadCount = 0,
  });

  DownloadManagerState copyWith({
    List<DownloadTask>? downloads,
    bool? isDownloading,
    int? activeDownloadCount,
  }) {
    return DownloadManagerState(
      downloads: downloads ?? this.downloads,
      isDownloading: isDownloading ?? this.isDownloading,
      activeDownloadCount: activeDownloadCount ?? this.activeDownloadCount,
    );
  }

  List<DownloadTask> get completedDownloads => 
      downloads.where((task) => task.status == DownloadStatus.completed).toList();

  List<DownloadTask> get pendingDownloads => 
      downloads.where((task) => task.status == DownloadStatus.pending).toList();

  List<DownloadTask> get activeDownloadTasks => 
      downloads.where((task) => task.status == DownloadStatus.downloading).toList();

  List<DownloadTask> get failedDownloads => 
      downloads.where((task) => task.status == DownloadStatus.failed).toList();
}

class DownloadManager extends StateNotifier<DownloadManagerState> {
  DownloadManager() : super(const DownloadManagerState());
  
  final YouTubeService _youtubeService = YouTubeService();
  final Queue<DownloadTask> _downloadQueue = Queue<DownloadTask>();
  final int _maxConcurrentDownloads = 3;
  Timer? _progressTimer;
  
  // Add a download to the queue
  Future<void> addDownload(SearchResult searchResult) async {
    final downloadTask = DownloadTask(
      id: searchResult.videoId,
      url: 'https://www.youtube.com/watch?v=${searchResult.videoId}',
      title: searchResult.title,
      artist: searchResult.artist,
      status: DownloadStatus.pending,
      createdDate: DateTime.now(),
      progress: 0.0,
    );

    final updatedDownloads = [...state.downloads, downloadTask];
    state = state.copyWith(downloads: updatedDownloads);
    
    _downloadQueue.add(downloadTask);
    _processDownloadQueue();
  }

  // Process the download queue
  Future<void> _processDownloadQueue() async {
    if (state.activeDownloadCount >= _maxConcurrentDownloads || _downloadQueue.isEmpty) {
      return;
    }

    final task = _downloadQueue.removeFirst();
    await _startDownload(task);
  }

  // Start a download
  Future<void> _startDownload(DownloadTask task) async {
    try {
      // Update task status to downloading
      _updateDownloadTask(task.id, task.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.0,
      ));

      // Get download path
      final downloadPath = await _youtubeService.getDefaultDownloadPath();
      
      // Start the download
      final completedTask = await _youtubeService.downloadAudio(
        task.id,
        downloadPath,
        onProgress: (progress) {
          _updateDownloadTask(task.id, task.copyWith(progress: progress));
        },
      );

      // Update the task with completion status
      _updateDownloadTask(task.id, completedTask);
      
      // Process next download in queue
      _processDownloadQueue();
    } catch (e) {
      print('Download failed for ${task.title}: $e');
      _updateDownloadTask(task.id, task.copyWith(
        status: DownloadStatus.failed,
        progress: 0.0,
      ));
      
      // Process next download in queue even if this one failed
      _processDownloadQueue();
    }
  }

  // Update a specific download task
  void _updateDownloadTask(String taskId, DownloadTask updatedTask) {
    final updatedDownloads = state.downloads.map((task) {
      return task.id == taskId ? updatedTask : task;
    }).toList();

    final activeCount = updatedDownloads
        .where((task) => task.status == DownloadStatus.downloading)
        .length;

    state = state.copyWith(
      downloads: updatedDownloads,
      activeDownloadCount: activeCount,
      isDownloading: activeCount > 0,
    );
  }

  // Retry a failed download
  Future<void> retryDownload(String taskId) async {
    final task = state.downloads.firstWhere((task) => task.id == taskId);
    if (task.status == DownloadStatus.failed) {
      _updateDownloadTask(taskId, task.copyWith(
        status: DownloadStatus.pending,
        progress: 0.0,
      ));
      
      _downloadQueue.add(task);
      _processDownloadQueue();
    }
  }

  // Cancel a download
  void cancelDownload(String taskId) {
    final task = state.downloads.firstWhere((task) => task.id == taskId);
    if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.pending) {
      _updateDownloadTask(taskId, task.copyWith(
        status: DownloadStatus.cancelled,
        progress: 0.0,
      ));
      
      // Remove from queue if pending
      _downloadQueue.removeWhere((queueTask) => queueTask.id == taskId);
    }
  }

  // Remove a download from history
  void removeDownload(String taskId) {
    final updatedDownloads = state.downloads.where((task) => task.id != taskId).toList();
    state = state.copyWith(downloads: updatedDownloads);
  }

  // Clear completed downloads
  void clearCompleted() {
    final updatedDownloads = state.downloads
        .where((task) => task.status != DownloadStatus.completed)
        .toList();
    state = state.copyWith(downloads: updatedDownloads);
  }

  // Clear failed downloads
  void clearFailed() {
    final updatedDownloads = state.downloads
        .where((task) => task.status != DownloadStatus.failed)
        .toList();
    state = state.copyWith(downloads: updatedDownloads);
  }

  // Get download by ID
  DownloadTask? getDownload(String taskId) {
    try {
      return state.downloads.firstWhere((task) => task.id == taskId);
    } catch (e) {
      return null;
    }
  }

  // Check if a video is already downloaded or downloading
  bool isVideoDownloaded(String videoId) {
    return state.downloads.any((task) => 
        task.id == videoId && 
        (task.status == DownloadStatus.completed || task.status == DownloadStatus.downloading)
    );
  }

  // Pause all downloads
  void pauseAll() {
    // Implementation would depend on yt-dlp process management
    // For now, just update state
    state = state.copyWith(isDownloading: false);
  }

  // Resume all downloads
  void resumeAll() {
    _processDownloadQueue();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
}
