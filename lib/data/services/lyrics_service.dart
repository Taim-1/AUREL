import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/lyrics_document.dart';
import '../models/track.dart';

class LyricsService {
  LyricsService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.musixmatch.com/ws/1.1/',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 16),
            sendTimeout: const Duration(seconds: 10),
            responseType: ResponseType.json,
            headers: const {'Accept': 'application/json'},
          ),
        );

  static const _storageKey = 'aurel.musixmatch.api_key';
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Map<String, LyricsDocument?> _cache = {};
  final Map<String, Future<LyricsDocument?>> _inFlight = {};
  String? _apiKey;
  int _cacheGeneration = 0;

  bool get hasApiKey => _apiKey?.isNotEmpty == true;

  Future<void> initialize() async {
    _apiKey = await _storage.read(key: _storageKey);
  }

  Future<void> saveApiKey(String value) async {
    final key = value.trim();
    if (key.isEmpty) {
      throw const LyricsServiceException('Enter a Musixmatch API key first.');
    }
    await _storage.write(key: _storageKey, value: key);
    _apiKey = key;
    _cacheGeneration++;
    _cache.clear();
    _inFlight.clear();
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: _storageKey);
    _apiKey = null;
    _cacheGeneration++;
    _cache.clear();
    _inFlight.clear();
  }

  Future<LyricsDocument?> fetchFor(
    Track track, {
    bool forceRefresh = false,
    bool allowNetwork = true,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw const LyricsServiceException(
        'Add your Musixmatch API key in Profile to load licensed lyrics.',
      );
    }

    final cacheKey = _cacheKey(track);
    // Offline mode can reuse only the in-memory result for this exact
    // recording/version. Lyrics are never written to persistent storage.
    if (!allowNetwork) return _cache[cacheKey];
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // A refresh never races an existing fetch for the same recording.
    final existing = _inFlight[cacheKey];
    if (existing != null) return existing;

    final generation = _cacheGeneration;
    final request = _fetch(
      track,
      cacheKey: cacheKey,
      cacheGeneration: generation,
      apiKey: apiKey,
    );
    _inFlight[cacheKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight[cacheKey], request)) {
        _inFlight.remove(cacheKey);
      }
    }
  }

  String _cacheKey(Track track) => [
        track.providerId.trim(),
        track.id.trim(),
        _normalize(track.title),
        _normalize(track.artist),
        _normalize(track.album),
        track.durationMs.toString(),
      ].join('|');

  Future<LyricsDocument?> _fetch(
    Track track, {
    required String cacheKey,
    required int cacheGeneration,
    required String apiKey,
  }) async {
    final search = await _request('track.search', {
      'q_track': track.title,
      'q_artist': track.artist,
      'page': 1,
      'page_size': 10,
      's_track_rating': 'desc',
    }, apiKey: apiKey);
    final list = _body(search)['track_list'];
    if (list is! List) {
      _storeCache(cacheKey, null, cacheGeneration);
      return null;
    }

    final title = _normalize(track.title);
    final artist = _normalize(track.artist);
    final exactMatches = list
        .whereType<Map<String, dynamic>>()
        .map((item) => item['track'])
        .whereType<Map<String, dynamic>>()
        .where((item) =>
            _normalize((item['track_name'] ?? '').toString()) == title &&
            _normalize((item['artist_name'] ?? '').toString()) == artist)
        .toList(growable: false);

    if (exactMatches.isEmpty) {
      _storeCache(cacheKey, null, cacheGeneration);
      return null;
    }

    final permittedMatches = exactMatches
        .where((item) => _int(item['restricted']) != 1)
        .toList(growable: false);
    if (permittedMatches.isEmpty) {
      throw const LyricsServiceException(
        'Lyrics for this track are restricted by the rights holder.',
      );
    }

    // Never attach lyrics from a different edit, live take or extended
    // version just because its title and credited artist happen to match.
    final durationMatches = permittedMatches.where((item) {
      final providerSeconds = _int(item['track_length']);
      if (track.durationMs <= 0 || providerSeconds <= 0) return true;
      return (providerSeconds * 1000 - track.durationMs).abs() <= 8000;
    }).toList(growable: false);

    if (durationMatches.isEmpty) {
      _storeCache(cacheKey, null, cacheGeneration);
      return null;
    }

    final orderedMatches = durationMatches.toList()
      ..sort((a, b) => _compareMatchQuality(track, a, b));
    final match = orderedMatches.first;

    final providerTrackId = match['track_id']?.toString() ?? '';
    if (providerTrackId.isEmpty) {
      _storeCache(cacheKey, null, cacheGeneration);
      return null;
    }

    if (_int(match['instrumental']) == 1) {
      final instrumental = LyricsDocument(
        trackName: track.title,
        artistName: track.artist,
        albumName: track.album,
        durationSeconds: (track.durationMs / 1000).round(),
        instrumental: true,
      );
      _storeCache(cacheKey, instrumental, cacheGeneration);
      return instrumental;
    }

    String? plain;
    String? copyright;
    if (_int(match['has_lyrics']) == 1) {
      final response = await _request('track.lyrics.get', {
        'track_id': providerTrackId,
      }, apiKey: apiKey);
      final lyrics = _body(response)['lyrics'];
      if (lyrics is Map<String, dynamic>) {
        if (_int(lyrics['restricted']) == 1) {
          throw const LyricsServiceException(
            'Lyrics for this track are restricted by the rights holder.',
          );
        }
        final value = (lyrics['lyrics_body'] ?? '').toString().trim();
        if (value.isNotEmpty) plain = value;
        final rights = (lyrics['lyrics_copyright'] ?? '').toString().trim();
        if (rights.isNotEmpty) copyright = rights;
      }
    }

    var synced = const <LyricsLine>[];
    if (_int(match['has_subtitles']) == 1) {
      try {
        final seconds = (track.durationMs / 1000).round();
        final response = await _request('track.subtitle.get', {
          'track_id': providerTrackId,
          'commontrack_id': match['commontrack_id'],
          'subtitle_format': 'lrc',
          if (seconds > 0) 'f_subtitle_length': seconds,
          'f_subtitle_length_max_deviation': 8,
        }, apiKey: apiKey);
        final subtitle = _subtitle(_body(response));
        if (subtitle != null && _int(subtitle['restricted']) != 1) {
          synced = _parseSubtitle(
            (subtitle['subtitle_body'] ?? '').toString(),
            durationSeconds: seconds,
          );
          final rights =
              (subtitle['lyrics_copyright'] ?? '').toString().trim();
          if (copyright == null && rights.isNotEmpty) copyright = rights;
        }
      } on LyricsServiceException {
        // Keep plain licensed lyrics when synchronized subtitles are
        // unavailable for the current account plan.
      }
    }

    if (plain == null && synced.isEmpty) {
      _storeCache(cacheKey, null, cacheGeneration);
      return null;
    }
    final document = LyricsDocument(
      trackName: track.title,
      artistName: track.artist,
      albumName: track.album,
      durationSeconds: (track.durationMs / 1000).round(),
      plainLyrics: plain,
      lyricsCopyright: copyright,
      syncedLines: synced,
    );
    _storeCache(cacheKey, document, cacheGeneration);
    return document;
  }

  Future<Map<String, dynamic>> _request(
    String endpoint,
    Map<String, dynamic> parameters, {
    required String apiKey,
  }) async {
    final key = apiKey;
    if (key.isEmpty) {
      throw const LyricsServiceException(
        'Add your Musixmatch API key in Profile.',
      );
    }
    try {
      final response = await _dio.get<Object?>(
        endpoint,
        queryParameters: {
          'apikey': key,
          'format': 'json',
          ...parameters,
        },
      );
      final envelope = response.data;
      if (envelope is! Map<String, dynamic>) {
        throw const LyricsServiceException(
          'The lyrics provider returned an unreadable response.',
        );
      }
      final message = envelope['message'];
      if (message is! Map<String, dynamic>) {
        throw const LyricsServiceException(
          'The lyrics provider returned an incomplete response.',
        );
      }
      final header = message['header'];
      final status = header is Map<String, dynamic>
          ? _int(header['status_code'])
          : 0;
      if (status != 200) {
        if (status == 401 || status == 402 || status == 403) {
          throw const LyricsServiceException(
            'Musixmatch rejected the key or this feature is not included in its plan.',
          );
        }
        if (status == 404) {
          throw const LyricsServiceException(
            'No licensed lyrics match was found for this track.',
          );
        }
        if (status == 429) {
          throw const LyricsServiceException(
            'The lyrics service is busy. Try again shortly.',
          );
        }
        throw LyricsServiceException('Lyrics provider status: $status.');
      }
      return message;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        throw const LyricsServiceException(
          'Musixmatch rejected the API key or account permissions.',
        );
      }
      if (error.response?.statusCode == 429) {
        throw const LyricsServiceException(
          'The lyrics service is busy. Try again shortly.',
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        throw const LyricsServiceException(
          'Could not connect to the lyrics service. Check your connection.',
        );
      }
      throw const LyricsServiceException(
        'Lyrics could not be loaded right now. Please try again.',
      );
    }
  }

  Map<String, dynamic> _body(Map<String, dynamic> message) {
    final body = message['body'];
    return body is Map<String, dynamic> ? body : const {};
  }

  Map<String, dynamic>? _subtitle(Map<String, dynamic> body) {
    final value = body['subtitle'];
    if (value is Map<String, dynamic>) return value;
    final list = body['subtitle_list'];
    if (list is List && list.isNotEmpty) {
      final first = list.first;
      if (first is Map<String, dynamic> &&
          first['subtitle'] is Map<String, dynamic>) {
        return first['subtitle'] as Map<String, dynamic>;
      }
    }
    return null;
  }

  List<LyricsLine> _parseSubtitle(
    String source, {
    required int durationSeconds,
  }) {
    final lrc = LyricsDocument.parseLrc(source);
    if (lrc.isNotEmpty) return _withinDuration(lrc, durationSeconds);

    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      final lines = <LyricsLine>[];
      for (final item in decoded.whereType<Map<String, dynamic>>()) {
        final text = (item['text'] ?? '').toString().trim();
        final time = item['time'];
        if (text.isEmpty || time is! Map<String, dynamic>) continue;
        lines.add(
          LyricsLine(
            start: Duration(
              minutes: _int(time['minutes']),
              seconds: _int(time['seconds']),
              milliseconds: _int(time['hundredths']) * 10,
            ),
            text: text,
          ),
        );
      }
      lines.sort((a, b) => a.start.compareTo(b.start));
      return _withinDuration(lines, durationSeconds);
    } on FormatException {
      return const [];
    }
  }

  List<LyricsLine> _withinDuration(
    List<LyricsLine> lines,
    int durationSeconds,
  ) {
    final latestAllowed = Duration(seconds: durationSeconds + 5);
    return List.unmodifiable(
      lines.where((line) =>
          line.text.trim().isNotEmpty &&
          !line.start.isNegative &&
          (durationSeconds <= 0 || line.start <= latestAllowed)),
    );
  }

  int _compareMatchQuality(
    Track requested,
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    int albumRank(Map<String, dynamic> item) {
      if (requested.album.trim().isEmpty) return 1;
      final album = _normalize((item['album_name'] ?? '').toString());
      return album == _normalize(requested.album) ? 0 : 1;
    }

    final album = albumRank(a).compareTo(albumRank(b));
    if (album != 0) return album;

    int durationDifference(Map<String, dynamic> item) {
      final seconds = _int(item['track_length']);
      return requested.durationMs <= 0 || seconds <= 0
          ? 1 << 30
          : (seconds * 1000 - requested.durationMs).abs();
    }

    final duration = durationDifference(a).compareTo(durationDifference(b));
    if (duration != 0) return duration;

    final subtitles = _int(b['has_subtitles']).compareTo(
      _int(a['has_subtitles']),
    );
    if (subtitles != 0) return subtitles;

    final lyrics = _int(b['has_lyrics']).compareTo(_int(a['has_lyrics']));
    if (lyrics != 0) return lyrics;

    return _int(b['track_rating']).compareTo(_int(a['track_rating']));
  }

  void _storeCache(
    String cacheKey,
    LyricsDocument? document,
    int generation,
  ) {
    if (generation == _cacheGeneration) {
      _cache[cacheKey] = document;
    }
  }

  int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'''[\s\-_.,!?;:'"()\[\]{}]+'''), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class LyricsServiceException implements Exception {
  const LyricsServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
