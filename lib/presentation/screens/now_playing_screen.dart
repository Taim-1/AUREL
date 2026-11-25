import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/album_art.dart';

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
                  IconButton(
                    onPressed: () =>
                        context.read<AurelController>().toggleFavorite(track),
                    icon: Icon(
                      controller.isFavorite(track)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: controller.isFavorite(track)
                          ? const Color(0xFFE58A9C)
                          : AurelColors.champagne,
                      size: 25,
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
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
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
