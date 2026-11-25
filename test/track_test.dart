import 'package:flutter_test/flutter_test.dart';
import 'package:aurel/data/models/track.dart';

void main() {
  group('Track.fromJamendo', () {
    test('maps stream and per-track download permission', () {
      final track = Track.fromJamendo({
        'id': 'track-1',
        'name': 'Golden Hour',
        'artist_name': 'Aurel Artist',
        'audio': 'https://example.com/audio.mp3',
        'audiodownload': 'https://example.com/download.mp3',
        'audiodownload_allowed': true,
        'duration': 205,
        'image': 'https://example.com/art.jpg',
      });

      expect(track.id, 'track-1');
      expect(track.title, 'Golden Hour');
      expect(track.durationMs, 205000);
      expect(track.downloadAllowed, isTrue);
    });

    test('does not allow a download when the artist has disabled it', () {
      final track = Track.fromJamendo({
        'id': 'track-2',
        'name': 'No Download',
        'audio': 'https://example.com/audio.mp3',
        'audiodownload': '',
        'audiodownload_allowed': false,
      });

      expect(track.downloadAllowed, isFalse);
      expect(track.downloadUrl, isEmpty);
    });
  });
}
