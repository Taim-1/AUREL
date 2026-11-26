import 'package:dio/dio.dart';

import '../../models/track.dart';

/// Last.fm adds broad discovery metadata and artist/album context.
/// It is deliberately metadata-only: Last.fm does not provide AUREL with
/// an authorized full-track audio stream.
class LastFmCatalogService {
  LastFmCatalogService({Dio? dio, String? apiKey})
      : _apiKey = apiKey ?? const String.fromEnvironment('LASTFM_API_KEY'),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://ws.audioscrobbler.com/2.0/',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 18),
                responseType: ResponseType.json,
                headers: const {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;
  final String _apiKey;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<List<Track>> topTracks({
    int limit = 30,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    if (!isConfigured) {
      throw const LastFmCatalogException(
        'Last.fm discovery is not configured for this build.',
      );
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '',
        queryParameters: {
          'method': 'chart.gettoptracks',
          'api_key': _apiKey,
          'format': 'json',
          'limit': limit.clamp(1, 100),
          'page': page.clamp(1, 100000),
        },
        cancelToken: cancelToken,
      );
      final chart = response.data?['tracks'];
      final rawTracks = chart is Map ? chart['track'] : null;
      return _parseTracks(rawTracks);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw const LastFmCatalogException(
        'Last.fm charts are temporarily unavailable.',
      );
    }
  }

  /// Returns an artist's most-played recordings from Last.fm's global
  /// listening data. Results remain metadata-only until a playback provider
  /// independently supplies an authorized stream.
  Future<List<Track>> artistTopTracks(
    String artist, {
    int limit = 30,
    CancelToken? cancelToken,
  }) async {
    final normalized = artist.trim();
    if (normalized.isEmpty) return const [];
    if (!isConfigured) {
      throw const LastFmCatalogException(
        'Last.fm discovery is not configured for this build.',
      );
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '',
        queryParameters: {
          'method': 'artist.gettoptracks',
          'artist': normalized,
          'api_key': _apiKey,
          'format': 'json',
          'limit': limit.clamp(1, 100),
        },
        cancelToken: cancelToken,
      );
      final topTracks = response.data?['toptracks'];
      final rawTracks = topTracks is Map ? topTracks['track'] : null;
      return _parseTracks(rawTracks);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      throw LastFmCatalogException(
        status == 429
            ? 'Last.fm artist discovery is busy. Try again shortly.'
            : status == 403
                ? 'Last.fm API access is unavailable for this key.'
                : 'Artist recordings could not be reached.',
      );
    }
  }

  Future<List<Track>> search(
    String query, {
    int limit = 30,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    if (!isConfigured) {
      throw const LastFmCatalogException(
        'Last.fm discovery is not configured for this build.',
      );
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '',
        queryParameters: {
          'method': 'track.search',
          'track': normalized,
          'api_key': _apiKey,
          'format': 'json',
          'limit': limit.clamp(1, 100),
          'page': page.clamp(1, 100000),
        },
        cancelToken: cancelToken,
      );

      final results = response.data?['results'];
      final matches = results is Map ? results['trackmatches'] : null;
      final rawTracks = matches is Map ? matches['track'] : null;
      return _parseTracks(rawTracks);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      throw LastFmCatalogException(
        status == 429
            ? 'Last.fm discovery is busy. Try again shortly.'
            : status == 403
                ? 'Last.fm API access is unavailable for this key.'
                : 'Last.fm discovery could not be reached.',
      );
    }
  }

  List<Track> _parseTracks(dynamic rawTracks) {
    if (rawTracks is! List) return const [];
    return rawTracks
        .whereType<Map>()
        .map((item) => Track.fromLastFm(Map<String, dynamic>.from(item)))
        .where((track) => track.id.isNotEmpty)
        .toList(growable: false);
  }
}

class LastFmCatalogException implements Exception {
  const LastFmCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
