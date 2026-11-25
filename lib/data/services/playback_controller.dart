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
  PlaybackController() {
    player.playerStateStream.listen((_) => notifyListeners());
    player.shuffleModeEnabledStream.listen((_) => notifyListeners());
    player.loopModeStream.listen((_) => notifyListeners());
    player.speedStream.listen((_) => notifyListeners());
    equalizer.enabledStream.listen((_) => notifyListeners());
    player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < queue.length) {
        currentIndex = index;
        notifyListeners();
      }
    });
  }

  final AndroidEqualizer equalizer = AndroidEqualizer();
  late final AudioPlayer player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
    useLazyPreparation: true,
    maxSkipsOnError: 2,
  );

  List<Track> queue = const [];
  int currentIndex = -1;

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
    final sources = tracks.map(_audioSource).toList(growable: false);

    try {
      await player.setAudioSources(
        sources,
        initialIndex: currentIndex,
      );
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
    if (enable) await player.shuffle();
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

  Future<void> setSpeed(double value) async {
    final normalized = value.clamp(0.5, 2.0).toDouble();
    await player.setSpeed(normalized);
    notifyListeners();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDeadline = null;
    sleepTimerRemaining = null;

    if (duration == null || duration <= Duration.zero) {
      notifyListeners();
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
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> toggleEqualizer() async {
    await equalizer.setEnabled(!equalizer.enabled);
    notifyListeners();
  }

  Future<AndroidEqualizerParameters> loadEqualizerParameters() =>
      equalizer.parameters;

  Future<void> setEqualizerBand(int index, double gain) async {
    final parameters = await equalizer.parameters;
    if (index < 0 || index >= parameters.bands.length) return;
    final value =
        gain.clamp(parameters.minDecibels, parameters.maxDecibels).toDouble();
    await parameters.bands[index].setGain(value);
    notifyListeners();
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
    notifyListeners();
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
    _sleepTimer?.cancel();
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
