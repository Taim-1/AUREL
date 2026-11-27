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

    final matches = localTracks
        .where(
          (local) =>
              local.isLocal &&
              local.canPlay &&
              recordings.any(
                (recording) => _isSameRecording(local, recording),
              ),
        )
        .toList(growable: false)
      ..sort((a, b) {
        final managedDownload =
            (b.isDownloaded ? 1 : 0).compareTo(a.isDownloaded ? 1 : 0);
        return managedDownload != 0
            ? managedDownload
            : CatalogRanking.compare(a, b);
      });

    return matches.isEmpty ? null : matches.first;
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
    final matchedSources = <String>[
      ...local.matchedSources,
      ...track.matchedSources,
      track.providerName,
      for (final alternative in track.alternatives) ...[
        ...alternative.matchedSources,
        alternative.providerName,
      ],
    ]
        .map((source) => source.trim())
        .where((source) => source.isNotEmpty)
        .toSet()
        .toList(growable: false);

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
