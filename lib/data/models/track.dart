class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.artworkUrl = '',
    this.streamUrl = '',
    this.downloadUrl = '',
    this.licenseUrl = '',
    this.durationMs = 0,
    this.downloadAllowed = false,
    this.isDeviceTrack = false,
    this.isDownloaded = false,
    this.localPath,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String streamUrl;
  final String downloadUrl;
  final String licenseUrl;
  final int durationMs;
  final bool downloadAllowed;
  final bool isDeviceTrack;
  final bool isDownloaded;
  final String? localPath;

  bool get isLocal => isDeviceTrack || isDownloaded;

  String get playbackUri {
    if (localPath != null && localPath!.isNotEmpty) {
      if (localPath!.startsWith('content://')) return localPath!;
      return Uri.file(localPath!).toString();
    }
    return streamUrl;
  }

  factory Track.fromJamendo(Map<String, dynamic> json) {
    final audio = (json['audio'] ?? '').toString();
    final rawDuration = json['duration'];
    final seconds = rawDuration is num
        ? rawDuration.round()
        : int.tryParse(rawDuration?.toString() ?? '') ?? 0;

    return Track(
      id: (json['id'] ?? '').toString(),
      title: (json['name'] ?? 'Unknown track').toString(),
      artist: (json['artist_name'] ?? 'Unknown artist').toString(),
      album: (json['album_name'] ?? '').toString(),
      artworkUrl: (json['album_image'] ?? json['image'] ?? '').toString(),
      streamUrl: audio,
      downloadUrl: (json['audiodownload'] ?? '').toString(),
      licenseUrl: (json['license_ccurl'] ?? '').toString(),
      durationMs: seconds * 1000,
      downloadAllowed: json['audiodownload_allowed'] == true &&
          (json['audiodownload'] ?? '').toString().isNotEmpty,
    );
  }

  factory Track.fromDevice(Map<Object?, Object?> json) {
    final uri = (json['uri'] ?? '').toString();
    final id = (json['id'] ?? uri).toString();
    final duration = json['duration'];
    return Track(
      id: 'device-$id',
      title: (json['title'] ?? 'Unknown track').toString(),
      artist: (json['artist'] ?? 'Unknown artist').toString(),
      album: (json['album'] ?? '').toString(),
      durationMs: duration is num ? duration.round() : 0,
      isDeviceTrack: true,
      localPath: uri,
    );
  }

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        artist: (json['artist'] ?? '').toString(),
        album: (json['album'] ?? '').toString(),
        artworkUrl: (json['artworkUrl'] ?? '').toString(),
        streamUrl: (json['streamUrl'] ?? '').toString(),
        downloadUrl: (json['downloadUrl'] ?? '').toString(),
        licenseUrl: (json['licenseUrl'] ?? '').toString(),
        durationMs: (json['durationMs'] as num?)?.round() ?? 0,
        downloadAllowed: json['downloadAllowed'] == true,
        isDeviceTrack: json['isDeviceTrack'] == true,
        isDownloaded: json['isDownloaded'] == true,
        localPath: json['localPath']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'artworkUrl': artworkUrl,
        'streamUrl': streamUrl,
        'downloadUrl': downloadUrl,
        'licenseUrl': licenseUrl,
        'durationMs': durationMs,
        'downloadAllowed': downloadAllowed,
        'isDeviceTrack': isDeviceTrack,
        'isDownloaded': isDownloaded,
        'localPath': localPath,
      };

  Track copyWith({
    String? localPath,
    bool? isDownloaded,
  }) =>
      Track(
        id: id,
        title: title,
        artist: artist,
        album: album,
        artworkUrl: artworkUrl,
        streamUrl: streamUrl,
        downloadUrl: downloadUrl,
        licenseUrl: licenseUrl,
        durationMs: durationMs,
        downloadAllowed: downloadAllowed,
        isDeviceTrack: isDeviceTrack,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        localPath: localPath ?? this.localPath,
      );
}
