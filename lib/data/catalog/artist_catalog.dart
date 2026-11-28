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
/// This layer intentionally avoids inventing discographies, release dates,
/// biographies, popularity scores or artist relationships. It only groups
/// the metadata already returned by AUREL's music providers.
class ArtistCatalog {
  const ArtistCatalog._();

  static List<Track> tracksForArtist(
    String artist,
    Iterable<Track> source,
  ) {
    final artistKey = CatalogIdentity.normalizeText(artist);
    if (artistKey.isEmpty) return const [];

    final Map<String, Track> unique = {};
    for (final track in source) {
      if (CatalogIdentity.normalizeText(track.artist) != artistKey) continue;

      unique.putIfAbsent(_trackIdentity(track), () => track);
    }

    final result = unique.values.toList(growable: false)
      ..sort(CatalogRanking.compare);
    return List.unmodifiable(result);
  }

  static String _trackIdentity(Track track) {
    final provider = track.providerId.trim().isEmpty
        ? 'unknown'
        : track.providerId.trim();
    final id = track.id.trim();
    if (id.isNotEmpty) return '$provider:$id';

    return '$provider:${CatalogIdentity.normalizeText(track.title)}:'
        '${CatalogIdentity.normalizeText(track.artist)}:'
        '${CatalogIdentity.normalizeText(track.album)}:'
        '${track.durationMs}';
  }

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
