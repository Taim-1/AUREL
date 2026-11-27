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
  static const _accountScopeKey = 'aurel.library.account_scope.v1';

  String _accountScope = 'guest';

  String _collectionKey(String key) =>
      _accountScope == 'guest' ? key : '$key.$_accountScope';

  /// Keeps local collections isolated per Firebase UID. Downloads remain
  /// device-owned and deliberately use their original global storage key.
  Future<void> setAccountScope(String? userId) async {
    final normalized = userId?.trim() ?? '';
    final nextScope = normalized.isEmpty ? 'guest' : normalized;
    final previousScope = await _preferences.getString(_accountScopeKey);

    // Move pre-account library data into the first account that claims this
    // device's guest collection. Never copy one signed-in user's library into
    // a different signed-in user's namespace.
    if (nextScope != 'guest' &&
        (previousScope == null || previousScope == 'guest')) {
      await _migrateLegacyGuestCollection(_favoritesKey, nextScope);
      await _migrateLegacyGuestCollection(_playlistsKey, nextScope);
      await _migrateLegacyGuestCollection(_recentKey, nextScope);
    }

    _accountScope = nextScope;
    await _preferences.setString(_accountScopeKey, nextScope);
  }

  Future<void> _migrateLegacyGuestCollection(
    String legacyKey,
    String targetScope,
  ) async {
    final targetKey = '$legacyKey.$targetScope';
    final target = await _preferences.getStringList(targetKey);
    final legacy = await _preferences.getStringList(legacyKey);
    if (target == null && legacy != null) {
      await _preferences.setStringList(targetKey, legacy);
    }
    if (legacy != null) {
      await _preferences.remove(legacyKey);
    }
  }

  Future<List<Track>> loadFavorites() =>
      _readTracks(_collectionKey(_favoritesKey));

  Future<List<Track>> loadDownloads() =>
      _readTracks(_downloadsKey, includeAurelDownloads: true);

  Future<List<Track>> loadRecentlyPlayed() =>
      _readTracks(_collectionKey(_recentKey));

  Future<bool> loadOfflineMode() async =>
      await _preferences.getBool(_offlineModeKey) ?? false;

  Future<void> saveOfflineMode(bool enabled) =>
      _preferences.setBool(_offlineModeKey, enabled);

  Future<List<MusicPlaylist>> loadPlaylists() async {
    final raw = await _preferences.getStringList(_collectionKey(_playlistsKey)) ??
        const <String>[];
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

  Future<List<Track>> _readTracks(
    String key, {
    bool includeAurelDownloads = false,
  }) async {
    final raw = await _preferences.getStringList(key) ?? const <String>[];
    final tracks = <Track>[];
    for (final item in raw) {
      try {
        final json = jsonDecode(item) as Map<String, dynamic>;
        tracks.add(
          includeAurelDownloads
              ? Track.fromDownloadedJson(json)
              : Track.fromJson(json),
        );
      } on FormatException {
        // Ignore a corrupted saved item without losing the rest of the library.
      } on TypeError {
        // Ignore an item written by an incompatible older schema.
      }
    }
    return tracks;
  }

  Future<void> saveFavorites(List<Track> tracks) =>
      _writeTracks(_collectionKey(_favoritesKey), tracks);

  Future<void> saveDownloads(List<Track> tracks) =>
      _writeTracks(_downloadsKey, tracks);

  Future<void> saveRecentlyPlayed(List<Track> tracks) =>
      _writeTracks(_collectionKey(_recentKey), tracks);

  Future<void> savePlaylists(List<MusicPlaylist> playlists) =>
      _preferences.setStringList(
        _collectionKey(_playlistsKey),
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
