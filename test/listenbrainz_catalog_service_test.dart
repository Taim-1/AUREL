import 'package:flutter_test/flutter_test.dart';
import 'package:aurel/data/models/track.dart';

void main() {
  group('Track.fromListenBrainz', () {
    test('maps global recording metadata without creating a stream', () {
      final track = Track.fromListenBrainz({
        'recording_mbid': '13dd61c7-ce73-4e97-9f0c-9f0e53144411',
        'release_mbid': 'ba8701ba-dc7c-4bca-9c83-846ee8c3d576',
        'track_name': 'Closer',
        'artist_name': 'Nine Inch Nails',
        'release_name': 'The Downward Spiral',
        'length': 373133,
      });

      expect(track.title, 'Closer');
      expect(track.artist, 'Nine Inch Nails');
      expect(track.album, 'The Downward Spiral');
      expect(track.durationMs, 373133);
      expect(track.providerId, 'listenbrainz');
      expect(track.recordingId, isEmpty);
      expect(track.isMetadataOnly, isTrue);
      expect(track.canPlay, isFalse);
      expect(track.streamUrl, isEmpty);
      expect(track.downloadAllowed, isFalse);
      expect(track.sourceUrl, contains('13dd61c7-ce73-4e97-9f0c-9f0e53144411'));
    });

    test('handles optional MBIDs and release metadata', () {
      final track = Track.fromListenBrainz({
        'track_name': 'Untitled',
        'artist_name': 'Unknown Artist',
      });

      expect(track.title, 'Untitled');
      expect(track.album, isEmpty);
      expect(track.artworkUrl, isEmpty);
      expect(track.sourceUrl, isEmpty);
      expect(track.canPlay, isFalse);
    });
  });
}
