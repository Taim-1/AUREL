import 'package:dio/dio.dart';

import '../models/track.dart';
import 'catalog_identity.dart';
import 'catalog_ranking.dart';
import 'providers/apple_music_catalog_service.dart';
import 'providers/audius_service.dart';
import 'providers/jamendo_service.dart';
import 'providers/internet_archive_service.dart';
import 'providers/openverse_service.dart';
import 'providers/soundcloud_service.dart';
import 'providers/spotify_catalog_service.dart';
import 'providers/wikimedia_commons_service.dart';
import 'providers/music_brainz_service.dart';
import 'providers/lastfm_catalog_service.dart';
import 'providers/listenbrainz_catalog_service.dart';

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
    required this.lastFm,
    required this.listenBrainz,
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
  final LastFmCatalogService lastFm;
  final ListenBrainzCatalogService listenBrainz;

  static const pageSize = 30;

  // Search text fields can emit several near-identical requests while the
  // user is typing. A short in-memory cache avoids repeated provider fan-out.
  final Map<String, _CatalogCacheEntry> _pageCache = {};

  CatalogPage? _readCache(String key, CancelToken? cancelToken) {
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: 'catalog-cache'),
        type: DioExceptionType.cancel,
        message: 'Catalogue request cancelled.',
      );
    }
    final entry = _pageCache[key];
    if (entry == null) return null;
    if (!entry.expiresAt.isAfter(DateTime.now())) {
      _pageCache.remove(key);
      return null;
    }
    return entry.page;
  }

  /// Drops cached pages after credentials or provider configuration change.
  void clearCache() => _pageCache.clear();

  void _writeCache(String key, CatalogPage page) {
    // Last.fm's API licence sets a strict data-storage cap and requires
    // caching to respect its response headers. Do not place Last.fm records
    // (including merged alternatives) in AUREL's generic catalogue cache.
    final containsLastFmData = page.tracks.any(
      (track) =>
          track.providerId == 'lastfm' ||
          track.alternatives.any(
            (alternative) => alternative.providerId == 'lastfm',
          ),
    );
    if (containsLastFmData) return;

    // Bound the cache so long sessions cannot accumulate unbounded results.
    if (_pageCache.length >= 30 && !_pageCache.containsKey(key)) {
      _pageCache.remove(_pageCache.keys.first);
    }
    final lifetime = page.sourceErrors.isEmpty
        ? const Duration(minutes: 4)
        : const Duration(seconds: 30);
    _pageCache[key] = _CatalogCacheEntry(
      page,
      DateTime.now().add(lifetime),
    );
  }

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
    final cacheKey = 'search:${normalized.toLowerCase()}:$page';
    final cached = _readCache(cacheKey, cancelToken);
    if (cached != null) return cached;

    final offset = page * pageSize;
    final collected = await _collect([
      _SourceRequest(
        'Jamendo',
        () => jamendo.search(
          normalized,
          limit: pageSize,
          offset: offset,
          cancelToken: cancelToken,
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
          offset: page * 15,
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
      if (lastFm.isConfigured)
        _SourceRequest(
          'Last.fm discovery',
          () => lastFm.search(
            normalized,
            limit: pageSize,
            page: page + 1,
            cancelToken: cancelToken,
          ),
        ),
      if (lastFm.isConfigured)
        _SourceRequest(
          'Last.fm artist catalogue',
          () => lastFm.searchArtistTopTracks(
            normalized,
            limit: pageSize,
            page: page + 1,
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
      _SourceRequest(
        'Open audio',
        () => wikimediaCommons.search(
          normalized,
          page: page,
          cancelToken: cancelToken,
        ),
      ),
    ]);
    final result = _buildPage(collected);
    _writeCache(cacheKey, result);
    return result;
  }

  Future<CatalogPage> discover({
    int page = 0,
    CancelToken? cancelToken,
  }) async {
    final cacheKey = 'discover:$page';
    final cached = _readCache(cacheKey, cancelToken);
    if (cached != null) return cached;

    final offset = page * pageSize;
    final collected = await _collect([
      _SourceRequest(
        'Jamendo',
        () => jamendo.popular(
          limit: pageSize,
          offset: offset,
          cancelToken: cancelToken,
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
      _SourceRequest(
        'ListenBrainz global charts',
        () => listenBrainz.sitewideTopRecordings(
          count: pageSize,
          offset: offset,
          cancelToken: cancelToken,
        ),
      ),
      if (lastFm.isConfigured)
        _SourceRequest(
          'Last.fm charts',
          () => lastFm.topTracks(
            limit: pageSize,
            page: page + 1,
            cancelToken: cancelToken,
          ),
        ),
      _SourceRequest(
        'Open audio',
        () => wikimediaCommons.search(
          'instrumental music',
          page: page,
          cancelToken: cancelToken,
        ),
      ),
    ]);
    final result = _buildPage(collected);
    _writeCache(cacheKey, result);
    return result;
  }

  Future<List<Track>> prepareQueue(
    List<Track> tracks, {
    String? requiredTrackId,
  }) async {
    final output = <Track>[];
    for (final track in tracks) {
      final hasPlayableAlternative = track.alternatives.any(
        (alternative) => alternative.canPlay,
      );
      if (!track.canPlay && !hasPlayableAlternative) continue;
      try {
        output.add(await prepareTrack(track));
      } catch (_) {
        // An unavailable recording must not block the rest of the queue.
        // The specifically selected track remains strict and reports failure.
        if (track.id == requiredTrackId) rethrow;
      }
    }
    return output;
  }

  /// Tries same-recording copies in AUREL priority order. Alternatives were
  /// grouped by recording identity before this method is called, so fallback
  /// can never silently switch to a different song, remix or live version.
  Future<Track> prepareTrack(Track track) async {
    // AUREL-managed downloads are already authorized local files. Never ask
    // an online provider for a token while playing a saved offline copy.
    if (track.isLocal && track.canPlay) return track;

    final candidates = <Track>[
      track,
      ...track.alternatives,
    ].where((candidate) => candidate.canPlay);

    Object? lastError;
    final attemptedIds = <String>{};
    for (final candidate in candidates) {
      try {
        final prepared = candidate.isLocal && candidate.canPlay
            ? candidate
            : candidate.providerId == 'soundcloud'
                ? await soundcloud.prepareForPlayback(candidate)
                : candidate;
        attemptedIds.add(candidate.id);

        // Keep the selected catalogue identity stable while removing every
        // source already tried during preparation from future playback retry.
        final remaining = track.alternatives
            .where((alternative) => !attemptedIds.contains(alternative.id))
            .toList(growable: false);
        return prepared.copyWith(
          id: track.id,
          alternatives: remaining,
        );
      } catch (error) {
        attemptedIds.add(candidate.id);
        lastError = error;
      }
    }

    if (lastError != null) {
      throw CatalogPlaybackException(
        'The preferred source and its eligible alternatives could not '
        'prepare this recording: $lastError',
      );
    }
    throw const CatalogPlaybackException(
      'This recording is listed in the AUREL catalogue, but an '
      'authorized in-app audio stream is not available.',
    );
  }

  /// Prepares authorization for an allowed offline copy independently of
  /// streaming eligibility. Some providers permit downloads for tracks that
  /// are not available as live streams.
  Future<Track> prepareTrackForDownload(Track track) async {
    if (!track.downloadAllowed || track.downloadUrl.trim().isEmpty) {
      throw const CatalogPlaybackException(
        'Offline download is not permitted for this recording.',
      );
    }
    if (track.providerId == 'soundcloud') {
      return soundcloud.prepareForDownload(track);
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
        if (error is DioException && error.type == DioExceptionType.cancel) {
          rethrow;
        }
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

    // Group by verified recording identity, not rounded duration buckets.
    final groups = CatalogIdentity.group(allTracks);

    final ranked = <Track>[];
    for (final group in groups) {
      final best = [...group]..sort(CatalogRanking.compare);
      final selected = best.first;
      final sources = best
          .map((track) => track.providerName)
          .toSet()
          .toList(growable: false);

      // Metadata catalogues can improve a playable recording's presentation,
      // but must never replace its stream, download rights or attribution.
      final artwork = best
          .firstWhere(
            (track) => track.artworkUrl.trim().isNotEmpty,
            orElse: () => selected,
          )
          .artworkUrl;
      final album = best
          .firstWhere(
            (track) => track.album.trim().isNotEmpty,
            orElse: () => selected,
          )
          .album;
      final duration = best
          .firstWhere(
            (track) => track.durationMs > 0,
            orElse: () => selected,
          )
          .durationMs;
      final recordingId = best
          .firstWhere(
            (track) => track.recordingId.trim().isNotEmpty,
            orElse: () => selected,
          )
          .recordingId;
      final recordingMbid = best
          .firstWhere(
            (track) => track.recordingMbid.trim().isNotEmpty,
            orElse: () => selected,
          )
          .recordingMbid;

      ranked.add(
        selected.copyWith(
          artworkUrl: selected.artworkUrl.trim().isEmpty
              ? artwork
              : selected.artworkUrl,
          album: selected.album.trim().isEmpty ? album : selected.album,
          durationMs: selected.durationMs > 0
              ? selected.durationMs
              : duration,
          recordingId: selected.recordingId.trim().isEmpty
              ? recordingId
              : selected.recordingId,
          recordingMbid: selected.recordingMbid.trim().isEmpty
              ? recordingMbid
              : selected.recordingMbid,
          matchedSources: sources,
          alternatives: best.skip(1).toList(growable: false),
        ),
      );
    }

    ranked.sort(_compareTracks);
    final playable = ranked.where((track) => track.canPlay).toList();
    final metadataOnly = ranked.where((track) => !track.canPlay).toList();

    // Playable matches are always preferred. Commercial and community
    // metadata indexes remain discoverable without inventing an audio stream.
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
      'Last.fm discovery': pageSize,
      'Last.fm artist catalogue': pageSize,
      'Last.fm charts': pageSize,
      'ListenBrainz global charts': pageSize,
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

  int _compareTracks(Track a, Track b) =>
      CatalogRanking.compare(a, b);
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


class _CatalogCacheEntry {
  const _CatalogCacheEntry(this.page, this.expiresAt);

  final CatalogPage page;
  final DateTime expiresAt;
}
