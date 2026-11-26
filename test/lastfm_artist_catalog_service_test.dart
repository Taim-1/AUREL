import 'dart:typed_data';

import 'package:aurel/data/catalog/providers/lastfm_catalog_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LastFmCatalogService.artistTopTracks', () {
    test('maps artist recordings as metadata-only catalogue entries', () async {
      late RequestOptions captured;
      final adapter = _JsonAdapter((options) {
        captured = options;
        return {
          'toptracks': {
            'track': [
              {
                'name': 'Midnight City',
                'mbid': 'recording-123',
                'url': 'https://www.last.fm/music/M83/_/Midnight+City',
                'duration': '244000',
                'artist': {'name': 'M83'},
              },
            ],
          },
        };
      });
      final service = LastFmCatalogService(
        apiKey: 'test-key',
        dio: Dio(
          BaseOptions(
            baseUrl: 'https://ws.audioscrobbler.com/2.0/',
            responseType: ResponseType.json,
          ),
        )..httpClientAdapter = adapter,
      );

      final tracks = await service.artistTopTracks('M83', limit: 12);

      expect(captured.queryParameters['method'], 'artist.gettoptracks');
      expect(captured.queryParameters['artist'], 'M83');
      expect(captured.queryParameters['limit'], 12);
      expect(tracks, hasLength(1));
      expect(tracks.single.title, 'Midnight City');
      expect(tracks.single.artist, 'M83');
      expect(tracks.single.canPlay, isFalse);
      expect(tracks.single.streamUrl, isEmpty);
      expect(tracks.single.downloadAllowed, isFalse);
      adapter.close();
    });

    test('does not make a request when artist is empty', () async {
      final adapter = _JsonAdapter((_) => throw StateError('unexpected request'));
      final service = LastFmCatalogService(
        apiKey: 'test-key',
        dio: Dio(
          BaseOptions(
            baseUrl: 'https://ws.audioscrobbler.com/2.0/',
            responseType: ResponseType.json,
          ),
        )..httpClientAdapter = adapter,
      );

      expect(await service.artistTopTracks('   '), isEmpty);
      expect(adapter.requestCount, 0);
      adapter.close();
    });

    test('requires an API key before requesting artist charts', () async {
      final adapter = _JsonAdapter((_) => throw StateError('unexpected request'));
      final service = LastFmCatalogService(
        apiKey: '',
        dio: Dio(
          BaseOptions(
            baseUrl: 'https://ws.audioscrobbler.com/2.0/',
            responseType: ResponseType.json,
          ),
        )..httpClientAdapter = adapter,
      );

      await expectLater(
        service.artistTopTracks('M83'),
        throwsA(isA<LastFmCatalogException>()),
      );
      expect(adapter.requestCount, 0);
      adapter.close();
    });
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.payload);

  final Map<String, dynamic> Function(RequestOptions options) payload;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    return ResponseBody.fromString(
      payload(options).toString().replaceAllMapped(
            RegExp(r'([a-zA-Z_]+):'),
            (match) => '"${match[1]}":',
          ),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
