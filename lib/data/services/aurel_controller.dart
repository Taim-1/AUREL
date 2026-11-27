import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/lyrics_document.dart';
import '../models/music_playlist.dart';
import '../models/track.dart';
import '../catalog/catalog_identity.dart';
import '../catalog/catalog_ranking.dart';
import '../catalog/local_track_priority.dart';
import '../repositories/library_repository.dart';
import 'aurel_account_service.dart';
import 'download_service.dart';
import '../catalog/providers/jamendo_service.dart';
import '../catalog/music_catalog_service.dart';
import 'lyrics_service.dart';
import 'library_collection_service.dart';
import 'playback_controller.dart';

class AurelController extends ChangeNotifier {
  bool _disposed = false;

  void _notifySafely() {
    if (!_disposed) super.notifyListeners();
  }

  AurelController({
    required this.repository,
    required this.jamendo,
    required this.downloads,
    required this.playback,
    required this.lyrics,
    required this.account,
    required this.catalog,
  }) {
    playback.setFallbackResolver((candidate) {
      if (offlineMode && !_isTrustedDownload(candidate)) {
        throw const PlaybackException(
          'Only verified AUREL downloads can play in Offline mode.',
        );
      }
      return catalog.prepareTrack(candidate);
    });
    playback.addListener(_onPlaybackChanged);
  }

  String? _lastHistoryTrackId;

  void _onPlaybackChanged() {
    if (_disposed) return;
    final track = playback.currentTrack;
    final trackId = track?.id;
    if (trackId != _lyricsTrackId) {
      unawaited(loadLyricsForCurrentTrack());
    }
    if (track != null && trackId != _lastHistoryTrackId) {
      unawaited(_recordRecentlyPlayed(track));
    }
    _notifySafely();
  }

  Future<void> _recordRecentlyPlayed(Track track) async {
    if (_disposed) return;
    if (_lastHistoryTrackId == track.id &&
        recentlyPlayed.isNotEmpty &&
        recentlyPlayed.first.id == track.id) {
      return;
    }
    _lastHistoryTrackId = track.id;
    recentlyPlayed = [
      track,
      ...recentlyPlayed.where((item) => item.id != track.id),
    ].take(100).toList(growable: false);
    await repository.saveRecentlyPlayed(recentlyPlayed);
    if (_disposed) return;
    try {
      await syncCloudRecentlyPlayed();
    } catch (error) {
      cloudSyncError = error.toString().replaceFirst('Exception: ', '');
    }
    _notifySafely();
  }

  Future<void> loadLyricsForCurrentTrack({bool forceRefresh = false}) async {
    final track = playback.currentTrack;
    if (track == null) {
      _lyricsRequestGeneration++;
      _lyricsTrackId = null;
      currentLyrics = null;
      isLoadingLyrics = false;
      lyricsError = null;
      _notifySafely();
      return;
    }
    if (!forceRefresh && _lyricsTrackId == track.id) return;

    final generation = ++_lyricsRequestGeneration;
    _lyricsTrackId = track.id;
    currentLyrics = null;
    lyricsError = null;
    isLoadingLyrics = true;
    _notifySafely();

    try {
      final document = await lyrics.fetchFor(
        track,
        forceRefresh: forceRefresh,
        allowNetwork: !offlineMode,
      );
      if (generation != _lyricsRequestGeneration) return;
      currentLyrics = document;
      if (document == null) {
        lyricsError = 'Lyrics are not available for this track yet.';
      }
    } catch (error) {
      if (generation != _lyricsRequestGeneration) return;
      lyricsError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (generation == _lyricsRequestGeneration) {
        isLoadingLyrics = false;
        _notifySafely();
      }
    }
  }

  final LibraryRepository repository;
  final JamendoService jamendo;
  final DownloadService downloads;
  final PlaybackController playback;
  final LyricsService lyrics;
  final AurelAccountService account;
  final MusicCatalogService catalog;
  Map<String, String> sourceErrors = const {};
  Map<String, int> sourceCounts = const {};

  String? cloudSyncError;
  String? _activeLibraryUid;

  // Cloud saves are serialized. Every queued operation reads the latest
  // in-memory collections when it starts, so rapid edits cannot be replayed
  // out of order and restore operations cannot leave older snapshots last.
  Future<void> _cloudSyncTail = Future<void>.value();
  int _cloudSyncRevision = 0;

