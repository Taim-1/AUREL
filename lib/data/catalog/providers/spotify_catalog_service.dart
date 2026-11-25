import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/track.dart';
import '../../services/catalog_token_service.dart';

class SpotifyCatalogService {
  SpotifyCatalogService({
    required this.tokens,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.spotify.com/v1/',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.json,
              ),
            );

  final CatalogTokenService tokens;
  final Dio _dio;

  String get _market {
    final locale = Platform.localeName;
    final pieces = locale.split(RegExp('[-_]'));
    final candidate = pieces.length > 1 ? pieces.last.toUpperCase() : 'US';
    return RegExp(r'^[A-Z]{2}$').hasMatch(candidate) ? candidate : 'US';
  }

  Future<List<Track>> search(
    String query, {
    int limit = 20,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final token = await tokens.tokenFor('spotify');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'search',
        queryParameters: {
          'q': normalized,
          'type': 'track',
          'market': _market,
          'limit': limit.clamp(1, 10),
          'offset': offset.clamp(0, 1000),
        },
        cancelToken: cancelToken,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final raw = response.data?['tracks'];
      final items = raw is Map ? raw['items'] : null;
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((item) => Track.fromSpotify(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      throw SpotifyCatalogException(
        status == 401
            ? 'Spotify catalog authorization expired.'
            : status == 403
                ? 'Spotify has not granted this AUREL application API access.'
                : status == 429
                    ? 'Spotify is rate-limiting catalog searches.'
                    : 'Spotify catalog search is unavailable.',
      );
    }
  }
}

class SpotifyCatalogException implements Exception {
  const SpotifyCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
