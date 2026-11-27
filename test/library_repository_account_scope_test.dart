import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:aurel/data/models/music_playlist.dart';
import 'package:aurel/data/models/track.dart';
import 'package:aurel/data/repositories/library_repository.dart';

Track savedTrack(String id, String title) => Track(
      id: id,
      title: title,
      artist: 'AUREL Artist',
      providerId: 'jamendo',
      streamUrl: 'https://audio.example/$id.mp3',
    );

void main() {
  group('LibraryRepository account isolation', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('keeps each account favorites and playlists in its own namespace',
        () async {
      final repository = LibraryRepository(SharedPreferencesAsync());
      final accountATrack = savedTrack('account-a', 'Account A Song');
      final accountBTrack = savedTrack('account-b', 'Account B Song');

      final playlistA = MusicPlaylist(
        id: 'playlist-a',
        name: 'Account A',
        tracks: [accountATrack],
      );
      final playlistB = MusicPlaylist(
        id: 'playlist-b',
        name: 'Account B',
        tracks: [accountBTrack],
      );

      await repository.setAccountScope('firebase-user-a');
      await repository.saveFavorites([accountATrack]);
      await repository.savePlaylists([playlistA]);

      await repository.setAccountScope('firebase-user-b');
      expect(await repository.loadFavorites(), isEmpty);
      expect(await repository.loadPlaylists(), isEmpty);
      await repository.saveFavorites([accountBTrack]);
      await repository.savePlaylists([playlistB]);

      await repository.setAccountScope('firebase-user-a');
      expect(
        (await repository.loadFavorites()).map((track) => track.id),
        ['account-a'],
      );
      expect(
        (await repository.loadPlaylists()).map((playlist) => playlist.id),
        ['playlist-a'],
      );

      await repository.setAccountScope('firebase-user-b');
      expect(
        (await repository.loadFavorites()).map((track) => track.id),
        ['account-b'],
      );
      expect(
        (await repository.loadPlaylists()).map((playlist) => playlist.id),
        ['playlist-b'],
      );
    });

    test('migrates a legacy guest library only into its first account',
        () async {
      final legacyTrack = savedTrack('legacy-song', 'Legacy Song');
      final preferences = SharedPreferencesAsync();
      await preferences.setStringList(
        'aurel.favorites.v1',
        [jsonEncode(legacyTrack.toJson())],
      );

      final repository = LibraryRepository(preferences);
      await repository.setAccountScope('firebase-user-a');
      expect(
        (await repository.loadFavorites()).single.id,
        'legacy-song',
      );

      await repository.setAccountScope(null);
      await repository.setAccountScope('firebase-user-b');
      expect(await repository.loadFavorites(), isEmpty);
    });

    test('keeps device downloads available when the signed-in account changes',
        () async {
      final download = savedTrack('offline-song', 'Offline Song').copyWith(
        isDownloaded: true,
        localPath: '/private/AUREL Downloads/offline-song.mp3',
      );
      final repository = LibraryRepository(SharedPreferencesAsync());

      await repository.setAccountScope('firebase-user-a');
      await repository.saveDownloads([download]);
      await repository.setAccountScope('firebase-user-b');

      expect(
        (await repository.loadDownloads()).map((track) => track.id),
        ['offline-song'],
      );
    });
  });
}
