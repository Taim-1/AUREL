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

    return Scaffold(
      backgroundColor: AurelColors.background,
      appBar: AppBar(
        leading: IconButton(
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
            tooltip: 'Sound and playback settings',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AurelColors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              builder: (_) => const PlaybackSettingsSheet(),
            ),
            icon: const Icon(
              Icons.tune_rounded,
              color: AurelColors.champagne,
            ),
          ),
          IconButton(
            tooltip: controller.isFavorite(track)
                ? 'Remove from favourites'
                : 'Add to favourites',
            onPressed: () => context.read<AurelController>().toggleFavorite(track),
            icon: Icon(
              controller.isFavorite(track)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: controller.isFavorite(track)
                  ? const Color(0xFFE58A9C)
                  : Colors.white,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 8, 25, 26),
          child: Column(
            children: [
              const Spacer(),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AurelColors.champagne.withValues(alpha: 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AurelColors.champagne.withValues(alpha: 0.10),
                        blurRadius: 42,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: AlbumArt(
                    imageUrl: track.artworkUrl,
                    size: MediaQuery.sizeOf(context).width * 0.68,
                    radius: 23,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          track.artist,
                          style: const TextStyle(
                            color: AurelColors.muted,
                            fontSize: 14,
                          ),
                        ),
                      ],
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
                        onChanged: (value) =>
                            playback.seek(Duration(milliseconds: value.round())),
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
                              ),
                            ),
                            Text(
                              _format(duration),
                              style: const TextStyle(
                                color: AurelColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
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
                    ),
                  ),
                  Text(
                    '${playback.currentIndex + 1} / ${playback.queue.length}',
                    style: const TextStyle(
                      color: AurelColors.muted,
                      fontSize: 11,
                      letterSpacing: 1,
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AurelColors.background,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                      ),
                      builder: (_) => const LyricsSheet(),
                    ),
                    icon: const Icon(Icons.lyrics_rounded, size: 17),
                    label: const Text('LYRICS'),
                    style: TextButton.styleFrom(
                      foregroundColor: AurelColors.champagneLight,
                      textStyle: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AurelColors.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                      ),
                      builder: (_) => const UpNextSheet(),
                    ),
                    icon: const Icon(Icons.queue_music_rounded, size: 17),
                    label: Text('UP NEXT · ${playback.queue.length}'),
                    style: TextButton.styleFrom(
                      foregroundColor: AurelColors.champagne,
                      textStyle: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Previous track',
                    onPressed: () => playback.previous(),
                    icon: const Icon(Icons.skip_previous_rounded, size: 34),
                  ),
                  InkWell(
                    onTap: () => playback.togglePlayback(),
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AurelColors.champagneLight,
                            AurelColors.champagne,
                          ],
                        ),
                      ),
                      child: Icon(
                        playback.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AurelColors.background,
                        size: 38,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next track',
                    onPressed: () => playback.next(),
                    icon: const Icon(Icons.skip_next_rounded, size: 34),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