  List<Track> discoverTracks = [];
  List<Track> searchResults = [];
  List<Track> favoriteTracks = [];
  List<Track> downloadedTracks = [];
  List<Track> recentlyPlayed = [];
  List<Track> previouslyDownloadedTracks = [];
  List<MusicPlaylist> playlists = [];
  bool offlineMode = false;

  LyricsDocument? currentLyrics;
  bool isLoadingLyrics = false;
  String? lyricsError;
  String? _lyricsTrackId;
  int _lyricsRequestGeneration = 0;

  final Set<String> downloadingIds = {};
  final Map<String, double> downloadProgress = {};
  final Map<String, CancelToken> _downloadTokens = {};

  bool isLoadingDiscover = false;
  bool isLoadingMoreDiscover = false;
  bool hasMoreDiscover = true;
  bool isSearching = false;
  bool isLoadingMoreSearch = false;
  bool hasMoreSearch = false;

  String? discoverError;
  String? searchError;
  String? searchMoreError;
  String searchQuery = '';
  int _discoverOffset = 0;
  int _searchOffset = 0;
  int _discoverGeneration = 0;
  int _searchGeneration = 0;
  CancelToken? _discoverCancelToken;
  CancelToken? _searchCancelToken;
  int selectedTab = 0;

  Future<void> initialize() async {
    await jamendo.initialize();
    await lyrics.initialize();
    await repository.setAccountScope(account.currentUser?.uid);
    _activeLibraryUid = account.currentUser?.uid;
    favoriteTracks = await repository.loadFavorites();
    final storedDownloads = await repository.loadDownloads();
    downloadedTracks = await downloads.validateSavedDownloads(storedDownloads);
    await repository.saveDownloads(downloadedTracks);
    recentlyPlayed = await repository.loadRecentlyPlayed();
    previouslyDownloadedTracks = await repository.loadDownloadHistory();
    previouslyDownloadedTracks = _mergeDownloadHistory(
      previouslyDownloadedTracks,
      downloadedTracks,
    );
    await repository.saveDownloadHistory(previouslyDownloadedTracks);
    playlists = await repository.loadPlaylists();
    offlineMode = await repository.loadOfflineMode();
    if (account.isSignedIn) {
      await restoreCloudLibrary();
    }
    _notifySafely();
    if (!offlineMode) {
      await refreshDiscover();
    }
  }

  Future<void> restoreCloudLibrary() async {
    final userId = account.currentUser?.uid;
    if (userId == null) return;

    // Switch the local namespace before reading collections so accounts
    // signing in on the same device never inherit one another's library.
    if (_activeLibraryUid != userId) {
      await repository.setAccountScope(userId);
      favoriteTracks = await repository.loadFavorites();
      recentlyPlayed = await repository.loadRecentlyPlayed();
      previouslyDownloadedTracks = await repository.loadDownloadHistory();
      playlists = await repository.loadPlaylists();
      _activeLibraryUid = userId;
    }

    try {
      final cloud = await account.loadCloudLibrary();
      if (cloud == null) {
        await syncCloudLibrary();
        return;
      }

      favoriteTracks = _appendUnique(favoriteTracks, cloud.favorites);
      recentlyPlayed = _appendUnique(recentlyPlayed, cloud.recentlyPlayed)
          .take(100)
          .toList(growable: false);
      previouslyDownloadedTracks = _mergeDownloadHistory(
        previouslyDownloadedTracks,
        cloud.downloadHistory,
      );

      final mergedPlaylists = <String, MusicPlaylist>{
        for (final playlist in cloud.playlists) playlist.id: playlist,
        for (final playlist in playlists) playlist.id: playlist,
      };
      playlists = mergedPlaylists.values.toList(growable: false);

      await repository.saveFavorites(favoriteTracks);
      await repository.saveRecentlyPlayed(recentlyPlayed);
      await repository.saveDownloadHistory(previouslyDownloadedTracks);
      await repository.savePlaylists(playlists);
      await syncCloudLibrary();
    } catch (error) {
      cloudSyncError = error.toString().replaceFirst('Exception: ', '');
    }
    _notifySafely();
  }

