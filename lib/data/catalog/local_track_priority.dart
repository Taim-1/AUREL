import '../models/track.dart';
import 'catalog_identity.dart';
import 'catalog_ranking.dart';

class LocalTrackPriority {
  const LocalTrackPriority._();

  static Track? findLocalCopy(
    Track track,
    Iterable<Track> localTracks,
  ) {
    final recordings = <Track>[track, ...track.alternatives];

    for (final local in localTracks) {
      if (!local.isLocal || !local.canPlay) continue;
      if (recordings.any((recording) => _isSameRecording(local, recording))) {
        return local;
      }
    }

    return null;
  }

  static Track preferLocalCopy(
    Track track,
    Iterable<Track> localTracks,
  ) {
    final local = findLocalCopy(track, localTracks);
    if (local == null) return track;

    final candidates = <String, Track>{};
    for (final candidate in [track, ...track.alternatives, ...local.alternatives]) {
      if (!candidate.canPlay || candidate.id == local.id) continue;
      candidates[candidate.id] = candidate.copyWith(alternatives: const []);
    }

    final alternatives = candidates.values.toList(growable: false)
      ..sort(CatalogRanking.compare);

    final recordingMetadata = <Track>[track, ...track.alternatives];
    final title = _firstNonEmpty(
      [local.title, ...recordingMetadata.map((item) => item.title)],
      fallback: 'Unknown track',
    );
    final artist = _firstNonEmpty(
      [local.artist, ...recordingMetadata.map((item) => item.artist)],
      fallback: 'Unknown artist',
    );
    final album = _firstNonEmpty(
      [local.album, ...recordingMetadata.map((item) => item.album)],
    );
    final artwork = _firstNonEmpty(
      [local.artworkUrl, ...recordingMetadata.map((item) => item.artworkUrl)],
    );
    final duration = local.durationMs > 0
        ? local.durationMs
        : recordingMetadata
            .firstWhere(
              (item) => item.durationMs > 0,
              orElse: () => local,
            )
            .durationMs;
    final recordingId = _firstNonEmpty([
      local.recordingId,
      ...recordingMetadata.map((item) => item.recordingId),
    ]);
    final recordingMbid = _firstNonEmpty([
      local.recordingMbid,
      ...recordingMetadata.map((item) => item.recordingMbid),
    ]);
    final matchedSources = {
      ...local.matchedSources,
      ...track.matchedSources,
      if (track.providerName.trim().isNotEmpty) track.providerName,
      for (final alternative in track.alternatives) ...[
        ...alternative.matchedSources,
        if (alternative.providerName.trim().isNotEmpty)
          alternative.providerName,
      ],
    }.toList(growable: false);

    return local.copyWith(
      title: title,
      artist: artist,
      album: album,
      artworkUrl: artwork,
      durationMs: duration,
      recordingId: recordingId,
      recordingMbid: recordingMbid,
      matchedSources: matchedSources,
      alternatives: alternatives,
    );
  }

  static bool _isSameRecording(Track local, Track candidate) =>
      local.id == candidate.id || CatalogIdentity.matches(local, candidate);

  static String _firstNonEmpty(
    Iterable<String> values, {
    String fallback = '',
  }) {
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isNotEmpty && normalized != 'Unknown track' &&
          normalized != 'Unknown artist') {
        return normalized;
      }
    }
    return fallback;
  }
}
