import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/track_tile.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final tracks = controller.downloadedTracks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 28),
      children: [
        const Text(
          'Downloads',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your music, ready when the signal is not.',
          style: TextStyle(color: AurelColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 23),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF3B3329), Color(0xFF1B1917)],
            ),
            border: Border.all(color: AurelColors.champagne.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              const Icon(Icons.offline_pin_rounded,
                  color: AurelColors.champagneLight, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offline collection',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tracks.length} tracks saved on this device',
                      style: const TextStyle(
                        color: AurelColors.champagneLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        if (tracks.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AurelColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(Icons.download_for_offline_outlined,
                    color: AurelColors.champagne, size: 36),
                SizedBox(height: 10),
                Text(
                  'Nothing downloaded yet',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Explore music and save tracks that have downloads enabled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AurelColors.muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ...tracks.map(
            (track) => Dismissible(
              key: ValueKey(track.id),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B343A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (_) =>
                  context.read<AurelController>().removeDownload(track),
              child: TrackTile(
                track: track,
                queue: tracks,
                showDownload: false,
              ),
            ),
          ),
      ],
    );
  }
}
