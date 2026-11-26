import 'package:aurel/data/catalog/catalog_identity.dart';
import 'package:aurel/data/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

Track recording({
  String id = 'one',
  String title = 'Blue Hour',
  String artist = 'Aurel Artist',
  String isrc = '',
  String mbid = '',
  String provider = 'jamendo',
  int duration = 200000,
}) =>
    Track(
      id: id,
      title: title,
      artist: artist,
      recordingId: isrc,
      recordingMbid: mbid,
      providerId: provider,
      durationMs: duration,
      streamUrl: 'https://example.com/audio.mp3',
    );

void main() {
  group('CatalogIdentity', () {
    test('matches exact ISRC even when catalogue metadata differs', () {
      expect(
        CatalogIdentity.matches(
          recording(title: 'Blue Hour', isrc: 'US-ABC-26-00001'),
          recording(
            id: 'metadata',
            title: 'Blue Hour (Remastered)',
            isrc: 'USABC2600001',
          ),
        ),
        isTrue,
      );
    });

    test('matches fallback title, artist and close duration', () {
      expect(
        CatalogIdentity.matches(
          recording(title: 'Blue Hour!', duration: 200000),
          recording(
            id: 'other-source',
            title: 'blue   hour',
            artist: 'AUREL ARTIST',
            duration: 204500,
          ),
        ),
        isTrue,
      );
    });

    test('does not merge different ISRCs', () {
      expect(
        CatalogIdentity.matches(
          recording(isrc: 'USABC2600001'),
          recording(id: 'other', isrc: 'USABC2600002'),
        ),
        isFalse,
      );
    });

    test('keeps meaningful versions separate without matching ISRCs', () {
      expect(
        CatalogIdentity.matches(
          recording(title: 'Blue Hour'),
          recording(id: 'live', title: 'Blue Hour (Live)'),
        ),
        isFalse,
      );
      expect(
        CatalogIdentity.matches(
          recording(title: 'Blue Hour'),
          recording(id: 'remix', title: 'Blue Hour Remix'),
        ),
        isFalse,
      );
    });

    test('does not let an ambiguous entry bridge different ISRCs', () {
      final first = recording(
        id: 'first',
        title: 'Same Title',
        isrc: 'USABC2600001',
        duration: 200000,
      );
      final second = recording(
        id: 'second',
        title: 'Same Title',
        isrc: 'USABC2600002',
        duration: 204000,
      );
      final ambiguous = recording(
        id: 'ambiguous',
        title: 'Same Title',
        duration: 202000,
      );

      final groups = CatalogIdentity.group([first, second, ambiguous]);

      expect(groups, hasLength(3));
      expect(groups[0], [first]);
      expect(groups[1], [second]);
      expect(groups[2], [ambiguous]);
    });

    test('groups one matching recording across catalogues', () {
      final first = recording(id: 'first', duration: 200000);
      final second = recording(
        id: 'second',
        title: 'blue hour',
        artist: 'AUREL ARTIST',
        duration: 204000,
      );

      final groups = CatalogIdentity.group([first, second]);

      expect(groups, hasLength(1));
      expect(groups.single, [first, second]);
    });

    test('does not merge when duration is missing', () {
      expect(
        CatalogIdentity.matches(
          recording(duration: 0),
          recording(id: 'other', duration: 0),
        ),
        isFalse,
      );
    });

    test('does not merge tracks outside the duration tolerance', () {
      expect(
        CatalogIdentity.matches(
          recording(duration: 200000),
          recording(id: 'other', duration: 205001),
        ),
        isFalse,
      );
    });
  });

    test('matches the same provider track ID without metadata', () {
      final first = recording(
        id: 'jamendo-42',
        duration: 0,
        provider: 'jamendo',
      );
      final duplicate = recording(
        id: 'jamendo-42',
        title: 'Different catalogue formatting',
        artist: 'A different text credit',
        duration: 0,
        provider: 'jamendo',
      );

      expect(CatalogIdentity.matches(first, duplicate), isTrue);
      expect(
        CatalogIdentity.group([first, duplicate]),
        hasLength(1),
      );
    });

    test('matches exact MusicBrainz recording MBID across catalogues', () {
      expect(
        CatalogIdentity.matches(
          recording(mbid: '13dd61c7-ce73-4e97-9f0c-9f0e53144411'),
          recording(
            id: 'lastfm',
            title: 'Different title formatting',
            artist: 'Different artist formatting',
            mbid: '13DD61C7-CE73-4E97-9F0C-9F0E53144411',
          ),
        ),
        isTrue,
      );
    });

    test('uses exact ISRC when duplicate catalogue entries have different MBIDs', () {
      expect(
        CatalogIdentity.matches(
          recording(
            mbid: '13dd61c7-ce73-4e97-9f0c-9f0e53144411',
            isrc: 'USABC2600001',
          ),
          recording(
            id: 'duplicate-recording-entity',
            mbid: 'ba8701ba-dc7c-4bca-9c83-846ee8c3d576',
            isrc: 'USABC2600001',
          ),
        ),
        isTrue,
      );
    });

    test('does not merge conflicting verified recording MBIDs', () {
      expect(
        CatalogIdentity.matches(
          recording(mbid: '13dd61c7-ce73-4e97-9f0c-9f0e53144411'),
          recording(
            id: 'different-recording',
            mbid: 'ba8701ba-dc7c-4bca-9c83-846ee8c3d576',
          ),
        ),
        isFalse,
      );
    });

}
