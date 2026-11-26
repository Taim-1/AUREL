import 'dart:collection';

import 'package:dio/dio.dart';

import '../../models/track.dart';

/// Openly licensed audio search through the MediaWiki Action API.
///
/// Only direct audio files with an explicit reusable licence are returned.
/// The adapter is deliberately called after the other catalogue requests so
/// AUREL does not fan out several concurrent requests to the same API.
class WikimediaCommonsService {
  WikimediaCommonsService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://commons.wikimedia.org/w/api.php',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 24),
                sendTimeout: const Duration(seconds: 12),
                responseType: ResponseType.json,
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent':
                      'AUREL/1.0.0 (https://github.com/Taim-1/AUREL) Flutter/3.50',
                },
              ),
            );

  final Dio _dio;

  static const _cacheDuration = Duration(minutes: 3);
  final LinkedHashMap<String, _CachedCommonsPage> _cache =
      LinkedHashMap<String, _CachedCommonsPage>();

  Future<List<Track>> search(
    String query, {
    int page = 0,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return const [];
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.cancel,
        message: 'Open audio search cancelled.',
      );
    }

    final cacheKey = '${normalized.toLowerCase()}:${page.clamp(0, 50)}';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.savedAt) < _cacheDuration) {
      return cached.tracks;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '',
        queryParameters: {
          'action': 'query',
          'format': 'json',
          'formatversion': 2,
          'generator': 'search',
          'gsrsearch': 'filetype:audio $normalized',
          'gsrnamespace': 6,
          'gsrlimit': limit.clamp(1, 40),
          'gsroffset': page.clamp(0, 50) * limit.clamp(1, 40),
          'prop': 'imageinfo',
          'iiprop': 'url|mime|size|extmetadata',
        },
        cancelToken: cancelToken,
      );

      final pages = response.data?['query'] is Map
          ? (response.data!['query'] as Map)['pages']
          : null;
      if (pages is! List) {
        if (pages == null) return _cacheAndReturn(cacheKey, const []);
        throw const WikimediaCommonsException(
          'The open audio catalogue returned an unreadable result.',
        );
      }

      final tracks = <Track>[];
      for (final pageData in pages.whereType<Map>()) {
        final pageMap = Map<String, dynamic>.from(pageData);
        final rawInfo = pageMap['imageinfo'];
        if (rawInfo is! List || rawInfo.isEmpty || rawInfo.first is! Map) {
          continue;
        }

        final info = Map<String, dynamic>.from(rawInfo.first as Map);
        final mime = (info['mime'] ?? '').toString().toLowerCase();
        final metadata = info['extmetadata'];
        if (!mime.startsWith('audio/') || metadata is! Map) continue;

        final ext = Map<String, dynamic>.from(metadata);
        final license = _license(ext);
        if (license == null) continue;

        final mediaUrl = (info['url'] ?? '').toString();
        final uri = Uri.tryParse(mediaUrl);
        if (uri == null || uri.scheme != 'https') continue;

        final title = _fileTitle(pageMap['title']?.toString() ?? '');
        final artist = _metadataValue(ext, 'Artist').isNotEmpty
            ? _metadataValue(ext, 'Artist')
            : _metadataValue(ext, 'Credit');
        final cleanArtist =
            artist.isEmpty ? 'Open audio contributor' : artist;
        final descriptionUrl = (info['descriptionurl'] ?? '').toString();
        final attribution = _attribution(
          title: title,
          artist: cleanArtist,
          metadata: ext,
          licenseName: license.name,
          licenseUrl: license.url,
          descriptionUrl: descriptionUrl,
        );

        tracks.add(
          Track.fromWikimediaCommons(
            pageId: (pageMap['pageid'] ?? pageMap['title'] ?? '').toString(),
            title: title,
            artist: cleanArtist,
            mediaUrl: mediaUrl,
            sourceUrl: descriptionUrl,
            licenseName: license.name,
            licenseUrl: license.url,
            attribution: attribution,
            durationMs: _durationMs(_metadataValue(ext, 'Length')),
          ),
        );
      }

      return _cacheAndReturn(cacheKey, tracks);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      throw WikimediaCommonsException(
        status == 429 || status == 503
            ? 'The open audio collection is busy. Try again shortly.'
            : 'The open audio collection is temporarily unavailable.',
      );
    }
  }

  List<Track> _cacheAndReturn(String key, List<Track> tracks) {
    _cache[key] = _CachedCommonsPage(
      savedAt: DateTime.now(),
      tracks: List.unmodifiable(tracks),
    );
    while (_cache.length > 60) {
      _cache.remove(_cache.keys.first);
    }
    return tracks;
  }

  _ReusableLicense? _license(Map<String, dynamic> metadata) {
    final url = _metadataValue(metadata, 'LicenseUrl').trim();
    final shortName = _metadataValue(metadata, 'LicenseShortName').trim();
    final normalizedUrl = url.toLowerCase();
    final normalizedName = shortName.toLowerCase();

    if (normalizedUrl.contains('/licenses/by-sa/') ||
        normalizedName.startsWith('cc by-sa')) {
      return _ReusableLicense('CC BY-SA', url);
    }
    if (normalizedUrl.contains('/licenses/by/') ||
        (normalizedName.startsWith('cc by') &&
            !normalizedName.contains('nc') &&
            !normalizedName.contains('nd') &&
            !normalizedName.contains('sa'))) {
      return _ReusableLicense('CC BY', url);
    }
    if (normalizedUrl.contains('/publicdomain/zero/') ||
        normalizedName.startsWith('cc0')) {
      return _ReusableLicense('CC0', url);
    }
    if (normalizedUrl.contains('/publicdomain/mark/') ||
        normalizedName.contains('public domain')) {
      return _ReusableLicense('Public Domain', url);
    }
    return null;
  }

  String _metadataValue(Map<String, dynamic> metadata, String key) {
    final raw = metadata[key];
    if (raw is Map) {
      return _stripHtml((raw['value'] ?? '').toString()).trim();
    }
    return _stripHtml(raw?.toString() ?? '').trim();
  }

  String _stripHtml(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _fileTitle(String raw) {
    var title = raw.replaceFirst(RegExp(r'^File:', caseSensitive: false), '');
    title = title.replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,5}$'), '');
    return title.replaceAll('_', ' ').trim();
  }

  int _durationMs(String raw) {
    final value = raw.trim();
    final parts = value.split(':');
    if (parts.length >= 2 && parts.length <= 3) {
      final numbers = parts.map((part) => double.tryParse(part)).toList();
      if (numbers.every((part) => part != null)) {
        var seconds = 0.0;
        for (final part in numbers) {
          seconds = seconds * 60 + part!;
        }
        return (seconds * 1000).round();
      }
    }
    return 0;
  }

  String _attribution({
    required String title,
    required String artist,
    required Map<String, dynamic> metadata,
    required String licenseName,
    required String licenseUrl,
    required String descriptionUrl,
  }) {
    final credit = _metadataValue(metadata, 'Credit');
    final artistLine = credit.isNotEmpty ? credit : artist;
    final description =
        _metadataValue(metadata, 'Attribution').replaceAll(RegExp(r'\s+'), ' ');
    if (description.isNotEmpty) return description;
    return '"$title" by $artistLine — $licenseName ($licenseUrl). $descriptionUrl';
  }
}

class _ReusableLicense {
  const _ReusableLicense(this.name, this.url);

  final String name;
  final String url;
}

class _CachedCommonsPage {
  const _CachedCommonsPage({
    required this.savedAt,
    required this.tracks,
  });

  final DateTime savedAt;
  final List<Track> tracks;
}

class WikimediaCommonsException implements Exception {
  const WikimediaCommonsException(this.message);

  final String message;

  @override
  String toString() => message;
}
