import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/models/track.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/track_tile.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final tracks = controller.downloadedTracks;
    final activeDownloads = <String, Track>{
      for (final track in [
        ...controller.searchResults,
        ...controller.discoverTracks,
        ...controller.favoriteTracks,
        ...controller.playlists.expand((playlist) => playlist.tracks),
      ])
        if (controller.downloadingIds.contains(track.id)) track.id: track,
    }.values.toList(growable: false);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Downloads',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => controller.selectTab(4),
              icon: const Icon(
                Icons.settings_outlined,
                color: AurelColors.champagneLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Your music, ready whenever you are.',
          style: TextStyle(color: AurelColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B3329), Color(0xFF1B1917)],
            ),
            border: Border.all(
              color: AurelColors.champagne.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AurelColors.champagne.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.download_done_rounded,
                  color: AurelColors.champagneLight,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saved inside AUREL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'} available offline',
                      style: const TextStyle(
                        color: AurelColors.champagneLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (activeDownloads.isNotEmpty) ...[
          const SizedBox(height: 25),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Downloading now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              Text(
                '${activeDownloads.length}',
                style: const TextStyle(color: AurelColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...activeDownloads.map(
            (track) => TrackTile(track: track, showDownload: true),
          ),
        ],
        const SizedBox(height: 27),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Downloaded Songs',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            Text(
              '${tracks.length}',
              style: const TextStyle(
                color: AurelColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (tracks.isEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 25),
            decoration: BoxDecoration(
              color: AurelColors.surface,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: AurelColors.divider),
            ),
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AurelColors.champagne.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download_for_offline_outlined,
                    color: AurelColors.champagneLight,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your offline collection starts here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Explore music in AUREL and tap the download control on tracks that allow offline saving. They will appear here automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AurelColors.muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 17),
                FilledButton.icon(
                  onPressed: () => controller.selectTab(0),
                  icon: const Icon(Icons.explore_rounded, size: 17),
                  label: const Text('Explore music'),
                ),
              ],
            ),
          )
        else
          ...tracks.map(
            (track) => Dismissible(
              key: ValueKey(track.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B343A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                ),
              ),
              onDismissed: (_) =>
                  context.read<AurelController>().removeDownload(track),
              child: TrackTile(
                track: track,
                queue: tracks,
                showDownload: false,
              ),
            ),
          ),
        const SizedBox(height: 14),
        if (tracks.isNotEmpty)
          const Text(
            'Swipe a song to remove its offline copy from AUREL.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurelColors.muted, fontSize: 10),
          ),
      ],
    );
  }
}
