import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/models/track.dart';
import '../../data/services/aurel_controller.dart';
import 'album_art.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.queue,
    this.showDownload = true,
    this.compact = false,
  });

  final Track track;
  final List<Track>? queue;
  final bool showDownload;
  final bool compact;

  void _showTrackInformation(BuildContext context) {
    final details = <String>[
      'Artist: ${track.artist}',
      if (track.album.isNotEmpty) 'Album: ${track.album}',
      if (track.durationMs > 0)
        'Duration: ${Duration(milliseconds: track.durationMs).inMinutes}:'
            '${(Duration(milliseconds: track.durationMs).inSeconds % 60).toString().padLeft(2, '0')}',
      if (track.licenseName.isNotEmpty) 'Usage license: ${track.licenseName}',
      if (track.downloadAllowed) 'Offline download: Available',
      if (!track.downloadAllowed) 'Offline download: Not available for this recording',
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AurelColors.surfaceRaised,
        title: Text(
          track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            details.join('\\n\\n'),
            style: const TextStyle(
              color: AurelColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlaylistAction(BuildContext context, String value) async {
    final controller = context.read<AurelController>();

    if (value == '__track_info__') {
      _showTrackInformation(context);
      return;
    }
    if (value == '__play_next__' || value == '__queue__') {
      try {
        if (value == '__play_next__') {
          await controller.playNext(track);
        } else {
          await controller.addToQueue(track);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value == '__play_next__'
                    ? 'Added to play next'
                    : 'Added to the queue',
              ),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
      return;
    }
    if (value == '__create__') {
      final nameController = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AurelColors.surfaceRaised,
          title: const Text('New playlist'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            maxLength: 32,
            decoration: const InputDecoration(hintText: 'Playlist name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, nameController.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      nameController.dispose();
      if (name != null && name.trim().isNotEmpty) {
        await controller.createPlaylist(name, initialTrack: track);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Playlist created and track added')),
          );
        }
      }
      return;
    }

    await controller.addTrackToPlaylist(value, track);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to playlist')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final favorite = controller.isFavorite(track);
    final downloading = controller.downloadingIds.contains(track.id);

    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () async {
        if (!track.canPlay) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This recording is listed in the AUREL catalogue, but '
                'an authorized in-app audio stream is not available.',
              ),
            ),
          );
          return;
        }
        try {
          await context.read<AurelController>().playTrack(track, queue: queue);
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.toString())),
            );
          }
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9),
        child: Row(
          children: [
            AlbumArt(
              imageUrl: track.artworkUrl,
              size: compact ? 48 : 54,
              radius: 13,
            ),
            const SizedBox(width: 13),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
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
            IconButton(
              tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
              onPressed: () => context.read<AurelController>().toggleFavorite(track),
              icon: Icon(
                favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: favorite ? const Color(0xFFE58A9C) : AurelColors.muted,
                size: 20,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Track actions',
              icon: const Icon(
                Icons.playlist_add_rounded,
                color: AurelColors.champagne,
                size: 21,
              ),
              onSelected: (value) => _handlePlaylistAction(context, value),
              itemBuilder: (_) => [
                const PopupMenuItem<String>(
                  value: '__play_next__',
                  child: Text('Play next'),
                ),
                const PopupMenuItem<String>(
                  value: '__queue__',
                  child: Text('Add to queue'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: '__create__',
                  child: Text('Create new playlist'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: '__track_info__',
                  child: Text('Track information'),
                ),
                if (controller.playlists.isNotEmpty)
                  const PopupMenuDivider(),
                ...controller.playlists.map(
                  (playlist) => PopupMenuItem<String>(
                    value: playlist.id,
                    child: Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            if (showDownload)
              IconButton(
                tooltip: downloading
                    ? 'Cancel download'
                    : controller.offlineMode
                        ? 'Turn off Offline mode to download'
                        : track.downloadAllowed
                            ? 'Download for offline listening'
                            : 'Download not allowed',
                onPressed: !track.downloadAllowed || controller.offlineMode
                    ? null
                    : downloading
                        ? () => context
                            .read<AurelController>()
                            .cancelDownload(track.id)
                        : () async {
                            final message = await context
                                .read<AurelController>()
                                .downloadTrack(track);
                            if (!context.mounted) return;
                            if (message != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Saved for offline listening'),
                                ),
                              );
                            }
                          },
                icon: downloading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: controller.downloadProgress[track.id],
                          strokeWidth: 2.2,
                          color: AurelColors.champagne,
                          backgroundColor: AurelColors.divider,
                        ),
                      )
                    : Icon(
                        track.downloadAllowed
                            ? Icons.download_rounded
                            : Icons.download_for_offline_outlined,
                        color: track.downloadAllowed
                            ? AurelColors.champagne
                            : AurelColors.muted.withValues(alpha: 0.45),
                        size: 20,
                      ),
              ),
            if (!showDownload)
              const Icon(Icons.chevron_right_rounded, color: AurelColors.muted),
          ],
        ),
      ),
    );
  }
}
