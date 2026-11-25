import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

class DownloadService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  Future<Track> download(Track track) async {
    if (!track.downloadAllowed || track.downloadUrl.isEmpty) {
      throw const DownloadException(
        'This artist has not enabled downloads for this track.',
      );
    }

    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/AUREL Downloads');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final safeTitle = track.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .trim()
        .replaceAll(RegExp(r'\\s+'), '_');
    final safeArtist = track.artist
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .trim()
        .replaceAll(RegExp(r'\\s+'), '_');
    final file = File('${folder.path}/${safeArtist}_${safeTitle}_${track.id}.mp3');

    try {
      await _dio.download(
        track.downloadUrl,
        file.path,
        options: Options(
          followRedirects: true,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      if (!await file.exists() || await file.length() == 0) {
        throw const DownloadException('The downloaded audio file is empty.');
      }
      return track.copyWith(localPath: file.path, isDownloaded: true);
    } on DioException catch (error) {
      if (await file.exists()) await file.delete();
      throw DownloadException(
        error.response?.statusCode == 403
            ? 'The download is no longer available for this track.'
            : 'Download failed. Check your connection and try again.',
      );
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<void> delete(Track track) async {
    final path = track.localPath;
    if (path == null || path.startsWith('content://')) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

class DownloadException implements Exception {
  const DownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}
