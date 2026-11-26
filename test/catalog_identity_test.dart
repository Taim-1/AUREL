import 'package:aurel/data/catalog/catalog_identity.dart';
import 'package:aurel/data/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

Track recording({
  String id = 'one',
  String title = 'Blue Hour',
  String artist = 'Aurel Artist',
  String isrc = '',
  int duration = 200000,
}) =>
    Track(
      id: id,
      title: title,
      artist: artist,
      recordingId: isrc,
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
}
