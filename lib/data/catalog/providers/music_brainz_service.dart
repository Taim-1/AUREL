import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

import '../../models/track.dart';

/// Non-commercial recording metadata lookup.
///
/// MusicBrainz asks clients not to exceed one API request per second. All
/// requests from this adapter share one queue, and query results are cached.
class MusicBrainzService {
  MusicBrainzService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://musicbrainz.org/ws/2/',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 12),
                responseType: ResponseType.json,
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent':
                      'AUREL/1.0.0 (https://github.com/Taim-1/AUREL) Flutter/3.50',
                },
              ),
            );

  final Dio _dio;
  Future<void> _requestQueue = Future<void>.value();
  DateTime? _lastRequestAt;

  static const _cacheDuration = Duration(minutes: 10);
  final LinkedHashMap<String, _CachedRecordings> _cache =
      LinkedHashMap<String, _CachedRecordings>();

  Future<List<Track>> search(
    String query, {
    int limit = 25,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return const [];
    if (cancelToken?.isCancelled ?? false) return const [];

    final key = '${normalized.toLowerCase()}:${offset.clamp(0, 100000)}';
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.savedAt) < _cacheDuration) {
      return cached.tracks;
    }

    return _serialized(() async {
      if (cancelToken?.isCancelled ?? false) return const <Track>[];
      final queryText = _escapeLucene(normalized);
      final response = await _dio.get<Map<String, dynamic>>(
        'recording/',
        queryParameters: {
          'query': 'recording:"$queryText" OR artist:"$queryText"',
          'fmt': 'json',
          'limit': limit.clamp(1, 100),
          'offset': offset.clamp(0, 100000),
          'inc': 'isrcs',
        },
        cancelToken: cancelToken,
      );
      final raw = response.data?['recordings'];
      if (raw is! List) {
        throw const MusicBrainzException(
          'The recording catalogue returned an unreadable result.',
        );
      }

      final tracks = raw
          .whereType<Map>()
          .map((item) => Track.fromMusicBrainz(
                Map<String, dynamic>.from(item),
              ))
          .where((track) => track.id != 'musicbrainz-')
          .toList(growable: false);

      _cache[key] = _CachedRecordings(
        savedAt: DateTime.now(),
        tracks: List.unmodifiable(tracks),
      );
      while (_cache.length > 80) {
        _cache.remove(_cache.keys.first);
      }
      return tracks;
    });
  }

  String _escapeLucene(String value) => value
      .replaceAll(String.fromCharCode(92), r'\\')
      .replaceAll('"', r'\"');

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = Completer<T>();
    final previous = _requestQueue;
    final release = Completer<void>();
    _requestQueue = release.future;

    () async {
      await previous;
      try {
        final lastRequest = _lastRequestAt;
        if (lastRequest != null) {
          final elapsed = DateTime.now().difference(lastRequest);
          const spacing = Duration(seconds: 1);
          if (elapsed < spacing) {
            await Future<void>.delayed(spacing - elapsed);
          }
        }
        _lastRequestAt = DateTime.now();
        result.complete(await action());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        release.complete();
      }
    }();

    return result.future;
  }
}

class _CachedRecordings {
  const _CachedRecordings({
    required this.savedAt,
    required this.tracks,
  });

  final DateTime savedAt;
  final List<Track> tracks;
}

class MusicBrainzException implements Exception {
  const MusicBrainzException(this.message);

  final String message;

  @override
  String toString() => message;
}
