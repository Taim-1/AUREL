import 'dart:io';

import 'package:dio/dio.dart';

import '../models/track.dart';
import 'catalog_token_service.dart';

class AppleMusicCatalogService {
  AppleMusicCatalogService({
    required this.tokens,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.music.apple.com/v1/',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.json,
              ),
            );

  final CatalogTokenService tokens;
  final Dio _dio;

  String get storefront {
    final locale = Platform.localeName;
    final pieces = locale.split(RegExp('[-_]'));
    final candidate = pieces.length > 1 ? pieces.last.toLowerCase() : 'us';
    return RegExp(r'^[a-z]{2}$').hasMatch(candidate) ? candidate : 'us';
  }

  Future<List<Track>> search(
    String query, {
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final token = await tokens.tokenFor('apple_music');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'catalog/$storefront/search',
        queryParameters: {
          'term': normalized,
          'types': 'songs',
          'limit': limit.clamp(1, 25),
        },
        cancelToken: cancelToken,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final songs = response.data?['results'];
      final raw = songs is Map ? songs['songs'] : null;
      final items = raw is Map ? raw['data'] : null;
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((item) => Track.fromAppleMusic(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      throw AppleMusicCatalogException(
        status == 401 || status == 403
            ? 'Apple Music developer token is missing or expired.'
            : status == 429
                ? 'Apple Music catalog is rate-limiting searches.'
                : 'Apple Music catalog search is unavailable.',
      );
    }
  }
}

class AppleMusicCatalogException implements Exception {
  const AppleMusicCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
