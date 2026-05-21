import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/playlist.dart';
import '../models/track.dart';

// Playlist provider
final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, List<Track>>((ref) {
  return PlaylistNotifier();
});

// Search results provider
final searchResultsProvider = StateProvider<List<Track>>((ref) => []);

// Download tasks provider
final downloadTasksProvider = StateProvider<List<DownloadTask>>((ref) => []);

// Current search query provider
final searchQueryProvider = StateProvider<String>((ref) => '');

class PlaylistNotifier extends StateNotifier<List<Track>> {
  PlaylistNotifier() : super([]);

  void addTrack(Track track) {
    if (!state.any((t) => t.id == track.id)) {
      state = [...state, track];
    }
  }

  void removeTrack(String trackId) {
    state = state.where((track) => track.id != trackId).toList();
  }

  void reorderTracks(int oldIndex, int newIndex) {
    final tracks = List<Track>.from(state);
    final track = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, track);
    state = tracks;
  }

  void clearPlaylist() {
    state = [];
  }

  void toggleFavorite(String trackId) {
    state = state.map((track) {
      if (track.id == trackId) {
        return track.copyWith(isFavorite: !track.isFavorite);
      }
      return track;
    }).toList();
  }

  void updatePlaylist(List<Track> newPlaylist) {
    state = newPlaylist;
  }

  List<Track> getFavorites() {
    return state.where((track) => track.isFavorite).toList();
  }

  List<Track> searchTracks(String query) {
    if (query.isEmpty) return state;

    final lowerQuery = query.toLowerCase();
    return state.where((track) {
      return track.title.toLowerCase().contains(lowerQuery) ||
          track.artist.toLowerCase().contains(lowerQuery) ||
          track.album.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  void sortTracks(SortOption sortOption) {
    final tracks = List<Track>.from(state);

    switch (sortOption) {
      case SortOption.title:
        tracks.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.artist:
        tracks.sort((a, b) => a.artist.compareTo(b.artist));
        break;
      case SortOption.album:
        tracks.sort((a, b) => a.album.compareTo(b.album));
        break;
      case SortOption.duration:
        tracks.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SortOption.dateAdded:
        tracks.sort((a, b) => b.addedDate.compareTo(a.addedDate));
        break;
    }

    state = tracks;
  }
}

enum SortOption {
  title,
  artist,
  album,
  duration,
  dateAdded,
}
