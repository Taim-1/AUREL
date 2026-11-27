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
    this.isDownloaded = false,
    this.localPath,
    this.providerId = 'jamendo',
    this.providerName = 'Jamendo',
    this.sourceUrl = '',
    this.recordingId = '',
    this.recordingMbid = '',
    this.licenseName = '',
    this.attribution = '',
    this.isPlayable = true,
    this.isPreviewOnly = false,
    this.isMetadataOnly = false,
    this.matchedSources = const [],
    this.alternatives = const [],
    this.playbackHeaders = const {},
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
  final bool isDownloaded;
  final String? localPath;

  /// Stable provider key for the authorized catalogue adapter. The key is
  /// not inferred from a display label.
  final String providerId;
  final String providerName;
  final String sourceUrl;

  /// ISRC when the provider exposes one. Used for exact cross-source matches.
  final String recordingId;

  /// MusicBrainz recording UUID, distinct from an ISRC.
  final String recordingMbid;
  final String licenseName;
  final String attribution;

  /// Metadata-only results remain visible but cannot be sent to the player.
  final bool isPlayable;
  final bool isPreviewOnly;
  final bool isMetadataOnly;

  /// Other catalogues that matched this same recording.
  final List<String> matchedSources;

  /// Same-recording alternatives retained in AUREL's internal priority order.
  /// The player may try the next eligible copy if the preferred source fails.
  final List<Track> alternatives;

  /// Short-lived in-memory request headers (for example SoundCloud OAuth).
  /// Deliberately omitted from toJson so access tokens never reach local or
  /// cloud library persistence.
  final Map<String, String> playbackHeaders;

  bool get hasLocalPlaybackUri {
    final path = localPath?.trim();
    if (path == null || path.isEmpty) return false;
    final uri = Uri.tryParse(path);
    return uri != null && (uri.scheme.isEmpty || uri.scheme == 'file');
  }

  bool get isLocal => isDownloaded && hasLocalPlaybackUri;

  /// Whether this recording has at least one provider-approved HTTPS download.
  /// A primary catalogue result may be stream-only while a same-recording
  /// alternative permits offline saving.
  bool get hasDownloadableSource {
    bool permitted(Track candidate) =>
        candidate.downloadAllowed && _isSecureHttpsUrl(candidate.downloadUrl);
    return permitted(this) || alternatives.any(permitted);
  }

  bool get canPlay {
    // Previews and metadata-only records are never full playable recordings.
    if (isPreviewOnly || isMetadataOnly || !isPlayable) return false;

    // An AUREL-managed download must use its saved local file. Never fall
    // back to a network stream for a broken offline entry.
    if (isDownloaded) return hasLocalPlaybackUri;
    return _isSecureHttpsUrl(streamUrl);
  }

  String get playbackUri {
    if (isDownloaded && hasLocalPlaybackUri) {
      final path = localPath!.trim();
      final uri = Uri.tryParse(path);
      return uri?.scheme == 'file' ? uri.toString() : Uri.file(path).toString();
    }
    return streamUrl;
  }

  factory Track.fromJamendo(Map<String, dynamic> json) {
    final audio = (json['audio'] ?? '').toString();
    final rawDuration = json['duration'];
    final seconds = rawDuration is num
        ? rawDuration.round()
        : int.tryParse(rawDuration?.toString() ?? '') ?? 0;
    final download = (json['audiodownload'] ?? '').toString();

    return Track(
      id: (json['id'] ?? '').toString(),
      title: (json['name'] ?? 'Unknown track').toString(),
      artist: (json['artist_name'] ?? 'Unknown artist').toString(),
      album: (json['album_name'] ?? '').toString(),
      artworkUrl: (json['album_image'] ?? json['image'] ?? '').toString(),
      streamUrl: audio,
      downloadUrl: download,
      licenseUrl: (json['license_ccurl'] ?? '').toString(),
      durationMs: seconds * 1000,
      downloadAllowed: json['audiodownload_allowed'] == true &&
          _isSecureHttpsUrl(download),
      providerId: 'jamendo',
      providerName: 'Jamendo',
      sourceUrl: (json['shareurl'] ?? '').toString(),
      recordingId: (json['isrc'] ?? '').toString(),
      isPlayable: audio.isNotEmpty,
    );
  }

  factory Track.fromAudius(Map<String, dynamic> json) {
    final user = json['user'];
    final artwork = json['artwork'];
    final artworkUrl = artwork is Map
        ? (artwork['480x480'] ?? artwork['1000x1000'] ??
                artwork['150x150'] ??
                '')
            .toString()
        : '';
    final id = (json['id'] ?? '').toString();
    final downloadable = json['is_downloadable'] == true;
    final streamable = json['is_streamable'] == true;
    final duration = json['duration'];
    final seconds = duration is num
        ? duration.round()
        : int.tryParse(duration?.toString() ?? '') ?? 0;

    return Track(
      id: 'audius-$id',
      title: (json['title'] ?? 'Unknown track').toString(),
      artist: user is Map
          ? (user['name'] ?? user['handle'] ?? 'Unknown artist').toString()
          : 'Unknown artist',
      album: (json['album_name'] ?? '').toString(),
      artworkUrl: artworkUrl,
      streamUrl: streamable
          ? 'https://api.audius.co/v1/tracks/$id/stream?app_name=AUREL'
          : '',
      downloadUrl: downloadable
          ? 'https://api.audius.co/v1/tracks/$id/download?app_name=AUREL'
          : '',
      durationMs: seconds * 1000,
      downloadAllowed: downloadable &&
          _isSecureHttpsUrl('https://api.audius.co/v1/tracks/$id/download?app_name=AUREL'),
      providerId: 'audius',
      providerName: 'Audius',
      sourceUrl: (json['permalink'] ?? '').toString(),
      recordingId: (json['isrc'] ?? '').toString(),
      isPlayable: streamable,
    );
  }

  factory Track.fromSoundCloud(
    Map<String, dynamic> json, {
    String accessToken = '',
  }) {
    final id = (json['id'] ?? '').toString();
    final user = json['user'];
    final mediaArtist = (json['metadata_artist'] ?? '').toString();
    final userArtist = user is Map
        ? (user['username'] ?? 'Unknown artist').toString()
        : 'Unknown artist';
    final artwork = (json['artwork_url'] ?? '').toString();
    final downloadable = json['downloadable'] == true;
    final downloadUrl = (json['download_url'] ?? '').toString();
    final access = (json['access'] ?? '').toString().toLowerCase();

    return Track(
      id: 'soundcloud-$id',
      title: (json['title'] ?? 'Unknown track').toString(),
      artist: mediaArtist.isNotEmpty ? mediaArtist : userArtist,
      album: (json['publisher_metadata'] is Map
              ? (json['publisher_metadata']['album_title'] ?? '')
              : '')
          .toString(),
      artworkUrl: artwork.isNotEmpty
          ? artwork
          : user is Map
              ? (user['avatar_url'] ?? '').toString()
              : '',
      streamUrl: access == 'blocked' || id.isEmpty
          ? ''
          : 'https://api.soundcloud.com/tracks/$id/stream',
      downloadUrl: downloadable ? downloadUrl : '',
      durationMs: (json['duration'] as num?)?.round() ?? 0,
      downloadAllowed: downloadable && _isSecureHttpsUrl(downloadUrl),
      providerId: 'soundcloud',
      providerName: 'SoundCloud',
      sourceUrl: (json['permalink_url'] ?? '').toString(),
      attribution:
          '"${(json['title'] ?? 'Untitled track').toString()}" by '
          '${mediaArtist.isNotEmpty ? mediaArtist : userArtist}. '
          'SoundCloud creator/source credit.',
      recordingId: (json['publisher_metadata'] is Map
              ? (json['publisher_metadata']['isrc'] ?? '')
              : '')
          .toString(),
      isPlayable: access == 'playable' ||
          (access.isEmpty && json['streamable'] == true),
      playbackHeaders: accessToken.isEmpty
          ? const {}
          : {'Authorization': 'OAuth $accessToken'},
    );
  }

  factory Track.fromSpotify(Map<String, dynamic> json) {
    final artists = json['artists'];
    final artistNames = artists is List
        ? artists
            .whereType<Map>()
            .map((artist) => (artist['name'] ?? '').toString())
            .where((name) => name.isNotEmpty)
            .join(', ')
        : '';
    final album = json['album'];
    final images = album is Map ? album['images'] : null;
    final artwork = images is List && images.isNotEmpty && images.first is Map
        ? (images.first['url'] ?? '').toString()
        : '';

    return Track(
      id: 'spotify-${json['id'] ?? ''}',
      title: (json['name'] ?? 'Unknown track').toString(),
      artist: artistNames.isEmpty ? 'Unknown artist' : artistNames,
      album: album is Map ? (album['name'] ?? '').toString() : '',
      artworkUrl: artwork,
      durationMs: (json['duration_ms'] as num?)?.round() ?? 0,
      providerId: 'spotify',
      providerName: 'Spotify',
      sourceUrl: json['external_urls'] is Map
          ? (json['external_urls']['spotify'] ?? '').toString()
          : '',
      recordingId: json['external_ids'] is Map
          ? (json['external_ids']['isrc'] ?? '').toString()
          : '',
      isPlayable: false,
      isMetadataOnly: true,
    );
  }

  factory Track.fromAppleMusic(Map<String, dynamic> json) {
    final attributes = json['attributes'];
    if (attributes is! Map) {
      return const Track(
        id: 'apple-music-unknown',

        title: 'Unknown track',

        artist: 'Unknown artist',

        providerId: 'apple_music',

        providerName: 'Apple Music',

        isPlayable: false,

        isMetadataOnly: true,

      );
    }
    final artwork = attributes['artwork'];
    var artworkUrl = artwork is Map
        ? (artwork['url'] ?? '').toString()
        : '';
    if (artworkUrl.isNotEmpty) {
      artworkUrl = artworkUrl
          .replaceAll('{w}', '600')
          .replaceAll('{h}', '600');
    }

    return Track(
      id: 'apple-music-${json['id'] ?? ''}',
      title: (attributes['name'] ?? 'Unknown track').toString(),
      artist: (attributes['artistName'] ?? 'Unknown artist').toString(),
      album: (attributes['albumName'] ?? '').toString(),
      artworkUrl: artworkUrl,
      durationMs: (attributes['durationInMillis'] as num?)?.round() ?? 0,
      providerId: 'apple_music',
      providerName: 'Apple Music',
      sourceUrl: (attributes['url'] ?? '').toString(),
      recordingId: (attributes['isrc'] ?? '').toString(),
      isPlayable: false,
      isMetadataOnly: true,
    );
  }

  factory Track.fromOpenverse(Map<String, dynamic> json) {
    final rawUrl = (json['url'] ?? '').toString().trim();
    final license = (json['license'] ?? '').toString().trim().toLowerCase();
    final licenseUrl = (json['license_url'] ?? '').toString().trim();
    final attribution = (json['attribution'] ?? '').toString().trim();
    const reusableLicenses = {'by', 'by-sa', 'cc0', 'pdm'};
    final licenseUri = Uri.tryParse(licenseUrl);
    final licensePath = licenseUri?.path.toLowerCase() ?? '';
    final licenseLocationIsValid = licenseUri != null &&
        licenseUri.scheme == 'https' &&
        licenseUri.host.toLowerCase() == 'creativecommons.org' &&
        switch (license) {
          'by' => licensePath.contains('/licenses/by/'),
          'by-sa' => licensePath.contains('/licenses/by-sa/'),
          'cc0' => licensePath.contains('/publicdomain/zero/'),
          'pdm' => licensePath.contains('/publicdomain/mark/'),
          _ => false,
        };
    const audioFileTypes = {
      'mp3',
      'ogg',
      'opus',
      'wav',
      'm4a',
      'aac',
      'flac',
    };
    final allowed = reusableLicenses.contains(license) &&
        licenseLocationIsValid;
    final id = (json['id'] ?? '').toString().trim();
    final duration = json['duration'];
    final fileType = (json['filetype'] ?? '').toString().toLowerCase();
    final mediaUri = Uri.tryParse(rawUrl);
    final landingUri =
        Uri.tryParse((json['foreign_landing_url'] ?? '').toString());
    final playable = id.isNotEmpty &&
        mediaUri != null &&
        mediaUri.scheme == 'https' &&
        mediaUri.host.isNotEmpty &&
        audioFileTypes.contains(fileType) &&
        (json['category'] ?? '').toString().toLowerCase() == 'music';
    final safeLandingUrl = landingUri != null &&
            landingUri.scheme == 'https' &&
            landingUri.host.isNotEmpty
        ? landingUri.toString()
        : '';

    return Track(
      id: 'openverse-$id',
      title: (json['title'] ?? 'Unknown track').toString(),
      artist: (json['creator'] ?? 'Unknown creator').toString(),
      artworkUrl: (json['thumbnail'] ?? '').toString(),
      streamUrl: playable ? mediaUri.toString() : '',
      downloadUrl: playable && allowed ? mediaUri.toString() : '',
      licenseUrl: licenseUrl,
      licenseName: license,
      attribution: attribution,
      durationMs: duration is num ? duration.round() : 0,
      downloadAllowed: playable && allowed && _isSecureHttpsUrl(rawUrl),
      providerId: 'openverse',
      providerName: 'Openverse',
      sourceUrl: safeLandingUrl,
      isPlayable: playable,
    );
  }

  factory Track.fromInternetArchive({
    required String identifier,
    required String title,
    required String artist,
    required String album,
    required String artworkUrl,
    required String mediaUrl,
    required String sourceUrl,
    required String licenseUrl,
    required String licenseName,
    required int durationMs,
  }) =>
      Track(
        id: 'internet-archive-$identifier',
        title: title.isEmpty ? 'Untitled audio' : title,
        artist: artist.isEmpty ? 'Internet Archive contributor' : artist,
        album: album,
        artworkUrl: artworkUrl,
        streamUrl: mediaUrl,
        downloadUrl: mediaUrl,
        licenseUrl: licenseUrl,
        licenseName: licenseName,
        attribution: '$title by $artist — Internet Archive. $licenseUrl',
        durationMs: durationMs,
        downloadAllowed: _isSecureHttpsUrl(mediaUrl),
        providerId: 'internet_archive',
        providerName: 'Internet Archive',
        sourceUrl: sourceUrl,
        isPlayable: mediaUrl.isNotEmpty,
      );

  factory Track.fromWikimediaCommons({
    required String pageId,
    required String title,
    required String artist,
    required String mediaUrl,
    required String sourceUrl,
    required String licenseName,
    required String licenseUrl,
    required String attribution,
    required int durationMs,
  }) =>
      Track(
        id: 'wikimedia-commons-$pageId',
        title: title.isEmpty ? 'Untitled audio' : title,
        artist: artist.isEmpty ? 'Open audio contributor' : artist,
        streamUrl: mediaUrl,
        downloadUrl: mediaUrl,
        licenseUrl: licenseUrl,
        licenseName: licenseName,
        attribution: attribution,
        durationMs: durationMs,
        downloadAllowed: _isSecureHttpsUrl(mediaUrl) &&
            _isSecureHttpsUrl(licenseUrl),
        providerId: 'wikimedia_commons',
        providerName: 'Open audio collection',
        sourceUrl: sourceUrl,
        isPlayable: mediaUrl.isNotEmpty,
      );

  factory Track.fromMusicBrainz(Map<String, dynamic> json) {
    final rawCredit = json['artist-credit'];
    final artistCredit = StringBuffer();
    if (rawCredit is List) {
      for (final entry in rawCredit) {
        if (entry is String) {
          artistCredit.write(entry);
          continue;
        }
        if (entry is! Map) continue;
        final directName = (entry['name'] ?? '').toString().trim();
        final artist = entry['artist'];
        final nestedName = artist is Map
            ? (artist['name'] ?? '').toString().trim()
            : '';
        final name = directName.isNotEmpty ? directName : nestedName;
        if (name.isNotEmpty) artistCredit.write(name);
        // MusicBrainz join phrases already contain their intended spacing.
        // Append directly instead of joining fragments with an extra space.
        artistCredit.write((entry['joinphrase'] ?? '').toString());
      }
    }
    final artistName = artistCredit.toString().trim();
    final isrcs = json['isrcs'];
    final recordingId = isrcs is List && isrcs.isNotEmpty
        ? isrcs.first.toString()
        : '';
    final length = (json['length'] as num?)?.round() ?? 0;
    final id = (json['id'] ?? '').toString();

    return Track(
      id: 'musicbrainz-$id',
      title: (json['title'] ?? 'Unknown recording').toString(),
      artist: artistName.isEmpty ? 'Unknown artist' : artistName,
      durationMs: length,
      providerId: 'musicbrainz',
      providerName: 'Recording metadata',
      sourceUrl: id.isEmpty ? '' : 'https://musicbrainz.org/recording/$id',
      recordingId: recordingId,
      recordingMbid: _isValidMusicBrainzId(id) ? id : '',
      isPlayable: false,
      isMetadataOnly: true,
    );
  }


  factory Track.fromLastFm(Map<String, dynamic> json) {
    final rawArtist = json['artist'];
    final artist = rawArtist is Map
        ? (rawArtist['name'] ?? '').toString().trim()
        : (rawArtist ?? '').toString().trim();
    final rawAlbum = json['album'];
    final album = rawAlbum is Map
        ? (rawAlbum['title'] ?? rawAlbum['name'] ?? '').toString().trim()
        : '';
    // Last.fm API terms do not license artwork/image reuse.
    final rawDuration = json['duration'];
    final reportedDuration = rawDuration is num
        ? rawDuration.round()
        : int.tryParse(rawDuration?.toString() ?? '') ?? 0;
    // Last.fm search/track-info data may report milliseconds, while
    // artist.getTopTracks reports seconds. Normalize the smaller positive
    // values to milliseconds without changing already-millisecond values.
    final duration = reportedDuration > 0 && reportedDuration < 10000
        ? reportedDuration * 1000
        : reportedDuration;
    final mbid = (json['mbid'] ?? '').toString().trim();
    final source = (json['url'] ?? '').toString().trim();
    final parsedSource = Uri.tryParse(source);
    final sourceUri = parsedSource != null && parsedSource.scheme.isEmpty
        ? Uri.tryParse('https://$source')
        : parsedSource;
    final sourceHost = sourceUri?.host.toLowerCase() ?? '';
    final safeSource = sourceUri != null &&
            sourceUri.scheme == 'https' &&
            (sourceHost == 'last.fm' || sourceHost.endsWith('.last.fm'))
        ? sourceUri.toString()
        : '';
    final title = (json['name'] ?? 'Unknown recording').toString().trim();
    final stableKey = mbid.isNotEmpty
        ? mbid
        : safeSource.isNotEmpty
            ? safeSource
            : '${artist.toLowerCase()}::${title.toLowerCase()}';

    return Track(
      id: 'lastfm-$stableKey',
      title: title.isEmpty ? 'Unknown recording' : title,
      artist: artist.isEmpty ? 'Unknown artist' : artist,
      album: album,
      artworkUrl: '',
      durationMs: duration,
      providerId: 'lastfm',
      providerName: 'Last.fm',
      sourceUrl: safeSource,
      attribution: 'Metadata provided by Last.fm. No audio is supplied by this source.',
      // Last.fm's MBID is a MusicBrainz recording UUID, not an ISRC.
      recordingMbid: _isValidMusicBrainzId(mbid) ? mbid : '',
      isPlayable: false,
      isMetadataOnly: true,
    );
  }


  factory Track.fromListenBrainz(Map<String, dynamic> json) {
    final recordingMbid = (json['recording_mbid'] ?? '').toString().trim();
    final releaseMbid = (json['release_mbid'] ?? '').toString().trim();
    final title = (json['track_name'] ?? 'Unknown recording').toString().trim();
    final artist = (json['artist_name'] ?? 'Unknown artist').toString().trim();
    final album = (json['release_name'] ?? '').toString().trim();
    final rawLength = json['length'];
    final duration = rawLength is num
        ? rawLength.round()
        : int.tryParse(rawLength?.toString() ?? '') ?? 0;
    final validReleaseMbid = _isValidMusicBrainzId(releaseMbid);
    final validRecordingMbid = _isValidMusicBrainzId(recordingMbid);
    final artworkUrl = validReleaseMbid
        ? 'https://coverartarchive.org/release/$releaseMbid/front-250'
        : '';
    final sourceUrl = validRecordingMbid
        ? 'https://musicbrainz.org/recording/$recordingMbid'
        : '';
    final stableKey = validRecordingMbid
        ? recordingMbid
        : '${artist.toLowerCase()}::${title.toLowerCase()}';

    return Track(
      id: 'listenbrainz-$stableKey',
      title: title.isEmpty ? 'Unknown recording' : title,
      artist: artist.isEmpty ? 'Unknown artist' : artist,
      album: album,
      artworkUrl: artworkUrl,
      durationMs: duration,
      providerId: 'listenbrainz',
      providerName: 'ListenBrainz',
      sourceUrl: sourceUrl,
      // A MusicBrainz recording MBID is not an ISRC.
      recordingMbid: validRecordingMbid ? recordingMbid : '',
      isPlayable: false,
      isMetadataOnly: true,
    );
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final providerId = (json['providerId'] ?? 'jamendo').toString();
    final id = (json['id'] ?? '').toString();

    if (json['isDeviceTrack'] == true ||
        providerId == 'device' ||
        id.startsWith('device-')) {
      throw const FormatException(
        'Tracks indexed from the device library are no longer supported.',
      );
    }

    return Track(
      id: id,
      title: (json['title'] ?? '').toString(),
      artist: (json['artist'] ?? '').toString(),
      album: (json['album'] ?? '').toString(),
      artworkUrl: (json['artworkUrl'] ?? '').toString(),
      streamUrl: (json['streamUrl'] ?? '').toString(),
      downloadUrl: (json['downloadUrl'] ?? '').toString(),
      licenseUrl: (json['licenseUrl'] ?? '').toString(),
      durationMs: (json['durationMs'] as num?)?.round() ?? 0,
      downloadAllowed: json['downloadAllowed'] == true,
      isDownloaded: false,
      localPath: null,
      providerId: providerId,
      providerName: (json['providerName'] ?? 'Jamendo').toString(),
      sourceUrl: (json['sourceUrl'] ?? '').toString(),
      recordingId: (json['recordingId'] ?? '').toString(),
      recordingMbid: (json['recordingMbid'] ?? '').toString(),
      licenseName: (json['licenseName'] ?? '').toString(),
      attribution: (json['attribution'] ?? '').toString(),
      isPlayable: json['isPlayable'] != false,
      isPreviewOnly: json['isPreviewOnly'] == true,
      isMetadataOnly: json['isMetadataOnly'] == true,
      matchedSources: (json['matchedSources'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const [],
      alternatives: (json['alternatives'] as List?)
              ?.whereType<Map>()
              .map((value) {
                try {
                  return Track.fromJson(
                    Map<String, dynamic>.from(value),
                  ).copyWith(alternatives: const []);
                } on FormatException {
                  return null;
                }
              })
              .whereType<Track>()
              .toList(growable: false) ??
          const [],
    );
  }

  factory Track.fromDownloadedJson(Map<String, dynamic> json) {
    if (json['isDownloaded'] != true) {
      throw const FormatException(
        'Only AUREL-managed downloaded recordings can enter the offline library.',
      );
    }

    final track = Track.fromJson(json);
    final path = (json['localPath'] ?? '').toString().trim();
    if (path.isEmpty) {
      throw const FormatException(
        'The saved AUREL download does not have a local file path.',
      );
    }

    return track.copyWith(
      isDownloaded: true,
      localPath: path,
    );
  }

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
        'isDownloaded': isDownloaded,
        'localPath': localPath,
        'providerId': providerId,
        'providerName': providerName,
        'sourceUrl': sourceUrl,
        'recordingId': recordingId,
        'recordingMbid': recordingMbid,
        'licenseName': licenseName,
        'attribution': attribution,
        'isPlayable': isPlayable,
        'isPreviewOnly': isPreviewOnly,
        'isMetadataOnly': isMetadataOnly,
        'matchedSources': matchedSources,
        'alternatives': alternatives
            .map((track) => track.copyWith(alternatives: const []).toJson())
            .toList(growable: false),
      };

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    String? localPath,
    bool? isDownloaded,
    String? streamUrl,
    int? durationMs,
    String? recordingId,
    String? recordingMbid,
    List<String>? matchedSources,
    List<Track>? alternatives,
    Map<String, String>? playbackHeaders,
  }) =>
      Track(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        artworkUrl: artworkUrl ?? this.artworkUrl,
        streamUrl: streamUrl ?? this.streamUrl,
        downloadUrl: downloadUrl,
        licenseUrl: licenseUrl,
        durationMs: durationMs ?? this.durationMs,
        downloadAllowed: downloadAllowed,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        localPath: localPath ?? this.localPath,
        providerId: providerId,
        providerName: providerName,
        sourceUrl: sourceUrl,
        recordingId: recordingId ?? this.recordingId,
        recordingMbid: recordingMbid ?? this.recordingMbid,
        licenseName: licenseName,
        attribution: attribution,
        isPlayable: isPlayable,
        isPreviewOnly: isPreviewOnly,
        isMetadataOnly: isMetadataOnly,
        matchedSources: matchedSources ?? this.matchedSources,
        alternatives: alternatives ?? this.alternatives,
        playbackHeaders: playbackHeaders ?? this.playbackHeaders,
      );
}


bool _isValidMusicBrainzId(String value) {
  final parts = value.split('-');
  const expectedLengths = [8, 4, 4, 4, 12];
  if (parts.length != expectedLengths.length) return false;
  for (var index = 0; index < parts.length; index++) {
    if (parts[index].length != expectedLengths[index] ||
        int.tryParse(parts[index], radix: 16) == null) {
      return false;
    }
  }
  return true;
}

bool _isSecureHttpsUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}
