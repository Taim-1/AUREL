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
    final downloadUri = Uri.tryParse(track.downloadUrl.trim());
    if (!track.downloadAllowed ||
        downloadUri == null ||
        downloadUri.scheme != 'https' ||
        downloadUri.host.isEmpty) {
      throw const DownloadException(
        'Offline download is not permitted for this recording.',
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
    final extension = audioFileExtensionFromUrl(track.downloadUrl);
    final file = File(
      '${folder.path}/$safeArtist' '_$safeTitle' '_$safeId.$extension',
    );
    final temporaryFile = File('${file.path}.part');

    try {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }

      var requestUri = downloadUri;
      final requestHeaders = Map<String, String>.of(track.playbackHeaders);
      Response<dynamic>? response;

      // Follow redirects manually so an HTTPS request can never silently
      // continue to an HTTP target. Provider authorization is not forwarded
      // when a redirect crosses an origin boundary.
      for (var redirectCount = 0; redirectCount <= 5; redirectCount++) {
        if (!isSecureDownloadUri(requestUri)) {
          throw const DownloadException(
            'The download server redirected to an insecure address.',
          );
        }

        response = await _dio.download(
          requestUri.toString(),
          temporaryFile.path,
          cancelToken: cancelToken,
          onReceiveProgress: onProgress,
          options: Options(
            headers: requestHeaders.isEmpty ? null : requestHeaders,
            followRedirects: false,
            maxRedirects: 0,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
        );

        final status = response.statusCode ?? 0;
        if (status >= 200 && status < 300) break;
        if (!_isRedirectStatus(status)) {
          throw DownloadException(
            'The download server returned HTTP $status.',
          );
        }
        if (redirectCount == 5) {
          throw const DownloadException(
            'The download server redirected too many times.',
          );
        }

        final nextUri = resolveSecureDownloadRedirect(
          requestUri,
          response.headers.value('location'),
        );
        if (!_sameDownloadOrigin(requestUri, nextUri)) {
          requestHeaders.removeWhere(
            (key, _) =>
                key.toLowerCase() == 'authorization' ||
                key.toLowerCase() == 'cookie',
          );
        }
        requestUri = nextUri;
        if (await temporaryFile.exists()) {
          await temporaryFile.delete();
        }
      }

      if (response == null ||
          response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw const DownloadException(
          'The download server did not return an audio file.',
        );
      }
      if (!isSecureDownloadUri(response.realUri)) {
        throw const DownloadException(
          'The download server redirected to an insecure address.',
        );
      }

      if (!await temporaryFile.exists() || await temporaryFile.length() == 0) {
        throw const DownloadException('The downloaded audio file is empty.');
      }

      final contentType = response.headers.value(Headers.contentTypeHeader);
      if (!isAllowedAudioContentType(contentType)) {
        throw const DownloadException(
          'The download server did not return an audio file.',
        );
      }

      final handle = await temporaryFile.open();
      late final List<int> header;
      try {
        header = await handle.read(64);
      } finally {
        await handle.close();
      }

      final detectedExtension = audioFileExtensionFromSignature(header);
      if (detectedExtension == null) {
        throw const DownloadException(
          'The downloaded content is not a supported audio format.',
        );
      }

      // Trust the actual file signature rather than a misleading URL suffix.
      final destination = detectedExtension == extension
          ? file
          : File(
              '${folder.path}/$safeArtist' '_$safeTitle' '_$safeId.$detectedExtension',
            );
      if (await destination.exists()) {
        await destination.delete();
      }
      await temporaryFile.rename(destination.path);

      return track.copyWith(
        localPath: destination.path,
        isDownloaded: true,
      );
    } on DioException catch (error) {
      if (await temporaryFile.exists()) await temporaryFile.delete();
      if (error.type == DioExceptionType.cancel) {
        throw const DownloadException('Download cancelled.');
      }
      throw DownloadException(
        error.response?.statusCode == 403
            ? 'The download is no longer available for this track.'
            : 'Download failed. Check your connection and try again.',
      );
    } catch (_) {
      if (await temporaryFile.exists()) await temporaryFile.delete();
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

  Future<List<Track>> validateSavedDownloads(
    Iterable<Track> tracks,
  ) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}AUREL Downloads',
    );
    if (!await directory.exists()) return const [];

    final resolvedDirectory = await directory.resolveSymbolicLinks();
    final validTracks = <Track>[];

    for (final track in tracks) {
      if (!track.isDownloaded || !track.hasLocalPlaybackUri) continue;

      final rawPath = track.localPath?.trim() ?? '';
      if (rawPath.isEmpty) continue;

      final uri = Uri.tryParse(rawPath);
      if (uri == null) continue;

      final candidate = uri.scheme == 'file'
          ? File.fromUri(uri)
          : uri.scheme.isEmpty
              ? File(rawPath)
              : null;
      if (candidate == null) continue;

      try {
        final resolvedPath = await candidate.resolveSymbolicLinks();
        if (!isWithinAurelDownloadsDirectory(
          resolvedPath,
          resolvedDirectory,
        )) {
          continue;
        }

        final file = File(resolvedPath);
        if (!await file.exists() || await file.length() == 0) continue;

        final handle = await file.open();
        late final List<int> header;
        try {
          header = await handle.read(64);
        } finally {
          await handle.close();
        }

        if (audioFileExtensionFromSignature(header) == null) continue;

        validTracks.add(
          track.copyWith(
            isDownloaded: true,
            localPath: resolvedPath,
          ),
        );
      } on FileSystemException {
        continue;
      } on FormatException {
        continue;
      }
    }

    return List.unmodifiable(validTracks);
  }

  Future<void> delete(Track track) async {
    final path = track.localPath;
    if (path == null || !track.isDownloaded || !track.hasLocalPlaybackUri) {
      return;
    }

    final root = await getApplicationDocumentsDirectory();
    final downloadsPath =
        Directory('${root.path}${Platform.pathSeparator}AUREL Downloads')
            .absolute
            .path;
    final file = File(path).absolute;
    if (!isWithinAurelDownloadsDirectory(file.path, downloadsPath)) return;

    if (await file.exists()) await file.delete();
  }
}

