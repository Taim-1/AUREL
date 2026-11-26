import 'package:aurel/data/services/device_library_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.aurel.music/device_library');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late DeviceLibraryService service;

  setUp(() {
    service = DeviceLibraryService(channel: channel);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('reads the current audio permission state', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'hasAudioPermission');
      return true;
    });

    expect(await service.hasAudioPermission(), isTrue);
  });

  test('requests audio permission only through the explicit method', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'requestAudioPermission');
      return true;
    });

    expect(await service.requestAudioPermission(), isTrue);
  });

  test('maps MediaStore rows to real local playable tracks', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'queryAudioTracks');
      return [
        {
          'id': '42',
          'uri': 'content://media/external/audio/media/42',
          'title': 'Local Song',
          'artist': 'Local Artist',
          'album': 'Local Album',
          'duration': 187000,
        },
      ];
    });

    final tracks = await service.loadTracks();

    expect(tracks, hasLength(1));
    expect(tracks.single.id, 'device-42');
    expect(tracks.single.title, 'Local Song');
    expect(tracks.single.artist, 'Local Artist');
    expect(tracks.single.album, 'Local Album');
    expect(tracks.single.durationMs, 187000);
    expect(tracks.single.isDeviceTrack, isTrue);
    expect(tracks.single.isLocal, isTrue);
    expect(tracks.single.canPlay, isTrue);
    expect(
      tracks.single.playbackUri,
      'content://media/external/audio/media/42',
    );
    expect(tracks.single.downloadAllowed, isFalse);
  });

  test('returns empty list when the local media library is empty', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => []);

    expect(await service.loadTracks(), isEmpty);
  });

  test('does not request permission implicitly while reading permission state',
      () async {
    var requested = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'requestAudioPermission') requested = true;
      return false;
    });

    await service.hasAudioPermission();

    expect(requested, isFalse);
  });
}