  Future<void> syncCloudLibrary() {
    final accountUid = account.currentUser?.uid;
    if (accountUid == null) return Future<void>.value();

    return _enqueueCloudWrite(accountUid, () {
      return account.saveCloudLibrary(
        favorites: List<Track>.unmodifiable(favoriteTracks),
        playlists: List<MusicPlaylist>.unmodifiable(playlists),
        recentlyPlayed: List<Track>.unmodifiable(recentlyPlayed),
        downloadHistory:
            List<Track>.unmodifiable(previouslyDownloadedTracks),
      );
    });
  }

  /// History changes are frequent, so they update only the compact history
  /// document instead of rewriting favorites and every playlist on each song.
  Future<void> syncCloudRecentlyPlayed() {
    final accountUid = account.currentUser?.uid;
    if (accountUid == null) return Future<void>.value();

    return _enqueueCloudWrite(accountUid, () {
      return account.saveCloudRecentlyPlayed(
        List<Track>.unmodifiable(recentlyPlayed),
      );
    });
  }

  Future<void> _enqueueCloudWrite(
    String accountUid,
    Future<void> Function() write,
  ) {
    final revision = ++_cloudSyncRevision;
    final operation = _cloudSyncTail.then((_) async {
      // Never replay a pending write under a different Firebase identity.
      if (account.currentUser?.uid != accountUid) return;

      await write();
      if (revision == _cloudSyncRevision) cloudSyncError = null;
      _notifySafely();
    });

    _cloudSyncTail = operation.catchError((Object error) {
      if (revision == _cloudSyncRevision) {
        cloudSyncError = error.toString().replaceFirst('Exception: ', '');
      }
      _notifySafely();
    });

    return operation;
  }

  Future<void> onAccountSignedOut() async {
    ++_cloudSyncRevision;
    _activeLibraryUid = null;
    await repository.setAccountScope(null);
    favoriteTracks = await repository.loadFavorites();
    recentlyPlayed = await repository.loadRecentlyPlayed();
    playlists = await repository.loadPlaylists();
    _lastHistoryTrackId = null;
    cloudSyncError = null;
    _notifySafely();
  }

  void notifyAccountChanged() => _notifySafely();

  List<Track> _appendUnique(List<Track> current, List<Track> incoming) {
    // IDs are not guaranteed to be present in every metadata-only catalogue.
    // Keep source-specific copies distinct in general library collections.
    final keys = current.map(CatalogIdentity.providerKeyOf).toSet();
    return [
      ...current,
      ...incoming.where(
        (track) => keys.add(CatalogIdentity.providerKeyOf(track)),
      ),
    ];
  }

  List<Track> _mergeDownloadHistory(
    List<Track> current,
    List<Track> incoming,
  ) {
    final merged = current.toList(growable: true);
    for (final track in incoming) {
      final index = merged.indexWhere(
        (saved) => CatalogIdentity.matches(saved, track),
      );
      if (index < 0) {
        merged.add(track);
      } else {
        // Prefer the latest metadata and provider URL for one recording.
        merged[index] = track;
      }
    }
    return List<Track>.unmodifiable(merged);
  }

  Future<void> refreshDiscover() async {
    if (offlineMode) return;
    _discoverCancelToken?.cancel('A newer discovery request started');
    final cancelToken = CancelToken();
    _discoverCancelToken = cancelToken;
    final generation = ++_discoverGeneration;
    isLoadingDiscover = true;
    isLoadingMoreDiscover = false;
    hasMoreDiscover = true;
    discoverError = null;
    _discoverOffset = 0;
    _notifySafely();

    try {
      final page = await catalog.discover(page: 0, cancelToken: cancelToken);
      if (generation != _discoverGeneration) return;
      discoverTracks = page.tracks;
      sourceErrors = page.sourceErrors;
      sourceCounts = page.sourceCounts;
      _discoverOffset = 1;
      hasMoreDiscover = page.hasMore;
    } catch (error) {
      if (generation == _discoverGeneration) {
        discoverError = error.toString();
      }
    } finally {
      if (generation == _discoverGeneration) {
        isLoadingDiscover = false;
        if (identical(_discoverCancelToken, cancelToken)) {
          _discoverCancelToken = null;
        }
        _notifySafely();
      }
    }
  }

