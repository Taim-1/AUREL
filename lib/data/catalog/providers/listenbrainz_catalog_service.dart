import 'package:dio/dio.dart';

import '../../models/track.dart';

/// Public ListenBrainz site-wide recording statistics for global discovery.
/// This is a popularity index, not an audio host; entries remain metadata-only.
class ListenBrainzCatalogService {
  ListenBrainzCatalogService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.listenbrainz.org/1/',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 18),
                responseType: ResponseType.json,
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent': 'AUREL/1.0.0 (https://github.com/Taim-1/AUREL)',
                },
              ),
            );

  final Dio _dio;

  Future<List<Track>> sitewideTopRecordings({
    int count = 100,
    int offset = 0,
    String range = 'all_time',
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'stats/sitewide/recordings',
        queryParameters: {
          'range': range,
          'count': count.clamp(1, 1000),
          'offset': offset.clamp(0, 100000),
        },
        cancelToken: cancelToken,
      );
      final payload = response.data?['payload'];
      final recordings = payload is Map ? payload['recordings'] : null;
      if (recordings is! List) return const [];
      return recordings
          .whereType<Map>()
          .map((item) => Track.fromListenBrainz(
                Map<String, dynamic>.from(item),
              ))
          .where((track) => track.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      if (error.response?.statusCode == 204) return const [];
      throw const ListenBrainzCatalogException(
        'Global listening charts are temporarily unavailable.',
      );
    }
  }
}

class ListenBrainzCatalogException implements Exception {
  const ListenBrainzCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
