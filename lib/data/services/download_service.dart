import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

class DownloadService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 20),
    ),
  );

  Future<Track> download(
    Track track, {
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
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

    final safeArtist = _safeFilePart(track.artist);
    final safeTitle = _safeFilePart(track.title);
    final safeId = _safeFilePart(track.id);
    final file = File(
      '${folder.path}/$safeArtist' '_$safeTitle' '_$safeId.mp3',
    );

    try {
      await _dio.download(
        track.downloadUrl,
        file.path,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(
          headers: track.playbackHeaders.isEmpty ? null : track.playbackHeaders,
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
      if (error.type == DioExceptionType.cancel) {
        throw const DownloadException('Download cancelled.');
      }
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

  String _safeFilePart(String value) {
    final clean = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    if (clean.isEmpty) return 'track';
    return clean.length > 64 ? clean.substring(0, 64) : clean;
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
