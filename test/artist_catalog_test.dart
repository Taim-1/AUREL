import 'package:aurel/data/catalog/artist_catalog.dart';
import 'package:aurel/data/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

Track track({
  required String id,
  String artist = 'Aurel Artist',
  String album = '',
  String title = 'Song',
  String provider = 'jamendo',
  String artwork = '',
  String stream = 'https://audio.example/song.mp3',
  String recordingId = '',
}) =>
    Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      providerId: provider,
      artworkUrl: artwork,
      recordingId: recordingId,
      streamUrl: stream,
    );

void main() {
  group('ArtistCatalog.tracksForArtist', () {
    test('matches normalized artist credits but excludes other artists', () {
      final result = ArtistCatalog.tracksForArtist(
        '  AUREL   ARTIST ',
        [
          track(id: 'one'),
          track(id: 'two', artist: 'Other Artist'),
          track(id: 'three', artist: 'aurel artist'),
        ],
      );

      expect(result.map((item) => item.id), containsAll(['one', 'three']));
      expect(result, hasLength(2));
    });

    test('removes duplicate provider records without merging other sources', () {
      final result = ArtistCatalog.tracksForArtist(
        'Aurel Artist',
        [
          track(id: 'same', title: 'First copy'),
          track(id: 'same', title: 'Duplicate copy'),
          track(id: 'same', provider: 'audius', title: 'Independent provider copy'),
        ],
      );

      expect(result, hasLength(2));
      expect(
        result.map((item) => '${item.providerId}:${item.id}').toSet(),
        {'jamendo:same', 'audius:same'},
      );
    });

    test('includes a recording when an alternate catalogue has the artist credit', () {
      final primary = track(
        id: 'audius-1',
        provider: 'audius',
        artist: 'Different spelling',
      ).copyWith(
        alternatives: [
          track(
            id: 'musicbrainz-1',
            provider: 'musicbrainz',
            artist: 'Aurel Artist',
            stream: '',
          ),
        ],
      );

      final result = ArtistCatalog.tracksForArtist(
        'Aurel Artist',
        [primary],
      );

      expect(result, hasLength(1));
      expect(result.single.id, 'audius-1');
      expect(result.single.alternatives.single.artist, 'Aurel Artist');
    });

    test('matches a complete featured artist credit', () {
      final result = ArtistCatalog.tracksForArtist(
        'Guest Artist',
        [
          track(
            id: 'featured',
            artist: 'Aurel Artist feat. Guest Artist',
          ),
          track(id: 'unrelated', artist: 'Guest Artists United'),
        ],
      );

      expect(result.map((item) => item.id), ['featured']);
    });

    test('merges verified cross-provider copies into one artist result', () {
      final result = ArtistCatalog.tracksForArtist(
        'Aurel Artist',
        [
          track(
            id: 'jamendo-1',
            provider: 'jamendo',
            recordingId: 'USABC2600001',
          ),
          track(
            id: 'audius-1',
            provider: 'audius',
            recordingId: 'US-ABC-26-00001',
          ),
        ],
      );

      expect(result, hasLength(1));
      expect(result.single.providerId, 'audius');
      expect(result.single.alternatives, hasLength(1));
      expect(result.single.alternatives.single.providerId, 'jamendo');
    });

    test('shows only standard versions on artist pages', () {
      final result = ArtistCatalog.tracksForArtist(
        'Aurel Artist',
        [
          track(id: 'standard', title: 'Blue Hour'),
          track(id: 'live', title: 'Blue Hour (Live at Wembley)'),
          track(id: 'remix', title: 'Blue Hour - Remix'),
          track(id: 'acoustic', title: 'Blue Hour [Acoustic Version]'),
          track(id: 'slowed', title: 'Blue Hour (Slowed + Reverb)'),
          track(id: 'sped', title: 'Blue Hour - Sped Up'),
          track(id: 'karaoke', title: 'Blue Hour (Karaoke)'),
          track(id: 'cover', title: 'Blue Hour - Cover'),
          track(id: 'demo', title: 'Blue Hour (Demo)'),
        ],
      );

      expect(result.map((item) => item.id), ['standard']);
    });

    test('excludes live and remix albums from artist discographies', () {
      final result = ArtistCatalog.tracksForArtist(
        'Aurel Artist',
        [
          track(id: 'studio', album: 'First Light'),
          track(id: 'live-album', album: 'Live at Wembley'),
          track(id: 'unplugged', album: 'MTV Unplugged'),
          track(id: 'remixes', album: 'The Remixes'),
          track(id: 'sessions', album: 'Acoustic Sessions'),
        ],
      );

      expect(result.map((item) => item.id), ['studio']);
    });

    test('does not reject an ordinary title containing the word live', () {
      final result = ArtistCatalog.tracksForArtist(
        'Aurel Artist',
        [
          track(id: 'live-title', title: 'Live Your Life'),
          track(id: 'live-suffix', title: 'A Life - Live'),
        ],
      );

      expect(result.map((item) => item.id), ['live-title']);
    });

    test('keeps the original version when a merged result also has a remix', () {
      final original = track(
        id: 'original',
        title: 'Blue Hour',
        recordingId: 'USABC2600001',
      ).copyWith(
        alternatives: [
          track(
            id: 'remix',
            title: 'Blue Hour (Remix)',
            recordingId: 'USABC2600001',
            provider: 'audius',
          ),
        ],
      );

      final result = ArtistCatalog.tracksForArtist(
        'Aurel Artist',
        [original],
      );

      expect(result, hasLength(1));
      expect(result.single.id, 'original');
      expect(result.single.alternatives, isEmpty);
    });

    test('keeps distinct tracks when a provider omits stable IDs', () {
      final result = ArtistCatalog.tracksForArtist(
        'Aurel Artist',
        [
          track(id: '', title: 'Opening', album: 'No IDs'),
          track(id: '', title: 'Closing', album: 'No IDs'),
        ],
      );

      expect(result, hasLength(2));
    });

    test('returns an immutable empty result for a blank artist', () {
      expect(ArtistCatalog.tracksForArtist('   ', const []), isEmpty);
    });

    test('does not create matches from empty or unrelated artist metadata', () {
      final result = ArtistCatalog.tracksForArtist(
        'Aurel Artist',
        [
          track(id: 'blank', artist: ''),
          track(id: 'other', artist: 'Aurel Artists'),
        ],
      );

      expect(result, isEmpty);
    });
  });

  group('ArtistCatalog.albumsForTracks', () {
    test('groups normalized album titles and excludes singles', () {
      final albums = ArtistCatalog.albumsForTracks([
        track(id: 'one', album: 'First Light'),
        track(id: 'two', album: ' first   light '),
        track(id: 'three', album: ''),
        track(id: 'four', album: 'Second Dawn'),
      ]);

      expect(albums, hasLength(2));
      expect(albums.map((album) => album.title), ['First Light', 'Second Dawn']);
      expect(albums.first.trackCount, 2);
      expect(albums.last.trackCount, 1);
    });

    test('keeps same track IDs from different providers distinct', () {
      final albums = ArtistCatalog.albumsForTracks([
        track(id: 'shared', album: 'One Album'),
        track(id: 'shared', provider: 'audius', album: 'One Album'),
      ]);

      expect(albums.single.trackCount, 2);
    });

    test('does not collapse different songs with missing IDs', () {
      final albums = ArtistCatalog.albumsForTracks([
        track(id: '', title: 'Opening', album: 'No IDs'),
        track(id: '', title: 'Closing', album: 'No IDs'),
      ]);

      expect(albums.single.trackCount, 2);
    });

    test('uses the first available album artwork', () {
      final albums = ArtistCatalog.albumsForTracks([
        track(id: 'without-art', album: 'One Album'),
        track(
          id: 'with-art',
          album: 'One Album',
          artwork: 'https://images.example/cover.jpg',
        ),
      ]);

      expect(albums.single.artworkUrl, 'https://images.example/cover.jpg');
    });

    test('returns album groups with immutable track collections', () {
      final albums = ArtistCatalog.albumsForTracks([
        track(id: 'one', album: 'One Album'),
      ]);

      expect(
        () => albums.single.tracks.add(track(id: 'two', album: 'One Album')),
        throwsUnsupportedError,
      );
    });
  });
}
