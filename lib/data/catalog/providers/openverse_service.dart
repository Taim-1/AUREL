import 'package:dio/dio.dart';

import '../../../models/track.dart';

class OpenverseService {
  OpenverseService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.openverse.org/v1/',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 25),
                sendTimeout: const Duration(seconds: 12),
                responseType: ResponseType.json,
                headers: const {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;

  static const _permittedLicenses = 'by,by-sa,cc0,pdm';

  Future<List<Track>> search(
    String query, {
    int page = 1,
    int pageSize = 15,
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'audio/',
        queryParameters: {
          'q': normalized,
          'category': 'music',
          'license': _permittedLicenses,
          'extension': 'mp3,ogg,wav,m4a,flac',
          'mature': false,
          'filter_dead': true,
          'page': page.clamp(1, 500),
          'page_size': pageSize.clamp(1, 20),
        },
        cancelToken: cancelToken,
      );
      final body = response.data;
      final raw = body?['results'];
      if (raw is! List) {
        throw const OpenverseException(
          'Openverse returned an unreadable audio catalogue.',
        );
      }
      return raw
          .whereType<Map>()
          .map((item) => Track.fromOpenverse(
                Map<String, dynamic>.from(item),
              ))
          .where((track) => track.canPlay)
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      throw OpenverseException(
        status == 429
            ? 'Openverse search is rate-limited. Try again shortly.'
            : status == 401 || status == 403
                ? 'Openverse requires an API access token for this request.'
                : 'Openverse could not be reached. Check your connection.',
      );
    }
  }
}

class OpenverseException implements Exception {
  const OpenverseException(this.message);

  final String message;

  @override
  String toString() => message;
}
