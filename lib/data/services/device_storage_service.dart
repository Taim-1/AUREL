import 'package:flutter/services.dart';

class DeviceStorageSnapshot {
  const DeviceStorageSnapshot({
    required this.totalBytes,
    required this.availableBytes,
  });

  final int totalBytes;
  final int availableBytes;

  int get usedBytes =>
      (totalBytes - availableBytes).clamp(0, totalBytes);

  double get usedFraction =>
      totalBytes <= 0 ? 0 : usedBytes / totalBytes;

  factory DeviceStorageSnapshot.fromMap(Map<Object?, Object?> map) {
    final total = (map['totalBytes'] as num?)?.toInt() ?? 0;
    final available = (map['availableBytes'] as num?)?.toInt() ?? 0;
    if (total <= 0 || available < 0) {
      throw const FormatException('Android returned invalid storage details.');
    }
    return DeviceStorageSnapshot(
      totalBytes: total,
      availableBytes: available.clamp(0, total),
    );
  }

  static String formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes < 1024) return '$bytes B';

    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = value >= 100 ? 0 : value >= 10 ? 1 : 2;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }
}

class DeviceStorageService {
  DeviceStorageService._();

  static const _channel = MethodChannel('com.aurel.aurel/device_storage');

  static Future<DeviceStorageSnapshot> read() async {
    final result =
        await _channel.invokeMethod<Map<Object?, Object?>>('getDeviceStorage');
    if (result == null) {
      throw const FormatException('Android did not return device storage details.');
    }
    return DeviceStorageSnapshot.fromMap(result);
  }
}
