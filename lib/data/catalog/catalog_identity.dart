import '../models/track.dart';

/// Recording identity rules shared by search, discovery and catalogue tests.
///
/// A matching MusicBrainz MBID is authoritative, followed by an exact ISRC.
/// Otherwise the title,
/// credited artist and a close duration must all agree. Version words remain
/// part of the normalized title, so Live/Remix/Acoustic releases stay distinct.
class CatalogIdentity {
  const CatalogIdentity._();

  static const int durationToleranceMs = 5000;

  static bool matches(Track a, Track b) {
    // A provider's own stable track ID is authoritative even when that
    // provider omits duration and recording identifiers.
    if (a.providerId == b.providerId &&
        a.id.isNotEmpty &&
        a.id == b.id) {
      return true;
    }

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

    // Conflicting verified MBIDs must not fall through to fuzzy matching.
    if (aMbid.isNotEmpty && bMbid.isNotEmpty) return false;

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

  /// Groups cross-source matches conservatively. Ambiguous entries are kept
  /// separate rather than being allowed to bridge distinct known recordings.
  static List<List<Track>> group(List<Track> tracks) {
    final groups = <List<Track>>[];
    for (final track in tracks) {
      final matchingGroups = <int>[];
      for (var index = 0; index < groups.length; index++) {
        if (groups[index].any(
          (candidate) => matches(candidate, track),
        )) {
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
