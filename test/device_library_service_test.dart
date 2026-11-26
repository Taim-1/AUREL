import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurel/data/services/device_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.aurel.music/device_library');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late DeviceLibraryService service;

  setUp(() {
    service = DeviceLibraryService();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('reports the Android audio permission state', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'hasAudioPermission');
      return true;
    });

    expect(await service.hasAudioPermission(), isTrue);
  });

  test('requests permission only through the explicit request method',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'requestAudioPermission');
      return true;
    });

    expect(await service.requestAudioPermission(), isTrue);
  });

  test('maps MediaStore rows to real content URI tracks', () async {
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
    expect(tracks.single.canPlay, isTrue);
    expect(tracks.single.playbackUri,
        'content://media/external/audio/media/42');
  });

  test('returns an empty list when MediaStore contains no audio', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => []);

    expect(await service.loadTracks(), isEmpty);
  });
}
