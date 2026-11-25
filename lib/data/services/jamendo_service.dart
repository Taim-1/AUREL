import 'package:dio/dio.dart';

import '../models/track.dart';
import '../repositories/library_repository.dart';

class JamendoService {
  JamendoService(this._repository)
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.jamendo.com/v3.0/',
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 12),
            responseType: ResponseType.json,
          ),
        );

  final LibraryRepository _repository;
  final Dio _dio;
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

  Future<List<Track>> popular({int limit = 30}) =>
      _requestTracks({'order': 'popularity_total', 'limit': '$limit'});

  Future<List<Track>> search(String query, {int limit = 40}) =>
      _requestTracks({'search': query, 'limit': '$limit'});

  Future<List<Track>> _requestTracks(Map<String, String> extra) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'tracks/',
        queryParameters: {
          'client_id': _clientId,
          'format': 'json',
          'audioformat': 'mp32',
          'imagesize': '300',
          'include': 'musicinfo',
          'limit': '30',
          ...extra,
        },
      );
      final body = response.data;
      if (body == null) throw const FormatException('Empty music response.');
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
      final detail = error.response?.statusCode == 401 ||
              error.response?.statusCode == 403
          ? 'Jamendo rejected the client ID. Add your own ID in Profile settings.'
          : 'Could not reach Jamendo. Check your connection and try again.';
      throw JamendoException(detail);
    } on FormatException {
      throw const JamendoException('The music service returned an unreadable response.');
    }
  }
}

class JamendoException implements Exception {
  const JamendoException(this.message);
  final String message;

  @override
  String toString() => message;
}
