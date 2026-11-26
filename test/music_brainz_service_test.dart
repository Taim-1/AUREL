import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurel/data/catalog/providers/music_brainz_service.dart';

void main() {
  group('MusicBrainzService request queue', () {
    test('a cancelled queued request exits without waiting for the prior call',
        () async {
      final firstRequestStarted = Completer<void>();
      final releaseFirstRequest = Completer<void>();
      final adapter = _BlockingAdapter(
        onFetch: (options) async {
          if (!firstRequestStarted.isCompleted) {
            firstRequestStarted.complete();
          }
          await releaseFirstRequest.future;
          return ResponseBody.fromString(
            '{"recordings":[]}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        },
      );
      final service = MusicBrainzService(
        dio: Dio(
          BaseOptions(
            baseUrl: 'https://musicbrainz.org/ws/2/',
            responseType: ResponseType.json,
          ),
        )..httpClientAdapter = adapter,
      );

      final first = service.search('first');
      await firstRequestStarted.future;

      final cancelToken = CancelToken();
      final queued = service.search('second', cancelToken: cancelToken);
      cancelToken.cancel('The user changed the search.');

      await expectLater(
        queued,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'cancellation type',
            DioExceptionType.cancel,
          ),
        ),
      );

      final third = service.search('third');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(adapter.requestCount, 1);

      releaseFirstRequest.complete();
      expect(await first, isEmpty);
      expect(await third, isEmpty);
      expect(adapter.requestCount, 2);
      adapter.close();
    });
  });
}

class _BlockingAdapter implements HttpClientAdapter {
  _BlockingAdapter({required this.onFetch});

  final Future<ResponseBody> Function(RequestOptions options) onFetch;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requestCount++;
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}