bool isWithinAurelDownloadsDirectory(
  String candidateFilePath,
  String downloadsDirectoryPath,
) {
  final separator = Platform.pathSeparator;
  final directory = Directory(downloadsDirectoryPath).absolute.path;
  final candidate = File(candidateFilePath).absolute.path;
  final prefix = directory.endsWith(separator)
      ? directory
      : '$directory$separator';
  return candidate.startsWith(prefix) && candidate.length > prefix.length;
}

/// Reject explicit non-audio responses while allowing generic binary
/// responses whose actual bytes are validated below.
bool isAllowedAudioContentType(String? contentType) {
  if (contentType == null || contentType.trim().isEmpty) return true;
  final mime = contentType.split(';').first.trim().toLowerCase();
  return mime.startsWith('audio/') ||
      mime == 'application/octet-stream' ||
      mime == 'application/ogg' ||
      mime == 'application/mp4' ||
      mime == 'application/x-ogg' ||
      mime == 'application/x-flac';
}

/// Returns the audio extension identified from a file's leading bytes.
/// Null means the content is not a supported audio format.
String? audioFileExtensionFromSignature(List<int> bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x66 &&
      bytes[1] == 0x4C &&
      bytes[2] == 0x61 &&
      bytes[3] == 0x43) {
    return 'flac';
  }

  if (bytes.length >= 4 &&
      bytes[0] == 0x4F &&
      bytes[1] == 0x67 &&
      bytes[2] == 0x67 &&
      bytes[3] == 0x53) {
    return 'ogg';
  }

  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x41 &&
      bytes[10] == 0x56 &&
      bytes[11] == 0x45) {
    return 'wav';
  }

  if (bytes.length >= 8 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    return 'm4a';
  }

  if (bytes.length >= 3 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33) {
    return 'mp3';
  }

  if (bytes.length >= 2 && bytes[0] == 0xFF) {
    final second = bytes[1];
    if ((second & 0xF6) == 0xF0) return 'aac';
    if ((second & 0xE0) == 0xE0 && ((second >> 1) & 0x03) != 0x00) {
      return 'mp3';
    }
  }

  return null;
}

/// Keeps the downloaded file extension aligned with the audio URL.
/// The final extension is corrected using the downloaded file signature.
String audioFileExtensionFromUrl(String url) {
  const supported = {'mp3', 'm4a', 'aac', 'ogg', 'opus', 'flac', 'wav'};
  final uri = Uri.tryParse(url);
  final fileName = uri == null || uri.pathSegments.isEmpty
      ? ''
      : uri.pathSegments.last;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return 'mp3';
  final extension = fileName.substring(dot + 1).toLowerCase();
  return supported.contains(extension) ? extension : 'mp3';
}

class DownloadException implements Exception {
  const DownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool _isRedirectStatus(int status) =>
    status == 300 ||
    status == 301 ||
    status == 302 ||
    status == 303 ||
    status == 307 ||
    status == 308;

bool _sameDownloadOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;

/// Resolves a redirect target and rejects insecure or malformed destinations
/// before AUREL sends the next request.
Uri resolveSecureDownloadRedirect(Uri source, String? location) {
  final value = location?.trim() ?? '';
  if (value.isEmpty) {
    throw const DownloadException(
      'The download server returned a redirect without a destination.',
    );
  }
  final target = source.resolve(value);
  if (!isSecureDownloadUri(target) || target.userInfo.isNotEmpty) {
    throw const DownloadException(
      'The download server redirected to an insecure address.',
    );
  }
  return target;
}

/// Confirms that the final resolved download URL remains HTTPS after redirects.
bool isSecureDownloadUri(Uri uri) =>
    uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty;
