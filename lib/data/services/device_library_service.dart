import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/track.dart';

class DeviceLibraryService {
  static const _channel = MethodChannel('com.aurel.music/device_library');

  Future<List<Track>> scan() async {
    if (!Platform.isAndroid) {
      throw const DeviceLibraryException(
        'Device library scanning is currently available on Android.',
      );
    }

    final sdk = await _channel.invokeMethod<int>('getSdkInt') ?? 33;
    final permission = sdk >= 33 ? Permission.audio : Permission.storage;
    final status = await permission.request();

    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        throw const DeviceLibraryException(
          'Audio access is disabled. Allow AUREL to access audio in Android settings.',
        );
      }
      throw const DeviceLibraryException(
        'AUREL needs audio access to scan songs stored on your device.',
      );
    }

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('listAudio');
      return (result ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(Track.fromDevice)
          .where((track) => track.localPath?.isNotEmpty == true)
          .toList(growable: false);
    } on PlatformException catch (error) {
      throw DeviceLibraryException(
        error.message ?? 'Could not read the device music library.',
      );
    }
  }
}

class DeviceLibraryException implements Exception {
  const DeviceLibraryException(this.message);
  final String message;

  @override
  String toString() => message;
}
