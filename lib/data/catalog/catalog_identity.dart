import '../models/track.dart';

/// Recording identity rules shared by search, discovery and catalogue tests.
///
/// ISRC is authoritative when both entries have one. Otherwise the title,
/// credited artist and a close duration must all agree. Version words remain
/// part of the normalized title, so Live/Remix/Acoustic releases stay distinct.
class CatalogIdentity {
  const CatalogIdentity._();

  static const int durationToleranceMs = 5000;

  static bool matches(Track a, Track b) {
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

  static String normalizeText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\\p{L}\\p{N}]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();

  static String _normalizeIsrc(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
