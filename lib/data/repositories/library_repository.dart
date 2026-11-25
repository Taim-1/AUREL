import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_playlist.dart';
import '../models/track.dart';

class LibraryRepository {
  LibraryRepository(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const _favoritesKey = 'aurel.favorites.v1';
  static const _downloadsKey = 'aurel.downloads.v1';
  static const _playlistsKey = 'aurel.playlists.v1';
  static const _recentKey = 'aurel.recent.v1';
  static const _clientIdKey = 'aurel.jamendo.client_id';
  static const _offlineModeKey = 'aurel.offline_mode.v1';

  Future<List<Track>> loadFavorites() => _readTracks(_favoritesKey);

  Future<List<Track>> loadDownloads() => _readTracks(_downloadsKey);

  Future<List<Track>> loadRecentlyPlayed() => _readTracks(_recentKey);

  Future<bool> loadOfflineMode() async =>
      await _preferences.getBool(_offlineModeKey) ?? false;

  Future<void> saveOfflineMode(bool enabled) =>
      _preferences.setBool(_offlineModeKey, enabled);

  Future<List<MusicPlaylist>> loadPlaylists() async {
    final raw = await _preferences.getStringList(_playlistsKey) ?? const <String>[];
    final playlists = <MusicPlaylist>[];
    for (final item in raw) {
      try {
        playlists.add(
          MusicPlaylist.fromJson(jsonDecode(item) as Map<String, dynamic>),
        );
      } on FormatException {
        // Ignore one corrupted playlist without losing the rest.
      } on TypeError {
        // Ignore data from an incompatible older schema.
      }
    }
    return playlists;
  }

  Future<List<Track>> _readTracks(String key) async {
    final raw = await _preferences.getStringList(key) ?? const <String>[];
    final tracks = <Track>[];
    for (final item in raw) {
      try {
        tracks.add(Track.fromJson(jsonDecode(item) as Map<String, dynamic>));
      } on FormatException {
        // Ignore a corrupted saved item without losing the rest of the library.
      } on TypeError {
        // Ignore an item written by an incompatible older schema.
      }
    }
    return tracks;
  }

  Future<void> saveFavorites(List<Track> tracks) =>
      _writeTracks(_favoritesKey, tracks);

  Future<void> saveDownloads(List<Track> tracks) =>
      _writeTracks(_downloadsKey, tracks);

  Future<void> saveRecentlyPlayed(List<Track> tracks) =>
      _writeTracks(_recentKey, tracks);

  Future<void> savePlaylists(List<MusicPlaylist> playlists) =>
      _preferences.setStringList(
        _playlistsKey,
        playlists.map((playlist) => jsonEncode(playlist.toJson())).toList(),
      );

  Future<void> _writeTracks(String key, List<Track> tracks) =>
      _preferences.setStringList(
        key,
        tracks.map((track) => jsonEncode(track.toJson())).toList(),
      );

  Future<String?> loadClientId() => _preferences.getString(_clientIdKey);

  Future<void> saveClientId(String value) =>
      _preferences.setString(_clientIdKey, value.trim());
}
