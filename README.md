# Windows Music Player

A modern Flutter music player with YouTube streaming integration, built for Windows and Android.

## Features

- **YouTube Streaming** — Search and stream music directly via yt-dlp
- **Dark Mode UI** — Three-pane responsive layout with persistent player controls
- **Queue Management** — Play, reorder, and loop through track queues
- **Playlist Import** — Import YouTube playlists by URL and save them locally
- **Download Manager** — Download tracks for offline playback

## Architecture

```
lib/
├── main.dart                    # App entry point
├── theme.dart                   # Color scheme & typography
├── models/
│   ├── track.dart               # Track data model
│   ├── playlist.dart            # Playlist & DownloadTask models
│   ├── search_result.dart       # YouTube search result model
│   ├── youtube_artist.dart      # YouTube artist model
│   └── youtube_playlist.dart    # YouTube playlist model
├── providers/
│   ├── audio_player_provider.dart   # Audio state, queue, repeat/shuffle
│   ├── download_manager_provider.dart # Download queue management
│   └── playlist_provider.dart       # Library & playlist state
├── screens/
│   ├── home_screen.dart         # Trending music, artists, playlists
│   ├── search_screen.dart       # YouTube search & playlist import
│   ├── queue_screen.dart        # Current playback queue
│   └── download_manager_screen.dart # Download progress & history
├── services/
│   ├── audio_service.dart       # just_audio wrapper & streams
│   ├── youtube_service.dart     # YouTube API & yt-dlp integration
│   └── theme_service.dart       # Theme state management
└── widgets/
    ├── app_scaffold.dart        # Three-pane shell & navigation
    ├── left_side_panel.dart     # Player card & saved playlists
    └── right_side_panel.dart    # Navigation sidebar & volume
```

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.10
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) installed and in PATH (for YouTube streaming)

### Run

```bash
flutter pub get
flutter run -d windows
```

## Tech Stack

- **Flutter** + **Riverpod** for state management
- **just_audio** for audio playback
- **yt-dlp** for YouTube stream URL extraction
