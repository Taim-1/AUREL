import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';

class PlaybackController extends ChangeNotifier {
  PlaybackController() {
    player.playerStateStream.listen((_) => notifyListeners());
    player.shuffleModeEnabledStream.listen((_) => notifyListeners());
    player.loopModeStream.listen((_) => notifyListeners());
    player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < queue.length) {
        currentIndex = index;
        notifyListeners();
      }
    });
  }

  final AudioPlayer player = AudioPlayer();
  List<Track> queue = const [];
  int currentIndex = -1;

  bool get isPlaying => player.playing;
  bool get isShuffleEnabled => player.shuffleModeEnabled;
  bool get isRepeatOne => player.loopMode == LoopMode.one;
  bool get isRepeatAll => player.loopMode == LoopMode.all;
  String get repeatLabel {
    if (isRepeatOne) return 'Repeat one';
    if (isRepeatAll) return 'Repeat all';
    return 'Repeat off';
  }

  Track? get currentTrack =>
      currentIndex >= 0 && currentIndex < queue.length
          ? queue[currentIndex]
          : null;

  Future<void> playTrack(Track track, List<Track> sourceQueue) async {
    final tracks = sourceQueue.isEmpty ? <Track>[track] : List<Track>.of(sourceQueue);
    final index = tracks.indexWhere((item) => item.id == track.id);
    if (index < 0) tracks.insert(0, track);

    queue = tracks;
    currentIndex = index < 0 ? 0 : index;

    final sources = tracks.map(_audioSource).toList(growable: false);
    try {
      await player.setAudioSources(sources, initialIndex: currentIndex);
      unawaited(player.play());
      notifyListeners();
    } on PlayerException catch (error) {
      throw PlaybackException(
        error.message ?? 'AUREL could not play this audio source.',
      );
    } on PlayerInterruptedException {
      throw const PlaybackException('Playback was interrupted. Try again.');
    }
  }

  AudioSource _audioSource(Track track) {
    final uri = Uri.parse(track.playbackUri);
    final artUri = Uri.tryParse(track.artworkUrl);
    return AudioSource.uri(
      uri,
      tag: MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        artUri: artUri != null && artUri.hasScheme ? artUri : null,
        duration: Duration(milliseconds: track.durationMs),
      ),
    );
  }

  Future<void> togglePlayback() async {
    if (player.playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    }
  }

  Future<void> toggleShuffle() async {
    final enable = !player.shuffleModeEnabled;
    if (enable) {
      await player.shuffle();
    }
    await player.setShuffleModeEnabled(enable);
    notifyListeners();
  }

  Future<void> cycleRepeatMode() async {
    final nextMode = switch (player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await player.setLoopMode(nextMode);
    notifyListeners();
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
    }
  }

  Future<void> previous() async {
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
    } else if (player.hasPrevious) {
      await player.seekToPrevious();
    }
  }

  Future<void> seek(Duration position) => player.seek(position);

  @override
  void dispose() {
    unawaited(player.dispose());
    super.dispose();
  }
}

class PlaybackException implements Exception {
  const PlaybackException(this.message);
  final String message;

  @override
  String toString() => message;
}
