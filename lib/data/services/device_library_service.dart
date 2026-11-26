import 'package:flutter/services.dart';

import '../models/track.dart';

/// Reads Android MediaStore entries in place. AUREL never copies, moves,
/// modifies, or uploads the user's device audio.
class DeviceLibraryService {
  DeviceLibraryService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.aurel.music/device_library';
  final MethodChannel _channel;

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
    final tracks = rows
        .map((row) => Track.fromDevice(
              Map<String, dynamic>.from(row),
            ))
        .where((track) => track.canPlay && track.isLocal)
        .toList(growable: false);
    return tracks;
  }
}
