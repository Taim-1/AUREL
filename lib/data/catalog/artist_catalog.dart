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
/// A merged recording can carry different artist-credit spellings from its
/// alternate catalogues. Those credits are considered when building an artist
/// page, while the recording itself remains one result.
class ArtistCatalog {
  const ArtistCatalog._();

  static List<Track> tracksForArtist(
    String artist,
    Iterable<Track> source,
  ) {
    final artistKey = CatalogIdentity.normalizeText(artist);
    if (artistKey.isEmpty) return const [];

    final matching = source
        .where((track) => _recordingCreditsArtist(track, artistKey))
        .toList(growable: false);

    // Reuse the same conservative recording matcher as global search. This
    // removes cross-provider copies only when their identity is verified or
    // their fallback metadata meets the strict title/artist/duration rule.
    final groups = CatalogIdentity.group(matching);
    final result = groups.map((group) {
      final ranked = [...group]..sort(CatalogRanking.compare);
      final selected = ranked.first;
      final alternatives = <String, Track>{};

      void addAlternative(Track candidate) {
        final key = CatalogIdentity.providerKeyOf(candidate);
        if (key == CatalogIdentity.providerKeyOf(selected)) return;
        alternatives.putIfAbsent(
          key,
          () => candidate.copyWith(alternatives: const []),
        );
      }

      for (final candidate in selected.alternatives) {
        addAlternative(candidate);
      }
      for (final candidate in ranked.skip(1)) {
        addAlternative(candidate);
        for (final alternative in candidate.alternatives) {
          addAlternative(alternative);
        }
      }

      final sources = <String>{
        ...selected.matchedSources,
        ...ranked.map((track) => track.providerName),
      }..removeWhere((value) => value.trim().isEmpty);

      return selected.copyWith(
        matchedSources: sources.toList(growable: false),
        alternatives: alternatives.values.toList(growable: false),
      );
    }).toList()
      ..sort(CatalogRanking.compare);

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

    // Feature credits are separate artist credits, not part of the lead
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
