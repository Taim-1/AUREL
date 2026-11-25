import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';

class LibraryRepository {
  LibraryRepository(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const _favoritesKey = 'aurel.favorites.v1';
  static const _downloadsKey = 'aurel.downloads.v1';
  static const _clientIdKey = 'aurel.jamendo.client_id';

  Future<List<Track>> loadFavorites() => _readTracks(_favoritesKey);

  Future<List<Track>> loadDownloads() => _readTracks(_downloadsKey);

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

  Future<void> _writeTracks(String key, List<Track> tracks) =>
      _preferences.setStringList(
        key,
        tracks.map((track) => jsonEncode(track.toJson())).toList(),
      );

  Future<String?> loadClientId() => _preferences.getString(_clientIdKey);

  Future<void> saveClientId(String value) =>
      _preferences.setString(_clientIdKey, value.trim());
}
