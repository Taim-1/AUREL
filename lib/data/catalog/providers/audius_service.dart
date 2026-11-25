import 'package:dio/dio.dart';

import '../../models/track.dart';

class AudiusService {
  AudiusService({Dio? dio, String? apiKey})
      : _apiKey = apiKey ??
            const String.fromEnvironment('AUDIUS_API_KEY'),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.audius.co/v1/',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 12),
                responseType: ResponseType.json,
                headers: const {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;
  final String _apiKey;

  Map<String, String> get _headers =>
      _apiKey.isEmpty ? const {} : {'x-api-key': _apiKey};

  Future<List<Track>> search(
    String query, {
    int limit = 25,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final body = await _get(
      'tracks/search',
      {
        'query': normalized,
        'app_name': 'AUREL',
        'limit': _safeLimit(limit),
        'offset': _safeOffset(offset),
      },
      cancelToken: cancelToken,
    );
    return _parseTracks(body);
  }

  Future<List<Track>> trending({
    int limit = 25,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final body = await _get(
      'tracks/trending',
      {
        'time': 'week',
        'app_name': 'AUREL',
        'limit': _safeLimit(limit),
        'offset': _safeOffset(offset),
      },
      cancelToken: cancelToken,
    );
    return _parseTracks(body);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, Object> parameters, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: parameters,
        cancelToken: cancelToken,
        options: Options(headers: _headers),
      );
      final body = response.data;
      if (body == null) {
        throw const AudiusException('Audius returned an empty response.');
      }
      if (response.statusCode == 429) {
        throw const AudiusException(
          'Audius is rate-limiting requests. Try again shortly.',
        );
      }
      return body;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      throw AudiusException(
        status == 429
            ? 'Audius is busy. Try again shortly.'
            : status == 401 || status == 403
                ? 'Audius rejected its API credentials.'
                : 'Audius could not be reached. Check your connection.',
      );
    }
  }

  List<Track> _parseTracks(Map<String, dynamic> body) {
    final raw = body['data'];
    if (raw is! List) {
      throw const AudiusException('Audius returned an unreadable track list.');
    }
    return raw
        .whereType<Map>()
        .map((item) => Track.fromAudius(Map<String, dynamic>.from(item)))
        .where((track) => track.id != 'audius-' && track.canPlay)
        .toList(growable: false);
  }

  String _safeLimit(int value) => value.clamp(1, 100).toString();
  String _safeOffset(int value) => value.clamp(0, 1000000).toString();
}

class AudiusException implements Exception {
  const AudiusException(this.message);

  final String message;

  @override
  String toString() => message;
}
