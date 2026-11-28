import '../models/track.dart';
import 'catalog_identity.dart';
import 'catalog_ranking.dart';

/// Immutable album grouping derived only from catalogue records returned by
/// AUREL's configured music sources.
class ArtistAlbumGroup {
  const ArtistAlbumGroup({
    required this.title,
    required this.tracks,
  });

  final String title;
  final List<Track> tracks;

  int get trackCount => tracks.length;

  String get artworkUrl => tracks
      .map((track) => track.artworkUrl.trim())
      .firstWhere((url) => url.isNotEmpty, orElse: () => '');
}

/// Pure catalogue transformations used by the artist and album screens.
///
/// Artist pages intentionally show standard studio/original releases only.
/// Alternate edits remain discoverable through global search, but are excluded
/// from artist discographies to keep those pages clean and canonical.
class ArtistCatalog {
  const ArtistCatalog._();

  static final RegExp _variantInBrackets = RegExp(
    r'[\(\[]\s*(?:live|remix(?:ed)?|acoustic|demo|instrumental|sped\s*up|slowed|nightcore|8d|cover|karaoke|radio\s*edit|extended\s*(?:mix|version)|alternate\s*version|alternative\s*version|rework|bootleg|mash\s*up|mashup|reverb|bass\s*boosted|chipmunk|pitch\s*shifted|piano\s*version|orchestral\s*version|guitar\s*version)(?:\b[^\)\]]*)?[\)\]]',
    caseSensitive: false,
  );

  static final RegExp _variantSuffix = RegExp(
    r'(?:\s[-–—|:]\s*|\s+)(?:live(?:\s+(?:at|from|in|version|recording|session)\b.*)?|remix(?:ed)?|acoustic(?:\s+version)?|demo(?:\s+version)?|instrumental(?:\s+version)?|sped\s*up|speed\s*up|slowed(?:\s+down)?|nightcore|8d(?:\s+audio)?|cover|karaoke|radio\s*edit|extended\s*(?:mix|version)|alternate\s+version|alternative\s+version|rework|bootleg|mash\s*up|mashup|reverb|bass\s*boosted|chipmunk|pitch\s*shifted|piano\s+version|orchestral\s+version|guitar\s+version)\s*$',
    caseSensitive: false,
  );

  static final RegExp _liveAlbum = RegExp(
    r'^(?:live\s+(?:at|from|in)\b|mtv\s+unplugged\b|unplugged\s+(?:live|session)\b)',
    caseSensitive: false,
  );

  static final RegExp _modifiedAlbum = RegExp(
    r'(?:^|\s)(?:remixes|remix\s+ep|karaoke|instrumental\s+versions|acoustic\s+sessions)(?:\s|$)',
    caseSensitive: false,
  );

  /// True for a standard release. Explicitly labelled alternate performances,
  /// edits and fan-style transformations are not shown in artist discographies.
  ///
  /// The checks are suffix/bracket-aware so ordinary titles such as
  /// "Live Your Life" are not rejected merely because they contain "live".
  static bool isOfficialVersion(Track track) {
    final title = track.title.trim();
    final album = track.album.trim();
    if (title.isEmpty) return false;

    if (_variantInBrackets.hasMatch(title) ||
        _variantSuffix.hasMatch(title)) {
      return false;
    }

    if (_liveAlbum.hasMatch(album) || _modifiedAlbum.hasMatch(album)) {
      return false;
    }

    return true;
  }

  static List<Track> tracksForArtist(
    String artist,
    Iterable<Track> source,
  ) {
    final artistKey = CatalogIdentity.normalizeText(artist);
    if (artistKey.isEmpty) return const [];

    final matching = source
        .where((track) => _recordingCreditsArtist(track, artistKey))
        .toList(growable: false);

    // Reuse the same conservative recording matcher as global search.
    // Artist pages then apply a stricter presentation filter: only standard
    // releases are retained, while all valid same-recording fallbacks remain.
    final groups = CatalogIdentity.group(matching);
    final result = <Track>[];

    for (final group in groups) {
      final candidates = <String, Track>{};

      void addOfficialCandidate(Track candidate) {
        if (!isOfficialVersion(candidate)) return;
        candidates.putIfAbsent(
          CatalogIdentity.providerKeyOf(candidate),
          () => candidate,
        );
      }

      for (final candidate in group) {
        addOfficialCandidate(candidate);
        for (final alternative in candidate.alternatives) {
          addOfficialCandidate(alternative);
        }
      }

      if (candidates.isEmpty) continue;

      final ranked = candidates.values.toList(growable: false)
        ..sort(CatalogRanking.compare);
      final selected = ranked.first;
      final sources = <String>{
        ...selected.matchedSources,
        ...ranked.map((track) => track.providerName),
      }..removeWhere((value) => value.trim().isEmpty);

      result.add(
        selected.copyWith(
          matchedSources: sources.toList(growable: false),
          alternatives: ranked
              .skip(1)
              .map((track) => track.copyWith(alternatives: const []))
              .toList(growable: false),
        ),
      );
    }

    result.sort(CatalogRanking.compare);
    return List.unmodifiable(result);
  }

  static bool _recordingCreditsArtist(Track track, String artistKey) {
    final credits = <String>[
      track.artist,
      ...track.alternatives.map((alternative) => alternative.artist),
    ];

    return credits.any((credit) => _creditMatches(credit, artistKey));
  }

  static bool _creditMatches(String credit, String artistKey) {
    final normalized = CatalogIdentity.normalizeText(credit);
    if (normalized == artistKey) return true;

    // Featured credits are separate artist credits, not part of the lead
    // artist's name. Match complete credited names, never partial substrings.
    final featuredParts = credit.split(
      RegExp(r'\b(?:feat(?:uring)?|ft)\b\.?', caseSensitive: false),
    );
    return featuredParts.any(
      (part) => CatalogIdentity.normalizeText(part) == artistKey,
    );
  }

  static String _trackIdentity(Track track) =>
      CatalogIdentity.providerKeyOf(track);

  static List<ArtistAlbumGroup> albumsForTracks(Iterable<Track> tracks) {
    final Map<String, _MutableAlbum> grouped = {};
    for (final track in tracks) {
      final title = track.album.trim();
      final key = CatalogIdentity.normalizeText(title);
      if (key.isEmpty) continue;

      final album = grouped.putIfAbsent(
        key,
        () => _MutableAlbum(title),
      );
      album.tracks.putIfAbsent(_trackIdentity(track), () => track);
    }

    final albums = grouped.values.map((album) {
      final albumTracks = album.tracks.values.toList(growable: false)
        ..sort(CatalogRanking.compare);
      return ArtistAlbumGroup(
        title: album.title,
        tracks: List.unmodifiable(albumTracks),
      );
    }).toList()
      ..sort(
        (a, b) => CatalogIdentity.normalizeText(a.title)
            .compareTo(CatalogIdentity.normalizeText(b.title)),
      );

    return List.unmodifiable(albums);
  }
}

class _MutableAlbum {
  _MutableAlbum(this.title);

  final String title;
  final Map<String, Track> tracks = {};
}
