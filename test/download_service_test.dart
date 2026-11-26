import 'package:flutter_test/flutter_test.dart';

import 'package:aurel/data/services/download_service.dart';

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

  group('download URL security', () {
    test('accepts HTTPS final URLs with a host', () {
      expect(
        isSecureDownloadUri(Uri.parse('https://cdn.example/audio.mp3')),
        isTrue,
      );
    });

    test('rejects HTTP, hostless and non-web final URLs', () {
      expect(
        isSecureDownloadUri(Uri.parse('http://cdn.example/audio.mp3')),
        isFalse,
      );
      expect(isSecureDownloadUri(Uri.parse('file:///audio.mp3')), isFalse);
      expect(isSecureDownloadUri(Uri.parse('https:///audio.mp3')), isFalse);
      expect(
        isSecureDownloadUri(
          Uri.parse('https://user:password@cdn.example/audio.mp3'),
        ),
        isFalse,
      );
    });

    test('resolves relative HTTPS redirects safely', () {
      expect(
        resolveSecureDownloadRedirect(
          Uri.parse('https://source.example/audio/song.mp3'),
          '../files/song.mp3',
        ).toString(),
        'https://source.example/files/song.mp3',
      );
    });

    test('rejects HTTP, credential-bearing and empty redirect targets', () {
      final source = Uri.parse('https://source.example/audio.mp3');
      expect(
        () => resolveSecureDownloadRedirect(
          source,
          'http://insecure.example/audio.mp3',
        ),
        throwsA(isA<DownloadException>()),
      );
      expect(
        () => resolveSecureDownloadRedirect(
          source,
          'https://user:pass@cdn.example/audio.mp3',
        ),
        throwsA(isA<DownloadException>()),
      );
      expect(
        () => resolveSecureDownloadRedirect(source, ' '),
        throwsA(isA<DownloadException>()),
      );
    });
  });

  group('download response validation', () {
    test('allows audio and generic binary content types', () {
      expect(isAllowedAudioContentType('audio/mpeg'), isTrue);
      expect(isAllowedAudioContentType('audio/mp4; codecs=mp4a'), isTrue);
      expect(isAllowedAudioContentType('application/octet-stream'), isTrue);
      expect(isAllowedAudioContentType(null), isTrue);
    });

    test('rejects explicit non-audio responses', () {
      expect(isAllowedAudioContentType('text/html; charset=utf-8'), isFalse);
      expect(isAllowedAudioContentType('application/json'), isFalse);
      expect(isAllowedAudioContentType('text/plain'), isFalse);
      expect(isAllowedAudioContentType('video/mp4'), isFalse);
    });

    test('recognizes supported audio file signatures', () {
      expect(
        audioFileExtensionFromSignature(
          [0x49, 0x44, 0x33, 0x04, 0x00, 0x00],
        ),
        'mp3',
      );
      expect(
        audioFileExtensionFromSignature(
          [0x66, 0x4C, 0x61, 0x43],
        ),
        'flac',
      );
      expect(
        audioFileExtensionFromSignature(
          [0x4F, 0x67, 0x67, 0x53, 0x00],
        ),
        'ogg',
      );
      expect(
        audioFileExtensionFromSignature(
          [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45],
        ),
        'wav',
      );
      expect(
        audioFileExtensionFromSignature(
          [0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70],
        ),
        'm4a',
      );
      expect(audioFileExtensionFromSignature('<html>'.codeUnits), isNull);
      expect(audioFileExtensionFromSignature('{"error":true}'.codeUnits), isNull);
    });

    test('recognizes MPEG and AAC frame headers', () {
      expect(audioFileExtensionFromSignature([0xFF, 0xFB, 0x90, 0x64]), 'mp3');
      expect(audioFileExtensionFromSignature([0xFF, 0xF1, 0x50, 0x80]), 'aac');
    });
  });
}
