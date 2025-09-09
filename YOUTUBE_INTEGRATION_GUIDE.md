# YouTube Integration with yt-dlp Setup Guide

## Overview

This Windows Music Player now includes real YouTube integration using `yt-dlp`, a powerful command-line tool for downloading videos and extracting metadata from YouTube and other video platforms.

## Prerequisites

### 1. Install Python (Required for yt-dlp)

1. Download Python from [python.org](https://www.python.org/downloads/)
2. During installation, make sure to check "Add Python to PATH"
3. Verify installation by opening Command Prompt and running:
   ```cmd
   python --version
   pip --version
   ```

### 2. Install yt-dlp

Open Command Prompt as Administrator and run:

```cmd
pip install yt-dlp
```

Or alternatively, you can install it via the Windows Package Manager:

```cmd
winget install yt-dlp
```

### 3. Verify yt-dlp Installation

Test the installation:

```cmd
yt-dlp --version
```

You should see the version number if installation was successful.

## Features Implemented

### 1. Real YouTube Search
- **Invidious API Integration**: Uses privacy-focused YouTube alternative frontends
- **Fallback Mechanism**: Multiple Invidious instances for reliability
- **Mock Fallback**: Generates realistic mock data if APIs are unavailable
- **Rich Metadata**: Retrieves title, artist, duration, view count, upload date

### 2. Audio Download with yt-dlp
- **High-Quality Audio**: Downloads best available audio quality
- **MP3 Conversion**: Automatically converts to MP3 format
- **Progress Tracking**: Real-time download progress updates
- **Error Handling**: Comprehensive error management and retry mechanisms

### 3. Download Manager
- **Queue Management**: Handles multiple concurrent downloads
- **Progress Monitoring**: Real-time progress for each download
- **Status Tracking**: Pending, downloading, completed, failed, cancelled states
- **Retry Mechanism**: Ability to retry failed downloads
- **Cleanup Options**: Clear completed or failed downloads

### 4. Stream URL Extraction
- **Direct Playback**: Get streaming URLs without downloading
- **Quality Selection**: Choose audio quality for streaming
- **Real-time Access**: Extract URLs for immediate playback

## Directory Structure

The app will create the following directories:

- **Windows**: `%USERPROFILE%\Music\YouTube Downloads\`
- **Other Platforms**: `$HOME/Music/YouTube Downloads/`

## API Endpoints Used

### Invidious Instances
1. Primary: `https://invidious.io/api/v1/search`
2. Fallback: `https://vid.puffyan.us/api/v1/search`

### Search Parameters
- `q`: Search query
- `type`: video (only videos)
- `page`: 1 (first page of results)

## Usage Instructions

### Searching for Music
1. Open the search screen (search icon in top bar or "Search" in sidebar)
2. Enter your search query (song name, artist, etc.)
3. Press Enter or click Search
4. Browse through real YouTube results

### Downloading Music
1. Find a track in search results
2. Click the download button
3. Track is added to download queue
4. Monitor progress in Download Manager

### Managing Downloads
1. Click the download icon in the top bar
2. View all downloads with their status
3. Retry failed downloads
4. Clear completed downloads
5. Cancel ongoing downloads

## Technical Implementation

### Search Service (`youtube_service.dart`)
```dart
// Real API search with fallback
Future<List<SearchResult>> searchVideos(String query, {int maxResults = 20})

// Extract video metadata
Future<Map<String, dynamic>?> getVideoInfo(String videoId)

// Download audio with progress tracking
Future<DownloadTask> downloadAudio(String videoId, String outputPath, {
  Function(double)? onProgress,
  String quality = 'best',
})

// Get streaming URL for direct playback
Future<String?> getStreamUrl(String videoId, {String quality = 'best'})
```

### Download Manager (`download_manager_provider.dart`)
```dart
// Add download to queue
Future<void> addDownload(SearchResult searchResult)

// Retry failed download
Future<void> retryDownload(String taskId)

// Cancel active download
void cancelDownload(String taskId)

// Check if video is already downloaded
bool isVideoDownloaded(String videoId)
```

## Troubleshooting

### Common Issues

1. **yt-dlp not found**
   - Ensure Python is installed and added to PATH
   - Reinstall yt-dlp: `pip install --upgrade yt-dlp`

2. **Download fails**
   - Check internet connection
   - Verify the YouTube video is available
   - Try updating yt-dlp: `pip install --upgrade yt-dlp`

3. **Slow downloads**
   - Adjust concurrent download limit in `DownloadManager`
   - Check available bandwidth

4. **Search returns no results**
   - Invidious instances might be down
   - App will fall back to mock results automatically

### Debug Commands

Test yt-dlp directly:
```cmd
# Test video info extraction
yt-dlp --dump-json --no-download "https://www.youtube.com/watch?v=VIDEO_ID"

# Test audio download
yt-dlp --extract-audio --audio-format mp3 "https://www.youtube.com/watch?v=VIDEO_ID"

# Get stream URL
yt-dlp --get-url --format "bestaudio/best" "https://www.youtube.com/watch?v=VIDEO_ID"
```

## Performance Considerations

- **Concurrent Downloads**: Limited to 3 simultaneous downloads
- **API Rate Limiting**: Implements proper delays between requests
- **Memory Management**: Efficient handling of large download queues
- **Cache Management**: Avoids duplicate downloads

## Future Enhancements

1. **Playlist Download**: Support for downloading entire YouTube playlists
2. **Quality Selection**: User-configurable audio quality settings
3. **Metadata Enhancement**: Extract album art and enhanced metadata
4. **Offline Sync**: Sync downloads across devices
5. **Format Options**: Support for different audio formats (FLAC, WAV, etc.)

## Legal Considerations

- Only download content you have permission to download
- Respect YouTube's Terms of Service
- Use downloaded content for personal use only
- Consider supporting artists through official channels

## Updates and Maintenance

Keep yt-dlp updated for best compatibility:
```cmd
pip install --upgrade yt-dlp
```

The app includes automatic yt-dlp installation and update mechanisms for seamless user experience.
