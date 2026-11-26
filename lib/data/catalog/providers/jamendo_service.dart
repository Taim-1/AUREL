import 'package:dio/dio.dart';

import '../../models/track.dart';
import '../../repositories/library_repository.dart';

class JamendoService {
  JamendoService(this._repository)
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.jamendo.com/v3.0/',
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 12),
            responseType: ResponseType.json,
            headers: const {'Accept': 'application/json'},
          ),
        );

  final LibraryRepository _repository;
  final Dio _dio;

  // A production application ID must be configured through the build.
  // The public example ID is for testing only and is intentionally not used.
  String _clientId = const String.fromEnvironment('JAMENDO_CLIENT_ID');
  String get clientId => _clientId;

  Future<void> initialize() async {
    final saved = await _repository.loadClientId();
    if (saved != null && saved.trim().isNotEmpty) {
      _clientId = saved.trim();
    }
  }

  Future<void> setClientId(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Enter the AUREL catalogue access ID.');
    }
    _clientId = normalized;
    await _repository.saveClientId(normalized);
  }

  Future<List<Track>> popular({
    int limit = 30,
    int offset = 0,
    CancelToken? cancelToken,
  }) =>
      _requestTracks({
        'order': 'popularity_total',
        'limit': _safeLimit(limit),
        'offset': _safeOffset(offset),
      }, cancelToken: cancelToken);

  Future<List<Track>> search(
    String query, {
    int limit = 30,
    int offset = 0,
    CancelToken? cancelToken,
  }) =>
      _requestTracks({
        'search': query.trim(),
        'limit': _safeLimit(limit),
        'offset': _safeOffset(offset),
      }, cancelToken: cancelToken);

  Future<List<Track>> byTag(
    String tag, {
    int limit = 30,
    int offset = 0,
    CancelToken? cancelToken,
  }) =>
      _requestTracks({
        'tags': tag.trim(),
        'order': 'popularity_total',
        'limit': _safeLimit(limit),
        'offset': _safeOffset(offset),
      }, cancelToken: cancelToken);

  String _safeLimit(int value) => value.clamp(1, 200).toString();
  String _safeOffset(int value) => value.clamp(0, 1000000).toString();

  Future<List<Track>> _requestTracks(
    Map<String, String> extra, {
    CancelToken? cancelToken,
  }) async {
    if (_clientId.isEmpty) {
      throw const JamendoException(
        'A music collection is not configured for this build yet.',
      );
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'tracks/',
        queryParameters: {
          'client_id': _clientId,
          'format': 'json',
          'audioformat': 'mp32',
          'audiodlformat': 'mp32',
          'imagesize': '300',
          'include': 'musicinfo',
          ...extra,
        },
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null) {
        throw const FormatException('Empty music response.');
      }

      final headers = body['headers'];
      if (headers is Map && headers['status'] == 'error') {
        final message = headers['error_message']?.toString();
        throw JamendoException(
          message == null || message.isEmpty
              ? 'The music catalogue could not complete this request.'
              : message,
        );
      }

      final results = body['results'];
      if (results is! List) {
        throw const FormatException('Unexpected music response.');
      }

      return results
          .whereType<Map<String, dynamic>>()
          .map(Track.fromJamendo)
          .where((track) => track.id.isNotEmpty && track.streamUrl.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      final detail = status == 401 || status == 403
          ? 'The music catalogue access settings need to be checked.'
          : status == 429
              ? 'Music search is temporarily busy. Try again in a moment.'
              : 'Could not reach the music catalogue. Check your connection and try again.';
      throw JamendoException(detail);
    } on FormatException {
      throw const JamendoException(
        'The music service returned an unreadable response.',
      );
    }
  }
}

class JamendoException implements Exception {
  const JamendoException(this.message);
  final String message;

  @override
  String toString() => message;
}
