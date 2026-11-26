import 'package:aurel/data/catalog/catalog_ranking.dart';
import 'package:aurel/data/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

Track track({
  String id = 'track',
  String provider = 'jamendo',
  bool playable = true,
  bool local = false,
  String stream = 'https://audio.example/track.mp3',
  String isrc = '',
  String artwork = '',
  String album = '',
  int duration = 180000,
}) =>
    Track(
      id: id,
      title: 'A Song',
      artist: 'An Artist',
      providerId: provider,
      providerName: provider,
      isPlayable: playable,
      isDeviceTrack: local,
      localPath: local ? 'content://music/$id' : null,
      streamUrl: stream,
      recordingId: isrc,
      artworkUrl: artwork,
      album: album,
      durationMs: duration,
      isMetadataOnly: !playable,
    );

void main() {
  group('CatalogRanking', () {
    test('keeps the agreed playable provider priority order', () {
      const ordered = [
        'audius',
        'jamendo',
        'soundcloud',
        'internet_archive',
        'wikimedia_commons',
        'openverse',
      ];

      for (var index = 0; index < ordered.length - 1; index++) {
        expect(
          CatalogRanking.compare(
            track(provider: ordered[index]),
            track(provider: ordered[index + 1]),
          ),
          lessThan(0),
          reason: '${ordered[index]} must outrank ${ordered[index + 1]}',
        );
      }
    });

    test('local playable music outranks every online playable source', () {
      expect(
        CatalogRanking.compare(
          track(provider: 'device', local: true),
          track(provider: 'audius'),
        ),
        lessThan(0),
      );
    });

    test('playable audio always outranks metadata-only results', () {
      expect(
        CatalogRanking.compare(
          track(provider: 'audius', playable: true),
          track(
            provider: 'apple_music',
            playable: false,
            stream: '',
          ),
        ),
        lessThan(0),
      );
    });

    test('source priority wins before metadata completeness', () {
      final preferred = track(
        provider: 'audius',
        isrc: '',
        artwork: '',
        album: '',
        duration: 0,
      );
      final lowerPriorityButRicher = track(
        provider: 'jamendo',
        isrc: 'USABC2600001',
        artwork: 'https://img.example/art.jpg',
        album: 'Album',
      );

      expect(
        CatalogRanking.compare(preferred, lowerPriorityButRicher),
        lessThan(0),
      );
    });

    test('quality breaks ties inside the same source priority', () {
      final rich = track(
        provider: 'audius',
        isrc: 'USABC2600001',
        artwork: 'https://img.example/art.jpg',
        album: 'Album',
      );
      final sparse = track(
        id: 'sparse',
        provider: 'audius',
        duration: 0,
      );

      expect(CatalogRanking.compare(rich, sparse), lessThan(0));
    });

    test('metadata-only sources follow their explicit fallback order', () {
      const ordered = [
        'apple_music',
        'spotify',
        'lastfm',
        'listenbrainz',
        'musicbrainz',
      ];

      for (var index = 0; index < ordered.length - 1; index++) {
        expect(
          CatalogRanking.compare(
            track(provider: ordered[index], playable: false, stream: ''),
            track(provider: ordered[index + 1], playable: false, stream: ''),
          ),
          lessThan(0),
        );
      }
    });
  });
}
