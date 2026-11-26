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
      _SourceRequest(
        'Last.fm discovery',
        () => lastFm.search(
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
      _SourceRequest(
        'Last.fm charts',
        () => lastFm.topTracks(
          limit: pageSize,
          page: page + 1,
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
      throw DioException(
        requestOptions: RequestOptions(path: 'commons-search'),
        type: DioExceptionType.cancel,
        message: 'Open audio search cancelled.',
      );
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
          matchedSources: sources,
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
