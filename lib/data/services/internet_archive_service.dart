import 'package:dio/dio.dart';

import '../models/track.dart';

class InternetArchiveService {
  InternetArchiveService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 25),
                sendTimeout: const Duration(seconds: 12),
                responseType: ResponseType.json,
                headers: const {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;

  Future<List<Track>> search(
    String query, {
    int page = 0,
    int pageSize = 12,
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    var safeQuery = normalized;
    for (final marker in const [
      '"', ':', '/', '+', '-', '!', '(', ')', '{', '}', '[', ']',
      '^', '~', '*', '?',
    ]) {
      safeQuery = safeQuery.replaceAll(marker, ' ');
    }
    safeQuery = safeQuery
        .replaceAll(String.fromCharCode(92), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (safeQuery.isEmpty) return const [];

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://archive.org/advancedsearch.php',
        queryParameters: {
          'q': 'mediatype:audio AND title:"$safeQuery"',
          'fl[]': ['identifier', 'title', 'creator', 'year'],
          'rows': pageSize.clamp(1, 20),
          'page': (page + 1).clamp(1, 500),
          'output': 'json',
        },
        cancelToken: cancelToken,
      );
      final docs = response.data?['response'];
      final rawItems = docs is Map ? docs['docs'] : null;
      if (rawItems is! List) {
        throw const InternetArchiveException(
          'Internet Archive returned an unreadable search result.',
        );
      }

      final identifiers = rawItems
          .whereType<Map>()
          .map((item) => (item['identifier'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      final resolved = <Track>[];
      for (var start = 0; start < identifiers.length; start += 3) {
        final chunk = identifiers.skip(start).take(3);
        final batch = await Future.wait(
          chunk.map(
            (identifier) => _resolveItem(
              identifier,
              cancelToken: cancelToken,
            ),
          ),
        );
        resolved.addAll(batch.whereType<Track>());
      }
      return resolved;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      throw InternetArchiveException(
        status == 429
            ? 'Internet Archive is temporarily rate-limiting requests.'
            : 'Internet Archive could not be reached. Check your connection.',
      );
    }
  }

  Future<Track?> _resolveItem(
    String identifier, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://archive.org/metadata/$identifier',
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null) return null;

      final metadata = body['metadata'];
      if (metadata is! Map) return null;
      final licenseUrl = _firstString(metadata['licenseurl']);
      final licenseName = _licenseName(licenseUrl);
      if (licenseName == null) return null;

      final rawFiles = body['files'];
      if (rawFiles is! List) return null;
      final candidates = rawFiles
          .whereType<Map>()
          .where(_isPublicAudioFile)
          .toList(growable: false)
        ..sort((a, b) => _fileRank(_fileName(a)).compareTo(_fileRank(_fileName(b))));
      if (candidates.isEmpty) return null;

      final fileName = _fileName(candidates.first);
      if (fileName.isEmpty) return null;

      final title = _firstString(metadata['title']);
      final artist = _firstString(metadata['creator']);
      final album = _firstString(metadata['album']);
      final runtime = _firstString(metadata['runtime']);
      final seconds = double.tryParse(runtime) ?? 0;
      final mediaUrl =
          'https://archive.org/download/${Uri.encodeComponent(identifier)}/${Uri.encodeComponent(fileName)}';

      return Track.fromInternetArchive(
        identifier: identifier,
        title: title,
        artist: artist,
        album: album,
        artworkUrl:
            'https://archive.org/services/img/${Uri.encodeComponent(identifier)}',
        mediaUrl: mediaUrl,
        sourceUrl:
            'https://archive.org/details/${Uri.encodeComponent(identifier)}',
        licenseUrl: licenseUrl,
        licenseName: licenseName,
        durationMs: (seconds * 1000).round(),
      );
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }

  bool _isPublicAudioFile(Map file) {
    final name = _fileName(file).toLowerCase();
    final isPrivate = (file['private'] ?? false).toString().toLowerCase() == 'true';
    final source = (file['source'] ?? '').toString().toLowerCase();
    if (isPrivate || source == 'metadata') return false;
    return const [
      '.mp3',
      '.m4a',
      '.aac',
      '.ogg',
      '.opus',
      '.flac',
      '.wav',
    ].any(name.endsWith);
  }

  String _fileName(Map file) => (file['name'] ?? '').toString();

  int _fileRank(String name) {
    final value = name.toLowerCase();
    if (value.endsWith('.mp3')) return 0;
    if (value.endsWith('.m4a')) return 1;
    if (value.endsWith('.aac')) return 2;
    if (value.endsWith('.ogg')) return 3;
    if (value.endsWith('.opus')) return 4;
    if (value.endsWith('.flac')) return 5;
    return 6;
  }

  String _firstString(dynamic value) {
    if (value is List) {
      return value.isEmpty ? '' : value.first.toString();
    }
    return value?.toString() ?? '';
  }

  String? _licenseName(String url) {
    final value = url.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value.contains('creativecommons.org/licenses/by-sa/')) {
      return 'CC BY-SA';
    }
    if (value.contains('creativecommons.org/licenses/by/')) {
      return 'CC BY';
    }
    if (value.contains('creativecommons.org/publicdomain/zero/')) {
      return 'CC0';
    }
    if (value.contains('creativecommons.org/publicdomain/mark/')) {
      return 'Public Domain Mark';
    }
    return null;
  }
}

class InternetArchiveException implements Exception {
  const InternetArchiveException(this.message);

  final String message;

  @override
  String toString() => message;
}
