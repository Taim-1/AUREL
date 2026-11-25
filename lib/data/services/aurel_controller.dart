import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/lyrics_document.dart';
import '../models/music_playlist.dart';
import '../models/track.dart';
import '../repositories/library_repository.dart';
import 'aurel_account_service.dart';
import 'download_service.dart';
import 'jamendo_service.dart';
import 'lyrics_service.dart';
import 'playback_controller.dart';

class AurelController extends ChangeNotifier {
  AurelController({
    required this.repository,
    required this.jamendo,
    required this.downloads,
    required this.playback,
    required this.lyrics,
    required this.account,
  }) {
    playback.addListener(_onPlaybackChanged);
  }

  static const _pageSize = 30;

  void _onPlaybackChanged() {
    final trackId = playback.currentTrack?.id;
    if (trackId != _lyricsTrackId) {
      unawaited(loadLyricsForCurrentTrack());
    }
    notifyListeners();
  }

  Future<void> loadLyricsForCurrentTrack({bool forceRefresh = false}) async {
    final track = playback.currentTrack;
    if (track == null) {
      _lyricsRequestGeneration++;
      _lyricsTrackId = null;
      currentLyrics = null;
      isLoadingLyrics = false;
      lyricsError = null;
      notifyListeners();
      return;
    }
    if (!forceRefresh && _lyricsTrackId == track.id) return;

    final generation = ++_lyricsRequestGeneration;
    _lyricsTrackId = track.id;
    currentLyrics = null;
    lyricsError = null;
    isLoadingLyrics = true;
    notifyListeners();

    try {
      final document = await lyrics.fetchFor(
        track,
        forceRefresh: forceRefresh,
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
        notifyListeners();
      }
    }
  }

  final LibraryRepository repository;
  final JamendoService jamendo;
  final DownloadService downloads;
  final PlaybackController playback;
  final LyricsService lyrics;
  final AurelAccountService account;

  String? cloudSyncError;

  List<Track> discoverTracks = [];
  List<Track> searchResults = [];
  List<Track> favoriteTracks = [];
  List<Track> downloadedTracks = [];
  List<Track> recentlyPlayed = [];
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
  String? _activeTag;
  int _discoverOffset = 0;
  int _searchOffset = 0;
  int _discoverGeneration = 0;
  int _searchGeneration = 0;
  int selectedTab = 0;

  Future<void> initialize() async {
    await jamendo.initialize();
    await lyrics.initialize();
    favoriteTracks = await repository.loadFavorites();
    downloadedTracks = await repository.loadDownloads();
    recentlyPlayed = await repository.loadRecentlyPlayed();
    playlists = await repository.loadPlaylists();
    offlineMode = await repository.loadOfflineMode();
    if (account.isSignedIn) {
      await restoreCloudLibrary();
    }
    notifyListeners();
    if (!offlineMode) {
      await refreshDiscover();
    }
  }

