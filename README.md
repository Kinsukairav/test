# Windows Music Player

A comprehensive Windows Music Player built with Flutter Dart that uses YouTube as a backend to fetch details and download songs in the highest quality possible.

## Features

### Core Functionality
- **YouTube Integration**: Search and download music from YouTube
- **High-Quality Audio**: Support for FLAC, WAV, MP3 formats with high bitrate
- **Audio Playback**: Advanced audio player with seek, volume, and quality controls
- **Playlist Management**: Create, edit, and organize playlists
- **Download Manager**: Queue and track music downloads with progress indicators

### User Interface
- **Main Player Screen**: Full-featured player with album art, metadata, and controls
- **Left Side Panel**: Navigation for library, playlists, favorites, and downloads
- **Top Bar**: Search, voice search, download controls, and settings
- **Responsive Design**: Optimized for Windows desktop with mobile compatibility
- **Dark/Light Theme**: Toggle between themes with system integration

### Advanced Features
- **Voice Search**: Search for music using voice commands
- **Equalizer**: Customize audio output with multi-band equalizer
- **Lyrics Display**: Show synchronized lyrics for tracks
- **Favorites System**: Like and organize favorite tracks
- **Queue Management**: Add, remove, and reorder tracks in queue
- **Shuffle & Repeat**: Various playback modes
- **Audio Quality Info**: Display sample rate, bit depth, and format information

## Project Status

**Current Implementation:** Basic Flutter project structure with placeholder implementations.

### ✅ Completed
- Flutter project scaffolding
- UI component structure
- State management setup (Riverpod)
- Theme system
- Navigation structure
- All widget files created

### 🔧 Next Steps for Full Implementation
To make this a fully functional music player, you'll need to:

1. **Add Audio Dependencies**: 
   ```yaml
   dependencies:
     just_audio: ^0.9.36
     audio_service: ^0.18.12
   ```

2. **Add YouTube Integration**:
   ```yaml
   dependencies:
     youtube_explode_dart: ^2.0.2
   ```

3. **Replace Placeholder Services**: The current audio and YouTube services contain placeholder implementations that need real functionality.

## Prerequisites

### Required Software
1. **Flutter SDK** (>=3.10.0)
   - Download from: https://flutter.dev/docs/get-started/install
   - Add Flutter to your system PATH

2. **Dart SDK** (>=3.0.0)
   - Included with Flutter SDK

3. **Windows SDK** (for Windows desktop support)
   - Visual Studio 2022 with Windows development workload
   - Or Visual Studio Build Tools 2022

4. **Git** (for version control)
   - Download from: https://git-scm.com/

### Optional Dependencies
- **yt-dlp**: For enhanced YouTube downloading (auto-installed)
- **FFmpeg**: For audio format conversion (auto-installed)

## Quick Start

### 1. Prerequisites
- Flutter SDK (>=3.10.0) - Download from https://flutter.dev/docs/get-started/install
- Add Flutter to your system PATH

### 2. Setup
```bash
# Enable Windows desktop support
flutter config --enable-windows-desktop

# Install dependencies
flutter pub get

# Check setup
flutter doctor
```

### 3. Run the Application
```bash
flutter run -d windows
```

**OR** in VS Code: Press `F5` to launch with debug configuration

## Project Structure

```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
│   ├── track.dart           # Track model with metadata
│   └── playlist.dart        # Playlist and download models
├── services/                 # Business logic services
│   ├── audio_service.dart   # Audio playback service
│   ├── youtube_service.dart # YouTube integration
│   └── theme_service.dart   # Theme management
├── providers/               # State management
│   ├── audio_player_provider.dart
│   └── playlist_provider.dart
├── screens/                 # Main application screens
│   └── main_player_screen.dart
└── widgets/                 # Reusable UI components
    ├── player_controls.dart
    ├── track_metadata_display.dart
    ├── seek_bar.dart
    ├── volume_control.dart
    ├── top_bar.dart
    ├── left_side_panel.dart
    └── playlist_panel.dart
```

## Dependencies

### Audio & Media
- `just_audio`: High-quality audio playback
- `just_audio_windows`: Windows-specific audio support
- `audio_service`: Background audio service
- `youtube_explode_dart`: YouTube video/audio extraction

### UI & Theming
- `material_design_icons_flutter`: Extended icon set
- `flutter_staggered_animations`: UI animations
- `sliding_up_panel`: Sliding panels for mobile

### State Management
- `flutter_riverpod`: Reactive state management
- `provider`: Additional state management utilities

### Storage & Files
- `hive`: Local database storage
- `path_provider`: System directory access
- `file_picker`: File selection dialogs
- `shared_preferences`: Settings storage

### Network & Downloads
- `http`: HTTP requests
- `dio`: Advanced HTTP client with download progress

### Platform Integration
- `window_manager`: Windows window management
- `desktop_window`: Desktop window utilities
- `permission_handler`: System permissions

### Voice & Audio Processing
- `speech_to_text`: Voice recognition
- `flutter_equalizer`: Audio equalizer
- `flutter_lyric`: Lyrics display

## Usage

### Basic Playback
1. **Search Music**: Use the search bar or voice search to find tracks
2. **Download**: Click the download button and paste YouTube URLs
3. **Play**: Select tracks from your library or playlists
4. **Control**: Use play/pause, skip, seek, and volume controls

### Advanced Features
- **Create Playlists**: Use the left panel to create and manage playlists
- **Favorites**: Click the heart icon to add tracks to favorites
- **Queue Management**: Use the queue panel to manage upcoming tracks
- **Equalizer**: Access through the equalizer button for audio customization
- **Lyrics**: View synchronized lyrics when available

### Keyboard Shortcuts
- `Space`: Play/Pause
- `Ctrl+F`: Focus search
- `Ctrl+N`: Create new playlist
- `Ctrl+L`: Toggle lyrics
- `Ctrl+E`: Open equalizer

## Configuration

### Settings Location
- Windows: `%APPDATA%\MusicPlayer\`
- Settings file: `settings.json`

### Download Location
- Default: `Documents\MusicDownloads\`
- Configurable through settings

## Troubleshooting

### Common Issues

1. **Flutter not recognized**
   - Ensure Flutter is added to system PATH
   - Run `flutter doctor` to check installation

2. **Windows build fails**
   - Install Visual Studio with Windows development workload
   - Run `flutter doctor` to verify Windows toolchain

3. **Audio playback issues**
   - Check Windows audio drivers
   - Verify audio device selection in settings

4. **Download failures**
   - Check internet connection
   - Verify YouTube URL format
   - Check available disk space

### Debug Mode
Run with verbose logging:
```bash
flutter run -d windows --verbose
```

## Building for Production

### Debug Build
```bash
flutter build windows --debug
```

### Release Build
```bash
flutter build windows --release
```

### Create Installer
```bash
# Using MSIX (recommended)
flutter pub add msix
flutter pub get
flutter build windows --release
flutter pub run msix:create
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the excellent framework
- YouTube Explode library for YouTube integration
- Just Audio plugin for high-quality audio playback
- Material Design team for design guidelines

## Support

For issues and feature requests, please use the GitHub issue tracker.

---

**Note**: This application is for personal use only. Respect YouTube's Terms of Service and copyright laws when downloading content.
# Music
