import 'package:flutter_test/flutter_test.dart';

import '../lib/data/services/download_service.dart';

void main() {
  group('audioFileExtensionFromUrl', () {
    test('keeps supported audio formats', () {
      expect(
        audioFileExtensionFromUrl(
          'https://archive.example/audio/recording.FLAC?download=1',
        ),
        'flac',
      );
      expect(
        audioFileExtensionFromUrl('https://cdn.example/music/song.m4a'),
        'm4a',
      );
      expect(
        audioFileExtensionFromUrl('https://cdn.example/song.ogg'),
        'ogg',
      );
    });

    test('uses MP3 fallback for extensionless and unknown URLs', () {
      expect(audioFileExtensionFromUrl('https://audio.example/stream'), 'mp3');
      expect(
        audioFileExtensionFromUrl('https://cdn.example/file.exe'),
        'mp3',
      );
    });
  });
}
