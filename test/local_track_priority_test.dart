import 'package:aurel/data/catalog/local_track_priority.dart';
import 'package:aurel/data/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

Track recording({
  required String id,
  required String providerId,
  required String providerName,
  required String title,
  required String artist,
  String streamUrl = '',
  String recordingId = '',
  String recordingMbid = '',
  String? localPath,
  bool isDeviceTrack = false,
  bool isDownloaded = false,
  bool isPlayable = true,
  bool isMetadataOnly = false,
  int durationMs = 180000,
  List<Track> alternatives = const [],
}) {
  return Track(
    id: id,
    title: title,
    artist: artist,
    providerId: providerId,
    providerName: providerName,
    streamUrl: streamUrl,
    recordingId: recordingId,
    recordingMbid: recordingMbid,
    localPath: localPath,
    isDeviceTrack: isDeviceTrack,
    isDownloaded: isDownloaded,
    isPlayable: isPlayable,
    isMetadataOnly: isMetadataOnly,
    durationMs: durationMs,
    alternatives: alternatives,
  );
}

void main() {
  group('LocalTrackPriority', () {
    final onlineJamendo = recording(
      id: 'jamendo-21',
      providerId: 'jamendo',
      providerName: 'Jamendo',
      title: 'Midnight Avenue',
      artist: 'Aurel Ensemble',
      streamUrl: 'https://audio.example/jamendo-21.mp3',
      recordingId: 'USABC2600001',
    );

    final localDevice = recording(
      id: 'device-51',
      providerId: 'device',
      providerName: 'On device',
      title: 'Midnight Avenue',
      artist: 'Aurel Ensemble',
      localPath: 'content://media/external/audio/media/51',
      isDeviceTrack: true,
      recordingId: 'USABC2600001',
    );

    test('selects a matching device recording ahead of an online stream', () {
      final selected = LocalTrackPriority.preferLocalCopy(
        onlineJamendo,
        [localDevice],
      );

      expect(selected.id, 'device-51');
      expect(selected.isDeviceTrack, isTrue);
      expect(selected.isLocal, isTrue);
      expect(selected.canPlay, isTrue);
    });

    test('retains the online recording as an automatic recovery source', () {
      final selected = LocalTrackPriority.preferLocalCopy(
        onlineJamendo,
        [localDevice],
      );

      expect(selected.alternatives, hasLength(1));
      expect(selected.alternatives.single.id, 'jamendo-21');
      expect(selected.alternatives.single.providerId, 'jamendo');
      expect(selected.alternatives.single.canPlay, isTrue);
    });

    test('finds a local copy through an eligible catalogue alternative', () {
      final metadata = recording(
        id: 'spotify-17',
        providerId: 'spotify',
        providerName: 'Spotify',
        title: 'Midnight Avenue',
        artist: 'Aurel Ensemble',
        isPlayable: false,
        isMetadataOnly: true,
        alternatives: [onlineJamendo],
      );

      expect(
        LocalTrackPriority.findLocalCopy(metadata, [localDevice])?.id,
        'device-51',
      );

      final selected = LocalTrackPriority.preferLocalCopy(
        metadata,
        [localDevice],
      );

      expect(selected.id, 'device-51');
      expect(selected.alternatives.single.id, 'jamendo-21');
    });

    test('chooses a downloaded copy when it is the matching local source', () {
      final download = recording(
        id: 'download-21',
        providerId: 'jamendo',
        providerName: 'Jamendo',
        title: 'Midnight Avenue',
        artist: 'Aurel Ensemble',
        localPath: '/data/user/0/com.aurel.aurel/files/AUREL Downloads/song.mp3',
        isDownloaded: true,
        recordingId: 'USABC2600001',
      );

      final selected = LocalTrackPriority.preferLocalCopy(
        onlineJamendo,
        [download],
      );

      expect(selected.id, 'download-21');
      expect(selected.isDownloaded, isTrue);
      expect(selected.isLocal, isTrue);
    });

    test('ignores a stale local entry without a real local playback URI', () {
      final stale = recording(
        id: 'stale-device-21',
        providerId: 'device',
        providerName: 'On device',
        title: 'Midnight Avenue',
        artist: 'Aurel Ensemble',
        isDeviceTrack: true,
        recordingId: 'USABC2600001',
      );

      expect(LocalTrackPriority.findLocalCopy(onlineJamendo, [stale]), isNull);
      expect(
        LocalTrackPriority.preferLocalCopy(onlineJamendo, [stale]).id,
        'jamendo-21',
      );
    });

    test('never substitutes a different recording version', () {
      final liveVersion = recording(
        id: 'device-live',
        providerId: 'device',
        providerName: 'On device',
        title: 'Midnight Avenue (Live)',
        artist: 'Aurel Ensemble',
        localPath: 'content://media/external/audio/media/52',
        isDeviceTrack: true,
        durationMs: 180000,
      );

      expect(
        LocalTrackPriority.findLocalCopy(onlineJamendo, [liveVersion]),
        isNull,
      );
    });

    test('local metadata fills gaps without removing the original identity', () {
      final sparseLocal = recording(
        id: 'device-53',
        providerId: 'device',
        providerName: 'On device',
        title: 'Midnight Avenue',
        artist: 'Aurel Ensemble',
        localPath: 'content://media/external/audio/media/53',
        isDeviceTrack: true,
        durationMs: 0,
      );

      final selected = LocalTrackPriority.preferLocalCopy(
        onlineJamendo,
        [sparseLocal],
      );

      expect(selected.title, 'Midnight Avenue');
      expect(selected.artist, 'Aurel Ensemble');
      expect(selected.durationMs, 180000);
      expect(selected.recordingId, 'USABC2600001');
      expect(selected.matchedSources, contains('Jamendo'));
    });

    test('keeps fallback sources in deterministic AUREL priority order', () {
      final audius = recording(
        id: 'audius-21',
        providerId: 'audius',
        providerName: 'Audius',
        title: 'Midnight Avenue',
        artist: 'Aurel Ensemble',
        streamUrl: 'https://audio.example/audius-21.mp3',
        recordingId: 'USABC2600001',
      );
      final soundcloud = recording(
        id: 'soundcloud-21',
        providerId: 'soundcloud',
        providerName: 'SoundCloud',
        title: 'Midnight Avenue',
        artist: 'Aurel Ensemble',
        streamUrl: 'https://audio.example/soundcloud-21.mp3',
        recordingId: 'USABC2600001',
      );
      final selected = LocalTrackPriority.preferLocalCopy(
        onlineJamendo.copyWith(alternatives: [soundcloud, audius]),
        [localDevice],
      );

      expect(
        selected.alternatives.map((track) => track.providerId).toList(),
        ['audius', 'jamendo', 'soundcloud'],
      );
    });
  });
}
