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

    final savedDownload = recording(
      id: 'download-51',
      providerId: 'jamendo',
      providerName: 'Jamendo',
      title: 'Midnight Avenue',
      artist: 'Aurel Ensemble',
      localPath: '/data/user/0/com.aurel.aurel/files/AUREL Downloads/51.mp3',
      isDownloaded: true,
      recordingId: 'USABC2600001',
    );

    test('selects an AUREL download ahead of an online stream', () {
      final selected = LocalTrackPriority.preferLocalCopy(
        onlineJamendo,
        [savedDownload],
      );

      expect(selected.id, 'download-51');
      expect(selected.isDownloaded, isTrue);
      expect(selected.isLocal, isTrue);
      expect(selected.canPlay, isTrue);
    });

    test('retains the online recording as an automatic recovery source', () {
      final selected = LocalTrackPriority.preferLocalCopy(
        onlineJamendo,
        [savedDownload],
      );

      expect(selected.alternatives, hasLength(1));
      expect(selected.alternatives.single.id, 'jamendo-21');
      expect(selected.alternatives.single.providerId, 'jamendo');
      expect(selected.alternatives.single.canPlay, isTrue);
    });

    test('finds a download through an eligible catalogue alternative', () {
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
        LocalTrackPriority.findLocalCopy(metadata, [savedDownload])?.id,
        'download-51',
      );

      final selected = LocalTrackPriority.preferLocalCopy(
        metadata,
        [savedDownload],
      );

      expect(selected.id, 'download-51');
      expect(selected.alternatives.single.id, 'jamendo-21');
    });

    test('recognizes a saved download only when its file still exists', () {
      final brokenDownload = recording(
        id: 'broken-download',
        providerId: 'jamendo',
        providerName: 'Jamendo',
        title: 'Midnight Avenue',
        artist: 'Aurel Ensemble',
        isDownloaded: true,
        recordingId: 'USABC2600001',
      );

      expect(
        LocalTrackPriority.findLocalCopy(onlineJamendo, [brokenDownload]),
        isNull,
      );
      expect(
        LocalTrackPriority.preferLocalCopy(
          onlineJamendo,
          [brokenDownload],
        ).id,
        'jamendo-21',
      );
    });

    test('does not import a matching file outside AUREL downloads', () {
      final externalFile = recording(
        id: 'external-file-21',
        providerId: 'jamendo',
        providerName: 'Jamendo',
        title: 'Midnight Avenue',
        artist: 'Aurel Ensemble',
        localPath: '/storage/emulated/0/Music/Midnight Avenue.mp3',
        recordingId: 'USABC2600001',
      );

      expect(
        LocalTrackPriority.findLocalCopy(onlineJamendo, [externalFile]),
        isNull,
      );
      expect(
        LocalTrackPriority.preferLocalCopy(
          onlineJamendo,
          [externalFile],
        ).id,
        'jamendo-21',
      );
    });

    test('does not match two unrelated recordings with empty IDs', () {
      final onlineWithoutId = recording(
        id: '',
        providerId: 'jamendo',
        providerName: 'Jamendo',
        title: 'First Recording',
        artist: 'Aurel Ensemble',
        streamUrl: 'https://audio.example/first.mp3',
        durationMs: 180000,
      );
      final unrelatedLocal = recording(
        id: '',
        providerId: 'jamendo',
        providerName: 'Jamendo',
        title: 'Different Recording',
        artist: 'Another Artist',
        localPath:
            '/data/user/0/com.aurel.aurel/files/AUREL Downloads/different.mp3',
        isDownloaded: true,
        durationMs: 205000,
      );

      expect(
        LocalTrackPriority.findLocalCopy(
          onlineWithoutId,
          [unrelatedLocal],
        ),
        isNull,
      );
    });

    test('keeps no-ID alternatives from different providers distinct', () {
      final onlineWithoutId = recording(
        id: '',
        providerId: 'jamendo',
        providerName: 'Jamendo',
        title: 'Quiet Horizon',
        artist: 'Aurel Ensemble',
        streamUrl: 'https://audio.example/jamendo.mp3',
        recordingMbid: 'recording-no-id-001',
      );
      final audiusAlternative = recording(
        id: '',
        providerId: 'audius',
        providerName: 'Audius',
        title: 'Quiet Horizon',
        artist: 'Aurel Ensemble',
        streamUrl: 'https://audio.example/audius.mp3',
        recordingMbid: 'recording-no-id-001',
      );
      final soundcloudAlternative = recording(
        id: '',
        providerId: 'soundcloud',
        providerName: 'SoundCloud',
        title: 'Quiet Horizon',
        artist: 'Aurel Ensemble',
        streamUrl: 'https://audio.example/soundcloud.mp3',
        recordingMbid: 'recording-no-id-001',
      );
      final localDownload = recording(
        id: '',
        providerId: 'jamendo',
        providerName: 'Jamendo',
        title: 'Quiet Horizon',
        artist: 'Aurel Ensemble',
        localPath:
            '/data/user/0/com.aurel.aurel/files/AUREL Downloads/quiet.mp3',
        isDownloaded: true,
        recordingMbid: 'recording-no-id-001',
      );

      final selected = LocalTrackPriority.preferLocalCopy(
        onlineWithoutId.copyWith(
          alternatives: [audiusAlternative, soundcloudAlternative],
        ),
        [localDownload],
      );

      expect(selected.isLocal, isTrue);
      expect(
        selected.alternatives.map((item) => item.providerId).toSet(),
        {'jamendo', 'audius', 'soundcloud'},
      );
      expect(selected.alternatives, hasLength(3));
    });

    test('never substitutes a different recording version', () {
      final liveVersion = recording(
        id: 'download-live',
        providerId: 'jamendo',
        providerName: 'Jamendo',
        title: 'Midnight Avenue (Live)',
        artist: 'Aurel Ensemble',
        localPath: '/data/user/0/com.aurel.aurel/files/AUREL Downloads/live.mp3',
        isDownloaded: true,
      );

      expect(
        LocalTrackPriority.findLocalCopy(onlineJamendo, [liveVersion]),
        isNull,
      );
    });

    test('local download metadata fills gaps without changing its identity', () {
      final sparseDownload = recording(
        id: 'download-53',
        providerId: 'jamendo',
        providerName: 'Jamendo',
        title: 'Midnight Avenue',
        artist: 'Aurel Ensemble',
        localPath: '/data/user/0/com.aurel.aurel/files/AUREL Downloads/53.mp3',
        isDownloaded: true,
        durationMs: 0,
        recordingId: 'USABC2600001',
      );

      final selected = LocalTrackPriority.preferLocalCopy(
        onlineJamendo,
        [sparseDownload],
      );

      expect(selected.id, 'download-53');
      expect(selected.isLocal, isTrue);
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
        [savedDownload],
      );

      expect(
        selected.alternatives.map((track) => track.providerId).toList(),
        ['audius', 'jamendo', 'soundcloud'],
      );
    });
  });
}
