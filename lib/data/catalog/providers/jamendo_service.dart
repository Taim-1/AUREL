import 'package:dio/dio.dart';

import '../../../models/track.dart';
import '../../../repositories/library_repository.dart';

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

  // Jamendo documents this ID for read-only testing only.
  // Replace it with an application ID before a public release.
  static const _developmentClientId = '709fa152';

  String _clientId = const String.fromEnvironment(
    'JAMENDO_CLIENT_ID',
    defaultValue: _developmentClientId,
  );
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
      throw ArgumentError('Enter a Jamendo client ID.');
    }
    _clientId = normalized;
    await _repository.saveClientId(normalized);
  }

  Future<List<Track>> popular({
    int limit = 30,
    int offset = 0,
  }) =>
      _requestTracks({
        'order': 'popularity_total',
        'limit': _safeLimit(limit),
        'offset': _safeOffset(offset),
      });

  Future<List<Track>> search(
    String query, {
    int limit = 30,
    int offset = 0,
  }) =>
      _requestTracks({
        'search': query.trim(),
        'limit': _safeLimit(limit),
        'offset': _safeOffset(offset),
      });

  Future<List<Track>> byTag(
    String tag, {
    int limit = 30,
    int offset = 0,
  }) =>
      _requestTracks({
        'tags': tag.trim(),
        'order': 'popularity_total',
        'limit': _safeLimit(limit),
        'offset': _safeOffset(offset),
      });

  String _safeLimit(int value) => value.clamp(1, 200).toString();
  String _safeOffset(int value) => value.clamp(0, 1000000).toString();

  Future<List<Track>> _requestTracks(Map<String, String> extra) async {
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
              ? 'Jamendo could not complete this request.'
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
      final status = error.response?.statusCode;
      final detail = status == 401 || status == 403
          ? 'Jamendo rejected the client ID. Add your own ID in Profile settings.'
          : status == 429
              ? 'Music search is temporarily busy. Try again in a moment.'
              : 'Could not reach Jamendo. Check your connection and try again.';
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
