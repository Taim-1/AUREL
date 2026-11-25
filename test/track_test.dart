import 'package:aurel/data/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Track.fromJamendo', () {
    test('maps stream, artwork, duration and per-track download permission', () {
      final track = Track.fromJamendo({
        'id': 'track-1',
        'name': 'Golden Hour',
        'artist_name': 'Aurel Artist',
        'album_name': 'First Light',
        'audio': 'https://example.com/audio.mp3',
        'audiodownload': 'https://example.com/download.mp3',
        'audiodownload_allowed': true,
        'license_ccurl': 'https://creativecommons.org/licenses/by/4.0/',
        'duration': 205,
        'image': 'https://example.com/art.jpg',
      });

      expect(track.id, 'track-1');
      expect(track.title, 'Golden Hour');
      expect(track.artist, 'Aurel Artist');
      expect(track.album, 'First Light');
      expect(track.durationMs, 205000);
      expect(track.artworkUrl, 'https://example.com/art.jpg');
      expect(track.downloadAllowed, isTrue);
      expect(track.licenseUrl, contains('creativecommons.org'));
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

    test('does not infer download permission from a URL alone', () {
      final track = Track.fromJamendo({
        'id': 'track-3',
        'name': 'Unknown Permission',
        'audio': 'https://example.com/audio.mp3',
        'audiodownload': 'https://example.com/download.mp3',
      });

      expect(track.downloadAllowed, isFalse);
    });
  });

  group('Track offline persistence', () {
    test('keeps the downloaded file path when serialised and restored', () {
      const original = Track(
        id: 'track-4',
        title: 'Offline Track',
        artist: 'Aurel Artist',
        streamUrl: 'https://example.com/stream.mp3',
        downloadUrl: 'https://example.com/download.mp3',
        downloadAllowed: true,
        isDownloaded: true,
        localPath: '/data/user/0/com.aurel.aurel/app_flutter/song.mp3',
      );

      final restored = Track.fromJson(original.toJson());

      expect(restored.isDownloaded, isTrue);
      expect(restored.localPath, original.localPath);
      expect(restored.playbackUri, startsWith('file:'));
    });
  });
}