  Future<void> loadMoreDiscover() async {
    if (offlineMode || !hasMoreDiscover || isLoadingDiscover || isLoadingMoreDiscover) {
      return;
    }
    final generation = _discoverGeneration;
    final cancelToken = _discoverCancelToken ??= CancelToken();
    isLoadingMoreDiscover = true;
    discoverError = null;
    _notifySafely();

    try {
      final page = await catalog.discover(
        page: _discoverOffset,
        cancelToken: cancelToken,
      );
      if (generation != _discoverGeneration) return;
      discoverTracks = _mergeCatalogResults(discoverTracks, page.tracks);
      sourceErrors = page.sourceErrors;
      sourceCounts = page.sourceCounts;
      _discoverOffset++;
      hasMoreDiscover = page.hasMore;
    } catch (error) {
      if (generation == _discoverGeneration) {
        discoverError = error.toString();
      }
    } finally {
      if (generation == _discoverGeneration) {
        isLoadingMoreDiscover = false;
        if (identical(_discoverCancelToken, cancelToken)) {
          _discoverCancelToken = null;
        }
        _notifySafely();
      }
    }
  }

  Future<void> searchMusic(String query) => _startSearch(query);

  Future<void> searchByTag(String tag) => _startSearch(tag);

  Future<void> _startSearch(String query) async {
    _searchCancelToken?.cancel('A newer search started');
    _searchCancelToken = null;
    final normalized = query.trim();
    final generation = ++_searchGeneration;
    searchQuery = normalized;
    searchResults = [];
    _searchOffset = 0;
    hasMoreSearch = false;
    isLoadingMoreSearch = false;
    searchError = null;
    searchMoreError = null;

    if (offlineMode) {
      final localTracksById = <String, Track>{};
      for (final track in downloadedTracks) {
        localTracksById[track.id] = track;
      }
      final localTracks = localTracksById.values.toList(growable: false);
      final term = normalized.toLowerCase();
      searchResults = term.isEmpty
          ? localTracks
          : localTracks.where((track) {
              final searchable =
                  '${track.title} ${track.artist} ${track.album}'.toLowerCase();
              return searchable.contains(term);
            }).toList(growable: false);
      hasMoreSearch = false;
      isSearching = false;
      _notifySafely();
      return;
    }

    if (normalized.isEmpty) {
      isSearching = false;
      _notifySafely();
      return;
    }

    final cancelToken = CancelToken();
    _searchCancelToken = cancelToken;
    isSearching = true;
    _notifySafely();

    try {
      final page = await catalog.search(
        normalized,
        page: 0,
        cancelToken: cancelToken,
      );
      if (generation != _searchGeneration) return;
      searchResults = page.tracks;
      sourceErrors = page.sourceErrors;
      sourceCounts = page.sourceCounts;
      _searchOffset = 1;
      hasMoreSearch = page.hasMore;
      if (searchResults.isEmpty && page.sourceErrors.length >= 7) {
        searchError =
            'Music sources are unavailable. Check your connection or account setup.';
      }
    } catch (error) {
      if (generation == _searchGeneration) {
        searchError = error.toString();
      }
    } finally {
      if (generation == _searchGeneration) {
        isSearching = false;
        if (identical(_searchCancelToken, cancelToken)) {
          _searchCancelToken = null;
        }
        _notifySafely();
      }
    }
  }

  Future<void> loadMoreSearch() async {
    if (offlineMode || !hasMoreSearch || isSearching || isLoadingMoreSearch) {
      return;
    }
    final generation = _searchGeneration;
    final query = searchQuery;
    final cancelToken = _searchCancelToken ??= CancelToken();
    isLoadingMoreSearch = true;
    searchMoreError = null;
    _notifySafely();

    try {
      final page = await catalog.search(
        query,
        page: _searchOffset,
        cancelToken: cancelToken,
      );
      if (generation != _searchGeneration) return;
      searchResults = _mergeCatalogResults(searchResults, page.tracks);
      sourceErrors = page.sourceErrors;
      sourceCounts = page.sourceCounts;
      _searchOffset++;
      hasMoreSearch = page.hasMore;
    } catch (error) {
      if (generation == _searchGeneration) {
        searchMoreError = error.toString();
      }
    } finally {
      if (generation == _searchGeneration) {
        isLoadingMoreSearch = false;
        if (identical(_searchCancelToken, cancelToken)) {
          _searchCancelToken = null;
        }
        _notifySafely();
      }
    }
  }

