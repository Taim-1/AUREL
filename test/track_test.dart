import 'package:aurel/data/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Track.fromJamendo', () {
    test('maps stream, artwork, duration and per-track download permission', () {
      final track = Track.fromJamendo({
        'id': 'track-1',
        'name': 'Golden Hour',
        'artist_name': 'Aurel Artist',
        'album_name': 'First Light',
        'audio': 'https://example.com/audio.mp3',
        'audiodownload': 'https://example.com/download.mp3',
        'audiodownload_allowed': true,
        'license_ccurl': 'https://creativecommons.org/licenses/by/4.0/',
        'duration': 205,
        'image': 'https://example.com/art.jpg',
        'isrc': 'USABC2600001',
      });

      expect(track.id, 'track-1');
      expect(track.title, 'Golden Hour');
      expect(track.artist, 'Aurel Artist');
      expect(track.album, 'First Light');
      expect(track.durationMs, 205000);
      expect(track.artworkUrl, 'https://example.com/art.jpg');
      expect(track.downloadAllowed, isTrue);
      expect(track.licenseUrl, contains('creativecommons.org'));
      expect(track.recordingId, 'USABC2600001');
      expect(track.providerId, 'jamendo');
      expect(track.canPlay, isTrue);
    });

    test('does not allow a download when the artist has disabled it', () {
      final track = Track.fromJamendo({
        'id': 'track-2',
        'name': 'No Download',
        'audio': 'https://example.com/audio.mp3',
        'audiodownload': '',
        'audiodownload_allowed': false,
      });

      expect(track.downloadAllowed, isFalse);
      expect(track.downloadUrl, isEmpty);
    });

    test('does not infer download permission from a URL alone', () {
      final track = Track.fromJamendo({
        'id': 'track-3',
        'name': 'Unknown Permission',
        'audio': 'https://example.com/audio.mp3',
        'audiodownload': 'https://example.com/download.mp3',
      });

      expect(track.downloadAllowed, isFalse);
    });
  });

  group('Multi-source capability parsing', () {
    test('Spotify results are metadata-only, never fake in-app streams', () {
      final track = Track.fromSpotify({
        'id': 'spotify-id',
        'name': 'Midnight City',
        'duration_ms': 240000,
        'artists': [{'name': 'M83'}],
        'album': {
          'name': 'Hurry Up, We Are Dreaming',
          'images': [{'url': 'https://example.com/cover.jpg'}],
        },
        'external_ids': {'isrc': 'USABC2600002'},
        'external_urls': {'spotify': 'https://open.spotify.com/track/spotify-id'},
      });

      expect(track.providerId, 'spotify');
      expect(track.title, 'Midnight City');
      expect(track.artist, 'M83');
      expect(track.recordingId, 'USABC2600002');
      expect(track.canPlay, isFalse);
      expect(track.isMetadataOnly, isTrue);
      expect(track.streamUrl, isEmpty);
      expect(track.downloadAllowed, isFalse);
    });

    test('Apple Music results are metadata-only', () {
      final track = Track.fromAppleMusic({
        'id': 'apple-id',
        'attributes': {
          'name': 'Blue',
          'artistName': 'Joni Mitchell',
          'albumName': 'Blue',
          'durationInMillis': 230000,
          'isrc': 'USABC2600003',
          'url': 'https://music.apple.com/us/album/blue/1',
          'artwork': {
            'url': 'https://example.com/{w}x{h}bb.jpg',
          },
        },
      });

      expect(track.providerId, 'apple_music');
      expect(track.canPlay, isFalse);
      expect(track.isMetadataOnly, isTrue);
      expect(track.artworkUrl, 'https://example.com/600x600bb.jpg');
    });

    test('Audius honours streamable and downloadable flags separately', () {
      final playable = Track.fromAudius({
        'id': 'audius-id',
        'title': 'Indigo',
        'duration': 180,
        'is_streamable': true,
        'is_downloadable': false,
        'permalink': 'https://audius.co/artist/indigo',
        'user': {'name': 'Artist'},
      });
      final blocked = Track.fromAudius({
        'id': 'audius-blocked',
        'title': 'Unavailable',
        'is_streamable': false,
        'is_downloadable': true,
        'user': {'name': 'Artist'},
      });

      expect(playable.canPlay, isTrue);
      expect(playable.downloadAllowed, isFalse);
      expect(blocked.canPlay, isFalse);
      expect(blocked.downloadAllowed, isTrue);
      expect(blocked.streamUrl, isEmpty);
    });

    test('SoundCloud rejects blocked items and needs explicit download flag', () {
      final blocked = Track.fromSoundCloud({
        'id': 100,
        'title': 'Blocked',
        'access': 'blocked',
        'streamable': true,
        'downloadable': true,
        'download_url': 'https://example.com/download',
        'user': {'username': 'Artist'},
      });
      final playable = Track.fromSoundCloud({
        'id': 101,
        'title': 'Playable',
        'access': 'playable',
        'streamable': true,
        'downloadable': false,
        'user': {'username': 'Artist'},
      });

      expect(blocked.canPlay, isFalse);
      expect(blocked.downloadAllowed, isTrue);
      expect(playable.canPlay, isTrue);
      expect(playable.downloadAllowed, isFalse);
    });

    test('Openverse only enables downloads for permitted reusable licenses', () {
      final by = Track.fromOpenverse({
        'id': 'open-by',
        'title': 'Open Piece',
        'creator': 'Composer',
        'url': 'https://example.com/open.mp3',
        'license': 'by',
        'license_url': 'https://creativecommons.org/licenses/by/4.0/',
        'attribution': 'Open Piece by Composer',
        'category': 'music',
      });
      final nc = Track.fromOpenverse({
        'id': 'open-nc',
        'title': 'Non-commercial Piece',
        'url': 'https://example.com/nc.mp3',
        'license': 'by-nc',
        'category': 'music',
      });

      expect(by.canPlay, isTrue);
      expect(by.downloadAllowed, isTrue);
      expect(by.licenseName, 'by');
      expect(by.attribution, contains('Composer'));
      expect(nc.canPlay, isTrue);
      expect(nc.downloadAllowed, isFalse);
    });
  });

  group('Track persistence and provider identity', () {
    test('does not serialize ephemeral provider authorization headers', () {
      const original = Track(
        id: 'soundcloud-42',
        title: 'Authorized',
        artist: 'Artist',
        providerId: 'soundcloud',
        providerName: 'SoundCloud',
        streamUrl: 'https://api.soundcloud.com/tracks/42/stream',
        playbackHeaders: {'Authorization': 'OAuth private-temporary-token'},
      );

      final json = original.toJson();
      final restored = Track.fromJson(json);

      expect(json.containsKey('playbackHeaders'), isFalse);
      expect(json.toString(), isNot(contains('private-temporary-token')));
      expect(restored.playbackHeaders, isEmpty);
    });

    test('keeps provider attribution and matched sources after copy and restore', () {
      const original = Track(
        id: 'openverse-1',
        title: 'Open Piece',
        artist: 'Composer',
        providerId: 'openverse',
        providerName: 'Openverse',
        licenseName: 'CC BY',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        attribution: 'Open Piece by Composer',
        matchedSources: ['Openverse', 'Jamendo'],
        streamUrl: 'https://example.com/audio.mp3',
      );

      final copied = original.copyWith(
        localPath: '/music/open-piece.mp3',
        isDownloaded: true,
      );
      final restored = Track.fromJson(copied.toJson());

      expect(restored.providerId, 'openverse');
      expect(restored.licenseName, 'CC BY');
      expect(restored.attribution, 'Open Piece by Composer');
      expect(restored.matchedSources, ['Openverse', 'Jamendo']);
      expect(restored.isDownloaded, isTrue);
    });

    test('keeps the downloaded file path when serialised and restored', () {
      const original = Track(
        id: 'track-4',
        title: 'Offline Track',
        artist: 'Aurel Artist',
        streamUrl: 'https://example.com/stream.mp3',
        downloadUrl: 'https://example.com/download.mp3',
        downloadAllowed: true,
        isDownloaded: true,
        localPath: '/data/user/0/com.aurel.aurel/app_flutter/song.mp3',
      );

      final restored = Track.fromJson(original.toJson());

      expect(restored.isDownloaded, isTrue);
      expect(restored.localPath, original.localPath);
      expect(restored.playbackUri, startsWith('file:'));
    });
  group('Expanded catalogue metadata', () {
    test('normalizes recording metadata and preserves ISRC', () {
      final track = Track.fromMusicBrainz({
        'id': 'recording-123',
        'title': 'A Song',
        'length': 213000,
        'isrcs': ['USABC2600001'],
        'artist-credit': [
          {
            'name': 'Aurel Artist',
            'artist': {'name': 'Aurel Artist'},
            'joinphrase': '',
          },
        ],
      });

      expect(track.id, 'musicbrainz-recording-123');
      expect(track.title, 'A Song');
      expect(track.artist, 'Aurel Artist');
      expect(track.recordingId, 'USABC2600001');
      expect(track.durationMs, 213000);
      expect(track.canPlay, isFalse);
      expect(track.isMetadataOnly, isTrue);
    });

    test('marks openly licensed audio as playable and downloadable', () {
      final track = Track.fromWikimediaCommons(
        pageId: '98765',
        title: 'Open Piano',
        artist: 'Aurel Composer',
        mediaUrl: 'https://upload.wikimedia.org/example/open-piano.ogg',
        sourceUrl: 'https://commons.wikimedia.org/wiki/File:Open_Piano.ogg',
        licenseName: 'CC BY-SA',
        licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
        attribution: 'Open Piano by Aurel Composer',
        durationMs: 120000,
      );

      expect(track.canPlay, isTrue);
      expect(track.downloadAllowed, isTrue);
      expect(track.providerId, 'wikimedia_commons');
      expect(track.licenseName, 'CC BY-SA');
      expect(track.attribution, contains('Aurel Composer'));
    });
  });
  });
}
