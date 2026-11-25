import 'package:dio/dio.dart';

import '../models/track.dart';
import 'providers/apple_music_catalog_service.dart';
import 'providers/audius_service.dart';
import 'providers/jamendo_service.dart';
import 'providers/internet_archive_service.dart';
import 'providers/openverse_service.dart';
import 'providers/soundcloud_service.dart';
import 'providers/spotify_catalog_service.dart';
import 'providers/wikimedia_commons_service.dart';
import 'providers/music_brainz_service.dart';

class CatalogPage {
  const CatalogPage({
    required this.tracks,
    required this.hasMore,
    required this.sourceCounts,
    required this.sourceErrors,
  });

  final List<Track> tracks;
  final bool hasMore;
  final Map<String, int> sourceCounts;
  final Map<String, String> sourceErrors;
}

class MusicCatalogService {
  MusicCatalogService({
    required this.jamendo,
    required this.audius,
    required this.soundcloud,
    required this.spotify,
    required this.appleMusic,
    required this.openverse,
    required this.internetArchive,
    required this.wikimediaCommons,
    required this.musicBrainz,
  });

  final JamendoService jamendo;
  final AudiusService audius;
  final SoundCloudService soundcloud;
  final SpotifyCatalogService spotify;
  final AppleMusicCatalogService appleMusic;
  final OpenverseService openverse;
  final InternetArchiveService internetArchive;
  final WikimediaCommonsService wikimediaCommons;
  final MusicBrainzService musicBrainz;

  static const pageSize = 30;

  static const _providerRank = <String, int>{
    'soundcloud': 40,
    'audius': 30,
    'jamendo': 20,
    'internet_archive': 19,
    'openverse': 18,
    'wikimedia_commons': 17,
    'apple_music': 10,
    'spotify': 5,
    'musicbrainz': 4,
  };

  Future<CatalogPage> search(
    String query, {
    int page = 0,
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const CatalogPage(
        tracks: [],
        hasMore: false,
        sourceCounts: {},
        sourceErrors: {},
      );
    }
    final offset = page * pageSize;
    final collected = await _collect([
      _SourceRequest(
        'Jamendo',
        () => jamendo.search(
          normalized,
          limit: pageSize,
          offset: offset,
        ),
      ),
      _SourceRequest(
        'Audius',
        () => audius.search(
          normalized,
          limit: pageSize,
          offset: offset,
          cancelToken: cancelToken,
        ),
      ),
      _SourceRequest(
        'SoundCloud',
        () => soundcloud.search(
          normalized,
          limit: pageSize,
          offset: offset,
          cancelToken: cancelToken,
        ),
      ),
      _SourceRequest(
        'Spotify',
        () => spotify.search(
          normalized,
          limit: 10,
          offset: page * 10,
          cancelToken: cancelToken,
        ),
      ),
      _SourceRequest(
        'Apple Music',
        () => appleMusic.search(
          normalized,
          limit: 15,
          cancelToken: cancelToken,
        ),
      ),
      _SourceRequest(
        'Openverse',
        () => openverse.search(
          normalized,
          page: page + 1,
          pageSize: 15,
          cancelToken: cancelToken,
        ),
      ),
      _SourceRequest(
        'Internet Archive',
        () => internetArchive.search(
          normalized,
          page: page,
          pageSize: 12,
          cancelToken: cancelToken,
        ),
      ),
      _SourceRequest(
        'Recording metadata',
        () => musicBrainz.search(
          normalized,
          limit: 25,
          offset: page * 25,
          cancelToken: cancelToken,
        ),
      ),
    ]);
    final commons = await _collectCommons(
      normalized,
      page: page,
      cancelToken: cancelToken,
    );
    return _buildPage(
      _CollectedSources({...collected.sources, 'Open audio': commons}),
    );
  }

  Future<CatalogPage> discover({
    int page = 0,
    CancelToken? cancelToken,
  }) async {
    final offset = page * pageSize;
    final collected = await _collect([
      _SourceRequest(
        'Jamendo',
        () => jamendo.popular(
          limit: pageSize,
          offset: offset,
        ),
      ),
      _SourceRequest(
        'Audius',
        () => audius.trending(
          limit: pageSize,
          offset: offset,
          cancelToken: cancelToken,
        ),
      ),
      _SourceRequest(
        'Openverse',
        () => openverse.search(
          'instrumental music',
          page: page + 1,
          pageSize: 15,
          cancelToken: cancelToken,
        ),
      ),
      _SourceRequest(
        'Internet Archive',
        () => internetArchive.search(
          'music',
          page: page,
          pageSize: 12,
          cancelToken: cancelToken,
        ),
      ),
      _SourceRequest(
        'SoundCloud',
        () => soundcloud.search(
          'trending music',
          limit: pageSize,
          offset: offset,
          cancelToken: cancelToken,
        ),
      ),
    ]);
    final commons = await _collectCommons(
      'instrumental music',
      page: page,
      cancelToken: cancelToken,
    );
    return _buildPage(
      _CollectedSources({...collected.sources, 'Open audio': commons}),
    );
  }

