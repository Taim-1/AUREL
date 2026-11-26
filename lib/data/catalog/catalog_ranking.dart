import '../models/track.dart';

/// Deterministic AUREL source priority and result-quality ordering.
///
/// Priority applies only after playback eligibility: an unavailable metadata
/// result can never displace a real playable copy. Local playable files always
/// win, followed by AUREL's agreed online-source order.
class CatalogRanking {
  const CatalogRanking._();

  static const Map<String, int> sourcePriority = {
    'device': 120,
    'local': 120,
    'audius': 100,
    'jamendo': 90,
    'soundcloud': 80,
    'internet_archive': 65,
    'wikimedia_commons': 60,
    'openverse': 55,
    'apple_music': 20,
    'spotify': 15,
    'lastfm': 12,
    'listenbrainz': 11,
    'musicbrainz': 5,
  };

  /// Negative means [a] should appear before [b].
  static int compare(Track a, Track b) {
    final playable = _descending(a.canPlay ? 1 : 0, b.canPlay ? 1 : 0);
    if (playable != 0) return playable;

    // Among playable copies, prefer the user's own local/downloaded file.
    final local = _descending(a.isLocal ? 1 : 0, b.isLocal ? 1 : 0);
    if (local != 0) return local;

    // Source priority is intentional and deterministic. Quality breaks ties
    // within a source tier; it must not silently reorder the agreed providers.
    final priority = _descending(
      sourcePriority[a.providerId] ?? 0,
      sourcePriority[b.providerId] ?? 0,
    );
    if (priority != 0) return priority;

    final quality = _descending(_qualityScore(a), _qualityScore(b));
    if (quality != 0) return quality;

    // Stable final tie-break keeps ordering deterministic across requests.
    final title = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (title != 0) return title;
    return a.id.compareTo(b.id);
  }

  static int _qualityScore(Track track) {
    var score = 0;
    if (track.recordingId.trim().isNotEmpty) score += 8;
    if (track.artworkUrl.trim().isNotEmpty) score += 4;
    if (track.album.trim().isNotEmpty) score += 3;
    if (track.durationMs > 0) score += 2;
    if (track.sourceUrl.trim().isNotEmpty) score += 1;
    if (track.downloadAllowed && track.downloadUrl.trim().isNotEmpty) {
      score += 1;
    }
    if (track.licenseUrl.trim().isNotEmpty) score += 1;
    return score;
  }

  static int _descending(int a, int b) => b.compareTo(a);
}
