import 'package:flutter/services.dart';
import 'dart:async';

import '../models/track.dart';

/// Reads Android MediaStore entries in place. AUREL never copies, moves,
/// modifies, or uploads the user's device audio.
class DeviceLibraryService {
  DeviceLibraryService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.aurel.music/device_library';
  static const EventChannel _changesChannel =
      EventChannel('com.aurel.music/device_library/changes');
  final MethodChannel _channel;

  Stream<void> get changes =>
      _changesChannel.receiveBroadcastStream().map<void>((_) {});

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
