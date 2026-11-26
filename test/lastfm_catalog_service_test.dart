import 'package:flutter_test/flutter_test.dart';
import 'package:aurel/data/models/track.dart';

void main() {
  group('Track.fromLastFm', () {
    test('maps discovery metadata without inventing playable audio', () {
      final track = Track.fromLastFm({
        'name': 'Midnight City',
        'mbid': 'recording-123',
        'url': 'https://www.last.fm/music/M83/_/Midnight+City',
        'duration': '244000',
        'artist': {'name': 'M83'},
        'album': {'title': 'Hurry Up, We’re Dreaming'},
        'image': [
          {'size': 'small', '#text': 'https://img.example/small.jpg'},
          {'size': 'large', '#text': 'https://img.example/large.jpg'},
          {'size': 'extralarge', '#text': 'https://img.example/large.jpg'},
        ],
      });

      expect(track.title, 'Midnight City');
      expect(track.artist, 'M83');
      expect(track.album, 'Hurry Up, We’re Dreaming');
      expect(track.durationMs, 244000);
      expect(track.recordingId, isEmpty);
      expect(track.artworkUrl, 'https://img.example/large.jpg');
      expect(track.providerId, 'lastfm');
      expect(track.isMetadataOnly, isTrue);
      expect(track.canPlay, isFalse);
      expect(track.streamUrl, isEmpty);
      expect(track.downloadAllowed, isFalse);
    });

    test('uses a stable fallback identity when MBID is absent', () {
      final track = Track.fromLastFm({
        'name': 'Unknown Song',
        'url': 'https://www.last.fm/music/Artist/_/Unknown+Song',
        'artist': {'name': 'Artist'},
      });

      expect(track.id, contains('lastfm-'));
      expect(track.recordingId, isEmpty);
      expect(track.canPlay, isFalse);
    });
  });
}