  Future<_SourceResult> _collectCommons(
    String query, {
    required int page,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      return _SourceResult.success(const []);
    }
    try {
      final tracks = await wikimediaCommons.search(
        query,
        page: page,
        cancelToken: cancelToken,
      );
      return _SourceResult.success(tracks);
    } catch (error) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        rethrow;
      }
      return _SourceResult.failure(
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<List<Track>> prepareQueue(
    List<Track> tracks, {
    String? requiredTrackId,
  }) async {
    final output = <Track>[];
    for (final track in tracks) {
      if (!track.canPlay) continue;
      try {
        output.add(await prepareTrack(track));
      } catch (_) {
        // An unavailable provider entry must not block other playable
        // providers in the queue. The specifically selected track is strict.
        if (track.id == requiredTrackId) rethrow;
      }
    }
    return output;
  }

  Future<Track> prepareTrack(Track track) async {
    if (!track.canPlay) {
      throw const CatalogPlaybackException(
        'This recording is listed in the AUREL catalogue, but an '
        'authorized in-app audio stream is not available.',
      );
    }
    if (track.providerId == 'soundcloud') {
      return soundcloud.prepareForPlayback(track);
    }
    return track;
  }

  Future<_CollectedSources> _collect(
    List<_SourceRequest> requests,
  ) async {
    final tasks = requests.map((request) async {
      try {
        final tracks = await request.load();
        return MapEntry(request.name, _SourceResult.success(tracks));
      } catch (error) {
        return MapEntry(
          request.name,
          _SourceResult.failure(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        );
      }
    });
    final entries = await Future.wait(tasks);
    return _CollectedSources({
      for (final entry in entries) entry.key: entry.value,
    });
  }

  CatalogPage _buildPage(_CollectedSources results) {
    final sourceCounts = <String, int>{
      for (final entry in results.sources.entries)
        entry.key: entry.value.tracks.length,
    };
    final sourceErrors = <String, String>{
      for (final entry in results.sources.entries)
        if (entry.value.error != null) entry.key: entry.value.error!,
    };

    final allTracks = results.sources.values
        .expand((result) => result.tracks)
        .where((track) => track.id.isNotEmpty)
        .toList(growable: false);

    final groups = <String, List<Track>>{};
    for (final track in allTracks) {
      final identity = _identity(track);
      groups.putIfAbsent(identity, () => <Track>[]).add(track);
    }

    final ranked = <Track>[];
    for (final group in groups.values) {
      final best = [...group]..sort(_compareTracks);
      final selected = best.first;
      final sources = group
          .map((track) => track.providerName)
          .toSet()
          .toList(growable: false);
      ranked.add(
        selected.copyWith(
          matchedSources: sources,
        ),
      );
    }

    ranked.sort(_compareTracks);
    final playable = ranked.where((track) => track.canPlay).toList();
    final metadataOnly = ranked.where((track) => !track.canPlay).toList();

    // Playable matches are always preferred. Metadata-only Spotify/Apple
    // results remain discoverable when there is no eligible in-app copy.
    final ordered = [...playable, ...metadataOnly];
    final pageThresholds = <String, int>{
      'Jamendo': pageSize,
      'Audius': pageSize,
      'SoundCloud': pageSize,
      'Spotify': 10,
      'Apple Music': 15,
      'Openverse': 15,
      'Internet Archive': 12,
      'Open audio': 20,
      'Recording metadata': 25,
    };
    final hasMore = results.sources.entries.any(
      (entry) =>
          entry.value.tracks.length >=
          (pageThresholds[entry.key] ?? pageSize),
    );

    return CatalogPage(
      tracks: ordered,
      hasMore: hasMore,
      sourceCounts: sourceCounts,
      sourceErrors: sourceErrors,
    );
  }

  String _identity(Track track) {
    final isrc = track.recordingId
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (isrc.isNotEmpty) return 'isrc:$isrc';

    final title = _normalize(track.title);
    final artist = _normalize(track.artist);
    final durationBucket = track.durationMs > 0
        ? (track.durationMs / 10000).round().toString()
        : 'unknown';
    return 'title:$title|artist:$artist|duration:$durationBucket';
  }

  String _normalize(String value) => value
      .toLowerCase()
      // Keep version labels such as (Live), (Remix), and (Acoustic).
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  int _compareTracks(Track a, Track b) {
    final aPlayable = a.canPlay ? 1 : 0;
    final bPlayable = b.canPlay ? 1 : 0;
    final playableCompare = bPlayable.compareTo(aPlayable);
    if (playableCompare != 0) return playableCompare;

    final aRank = _providerRank[a.providerId] ?? 0;
    final bRank = _providerRank[b.providerId] ?? 0;
    return bRank.compareTo(aRank);
  }
}

class CatalogPlaybackException implements Exception {
  const CatalogPlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _SourceRequest {
  const _SourceRequest(this.name, this.load);

  final String name;
  final Future<List<Track>> Function() load;
}

class _SourceResult {
  const _SourceResult._(this.tracks, this.error);

  factory _SourceResult.success(List<Track> tracks) =>
      _SourceResult._(tracks, null);

  factory _SourceResult.failure(String error) =>
      _SourceResult._(const [], error);

  final List<Track> tracks;
  final String? error;
}

class _CollectedSources {
  const _CollectedSources(this.sources);

  final Map<String, _SourceResult> sources;
}
