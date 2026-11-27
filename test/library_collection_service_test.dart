import 'package:flutter_test/flutter_test.dart';

import 'package:aurel/data/models/music_playlist.dart';
import 'package:aurel/data/models/track.dart';
import 'package:aurel/data/services/library_collection_service.dart';

Track track({
  required String id,
  required String title,
  required String artist,
  String album = '',
  String provider = 'jamendo',
  String license = '',
}) =>
    Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      providerId: provider,
      providerName: provider.toUpperCase(),
      licenseName: license,
      streamUrl: 'https://audio.example/$id.mp3',
    );

void main() {
  group('LibraryCollectionService collection mutations', () {
    test('toggles a cross-provider favorite using recording identity', () {
      const primary = Track(
        id: 'audius-1',
        title: 'Golden Hour',
        artist: 'AUREL Artist',
        providerId: 'audius',
        recordingMbid: 'recording-001',
      );
      const matchedAlternative = Track(
        id: 'jamendo-1',
        title: 'Golden Hour',
        artist: 'AUREL Artist',
        providerId: 'jamendo',
        recordingMbid: 'recording-001',
      );

      final saved = LibraryCollectionService.toggleFavorite([], primary);
      expect(LibraryCollectionService.isFavorite(saved, matchedAlternative), isTrue);

      final removed = LibraryCollectionService.toggleFavorite(
        saved,
        matchedAlternative,
      );
      expect(removed, isEmpty);
    });

    test('adds a matched recording only once to a playlist', () {
      const primary = Track(
        id: 'audius-2',
        title: 'Evening Light',
        artist: 'AUREL Artist',
        providerId: 'audius',
        recordingMbid: 'recording-002',
      );
      const alternative = Track(
        id: 'jamendo-2',
        title: 'Evening Light',
        artist: 'AUREL Artist',
        providerId: 'jamendo',
        recordingMbid: 'recording-002',
      );
      final playlist = MusicPlaylist(
        id: 'one',
        name: 'Evening',
        tracks: [primary],
      );

      final unchanged = LibraryCollectionService.addTrackToPlaylist(
        playlist,
        alternative,
      );

      expect(identical(unchanged, playlist), isTrue);
      expect(unchanged.tracks, hasLength(1));
    });

    test('removes only the selected provider entry when requested', () {
      const jamendo = Track(
        id: 'shared-id',
        title: 'Same title',
        artist: 'AUREL Artist',
        providerId: 'jamendo',
      );
      const audius = Track(
        id: 'shared-id',
        title: 'Same title',
        artist: 'AUREL Artist',
        providerId: 'audius',
      );
      final playlist = MusicPlaylist(
        id: 'two',
        name: 'Sources',
        tracks: [jamendo, audius],
      );

      final updated = LibraryCollectionService.removeTrackFromPlaylist(
        playlist,
        'shared-id',
        providerId: 'jamendo',
      );

      expect(updated.tracks, [audius]);
    });

    test('returns the original playlist if no matching entry exists', () {
      final playlist = MusicPlaylist(
        id: 'three',
        name: 'Untouched',
        tracks: [track(id: 'one', title: 'First', artist: 'Artist')],
      );

      final updated = LibraryCollectionService.removeTrackFromPlaylist(
        playlist,
        'missing',
        providerId: 'jamendo',
      );

      expect(identical(updated, playlist), isTrue);
    });
  });

  group('LibraryCollectionService.filterTracks', () {
    final collection = [
      track(
        id: 'one',
        title: 'Summertime Sadness',
        artist: 'Lana Del Rey',
        album: 'Born to Die',
      ),
      track(
        id: 'two',
        title: 'Midnight City',
        artist: 'M83',
        album: 'Hurry Up, We Are Dreaming',
      ),
      track(
        id: 'three',
        title: 'Video Games',
        artist: 'Lana Del Rey',
        album: 'Born to Die',
        provider: 'audius',
      ),
    ];

    test('searches title, artist and album together using multiple terms', () {
      final result = LibraryCollectionService.filterTracks(
        collection,
        query: 'lana born',
      );

      expect(result.map((item) => item.id), ['one', 'three']);
    });

    test('matches provider and licence metadata without changing track data', () {
      final openTrack = track(
        id: 'open',
        title: 'Open Piece',
        artist: 'Composer',
        provider: 'wikimedia_commons',
        license: 'CC BY-SA',
      );

      final result = LibraryCollectionService.filterTracks(
        [openTrack],
        query: 'wikimedia cc by-sa',
      );

      expect(result, hasLength(1));
      expect(result.single.id, 'open');
      expect(result.single.licenseName, 'CC BY-SA');
    });

    test('preserves the source order for recently added sorting', () {
      final result = LibraryCollectionService.filterTracks(
        collection,
        sort: LibrarySort.recentlyAdded,
      );

      expect(result.map((item) => item.id), ['one', 'two', 'three']);
    });

    test('sorts titles alphabetically with stable artist and ID tie breaks', () {
      final result = LibraryCollectionService.filterTracks(
        [
          track(id: 'b', title: 'Alpha', artist: 'Zed'),
          track(id: 'a', title: 'Alpha', artist: 'Adele'),
          track(id: 'c', title: 'Beta', artist: 'M83'),
        ],
        sort: LibrarySort.titleAscending,
      );

      expect(result.map((item) => item.id), ['a', 'b', 'c']);
    });

    test('sorts artists alphabetically then titles', () {
      final result = LibraryCollectionService.filterTracks(
        [
          track(id: 'one', title: 'Second', artist: 'Lana Del Rey'),
          track(id: 'two', title: 'First', artist: 'Lana Del Rey'),
          track(id: 'three', title: 'Anything', artist: 'Adele'),
        ],
        sort: LibrarySort.artistAscending,
      );

      expect(result.map((item) => item.id), ['three', 'two', 'one']);
    });

    test('sorts albums alphabetically then titles', () {
      final result = LibraryCollectionService.filterTracks(
        [
          track(
            id: 'one',
            title: 'First Song',
            artist: 'A',
            album: 'Zebra',
          ),
          track(
            id: 'two',
            title: 'Second Song',
            artist: 'B',
            album: 'Amber',
          ),
          track(
            id: 'three',
            title: 'Opening',
            artist: 'C',
            album: 'Amber',
          ),
        ],
        sort: LibrarySort.albumAscending,
      );

      expect(result.map((item) => item.id), ['three', 'two', 'one']);
    });

    test('returns an immutable filtered result', () {
      final result = LibraryCollectionService.filterTracks(collection);

      expect(
        () => result.add(
          track(id: 'four', title: 'New', artist: 'Artist'),
        ),
        throwsUnsupportedError,
      );
    });

    test('returns an empty result for a query with no match', () {
      expect(
        LibraryCollectionService.filterTracks(
          collection,
          query: 'artist that does not exist',
        ),
        isEmpty,
      );
    });
  });

  group('LibraryCollectionService.filterPlaylists', () {
    final playlists = [
      MusicPlaylist(
        id: 'night',
        name: 'Night Drive',
        tracks: [
          track(
            id: 'night-track',
            title: 'Midnight City',
            artist: 'M83',
          ),
        ],
      ),
      MusicPlaylist(
        id: 'acoustic',
        name: 'Quiet Moments',
        tracks: [
          track(
            id: 'quiet-track',
            title: 'Video Games',
            artist: 'Lana Del Rey',
          ),
        ],
      ),
    ];

    test('matches playlist names', () {
      final result = LibraryCollectionService.filterPlaylists(
        playlists,
        query: 'night drive',
      );

      expect(result.map((item) => item.id), ['night']);
    });

    test('matches tracks contained by a playlist', () {
      final result = LibraryCollectionService.filterPlaylists(
        playlists,
        query: 'lana games',
      );

      expect(result.map((item) => item.id), ['acoustic']);
    });

    test('returns all playlists for an empty query', () {
      expect(
        LibraryCollectionService.filterPlaylists(playlists),
        hasLength(2),
      );
    });

    test('does not mutate the source playlist collection', () {
      final result = LibraryCollectionService.filterPlaylists(
        playlists,
        query: 'quiet',
      );

      expect(result, hasLength(1));
      expect(playlists, hasLength(2));
    });
  });
  group('LibraryCollectionService grouping', () {
    test('normalizes album titles and places singles in their own group', () {
      final groups = LibraryCollectionService.groupByAlbum([
        track(
          id: 'one',
          title: 'First',
          artist: 'Aurel Artist',
          album: 'Born to Die',
        ),
        track(
          id: 'two',
          title: 'Second',
          artist: 'Aurel Artist',
          album: ' born   to die ',
        ),
        track(
          id: 'three',
          title: 'Standalone',
          artist: 'Aurel Artist',
        ),
      ]);

      expect(groups.map((group) => group.name), ['Born to Die', 'Singles']);
      expect(groups.first.tracks, hasLength(2));
      expect(groups.last.tracks.single.title, 'Standalone');
    });

    test('normalizes artist names and ignores blank artist metadata', () {
      final groups = LibraryCollectionService.groupByArtist([
        const Track(
          id: 'one',
          title: 'First',
          artist: 'Lana Del Rey',
        ),
        const Track(
          id: 'two',
          title: 'Second',
          artist: ' lana   del rey ',
        ),
        track(
          id: 'three',
          title: 'No artist',
          artist: '',
        ),
        track(
          id: 'four',
          title: 'Another',
          artist: 'Adele',
        ),
      ]);

      expect(groups.map((group) => group.name), ['Adele', 'Lana Del Rey']);
      expect(groups.last.tracks, hasLength(2));
    });

    test('keeps same IDs from distinct music providers separate', () {
      final groups = LibraryCollectionService.groupByAlbum([
        track(
          id: 'shared',
          title: 'Same Name',
          artist: 'Artist',
          album: 'Same Album',
        ),
        track(
          id: 'shared',
          title: 'Same Name',
          artist: 'Artist',
          album: 'Same Album',
          provider: 'audius',
        ),
      ]);

      expect(groups.single.tracks, hasLength(2));
    });

    test('returns immutable group lists', () {
      final groups = LibraryCollectionService.groupByArtist([
        track(id: 'one', title: 'First', artist: 'Artist'),
      ]);

      expect(
        () => groups.add(
          const LibraryTrackGroup(name: 'Another', tracks: []),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => groups.single.tracks.add(
          track(id: 'two', title: 'Second', artist: 'Artist'),
        ),
        throwsUnsupportedError,
      );
    });
  });

}
