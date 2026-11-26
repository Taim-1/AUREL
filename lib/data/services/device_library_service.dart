import 'package:flutter/services.dart';

import '../models/track.dart';

/// Reads the Android MediaStore without copying or uploading device audio.
/// Permission is requested only after the user opens the On Device library.
class DeviceLibraryService {
  static const MethodChannel _channel =
      MethodChannel('com.aurel.music/device_library');

  Future<bool> hasAudioPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasAudioPermission') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> requestAudioPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestAudioPermission') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<List<Track>> loadTracks() async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
          'queryAudioTracks',
        ) ??
        const <Map<Object?, Object?>>[];
    return rows
        .map(Track.fromDevice)
        .where((track) => track.canPlay)
        .toList(growable: false);
  }
}
