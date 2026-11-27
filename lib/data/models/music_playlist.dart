import 'track.dart';

class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.name,
    required this.tracks,
  });

  final String id;
  final String name;
  final List<Track> tracks;

  factory MusicPlaylist.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'];
    final tracks = <Track>[];

    if (rawTracks is List) {
      for (final rawTrack in rawTracks.whereType<Map>()) {
        try {
          tracks.add(
            Track.fromJson(Map<String, dynamic>.from(rawTrack)),
          );
        } on FormatException {
          // Ignore entries from the retired device music library.
        } on TypeError {
          // Ignore incompatible legacy records without losing the playlist.
        }
      }
    }

    return MusicPlaylist(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Playlist').toString(),
      tracks: List.unmodifiable(tracks),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': tracks.map((track) => track.toJson()).toList(),
      };

  MusicPlaylist copyWith({String? name, List<Track>? tracks}) => MusicPlaylist(
        id: id,
        name: name ?? this.name,
        tracks: tracks ?? this.tracks,
      );

  /// Returns a new playlist with one item moved to its final target index.
  /// Invalid indexes leave the original immutable playlist unchanged.
  MusicPlaylist moveTrack({
    required int fromIndex,
    required int toIndex,
  }) {
    if (fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= tracks.length ||
        toIndex >= tracks.length ||
        fromIndex == toIndex) {
      return this;
    }

    final reordered = tracks.toList(growable: true);
    final moved = reordered.removeAt(fromIndex);
    reordered.insert(toIndex, moved);
    return copyWith(tracks: List<Track>.unmodifiable(reordered));
  }
}