  List<Track> _mergeCatalogResults(
    List<Track> current,
    List<Track> incoming,
  ) {
    // Pagination must retain alternatives already found on earlier pages.
    final byId = <String, Track>{};
    for (final track in [...current, ...incoming]) {
      byId[track.id] = track;
      for (final alternative in track.alternatives) {
        byId[alternative.id] = alternative;
      }
    }

    final groups = CatalogIdentity.group(byId.values.toList(growable: false));
    return groups.map((group) {
      final ranked = [...group]..sort(CatalogRanking.compare);
      final selected = ranked.first;
      final sources = ranked
          .expand((track) => [
                ...track.matchedSources,
                track.providerName,
              ])
          .where((source) => source.trim().isNotEmpty)
          .toSet()
          .toList(growable: false);
      final artwork = ranked
          .firstWhere(
            (track) => track.artworkUrl.trim().isNotEmpty,
            orElse: () => selected,
          )
          .artworkUrl;
      final album = ranked
          .firstWhere(
            (track) => track.album.trim().isNotEmpty,
            orElse: () => selected,
          )
          .album;
      final duration = ranked
          .firstWhere(
            (track) => track.durationMs > 0,
            orElse: () => selected,
          )
          .durationMs;
      final recordingId = ranked
          .firstWhere(
            (track) => track.recordingId.trim().isNotEmpty,
            orElse: () => selected,
          )
          .recordingId;
      final recordingMbid = ranked
          .firstWhere(
            (track) => track.recordingMbid.trim().isNotEmpty,
            orElse: () => selected,
          )
          .recordingMbid;
      return selected.copyWith(
        artworkUrl: selected.artworkUrl.trim().isEmpty
            ? artwork
            : selected.artworkUrl,
        album: selected.album.trim().isEmpty ? album : selected.album,
        durationMs: selected.durationMs > 0 ? selected.durationMs : duration,
        recordingId: selected.recordingId.trim().isEmpty
            ? recordingId
            : selected.recordingId,
        recordingMbid: selected.recordingMbid.trim().isEmpty
            ? recordingMbid
            : selected.recordingMbid,
        matchedSources: sources,
        alternatives: ranked.skip(1).toList(growable: false),
      );
    }).toList(growable: false);
  }

  Future<void> toggleFavorite(Track track) async {
    favoriteTracks = LibraryCollectionService.toggleFavorite(
      favoriteTracks,
      track,
    );
    await repository.saveFavorites(favoriteTracks);
    await syncCloudLibrary();
    _notifySafely();
  }

  bool isFavorite(Track track) =>
      LibraryCollectionService.isFavorite(favoriteTracks, track);

