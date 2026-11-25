import 'package:dio/dio.dart';

import '../../../models/track.dart';
import '../../../services/catalog_token_service.dart';

class SoundCloudService {
  SoundCloudService({
    required this.tokens,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.soundcloud.com/',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 12),
                responseType: ResponseType.json,
                headers: const {'Accept': 'application/json; charset=utf-8'},
              ),
            );

  final CatalogTokenService tokens;
  final Dio _dio;

  Future<List<Track>> search(
    String query, {
    int limit = 25,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final accessToken = await tokens.tokenFor('soundcloud');
    try {
      final response = await _dio.get<dynamic>(
        'tracks',
        queryParameters: {
          'q': normalized,
          'access': 'playable',
          'limit': limit.clamp(1, 100),
          'offset': offset.clamp(0, 1000000),
          'linked_partitioning': true,
        },
        cancelToken: cancelToken,
        options: Options(
          headers: {'Authorization': 'OAuth $accessToken'},
        ),
      );
      final body = response.data;
      final raw = body is Map
          ? (body['collection'] ?? body['data'])
          : body;
      if (raw is! List) {
        throw const SoundCloudException(
          'SoundCloud returned an unreadable track list.',
        );
      }
      return raw
          .whereType<Map>()
          .map((item) => Track.fromSoundCloud(
                Map<String, dynamic>.from(item),
              ))
          .where((track) => track.canPlay)
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      throw SoundCloudException(
        status == 401
            ? 'SoundCloud authorization expired. Try again.'
            : status == 403
                ? 'SoundCloud did not allow this app to access the track.'
                : status == 429
                    ? 'SoundCloud is busy. Try again shortly.'
                    : 'SoundCloud could not be reached.',
      );
    }
  }

  /// Refreshes the short-lived OAuth token just before playback. The token is
  /// kept only in memory on this device and is never serialized into a track.
  Future<Track> prepareForPlayback(Track track) async {
    if (track.providerId != 'soundcloud') return track;
    if (!track.isPlayable || track.streamUrl.isEmpty) {
      throw const SoundCloudException(
        'This SoundCloud track is not available for in-app playback.',
      );
    }
    final accessToken = await tokens.tokenFor('soundcloud');
    return track.copyWith(
      playbackHeaders: {'Authorization': 'OAuth $accessToken'},
    );
  }
}

class SoundCloudException implements Exception {
  const SoundCloudException(this.message);

  final String message;

  @override
  String toString() => message;
}
