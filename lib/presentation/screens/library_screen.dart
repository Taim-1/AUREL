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
          'Everything you have made yours.',
          style: TextStyle(color: AurelColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _LibrarySummary(
          title: 'Liked songs',
          subtitle: '${controller.favoriteTracks.length} saved tracks',
          icon: Icons.favorite_rounded,
          tint: const Color(0xFF70445E),
          onTap: () => _showFavorites(context),
        ),
        const SizedBox(height: 11),
        _LibrarySummary(
          title: 'On this device',
          subtitle: '${controller.deviceTracks.length} local tracks',
          icon: Icons.phone_android_rounded,
          tint: const Color(0xFF3D5C62),
          onTap: () => _scan(context),
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
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: AurelColors.surface,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Text(
              'Build a collection for every mood. Add tracks to a playlist from Search or Discover.',
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
        const SizedBox(height: 27),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Music on your device',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: controller.isScanningDevice ? null : () => _scan(context),
              icon: controller.isScanningDevice
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AurelColors.champagne,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Scan'),
            ),
          ],
        ),
        if (controller.deviceError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              controller.deviceError!,
              style: const TextStyle(color: Color(0xFFE6A0A0), fontSize: 12),
            ),
          ),
        if (controller.isScanningDevice)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: CircularProgressIndicator(color: AurelColors.champagne),
            ),
          )
        else if (controller.deviceTracks.isEmpty)
          Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              color: AurelColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.library_music_outlined,
                  color: AurelColors.champagne,
                  size: 32,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bring your music into AUREL',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Scan audio saved on your phone. Your files stay on your device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AurelColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _scan(context),
                  child: const Text('Scan device'),
                ),
              ],
            ),
          )
        else
          ...controller.deviceTracks.map(
            (track) => TrackTile(
              track: track,
              queue: controller.deviceTracks,
              showDownload: false,
            ),
          ),
      ],
    );
  }

  Future<void> _scan(BuildContext context) async {
    await context.read<AurelController>().scanDevice();
  }

  void _showFavorites(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _FavoritesPage(),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist?.name ?? 'Playlist'),
        actions: [
          if (playlist != null)
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
      body: playlist == null
          ? const Center(child: Text('This playlist is no longer available.'))
          : playlist.tracks.isEmpty
              ? const Center(
                  child: Text(
                    'No tracks yet. Add music from Search or Discover.',
                    style: TextStyle(color: AurelColors.muted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: playlist.tracks
                      .map(
                        (track) => TrackTile(
                          track: track,
                          queue: playlist!.tracks,
                        ),
                      )
                      .toList(),
                ),
    );
  }
}
