import 'package:flutter_test/flutter_test.dart';

import 'package:aurel/data/models/music_playlist.dart';
import 'package:aurel/data/models/track.dart';

Track track(String id, String title) => Track(
      id: id,
      title: title,
      artist: 'AUREL Artist',
      providerId: 'jamendo',
      streamUrl: 'https://audio.example/$id.mp3',
    );

void main() {
  group('MusicPlaylist immutable ordering', () {
    final playlist = MusicPlaylist(
      id: 'playlist-1',
      name: 'Evening',
      tracks: [
        track('one', 'First'),
        track('two', 'Second'),
        track('three', 'Third'),
      ],
    );

    test('moves a track to an earlier position', () {
      final reordered = playlist.moveTrack(fromIndex: 2, toIndex: 0);

      expect(
        reordered.tracks.map((item) => item.id),
        ['three', 'one', 'two'],
      );
      expect(
        playlist.tracks.map((item) => item.id),
        ['one', 'two', 'three'],
      );
    });

    test('moves a track to a later position', () {
      final reordered = playlist.moveTrack(fromIndex: 0, toIndex: 2);

      expect(
        reordered.tracks.map((item) => item.id),
        ['two', 'three', 'one'],
      );
    });

    test('does not change the playlist for invalid positions', () {
      expect(
        identical(
          playlist,
          playlist.moveTrack(fromIndex: -1, toIndex: 0),
        ),
        isTrue,
      );
      expect(
        identical(
          playlist,
          playlist.moveTrack(fromIndex: 0, toIndex: 9),
        ),
        isTrue,
      );
      expect(
        identical(
          playlist,
          playlist.moveTrack(fromIndex: 1, toIndex: 1),
        ),
        isTrue,
      );
    });

    test('returns an immutable ordered track list', () {
      final reordered = playlist.moveTrack(fromIndex: 0, toIndex: 1);

      expect(
        () => reordered.tracks.add(track('four', 'Fourth')),
        throwsUnsupportedError,
      );
    });
  });
}
