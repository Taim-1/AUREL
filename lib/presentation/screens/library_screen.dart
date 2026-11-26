import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/models/music_playlist.dart';
import '../../data/models/track.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/track_tile.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedTab = 0;

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
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
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
        builder: (_) => PlaylistDetailScreen(playlistId: id),
      ),
    );
  }

  List<Track> _savedTracks(AurelController controller) {
    final unique = <String, Track>{};
    for (final track in [
      ...controller.favoriteTracks,
      ...controller.downloadedTracks,
      ...controller.recentlyPlayed,
    ]) {
      unique.putIfAbsent(track.id, () => track);
    }
    return unique.values.toList(growable: false);
  }

  List<_TrackGroup> _groupTracks(
    List<Track> tracks,
    String Function(Track) groupName,
  ) {
    final groups = <String, List<Track>>{};
    for (final track in tracks) {
      final name = groupName(track).trim();
      if (name.isEmpty) continue;
      groups.putIfAbsent(name, () => <Track>[]).add(track);
    }
    final result = groups.entries
        .map((entry) => _TrackGroup(entry.key, entry.value))
        .toList();
    result.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final saved = _savedTracks(controller);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your Library',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Search music',
              onPressed: () => controller.selectTab(1),
              icon: const Icon(
                Icons.search_rounded,
                color: AurelColors.champagneLight,
              ),
            ),
            IconButton(
              tooltip: 'Create playlist',
              onPressed: () => _createPlaylist(context),
              icon: const Icon(
                Icons.add_rounded,
                color: AurelColors.champagneLight,
                size: 27,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _LibraryTab(
                label: 'Playlists',
                selected: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
              ),
              _LibraryTab(
                label: 'Liked Songs',
                selected: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
              _LibraryTab(
                label: 'Albums',
                selected: _selectedTab == 2,
                onTap: () => setState(() => _selectedTab = 2),
              ),
              _LibraryTab(
                label: 'Artists',
                selected: _selectedTab == 3,
                onTap: () => setState(() => _selectedTab = 3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_selectedTab == 0) ...[
          _LibrarySummary(
            title: 'Favorites',
            subtitle: '${controller.favoriteTracks.length} songs',
            icon: Icons.favorite_rounded,
            tint: const Color(0xFF70445E),
            onTap: () => setState(() => _selectedTab = 1),
          ),
          const SizedBox(height: 13),
          if (controller.playlists.isEmpty)
            _LibraryEmptyState(
              title: 'Your playlists',
              message:
                  'Create your first playlist and keep every mood in one place.',
              action: 'Create playlist',
              onTap: () => _createPlaylist(context),
            )
          else ...[
            ...controller.playlists.map(
              (playlist) => _PlaylistCard(
                playlist: playlist,
                onTap: () => _openPlaylist(context, playlist.id),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _createPlaylist(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create playlist'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AurelColors.champagne,
                side: const BorderSide(color: AurelColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ],
        ] else if (_selectedTab == 1) ...[
          _LibrarySectionHeading(
            title: 'Liked Songs',
            count: '${controller.favoriteTracks.length} songs',
          ),
          if (controller.favoriteTracks.isEmpty)
            const _LibraryEmptyState(
              title: 'No liked songs yet',
              message:
                  'Tap the heart on any track to save it to your collection.',
            )
          else
            ...controller.favoriteTracks.map(
              (track) => TrackTile(
                track: track,
                queue: controller.favoriteTracks,
              ),
            ),
        ] else if (_selectedTab == 2) ...[
          const _LibrarySectionHeading(title: 'Albums', count: 'Saved music'),
          ..._buildGroups(
            context,
            _groupTracks(
              saved,
              (track) => track.album.isEmpty ? 'Singles' : track.album,
            ),
          ),
        ] else ...[
          const _LibrarySectionHeading(title: 'Artists', count: 'Saved music'),
          ..._buildGroups(
            context,
            _groupTracks(saved, (track) => track.artist),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildGroups(
    BuildContext context,
    List<_TrackGroup> groups,
  ) {
    if (groups.isEmpty) {
      return const [
        _LibraryEmptyState(
          title: 'Your collection is growing',
          message:
              'Albums and artists from your saved music will appear here.',
        ),
      ];
    }

    return groups
        .map(
          (group) => _CollectionRow(
            group: group,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _CollectionDetailPage(
                  title: group.name,
                  tracks: group.tracks,
                ),
              ),
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AurelColors.champagneLight : AurelColors.surface,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 9,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AurelColors.background : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibrarySectionHeading extends StatelessWidget {
  const _LibrarySectionHeading({
    required this.title,
    required this.count,
  });

  final String title;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            count,
            style: const TextStyle(
              color: AurelColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({
    required this.title,
    required this.message,
    this.action,
    this.onTap,
  });

  final String title;
  final String message;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AurelColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: AurelColors.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onTap,
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackGroup {
  const _TrackGroup(this.name, this.tracks);

  final String name;
  final List<Track> tracks;
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.group,
    required this.onTap,
  });

  final _TrackGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = group.tracks.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: first.artworkUrl.isEmpty
                      ? Container(
                          width: 52,
                          height: 52,
                          color: AurelColors.surfaceRaised,
                          child: const Icon(
                            Icons.album_rounded,
                            color: AurelColors.champagne,
                          ),
                        )
                      : Image.network(
                          first.artworkUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 52,
                            height: 52,
                            color: AurelColors.surfaceRaised,
                            child: const Icon(
                              Icons.album_rounded,
                              color: AurelColors.champagne,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
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
                        '${group.tracks.length} songs • ${first.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AurelColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AurelColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionDetailPage extends StatelessWidget {
  const _CollectionDetailPage({
    required this.title,
    required this.tracks,
  });

  final String title;
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: tracks
            .map(
              (track) => TrackTile(
                track: track,
                queue: tracks,
              ),
            )
            .toList(),
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

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  Future<void> _renamePlaylist(
    BuildContext context,
    MusicPlaylist playlist,
  ) async {
    final nameController = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AurelColors.surfaceRaised,
        title: const Text('Rename playlist'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(labelText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name != null && name.isNotEmpty && context.mounted) {
      await context.read<AurelController>().renamePlaylist(playlist.id, name);
    }
  }

  Future<void> _playPlaylist(
    BuildContext context,
    MusicPlaylist playlist,
    AurelController controller,
  ) async {
    final firstPlayable = playlist.tracks.cast<Track?>().firstWhere(
          (track) =>
              track != null &&
              track.canPlay &&
              (!controller.offlineMode || track.isDownloaded),
          orElse: () => null,
        );
    if (firstPlayable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tracks in this playlist are currently playable.'),
        ),
      );
      return;
    }
    try {
      await controller.playTrack(firstPlayable, queue: playlist.tracks);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

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
    final firstArtwork = selectedPlaylist?.tracks.isNotEmpty == true
        ? selectedPlaylist!.tracks.first.artworkUrl
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedPlaylist?.name ?? 'Playlist'),
        actions: [
          if (selectedPlaylist != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'rename') {
                  await _renamePlaylist(context, selectedPlaylist);
                } else if (value == 'delete') {
                  await context
                      .read<AurelController>()
                      .removePlaylist(playlistId);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename playlist')),
                PopupMenuItem(value: 'delete', child: Text('Delete playlist')),
              ],
            ),
        ],
      ),
      body: selectedPlaylist == null
          ? const Center(child: Text('This playlist is no longer available.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: AurelColors.surface,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: AurelColors.divider),
                  ),
                  child: Row(
                    children: [
                      AlbumArt(
                        imageUrl: firstArtwork,
                        size: 92,
                        radius: 17,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR PLAYLIST',
                              style: TextStyle(
                                color: AurelColors.champagne,
                                fontSize: 9,
                                letterSpacing: 1.7,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              selectedPlaylist.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${selectedPlaylist.tracks.length} tracks',
                              style: const TextStyle(
                                color: AurelColors.muted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: selectedPlaylist.tracks.isEmpty
                                  ? null
                                  : () => _playPlaylist(
                                        context,
                                        selectedPlaylist,
                                        controller,
                                      ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play playlist'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 19),
                if (selectedPlaylist.tracks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 25),
                    child: Center(
                      child: Text(
                        'No tracks yet. Add music from Search or Discover.',
                        style: TextStyle(color: AurelColors.muted),
                      ),
                    ),
                  )
                else
                  ...selectedPlaylist.tracks.map(
                    (track) => Row(
                      children: [
                        Expanded(
                          child: TrackTile(
                            track: track,
                            queue: selectedPlaylist.tracks,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove from playlist',
                          onPressed: () => context
                              .read<AurelController>()
                              .removeTrackFromPlaylist(
                                playlistId,
                                track.id,
                              ),
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: AurelColors.muted,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
