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
    _cache.clear();
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: _storageKey);
    _apiKey = null;
    _cache.clear();
  }

  Future<LyricsDocument?> fetchFor(
    Track track, {
    bool forceRefresh = false,
  }) {
    if (!hasApiKey) {
      return Future.error(
        const LyricsServiceException(
          'Add your Musixmatch API key in Profile to load licensed lyrics.',
        ),
      );
    }
    if (!forceRefresh && _cache.containsKey(track.id)) {
      return Future.value(_cache[track.id]);
    }
    if (!forceRefresh && _inFlight.containsKey(track.id)) {
      return _inFlight[track.id]!;
    }
    final request = _fetch(track);
    _inFlight[track.id] = request;
    return request.whenComplete(() {
      _inFlight.remove(track.id);
    });
  }

  Future<LyricsDocument?> _fetch(Track track) async {
    final search = await _request('track.search', {
      'q_track': track.title,
      'q_artist': track.artist,
      'page': 1,
      'page_size': 10,
      's_track_rating': 'desc',
    });
    final list = _body(search)['track_list'];
    if (list is! List) {
      _cache[track.id] = null;
      return null;
    }

    final title = _normalize(track.title);
    final artist = _normalize(track.artist);
    final matches = list
        .whereType<Map<String, dynamic>>()
        .map((item) => item['track'])
        .whereType<Map<String, dynamic>>()
        .where((item) =>
            _normalize((item['track_name'] ?? '').toString()) == title &&
            _normalize((item['artist_name'] ?? '').toString()) == artist)
        .toList(growable: false);

    if (matches.isEmpty) {
      _cache[track.id] = null;
      return null;
    }

    final match = matches.first;
    if (_int(match['restricted']) == 1) {
      throw const LyricsServiceException(
        'Lyrics for this track are restricted by the rights holder.',
      );
    }
    final providerTrackId = match['track_id']?.toString() ?? '';
    if (providerTrackId.isEmpty) {
      _cache[track.id] = null;
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
      _cache[track.id] = instrumental;
      return instrumental;
    }

    String? plain;
    String? copyright;
    if (_int(match['has_lyrics']) == 1) {
      final response = await _request('track.lyrics.get', {
        'track_id': providerTrackId,
      });
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
        });
        final subtitle = _subtitle(_body(response));
        if (subtitle != null && _int(subtitle['restricted']) != 1) {
          synced = _parseSubtitle(
            (subtitle['subtitle_body'] ?? '').toString(),
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
      _cache[track.id] = null;
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
    _cache[track.id] = document;
    return document;
  }

  Future<Map<String, dynamic>> _request(
    String endpoint,
    Map<String, dynamic> parameters,
  ) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
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

  List<LyricsLine> _parseSubtitle(String source) {
    final lrc = LyricsDocument.parseLrc(source);
    if (lrc.isNotEmpty) return lrc;
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
      return List.unmodifiable(lines);
    } on FormatException {
      return const [];
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
