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
    final tracks = rawTracks is List
        ? rawTracks
            .whereType<Map<String, dynamic>>()
            .map(Track.fromJson)
            .toList(growable: false)
        : <Track>[];
    return MusicPlaylist(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Playlist').toString(),
      tracks: tracks,
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
}