  Future<void> restoreCloudLibrary() async {
    if (!account.isSignedIn) return;
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

      final mergedPlaylists = <String, MusicPlaylist>{
        for (final playlist in cloud.playlists) playlist.id: playlist,
        for (final playlist in playlists) playlist.id: playlist,
      };
      playlists = mergedPlaylists.values.toList(growable: false);

      await repository.saveFavorites(favoriteTracks);
      await repository.saveRecentlyPlayed(recentlyPlayed);
      await repository.savePlaylists(playlists);
      await syncCloudLibrary();
    } catch (error) {
      cloudSyncError = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> syncCloudLibrary() async {
    if (!account.isSignedIn) return;
    try {
      await account.saveCloudLibrary(
        favorites: favoriteTracks,
        playlists: playlists,
        recentlyPlayed: recentlyPlayed,
      );
      cloudSyncError = null;
    } catch (error) {
      cloudSyncError = error.toString().replaceFirst('Exception: ', '');
      rethrow;
    }
    notifyListeners();
  }

  void notifyAccountChanged() => notifyListeners();

  List<Track> _appendUnique(List<Track> current, List<Track> incoming) {
    final ids = current.map((track) => track.id).toSet();
    return [
      ...current,
      ...incoming.where((track) => ids.add(track.id)),
    ];
  }

  Future<void> refreshDiscover() async {
    if (offlineMode) return;
    final generation = ++_discoverGeneration;
    isLoadingDiscover = true;
    isLoadingMoreDiscover = false;
    hasMoreDiscover = true;
    discoverError = null;
    _discoverOffset = 0;
    notifyListeners();

    try {
      final page = await jamendo.popular(limit: _pageSize, offset: 0);
      if (generation != _discoverGeneration) return;
      discoverTracks = page;
      _discoverOffset = page.length;
      hasMoreDiscover = page.length == _pageSize;
    } catch (error) {
      if (generation == _discoverGeneration) {
        discoverError = error.toString();
      }
    } finally {
      if (generation == _discoverGeneration) {
        isLoadingDiscover = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreDiscover() async {
    if (offlineMode || !hasMoreDiscover || isLoadingDiscover || isLoadingMoreDiscover) {
      return;
    }
    final generation = _discoverGeneration;
    isLoadingMoreDiscover = true;
    discoverError = null;
    notifyListeners();

    try {
      final page = await jamendo.popular(
        limit: _pageSize,
        offset: _discoverOffset,
      );
      if (generation != _discoverGeneration) return;
      discoverTracks = _appendUnique(discoverTracks, page);
      _discoverOffset += page.length;
      hasMoreDiscover = page.length == _pageSize;
    } catch (error) {
      if (generation == _discoverGeneration) {
        discoverError = error.toString();
      }
    } finally {
      if (generation == _discoverGeneration) {
        isLoadingMoreDiscover = false;
        notifyListeners();
      }
    }
  }

  Future<void> searchMusic(String query) => _startSearch(query);

  Future<void> searchByTag(String tag) =>
      _startSearch(tag, tag: tag.trim());

  Future<void> _startSearch(String query, {String? tag}) async {
    final normalized = query.trim();
    final generation = ++_searchGeneration;
    _activeTag = tag;
    searchQuery = normalized;
    searchResults = [];
    _searchOffset = 0;
    hasMoreSearch = false;
    isLoadingMoreSearch = false;
    searchError = null;
    searchMoreError = null;

    if (offlineMode) {
      final term = normalized.toLowerCase();
      searchResults = term.isEmpty
          ? List<Track>.of(downloadedTracks)
          : downloadedTracks.where((track) {
              final searchable =
                  '${track.title} ${track.artist} ${track.album}'.toLowerCase();
              return searchable.contains(term);
            }).toList(growable: false);
      hasMoreSearch = false;
      isSearching = false;
      notifyListeners();
      return;
    }

    if (normalized.isEmpty) {
      isSearching = false;
      notifyListeners();
      return;
    }

    isSearching = true;
    notifyListeners();

    try {
      final page = tag == null
          ? await jamendo.search(normalized, limit: _pageSize, offset: 0)
          : await jamendo.byTag(tag, limit: _pageSize, offset: 0);
      if (generation != _searchGeneration) return;
      searchResults = page;
      _searchOffset = page.length;
      hasMoreSearch = page.length == _pageSize;
    } catch (error) {
      if (generation == _searchGeneration) {
        searchError = error.toString();
      }
    } finally {
      if (generation == _searchGeneration) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreSearch() async {
    if (offlineMode || !hasMoreSearch || isSearching || isLoadingMoreSearch) {
      return;
    }
    final generation = _searchGeneration;
    final query = searchQuery;
    final tag = _activeTag;
    isLoadingMoreSearch = true;
    searchMoreError = null;
    notifyListeners();

    try {
      final page = tag == null
          ? await jamendo.search(
              query,
              limit: _pageSize,
              offset: _searchOffset,
            )
          : await jamendo.byTag(
              tag,
              limit: _pageSize,
              offset: _searchOffset,
            );
      if (generation != _searchGeneration) return;
      searchResults = _appendUnique(searchResults, page);
      _searchOffset += page.length;
      hasMoreSearch = page.length == _pageSize;
    } catch (error) {
      if (generation == _searchGeneration) {
        searchMoreError = error.toString();
      }
    } finally {
      if (generation == _searchGeneration) {
        isLoadingMoreSearch = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleFavorite(Track track) async {
    final exists = favoriteTracks.any((item) => item.id == track.id);
    if (exists) {
      favoriteTracks =
          favoriteTracks.where((item) => item.id != track.id).toList();
    } else {
      favoriteTracks = [...favoriteTracks, track];
    }
    await repository.saveFavorites(favoriteTracks);
    await syncCloudLibrary();
    notifyListeners();
  }

  bool isFavorite(Track track) =>
      favoriteTracks.any((item) => item.id == track.id);

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
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final index = playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index < 0) return;
    final playlist = playlists[index];
    if (playlist.tracks.any((item) => item.id == track.id)) return;
    final updated = playlist.copyWith(tracks: [...playlist.tracks, track]);
    playlists = [
      for (var i = 0; i < playlists.length; i++)
        if (i == index) updated else playlists[i],
    ];
    await repository.savePlaylists(playlists);
    await syncCloudLibrary();
    notifyListeners();
  }

  Future<void> removePlaylist(String playlistId) async {
    playlists = playlists.where((item) => item.id != playlistId).toList();
    await repository.savePlaylists(playlists);
    await syncCloudLibrary();
    notifyListeners();
  }

  Future<void> addToQueue(Track track) async {
    if (offlineMode && !track.isDownloaded) {
      throw const PlaybackException(
        'Only tracks saved inside AUREL can be queued in Offline mode.',
      );
    }
    await playback.addToQueue(track);
  }

  Future<void> playNext(Track track) async {
    if (offlineMode && !track.isDownloaded) {
      throw const PlaybackException(
        'Only tracks saved inside AUREL can be played next in Offline mode.',
      );
    }
    await playback.playNext(track);
  }

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    if (offlineMode && !track.isDownloaded) {
      throw const PlaybackException(
        'This track is not saved for offline listening yet.',
      );
    }
    final source = queue ??
        (track.isDownloaded ? downloadedTracks : discoverTracks);
    final tracks = offlineMode
        ? source.where((item) => item.isDownloaded).toList(growable: false)
        : source;
    await playback.playTrack(track, tracks);

    recentlyPlayed = [
      track,
      ...recentlyPlayed.where((item) => item.id != track.id),
    ].take(100).toList(growable: false);
    await repository.saveRecentlyPlayed(recentlyPlayed);
    await syncCloudLibrary();
    notifyListeners();
  }

  Future<void> setOfflineMode(bool enabled) async {
    if (offlineMode == enabled) return;
    offlineMode = enabled;
    await repository.saveOfflineMode(enabled);

    if (enabled) {
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

      // Never leave an online stream playing after entering offline mode.
      if (playback.currentTrack?.isDownloaded != true) {
        await playback.player.stop();
        playback.queue = const [];
        playback.currentIndex = -1;
      }
    }

    notifyListeners();
    if (!enabled) {
      await refreshDiscover();
    }
  }

  Future<String?> downloadTrack(Track track) async {
    if (offlineMode) return 'Turn off Offline mode to download more music.';
    if (!track.downloadAllowed) {
      return 'Downloads are not enabled for this track.';
    }
    if (downloadedTracks.any((item) => item.id == track.id)) {
      return 'This track is already in your downloads.';
    }
    if (downloadingIds.contains(track.id)) {
      return 'This track is already downloading.';
    }

    final token = CancelToken();
    _downloadTokens[track.id] = token;
    downloadingIds.add(track.id);
    downloadProgress[track.id] = 0;
    notifyListeners();

    try {
      final saved = await downloads.download(
        track,
        cancelToken: token,
        onProgress: (received, total) {
          if (total <= 0 || token.isCancelled) return;
          final next = (received / total).clamp(0.0, 1.0).toDouble();
          final previous = downloadProgress[track.id] ?? 0;
          if (next >= 1 || next - previous >= 0.03) {
            downloadProgress[track.id] = next;
            notifyListeners();
          }
        },
      );

      downloadedTracks = [...downloadedTracks, saved];
      await repository.saveDownloads(downloadedTracks);
      return null;
    } catch (error) {
      return error.toString();
    } finally {
      _downloadTokens.remove(track.id);
      downloadingIds.remove(track.id);
      downloadProgress.remove(track.id);
      notifyListeners();
    }
  }

  void cancelDownload(String trackId) {
    final token = _downloadTokens[trackId];
    if (token != null && !token.isCancelled) {
      token.cancel('Cancelled by user');
    }
  }

  Future<void> removeDownload(Track track) async {
    await downloads.delete(track);
    downloadedTracks =
        downloadedTracks.where((item) => item.id != track.id).toList();
    await repository.saveDownloads(downloadedTracks);
    if (playback.currentTrack?.id == track.id) {
      await playback.player.stop();
    }
    notifyListeners();
  }

  bool get hasLyricsApiKey => lyrics.hasApiKey;

  Future<void> saveLyricsApiKey(String value) async {
    await lyrics.saveApiKey(value);
    lyricsError = null;
    currentLyrics = null;
    notifyListeners();
  }

  Future<void> clearLyricsApiKey() async {
    await lyrics.clearApiKey();
    _lyricsRequestGeneration++;
    currentLyrics = null;
    isLoadingLyrics = false;
    lyricsError = 'Add your Musixmatch API key in Profile to load licensed lyrics.';
    notifyListeners();
  }

  Future<void> saveJamendoClientId(String value) async {
    await jamendo.setClientId(value);
    discoverError = null;
    await refreshDiscover();
  }

  void selectTab(int index) {
    selectedTab = index;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final token in _downloadTokens.values) {
      if (!token.isCancelled) token.cancel('AUREL is closing');
    }
    playback.removeListener(_onPlaybackChanged);
    playback.dispose();
    super.dispose();
  }
}
