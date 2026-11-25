import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/models/music_playlist.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/track_tile.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  Future<void> _createPlaylist(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AurelColors.surfaceRaised,
        title: const Text('Create a playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(hintText: 'Give it a name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty && context.mounted) {
      await context.read<AurelController>().createPlaylist(name);
    }
  }

  void _openPlaylist(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PlaylistDetailPage(playlistId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 28),
      children: [
        const Text(
          'Your library',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your favourites and your own collections.',
          style: TextStyle(color: AurelColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _LibrarySummary(
          title: 'Liked songs',
          subtitle: '${controller.favoriteTracks.length} saved tracks',
          icon: Icons.favorite_rounded,
          tint: const Color(0xFF70445E),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const _FavoritesPage()),
          ),
        ),
        const SizedBox(height: 27),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your playlists',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _createPlaylist(context),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('New'),
            ),
          ],
        ),
        if (controller.playlists.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AurelColors.surface,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Text(
              'Create collections for every mood. Add songs from Search or Discover.',
              style: TextStyle(color: AurelColors.muted, fontSize: 12, height: 1.5),
            ),
          )
        else
          ...controller.playlists.map(
            (playlist) => _PlaylistCard(
              playlist: playlist,
              onTap: () => _openPlaylist(context, playlist.id),
            ),
          ),
        const SizedBox(height: 28),
        const Text(
          'Made to feel like yours',
          style: TextStyle(color: AurelColors.champagne, fontSize: 11, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your AUREL library keeps the music you save inside the app, ready for your next listen.',
          style: TextStyle(color: AurelColors.muted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AurelColors.surface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AurelColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 53,
              height: 53,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AurelColors.champagneLight, size: 25),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AurelColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AurelColors.muted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, required this.onTap});

  final MusicPlaylist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AurelColors.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AurelColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF78614A), Color(0xFF342B2B)],
                  ),
                ),
                child: const Icon(
                  Icons.queue_music_rounded,
                  color: AurelColors.champagneLight,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.tracks.length} tracks',
                      style: const TextStyle(
                        color: AurelColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AurelColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesPage extends StatelessWidget {
  const _FavoritesPage();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Liked songs')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: controller.favoriteTracks
            .map(
              (track) => TrackTile(
                track: track,
                queue: controller.favoriteTracks,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PlaylistDetailPage extends StatelessWidget {
  const _PlaylistDetailPage({required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    MusicPlaylist? playlist;
    for (final item in controller.playlists) {
      if (item.id == playlistId) {
        playlist = item;
        break;
      }
    }
    final selectedPlaylist = playlist;

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedPlaylist?.name ?? 'Playlist'),
        actions: [
          if (selectedPlaylist != null)
            IconButton(
              tooltip: 'Delete playlist',
              onPressed: () async {
                await context.read<AurelController>().removePlaylist(playlistId);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: selectedPlaylist == null
          ? const Center(child: Text('This playlist is no longer available.'))
          : selectedPlaylist.tracks.isEmpty
              ? const Center(
                  child: Text(
                    'No tracks yet. Add music from Search or Discover.',
                    style: TextStyle(color: AurelColors.muted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: selectedPlaylist.tracks
                      .map(
                        (track) => TrackTile(
                          track: track,
                          queue: selectedPlaylist.tracks,
                        ),
                      )
                      .toList(),
                ),
    );
  }
}
