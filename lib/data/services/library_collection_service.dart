import '../catalog/catalog_identity.dart';
import '../models/music_playlist.dart';
import '../models/track.dart';

/// Deterministic sorting modes for the user's private AUREL library.
enum LibrarySort {
  recentlyAdded,
  titleAscending,
  artistAscending,
  albumAscending,
}

/// Pure filtering and ordering operations for AUREL-owned library data.
///
/// This service deliberately receives only the lists stored by AUREL. It has
/// no Android media, filesystem discovery, or device-library dependency.
class LibraryCollectionService {
  const LibraryCollectionService._();

  static bool containsTrack(Iterable<Track> tracks, Track candidate) =>
      tracks.any((track) => CatalogIdentity.matches(track, candidate));

  static bool isFavorite(Iterable<Track> favorites, Track track) =>
      containsTrack(favorites, track);

  static List<Track> toggleFavorite(
    Iterable<Track> favorites,
    Track track,
  ) {
    final current = favorites.toList(growable: false);
    final alreadySaved = containsTrack(current, track);
    final updated = alreadySaved
        ? current
            .where((item) => !CatalogIdentity.matches(item, track))
            .toList(growable: false)
        : [...current, track];
    return List<Track>.unmodifiable(updated);
  }

  static MusicPlaylist addTrackToPlaylist(
    MusicPlaylist playlist,
    Track track,
  ) {
    if (containsTrack(playlist.tracks, track)) return playlist;
    return playlist.copyWith(
      tracks: List<Track>.unmodifiable([...playlist.tracks, track]),
    );
  }

  static MusicPlaylist removeTrackFromPlaylist(
    MusicPlaylist playlist,
    String trackId, {
    String? providerId,
  }) {
    final updated = playlist.tracks.where((track) {
      if (track.id != trackId) return true;
      if (providerId == null) return false;
      return track.providerId != providerId;
    }).toList(growable: false);
    if (updated.length == playlist.tracks.length) return playlist;
    return playlist.copyWith(tracks: List<Track>.unmodifiable(updated));
  }

  static List<Track> filterTracks(
    Iterable<Track> tracks, {
    String query = '',
    LibrarySort sort = LibrarySort.recentlyAdded,
  }) {
    final terms = _searchTerms(query);
    final result = tracks
        .where((track) => _matchesTrack(track, terms))
        .toList(growable: true);

    switch (sort) {
      case LibrarySort.recentlyAdded:
        // The repository/controller already supplies this order. Keeping it
        // intact makes this mode stable and avoids inventing timestamps.
        break;
      case LibrarySort.titleAscending:
        result.sort(_compareByTitle);
        break;
      case LibrarySort.artistAscending:
        result.sort(_compareByArtist);
        break;
      case LibrarySort.albumAscending:
        result.sort(_compareByAlbum);
        break;
    }

    return List<Track>.unmodifiable(result);
  }

  static List<MusicPlaylist> filterPlaylists(
    Iterable<MusicPlaylist> playlists, {
    String query = '',
  }) {
    final terms = _searchTerms(query);
    final result = playlists.where((playlist) {
      if (terms.isEmpty) return true;
      final metadata = [
        playlist.name,
        ...playlist.tracks.expand(
          (track) => [track.title, track.artist, track.album],
        ),
      ].join(' ').toLowerCase();
      return terms.every(metadata.contains);
    }).toList(growable: false);
    return List<MusicPlaylist>.unmodifiable(result);
  }

  static List<LibraryTrackGroup> groupByAlbum(Iterable<Track> tracks) =>
      _groupTracks(
        tracks,
        (track) => track.album.trim().isEmpty ? 'Singles' : track.album,
        includeEmpty: false,
      );

  static List<LibraryTrackGroup> groupByArtist(Iterable<Track> tracks) =>
      _groupTracks(
        tracks,
        (track) => track.artist,
        includeEmpty: false,
      );

  static List<LibraryTrackGroup> _groupTracks(
    Iterable<Track> tracks,
    String Function(Track) labelFor, {
    required bool includeEmpty,
  }) {
    final groups = <String, _MutableLibraryTrackGroup>{};
    for (final track in tracks) {
      final label = labelFor(track).trim();
      if (label.isEmpty && !includeEmpty) continue;
      final visibleLabel = label.isEmpty ? 'Unknown' : label;
      final key = visibleLabel
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ');
      final group = groups.putIfAbsent(
        key,
        () => _MutableLibraryTrackGroup(visibleLabel),
      );
      final trackKey = track.id.isEmpty
          ? [
              track.providerId,
              track.recordingMbid,
              track.recordingId,
              track.title,
              track.artist,
              track.album,
              track.durationMs,
            ].join(':')
          : '${track.providerId}:${track.id}';
      group.tracks.putIfAbsent(trackKey, () => track);
    }

    final result = groups.values
        .map(
          (group) => LibraryTrackGroup(
            name: group.name,
            tracks: List<Track>.unmodifiable(group.tracks.values),
          ),
        )
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return List<LibraryTrackGroup>.unmodifiable(result);
  }

  static bool _matchesTrack(Track track, List<String> terms) {
    if (terms.isEmpty) return true;
    final metadata = [
      track.title,
      track.artist,
      track.album,
      track.providerName,
      track.providerId,
      track.licenseName,
    ].join(' ').toLowerCase();
    return terms.every(metadata.contains);
  }

  static List<String> _searchTerms(String query) => query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);

  static int _compareByTitle(Track a, Track b) {
    final title = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (title != 0) return title;
    final artist = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
    if (artist != 0) return artist;
    return a.id.compareTo(b.id);
  }

  static int _compareByArtist(Track a, Track b) {
    final artist = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
    if (artist != 0) return artist;
    return _compareByTitle(a, b);
  }

  static int _compareByAlbum(Track a, Track b) {
    final album = a.album.toLowerCase().compareTo(b.album.toLowerCase());
    if (album != 0) return album;
    return _compareByTitle(a, b);
  }
}

class LibraryTrackGroup {
  const LibraryTrackGroup({
    required this.name,
    required this.tracks,
  });

  final String name;
  final List<Track> tracks;
}

class _MutableLibraryTrackGroup {
  _MutableLibraryTrackGroup(this.name);

  final String name;
  final Map<String, Track> tracks = {};
}
