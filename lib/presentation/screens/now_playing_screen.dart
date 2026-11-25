import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/lyrics_sheet.dart';
import '../widgets/playback_settings_sheet.dart';
import '../widgets/up_next_sheet.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  void _showLyrics(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AurelColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => const LyricsSheet(),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AurelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => const UpNextSheet(),
    );
  }

  void _showPlaybackSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AurelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => const PlaybackSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final playback = controller.playback;
    final track = playback.currentTrack;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Choose a track to start listening.'),
        ),
      );
    }

    final duration = Duration(milliseconds: track.durationMs);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final artworkSize = (screenWidth * 0.70).clamp(220.0, 310.0).toDouble();

    return Scaffold(
      backgroundColor: AurelColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Collapse player',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
        ),
        title: const Column(
          children: [
            Text(
              'NOW PLAYING',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.2,
                color: AurelColors.champagne,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text('AUREL', style: TextStyle(fontSize: 13)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Up next',
            onPressed: () => _showQueue(context),
            icon: const Icon(
              Icons.queue_music_rounded,
              color: AurelColors.champagne,
            ),
          ),
          IconButton(
            tooltip: 'Sound and playback settings',
            onPressed: () => _showPlaybackSettings(context),
            icon: const Icon(
              Icons.tune_rounded,
              color: AurelColors.champagne,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(23, 8, 23, 26),
          child: Column(
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(
                      color: AurelColors.champagne.withValues(alpha: 0.20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AurelColors.champagne.withValues(alpha: 0.09),
                        blurRadius: 36,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: AlbumArt(
                    imageUrl: track.artworkUrl,
                    size: artworkSize,
                    radius: 21,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            height: 1.16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.45,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AurelColors.muted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: controller.isFavorite(track)
                        ? 'Remove from favourites'
                        : 'Add to favourites',
                    onPressed: () =>
                        context.read<AurelController>().toggleFavorite(track),
                    icon: Icon(
                      controller.isFavorite(track)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: controller.isFavorite(track)
                          ? const Color(0xFFE58A9C)
                          : AurelColors.champagneLight,
                      size: 27,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              StreamBuilder<Duration>(
                stream: playback.player.positionStream,
                initialData: playback.player.position,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final totalMs = (duration.inMilliseconds > 0
                          ? duration.inMilliseconds
                          : 1)
                      .toDouble();
                  final currentMs = position.inMilliseconds
                      .clamp(0, totalMs.toInt())
                      .toDouble();

                  return Column(
                    children: [
                      Slider(
                        value: currentMs,
                        min: 0,
                        max: totalMs,
                        onChanged: (value) => playback.seek(
                          Duration(milliseconds: value.round()),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _format(position),
                              style: const TextStyle(
                                color: AurelColors.muted,
                                fontSize: 11,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              _format(duration),
                              style: const TextStyle(
                                color: AurelColors.muted,
                                fontSize: 11,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: playback.isShuffleEnabled
                        ? 'Turn shuffle off'
                        : 'Turn shuffle on',
                    onPressed: () => playback.toggleShuffle(),
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: playback.isShuffleEnabled
                          ? AurelColors.champagneLight
                          : AurelColors.muted,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous track',
                    onPressed: () => playback.previous(),
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      color: Colors.white,
                      size: 31,
                    ),
                  ),
                  InkWell(
                    onTap: () => playback.togglePlayback(),
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AurelColors.champagneLight,
                            AurelColors.champagne,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33D9BC91),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        playback.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AurelColors.background,
                        size: 37,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next track',
                    onPressed: () => playback.next(),
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                      size: 31,
                    ),
                  ),
                  IconButton(
                    tooltip: playback.repeatLabel,
                    onPressed: () => playback.cycleRepeatMode(),
                    icon: Icon(
                      playback.isRepeatOne
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: playback.isRepeatAll || playback.isRepeatOne
                          ? AurelColors.champagneLight
                          : AurelColors.muted,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Material(
                color: AurelColors.surfaceRaised,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: InkWell(
                  onTap: () => _showLyrics(context),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lyrics_rounded,
                          color: AurelColors.champagneLight,
                          size: 19,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lyrics',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AurelColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'FEEL THE MUSIC',
                style: TextStyle(
                  color: AurelColors.champagne,
                  letterSpacing: 3,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
