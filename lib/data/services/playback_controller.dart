import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';

enum AurelEqualizerPreset {
  balanced,
  bass,
  vocal,
  treble,
  acoustic,
}

class PlaybackController extends ChangeNotifier {
  bool _disposed = false;

  void _notifySafely() {
    if (!_disposed) super.notifyListeners();
  }

  PlaybackController() {
    _subscriptions.addAll([
      player.errorStream.listen((error) {
        unawaited(_recoverFromSourceError(error).then<void>((_) {}));
      }),
      player.playerStateStream.listen((_) => _notifySafely()),
      player.shuffleModeEnabledStream.listen((_) => _notifySafely()),
      player.loopModeStream.listen((_) => _notifySafely()),
      player.speedStream.listen((_) => _notifySafely()),
      equalizer.enabledStream.listen((_) => _notifySafely()),
      player.currentIndexStream.listen((index) {
        if (index != null && index >= 0 && index < queue.length) {
          currentIndex = index;
          _notifySafely();
        }
      }),
    ]);
  }

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final AndroidEqualizer equalizer = AndroidEqualizer();
  late final AudioPlayer player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
    handleInterruptions: true,
    useLazyPreparation: true,
    // AUREL handles provider fallback itself so just_audio must not skip to
    // the next visible song when one source fails.
    maxSkipsOnError: 0,
  );

  List<Track> queue = const [];
  int currentIndex = -1;
  Future<Track> Function(Track)? _fallbackResolver;
  Future<bool>? _activeRecovery;
  final Set<String> _attemptedFallbackIds = {};

  void setFallbackResolver(Future<Track> Function(Track) resolver) {
    _fallbackResolver = resolver;
  }

  Timer? _sleepTimer;
  DateTime? _sleepDeadline;
  Duration? sleepTimerRemaining;

  bool get isPlaying => player.playing;
  bool get isShuffleEnabled => player.shuffleModeEnabled;
  bool get isRepeatOne => player.loopMode == LoopMode.one;
  bool get isRepeatAll => player.loopMode == LoopMode.all;
  bool get isEqualizerEnabled => equalizer.enabled;
  double get speed => player.speed;

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
    final tracks =
        sourceQueue.isEmpty ? <Track>[track] : List<Track>.of(sourceQueue);
    final index = tracks.indexWhere((item) => item.id == track.id);
    if (index < 0) tracks.insert(0, track);

    queue = tracks;
    currentIndex = index < 0 ? 0 : index;
    _attemptedFallbackIds.clear();
    final sources = tracks.map(_audioSource).toList(growable: false);

    try {
      await player.setAudioSources(
        sources,
        initialIndex: currentIndex,
      );
      unawaited(player.play());
      _notifySafely();
    } on PlayerException catch (error) {
      final recovered = await _recoverFromSourceError(error);
      if (recovered) return;
      throw PlaybackException(
        error.message ?? 'AUREL could not play this audio source.',
      );
    } on PlayerInterruptedException {
      throw const PlaybackException('Playback was interrupted. Try again.');
    }
  }

  Future<bool> _recoverFromSourceError(PlayerException error) async {
    final active = _activeRecovery;
    if (active != null) return active;

    final operation = _performSourceRecovery(error);
    _activeRecovery = operation;
    try {
      return await operation;
    } finally {
      if (identical(_activeRecovery, operation)) {
        _activeRecovery = null;
      }
    }
  }

  Future<bool> _performSourceRecovery(PlayerException error) async {
    if (queue.isEmpty) return false;
    final index = error.index ?? currentIndex;
    if (index != currentIndex || index < 0 || index >= queue.length) {
      return false;
    }

    final failed = queue[index];
    final resolver = _fallbackResolver;
    if (resolver == null) return false;

    final candidates = failed.alternatives.where(
      (candidate) =>
          candidate.canPlay && !_attemptedFallbackIds.contains(candidate.id),
    );
    if (candidates.isEmpty) return false;

    for (final candidate in candidates) {
      _attemptedFallbackIds.add(candidate.id);
      try {
        final prepared = await resolver(candidate);
        // The resolver may have tried and consumed more than one
        // underlying provider while preparing this candidate. Preserve its
        // remaining list rather than reintroducing an already-failed source.
        final replacement = prepared.copyWith(
          id: failed.id,
          alternatives: prepared.alternatives,
        );
        final updatedQueue = List<Track>.of(queue);
        updatedQueue[index] = replacement;

        // Replace only the failed source while retaining the visible queue.
        // The fallback is the same recording/version, not a different song.
        await player.setAudioSources(
          updatedQueue.map(_audioSource).toList(growable: false),
          initialIndex: index,
        );
        queue = updatedQueue;
        currentIndex = index;
        unawaited(player.play());
        _notifySafely();
        return true;
      } catch (_) {
        // Try the next same-recording source in the agreed priority order.
      }
    }
    return false;
  }

  /// Appends a track to the active queue without interrupting playback.
  Future<void> addToQueue(Track track) async {
    if (queue.isEmpty || currentIndex < 0) {
      await playTrack(track, [track]);
      return;
    }

    await player.addAudioSource(_audioSource(track));
    queue = [...queue, track];
    _notifySafely();
  }

  /// Places a track immediately after the currently playing item.
  /// Queue reordering is disabled while shuffle is active because the visible
  /// sequence and the original playlist indices are different in that mode.
  Future<void> playNext(Track track) async {
    if (isShuffleEnabled) {
      throw const PlaybackException(
        'Turn off shuffle before choosing a track to play next.',
      );
    }
    if (queue.isEmpty || currentIndex < 0) {
      await playTrack(track, [track]);
      return;
    }

    final insertionIndex = currentIndex + 1;
    await player.insertAudioSource(insertionIndex, _audioSource(track));
    queue = [
      ...queue.take(insertionIndex),
      track,
      ...queue.skip(insertionIndex),
    ];
    _notifySafely();
  }

  /// Removes an upcoming item. The current and already played items stay put.
  Future<void> removeCurrentTrackFromQueue() async {
    if (currentIndex < 0 || currentIndex >= queue.length) {
      await player.stop();
      return;
    }
    final index = currentIndex;
    await player.stop();
    await player.removeAudioSourceAt(index);
    queue = [
      ...queue.take(index),
      ...queue.skip(index + 1),
    ];
    currentIndex = player.currentIndex ?? -1;
    _notifySafely();
  }

  Future<void> removeUpcoming(int index) async {
    if (isShuffleEnabled) {
      throw const PlaybackException(
        'Turn off shuffle before editing the queue.',
      );
    }
    if (index <= currentIndex || index < 0 || index >= queue.length) return;

    await player.removeAudioSourceAt(index);
    queue = [
      ...queue.take(index),
      ...queue.skip(index + 1),
    ];
    _notifySafely();
  }

  /// Moves an upcoming item without allowing the current item to be displaced.
  Future<void> moveUpcoming(int oldIndex, int newIndex) async {
    if (isShuffleEnabled ||
        oldIndex <= currentIndex ||
        newIndex <= currentIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= queue.length ||
        newIndex >= queue.length ||
        oldIndex == newIndex) {
      return;
    }

    await player.moveAudioSource(oldIndex, newIndex);
    final updated = List<Track>.of(queue);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    queue = updated;
    _notifySafely();
  }

  /// Clears only the upcoming items, preserving the current track.
  Future<void> clearUpcoming() async {
    final firstUpcoming = currentIndex + 1;
    if (firstUpcoming < 0 || firstUpcoming >= queue.length) return;

    await player.removeAudioSourceRange(firstUpcoming, queue.length);
    queue = queue.take(firstUpcoming).toList(growable: false);
    _notifySafely();
  }

  AudioSource _audioSource(Track track) {
    final uri = Uri.parse(track.playbackUri);
    final artUri = Uri.tryParse(track.artworkUrl);
    return AudioSource.uri(
      uri,
      headers: track.playbackHeaders.isEmpty ? null : track.playbackHeaders,
      tag: MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        artUri: artUri != null &&
                (artUri.scheme == 'https' || artUri.scheme == 'content')
            ? artUri
            : null,
        artHeaders: const {'Accept': 'image/*'},
        displayTitle: track.title,
        displaySubtitle: track.artist,
        displayDescription:
            track.album.isEmpty ? 'AUREL · Feel the Music' : track.album,
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
    if (enable) await player.shuffle();
    await player.setShuffleModeEnabled(enable);
    _notifySafely();
  }

  Future<void> cycleRepeatMode() async {
    final nextMode = switch (player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await player.setLoopMode(nextMode);
    _notifySafely();
  }

  Future<void> setSpeed(double value) async {
    final normalized = value.clamp(0.5, 2.0).toDouble();
    await player.setSpeed(normalized);
    _notifySafely();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDeadline = null;
    sleepTimerRemaining = null;

    if (duration == null || duration <= Duration.zero) {
      _notifySafely();
      return;
    }

    _sleepDeadline = DateTime.now().add(duration);
    sleepTimerRemaining = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final deadline = _sleepDeadline;
      if (deadline == null) {
        timer.cancel();
        return;
      }

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        timer.cancel();
        _sleepTimer = null;
        _sleepDeadline = null;
        sleepTimerRemaining = null;
        unawaited(player.pause());
      } else {
        sleepTimerRemaining = Duration(seconds: remaining.inSeconds);
      }
      _notifySafely();
    });
    _notifySafely();
  }

  Future<void> toggleEqualizer() async {
    await equalizer.setEnabled(!equalizer.enabled);
    _notifySafely();
  }

  Future<AndroidEqualizerParameters> loadEqualizerParameters() =>
      equalizer.parameters;

  Future<void> setEqualizerBand(int index, double gain) async {
    final parameters = await equalizer.parameters;
    if (index < 0 || index >= parameters.bands.length) return;
    final value =
        gain.clamp(parameters.minDecibels, parameters.maxDecibels).toDouble();
    await parameters.bands[index].setGain(value);
    _notifySafely();
  }

  Future<void> applyEqualizerPreset(AurelEqualizerPreset preset) async {
    final parameters = await equalizer.parameters;
    for (final band in parameters.bands) {
      final frequency = band.centerFrequency;
      final double gain = switch (preset) {
        AurelEqualizerPreset.balanced => 0,
        AurelEqualizerPreset.bass => frequency < 160
            ? 4.0
            : frequency < 500
                ? 2.0
                : frequency < 2000
                    ? 0
                    : -1.0,
        AurelEqualizerPreset.vocal =>
          frequency >= 250 && frequency <= 4000 ? 2.5 : -1.0,
        AurelEqualizerPreset.treble =>
          frequency >= 4000 ? 3.0 : frequency < 160 ? -1.5 : 0,
        AurelEqualizerPreset.acoustic =>
          frequency >= 250 && frequency <= 8000
              ? 1.5
              : frequency < 160
                  ? 1.0
                  : 0,
      };
      final normalized =
          gain.clamp(parameters.minDecibels, parameters.maxDecibels).toDouble();
      await band.setGain(normalized);
    }
    _notifySafely();
  }

  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= queue.length) return;
    await player.seek(Duration.zero, index: index);
    if (!player.playing) unawaited(player.play());
  }

  Future<void> next() async {
    if (player.hasNext) await player.seekToNext();
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
    _disposed = true;
    _sleepTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
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