  Future<void> createPlaylist(String name, {Track? initialTrack}) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final playlist = MusicPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: normalized,
      tracks: initialTrack == null ? [] : [initialTrack],
    );
    playlists = [...playlists, playlist];
    await repository.savePlaylists(playlists);
    await syncCloudLibrary();
    _notifySafely();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final index = playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index < 0) return;
    final playlist = playlists[index];
    final updated = LibraryCollectionService.addTrackToPlaylist(
      playlist,
      track,
    );
    if (identical(updated, playlist)) return;
    playlists = [
      for (var i = 0; i < playlists.length; i++)
        if (i == index) updated else playlists[i],
    ];
    await repository.savePlaylists(playlists);
    await syncCloudLibrary();
    _notifySafely();
  }

  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId, {
    String? providerId,
  }) async {
    final index = playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index < 0) return;
    final playlist = playlists[index];
    final updated = LibraryCollectionService.removeTrackFromPlaylist(
      playlist,
      trackId,
      providerId: providerId,
    );
    if (identical(updated, playlist)) return;
    playlists = [
      for (var i = 0; i < playlists.length; i++)
        if (i == index) updated else playlists[i],
    ];
    await repository.savePlaylists(playlists);
    await syncCloudLibrary();
    _notifySafely();
  }

  /// Moves one exact provider entry without collapsing same-ID recordings.
  Future<void> moveTrackInPlaylist(
    String playlistId,
    Track track,
    Track relativeTrack,
  ) async {
    final playlistIndex =
        playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (playlistIndex < 0) return;

    final playlist = playlists[playlistIndex];
    final tracks = playlist.tracks;
    int indexOf(Track candidate) {
      final key = LibraryCollectionService.trackKey(candidate);
      return tracks.indexWhere(
        (item) => LibraryCollectionService.trackKey(item) == key,
      );
    }

    final trackIndex = indexOf(track);
    final targetIndex = indexOf(relativeTrack);
    if (trackIndex < 0 || targetIndex < 0 || trackIndex == targetIndex) return;

    final updated = playlist.moveTrack(
      fromIndex: trackIndex,
      toIndex: targetIndex,
    );
    playlists = [
      for (var i = 0; i < playlists.length; i++)
        if (i == playlistIndex) updated else playlists[i],
    ];
    await repository.savePlaylists(playlists);
    await syncCloudLibrary();
    _notifySafely();
  }

  Future<void> renamePlaylist(String playlistId, String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.length > 32) return;
    final index = playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index < 0) return;
    playlists = [
      for (var i = 0; i < playlists.length; i++)
        if (i == index) playlists[i].copyWith(name: normalized)
        else playlists[i],
    ];
    await repository.savePlaylists(playlists);
    await syncCloudLibrary();
    _notifySafely();
  }

  Future<void> removePlaylist(String playlistId) async {
    playlists = playlists.where((item) => item.id != playlistId).toList();
    await repository.savePlaylists(playlists);
    await syncCloudLibrary();
    _notifySafely();
  }

  /// Returns the app-managed local copy when the same recording has
  /// already been downloaded. The download must still point to a playable
  /// local file; stale database entries never outrank a network source.
  /// Chooses an AUREL-managed download before any online stream. Downloaded
  /// files stay inside AUREL and never become part of the device music index.
  List<Track> get _availableLocalTracks => downloadedTracks;

  bool _isTrustedDownload(Track track) => downloadedTracks.any(
        (saved) =>
            saved.id == track.id &&
            saved.localPath == track.localPath &&
            saved.isDownloaded &&
            saved.isLocal &&
            saved.canPlay,
      );

  Track _preferLocalCopy(Track track) {
    final local = LocalTrackPriority.findLocalCopy(
      track,
      _availableLocalTracks,
    );
    if (local != null) {
      return LocalTrackPriority.preferLocalCopy(
        track,
        _availableLocalTracks,
      );
    }
    if (track.isDownloaded) {
      return Track.fromJson(track.toJson());
    }
    return track;
  }

  bool hasLocalPlayableCopy(Track track) =>
      LocalTrackPriority.findLocalCopy(track, _availableLocalTracks) != null;

  bool hasDownloadedCopy(Track track) =>
      LocalTrackPriority.findLocalCopy(
        track,
        downloadedTracks.where((saved) => saved.isDownloaded),
      ) !=
      null;

  /// Whether this recording can actually start in the current mode.
  /// Online alternatives are never advertised as playable while offline.
  bool hasPlayableSource(Track track) {
    final localCopy = hasLocalPlayableCopy(track);
    if (offlineMode) return localCopy;
    return track.canPlay ||
        track.alternatives.any((alternative) => alternative.canPlay) ||
        localCopy;
  }

  Future<void> addToQueue(Track track) async {
    final selected = _preferLocalCopy(track);
    if (offlineMode && (!selected.isLocal || !selected.canPlay)) {
      throw const PlaybackException(
        'Only tracks downloaded inside AUREL can be queued in Offline mode.',
      );
    }
    await playback.addToQueue(await catalog.prepareTrack(selected));
  }

  Future<void> playNext(Track track) async {
    final selected = _preferLocalCopy(track);
    if (offlineMode && (!selected.isLocal || !selected.canPlay)) {
      throw const PlaybackException(
        'Only tracks downloaded inside AUREL can be played next in Offline mode.',
      );
    }
    await playback.playNext(await catalog.prepareTrack(selected));
  }

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final selectedTrack = _preferLocalCopy(track);
    if (offlineMode && (!selectedTrack.isLocal || !selectedTrack.canPlay)) {
      throw const PlaybackException(
        'Download this track inside AUREL before playing it in Offline mode.',
      );
    }
    final source = queue ??
        (selectedTrack.isDownloaded ? downloadedTracks : discoverTracks);

    // Substitute local copies throughout the queue while preserving one
    // canonical entry per recording and its visible queue identity.
    final sourceWithSelection = <Track>[];
    var selectionInserted = false;
    for (final item in source) {
      if (item.id == track.id || CatalogIdentity.matches(item, track)) {
        if (!selectionInserted) {
          sourceWithSelection.add(selectedTrack);
          selectionInserted = true;
        }
        continue;
      }
      sourceWithSelection.add(_preferLocalCopy(item));
    }
    if (!selectionInserted) {
      sourceWithSelection.insert(0, selectedTrack);
    }

    final tracks = offlineMode
        ? sourceWithSelection
            .where((item) => item.isLocal && item.canPlay)
            .toList(growable: false)
        : sourceWithSelection;
    final prepared = await catalog.prepareQueue(
      tracks,
      requiredTrackId: selectedTrack.id,
    );
    final selected = prepared.where((item) => item.id == selectedTrack.id);
    if (selected.isEmpty) {
      throw const PlaybackException(
        'This track has no authorized in-app playback source.',
      );
    }
    final playableTrack = selected.first;
    await playback.playTrack(playableTrack, prepared);
    await _recordRecentlyPlayed(playableTrack);
    _notifySafely();
  }

  Future<void> setOfflineMode(bool enabled) async {
    if (offlineMode == enabled) return;
    offlineMode = enabled;
    await repository.saveOfflineMode(enabled);

    if (enabled) {
      _discoverCancelToken?.cancel('Offline mode enabled');
      _searchCancelToken?.cancel('Offline mode enabled');
      _discoverCancelToken = null;
      _searchCancelToken = null;
      _discoverGeneration++;
      _searchGeneration++;
      isLoadingDiscover = false;
      isLoadingMoreDiscover = false;
      hasMoreDiscover = false;
      isSearching = false;
      isLoadingMoreSearch = false;
      hasMoreSearch = false;
      searchResults = [];
      searchError = null;
      searchMoreError = null;
      discoverError = null;

      // Switch the current online copy to its saved AUREL file when one is
      // available, preserving the current position and pause/play state.
      final current = playback.currentTrack;
      if (current != null) {
        final wasPlaying = playback.isPlaying;
        final position = playback.player.position;
        final localCopy = _preferLocalCopy(current);
        if (localCopy.isLocal && localCopy.canPlay) {
          if (!_isTrustedDownload(current) ||
              current.id != localCopy.id ||
              current.localPath != localCopy.localPath) {
            try {
              await playTrack(localCopy, queue: playback.queue);
              try {
                await playback.seek(position);
              } catch (_) {
                // The saved copy may have a slightly different duration.
              }
              if (!wasPlaying) await playback.player.pause();
            } catch (_) {
              await playback.player.stop();
              playback.queue = const [];
              playback.currentIndex = -1;
            }
          }
        } else if (!localCopy.isLocal || !localCopy.canPlay) {
          await playback.player.stop();
          playback.queue = const [];
          playback.currentIndex = -1;
        }
      }
    }

    _notifySafely();
    if (!enabled) {
      await refreshDiscover();
    }
  }

  Future<String?> downloadTrack(Track track) async {
    if (offlineMode) return 'Turn off Offline mode to download more music.';
    if (!track.hasDownloadableSource) {
      return 'Downloads are not enabled for this track.';
    }
    if (downloadedTracks.any((item) => item.id == track.id) ||
        hasLocalPlayableCopy(track)) {
      return 'This track is already in your downloads.';
    }
    if (downloadingIds.contains(track.id)) {
      return 'This track is already downloading.';
    }

    final token = CancelToken();
    _downloadTokens[track.id] = token;
    downloadingIds.add(track.id);
    downloadProgress[track.id] = 0;
    Track? saved;
    _notifySafely();

    try {
      final preparedTrack = await catalog.prepareTrackForDownload(track);
      saved = await downloads.download(
        preparedTrack,
        cancelToken: token,
        onProgress: (received, total) {
          if (total <= 0 || token.isCancelled) return;
          final next = (received / total).clamp(0.0, 1.0).toDouble();
          final previous = downloadProgress[track.id] ?? 0;
          if (next >= 1 || next - previous >= 0.03) {
            downloadProgress[track.id] = next;
            _notifySafely();
          }
        },
      );

      final updated = [...downloadedTracks, saved];
      await repository.saveDownloads(updated);
      downloadedTracks = updated;
      previouslyDownloadedTracks = _mergeDownloadHistory(
        previouslyDownloadedTracks,
        [saved],
      );
      await repository.saveDownloadHistory(previouslyDownloadedTracks);
      try {
        await syncCloudLibrary();
      } catch (error) {
        cloudSyncError = error.toString().replaceFirst('Exception: ', '');
      }
      return null;
    } catch (error) {
      if (saved != null) {
        try {
          await downloads.delete(saved);
        } catch (_) {
          // Keep the original error visible; a stale file can be cleaned up
          // by the next AUREL-managed download maintenance pass.
        }
      }
      return error.toString();
    } finally {
      _downloadTokens.remove(track.id);
      downloadingIds.remove(track.id);
      downloadProgress.remove(track.id);
      _notifySafely();
    }
  }

  void cancelDownload(String trackId) {
    final token = _downloadTokens[trackId];
    if (token != null && !token.isCancelled) {
      token.cancel('Cancelled by user');
    }
  }

  Future<void> removeDownload(Track track) async {
    final previous = downloadedTracks;
    final updated =
        previous.where((item) => item.id != track.id).toList(growable: false);
    if (updated.length == previous.length) return;

    await repository.saveDownloads(updated);
    downloadedTracks = updated;
    try {
      if (playback.currentTrack?.id == track.id) {
        await playback.removeCurrentTrackFromQueue();
      }
      await downloads.delete(track);
    } catch (_) {
      downloadedTracks = previous;
      await repository.saveDownloads(previous);
      rethrow;
    }
    _notifySafely();
  }

  Future<void> removeDownloadHistoryTrack(Track track) async {
    final key = CatalogIdentity.providerKeyOf(track);
    previouslyDownloadedTracks = previouslyDownloadedTracks
        .where((saved) => CatalogIdentity.providerKeyOf(saved) != key)
        .toList(growable: false);
    await repository.saveDownloadHistory(previouslyDownloadedTracks);
    await syncCloudLibrary();
    _notifySafely();
  }

  final Set<String> restoringDownloadIds = {};

  /// Rechecks a previous download against current catalogue permissions and
  /// refreshes expiring provider URLs before downloading again.
  Future<String?> redownloadPreviousTrack(Track previous) async {
    if (offlineMode) {
      return 'Turn off Offline mode before downloading this track again.';
    }
    if (restoringDownloadIds.contains(previous.id)) {
      return 'This download is already being restored.';
    }

    restoringDownloadIds.add(previous.id);
    _notifySafely();
    try {
      final query = '${previous.title} ${previous.artist}'.trim();
      final page = await catalog.search(query, page: 0);
      final candidates = page.tracks
          .where((candidate) => CatalogIdentity.matches(previous, candidate))
          .where((candidate) => candidate.hasDownloadableSource)
          .toList(growable: false);

      if (candidates.isEmpty) {
        return 'This recording no longer has a permitted AUREL download source.';
      }

      Object? lastError;
      for (final candidate in candidates) {
        final message = await downloadTrack(candidate);
        if (message == null) return null;
        lastError = message;
      }
      return lastError?.toString() ??
          'AUREL could not find a permitted download source for this recording.';
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    } finally {
      restoringDownloadIds.remove(previous.id);
      _notifySafely();
    }
  }

  bool get hasLyricsApiKey => lyrics.hasApiKey;

  Future<void> saveLyricsApiKey(String value) async {
    await lyrics.saveApiKey(value);
    lyricsError = null;
    currentLyrics = null;
    _notifySafely();
  }

  Future<void> clearLyricsApiKey() async {
    await lyrics.clearApiKey();
    _lyricsRequestGeneration++;
    currentLyrics = null;
    isLoadingLyrics = false;
    lyricsError = 'Add your Musixmatch API key in Profile to load licensed lyrics.';
    _notifySafely();
  }

  Future<void> saveJamendoClientId(String value) async {
    await jamendo.setClientId(value);
    catalog.clearCache();
    discoverError = null;
    await refreshDiscover();
  }

  void selectTab(int index) {
    selectedTab = index;
    _notifySafely();
  }

  @override
  void dispose() {
    _disposed = true;
    _discoverCancelToken?.cancel('AUREL is closing');
    _searchCancelToken?.cancel('AUREL is closing');
    for (final token in _downloadTokens.values) {
      if (!token.isCancelled) token.cancel('AUREL is closing');
    }
    playback.removeListener(_onPlaybackChanged);
    playback.dispose();
    super.dispose();
  }
}
