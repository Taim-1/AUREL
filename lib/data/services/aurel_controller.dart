import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../repositories/library_repository.dart';
import 'device_library_service.dart';
import 'download_service.dart';
import 'jamendo_service.dart';
import 'playback_controller.dart';

class AurelController extends ChangeNotifier {
  AurelController({
    required this.repository,
    required this.jamendo,
    required this.deviceLibrary,
    required this.downloads,
    required this.playback,
  }) {
    playback.addListener(notifyListeners);
  }

  final LibraryRepository repository;
  final JamendoService jamendo;
  final DeviceLibraryService deviceLibrary;
  final DownloadService downloads;
  final PlaybackController playback;

  List<Track> discoverTracks = [];
  List<Track> searchResults = [];
  List<Track> deviceTracks = [];
  List<Track> favoriteTracks = [];
  List<Track> downloadedTracks = [];
  final Set<String> downloadingIds = {};
  bool isLoadingDiscover = false;
  bool isSearching = false;
  bool isScanningDevice = false;
  String? discoverError;
  String? searchError;
  String? deviceError;
  String searchQuery = '';
  int selectedTab = 0;

  Future<void> initialize() async {
    await jamendo.initialize();
    favoriteTracks = await repository.loadFavorites();
    downloadedTracks = await repository.loadDownloads();
    notifyListeners();
    await refreshDiscover();
  }

  Future<void> refreshDiscover() async {
    isLoadingDiscover = true;
    discoverError = null;
    notifyListeners();
    try {
      discoverTracks = await jamendo.popular();
    } catch (error) {
      discoverError = error.toString();
    } finally {
      isLoadingDiscover = false;
      notifyListeners();
    }
  }

  Future<void> searchMusic(String query) async {
    searchQuery = query.trim();
    if (searchQuery.isEmpty) {
      searchResults = [];
      searchError = null;
      notifyListeners();
      return;
    }
    isSearching = true;
    searchError = null;
    notifyListeners();
    try {
      searchResults = await jamendo.search(searchQuery);
    } catch (error) {
      searchError = error.toString();
    } finally {
      isSearching = false;
      notifyListeners();
    }
  }

  Future<void> scanDevice() async {
    isScanningDevice = true;
    deviceError = null;
    notifyListeners();
    try {
      deviceTracks = await deviceLibrary.scan();
    } catch (error) {
      deviceError = error.toString();
    } finally {
      isScanningDevice = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(Track track) async {
    final exists = favoriteTracks.any((item) => item.id == track.id);
    if (exists) {
      favoriteTracks = favoriteTracks.where((item) => item.id != track.id).toList();
    } else {
      favoriteTracks = [...favoriteTracks, track];
    }
    await repository.saveFavorites(favoriteTracks);
    notifyListeners();
  }

  bool isFavorite(Track track) =>
      favoriteTracks.any((item) => item.id == track.id);

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final tracks = queue ??
        (track.isLocal
            ? (track.isDownloaded ? downloadedTracks : deviceTracks)
            : discoverTracks);
    try {
      await playback.playTrack(track, tracks);
    } catch (_) {
      rethrow;
    }
  }

  Future<String?> downloadTrack(Track track) async {
    if (!track.downloadAllowed) {
      return 'Downloads are not enabled for this track.';
    }
    if (downloadedTracks.any((item) => item.id == track.id)) {
      return 'This track is already in your downloads.';
    }

    downloadingIds.add(track.id);
    notifyListeners();
    try {
      final saved = await downloads.download(track);
      downloadedTracks = [...downloadedTracks, saved];
      await repository.saveDownloads(downloadedTracks);
      return null;
    } catch (error) {
      return error.toString();
    } finally {
      downloadingIds.remove(track.id);
      notifyListeners();
    }
  }

  Future<void> removeDownload(Track track) async {
    await downloads.delete(track);
    downloadedTracks = downloadedTracks.where((item) => item.id != track.id).toList();
    await repository.saveDownloads(downloadedTracks);
    if (playback.currentTrack?.id == track.id) {
      await playback.player.stop();
    }
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
    playback.removeListener(notifyListeners);
    playback.dispose();
    super.dispose();
  }
}
