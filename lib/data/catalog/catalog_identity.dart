import '../models/track.dart';

/// Recording identity rules shared by search, discovery and catalogue tests.
///
/// A matching MusicBrainz recording MBID is authoritative, followed by an
/// exact ISRC. Otherwise title, credited artist and a close duration must all
/// agree. Version words remain in the normalized title, so Live/Remix/Acoustic
/// releases stay distinct.
class CatalogIdentity {
  const CatalogIdentity._();

  static const int durationToleranceMs = 5000;

  /// Canonical recording key. Verified cross-provider IDs are shared; when
  /// neither exists the source identity remains part of the fallback key.
  static String keyOf(Track track) {
    final mbid = track.recordingMbid.trim().toLowerCase();
    if (mbid.isNotEmpty) return 'mbid:$mbid';

    final isrc = _normalizeIsrc(track.recordingId);
    if (isrc.isNotEmpty) return 'isrc:$isrc';

    if (track.id.trim().isNotEmpty) {
      return '${track.providerId}:${track.id.trim()}';
    }

    return [
      track.providerId,
      normalizeText(track.title),
      normalizeText(track.artist),
      normalizeText(track.album),
      track.durationMs,
    ].join(':');
  }

  /// Provider-specific key for trying every eligible source exactly once.
  /// Unlike [keyOf], this deliberately keeps same-recording providers apart.
  static String providerKeyOf(Track track) {
    final id = track.id.trim();
    if (id.isNotEmpty) return '${track.providerId}:$id';

    return [
      track.providerId,
      track.recordingMbid.trim().toLowerCase(),
      _normalizeIsrc(track.recordingId),
      normalizeText(track.title),
      normalizeText(track.artist),
      normalizeText(track.album),
      track.durationMs,
    ].join(':');
  }

  /// Conflicting verified identifiers are a hard boundary. A weak metadata
  /// result must never bridge two groups that identify different recordings.
  static bool _hasIdentifierConflict(Track a, Track b) {
    final aIsrc = _normalizeIsrc(a.recordingId);
    final bIsrc = _normalizeIsrc(b.recordingId);
    final bothHaveIsrc = aIsrc.isNotEmpty && bIsrc.isNotEmpty;

    if (bothHaveIsrc && aIsrc != bIsrc) return true;

    final aMbid = a.recordingMbid.trim().toLowerCase();
    final bMbid = b.recordingMbid.trim().toLowerCase();
    final bothHaveMbid = aMbid.isNotEmpty && bMbid.isNotEmpty;

    // An exact ISRC is allowed to reconcile different catalogue MBIDs, but
    // two conflicting MBIDs without that shared ISRC must remain separate.
    if (bothHaveMbid && aMbid != bMbid) {
      return !bothHaveIsrc || aIsrc != bIsrc;
    }

    return false;
  }

  static bool matches(Track a, Track b) {
    final aId = a.id.trim();
    final bId = b.id.trim();

    // A provider's own stable track ID is authoritative even when that
    // provider omits duration and recording identifiers.
    if (a.providerId == b.providerId &&
        aId.isNotEmpty &&
        aId == bId) {
      return true;
    }

    if (_hasIdentifierConflict(a, b)) return false;

    final aMbid = a.recordingMbid.trim().toLowerCase();
    final bMbid = b.recordingMbid.trim().toLowerCase();
    if (aMbid.isNotEmpty && bMbid.isNotEmpty && aMbid == bMbid) {
      return true;
    }

    final aIsrc = _normalizeIsrc(a.recordingId);
    final bIsrc = _normalizeIsrc(b.recordingId);
    if (aIsrc.isNotEmpty && bIsrc.isNotEmpty) {
      return aIsrc == bIsrc;
    }

    final aTitle = normalizeText(a.title);
    final bTitle = normalizeText(b.title);
    final aArtist = normalizeText(a.artist);
    final bArtist = normalizeText(b.artist);

    if (aTitle.isEmpty ||
        bTitle.isEmpty ||
        aArtist.isEmpty ||
        bArtist.isEmpty ||
        aTitle != bTitle ||
        aArtist != bArtist) {
      return false;
    }

    if (a.durationMs <= 0 || b.durationMs <= 0) return false;
    return (a.durationMs - b.durationMs).abs() <= durationToleranceMs;
  }

  /// Groups cross-source matches conservatively. Every existing member must
  /// be compatible with a new candidate, not just one member. That prevents
  /// an identifier-free result from joining two different known recordings.
  static List<List<Track>> group(List<Track> tracks) {
    final groups = <List<Track>>[];
    for (final track in tracks) {
      final matchingGroups = <int>[];
      for (var index = 0; index < groups.length; index++) {
        final group = groups[index];
        final compatibleWithEveryMember = group.every(
          (candidate) => !_hasIdentifierConflict(candidate, track),
        );
        if (compatibleWithEveryMember &&
            group.any((candidate) => matches(candidate, track))) {
          matchingGroups.add(index);
        }
      }

      if (matchingGroups.length == 1) {
        groups[matchingGroups.single].add(track);
      } else {
        groups.add([track]);
      }
    }
    return groups;
  }

  static String normalizeText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _normalizeIsrc(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
