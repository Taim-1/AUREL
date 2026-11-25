import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import 'album_art.dart';

class UpNextSheet extends StatelessWidget {
  const UpNextSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<AurelController>().playback;
    final queue = playback.queue;
    final hasUpcoming = playback.currentIndex + 1 < queue.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AurelColors.muted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Playing queue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${queue.length} tracks',
                  style: const TextStyle(
                    color: AurelColors.champagne,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasUpcoming && !playback.isShuffleEnabled)
                  TextButton(
                    onPressed: playback.clearUpcoming,
                    child: const Text('Clear upcoming'),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              playback.isShuffleEnabled
                  ? 'Shuffle is on. Turn it off to arrange or remove upcoming tracks.'
                  : 'Tap a track to play it now. Drag upcoming tracks to rearrange.',
              style: const TextStyle(color: AurelColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 15),
            if (queue.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Your queue is empty.',
                    style: TextStyle(color: AurelColors.muted),
                  ),
                ),
              )
            else
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  itemCount: queue.length,
                  onReorder: playback.isShuffleEnabled
                      ? null
                      : (oldIndex, newIndex) {
                          var destination = newIndex;
                          if (destination > oldIndex) destination--;
                          playback.moveUpcoming(oldIndex, destination);
                        },
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final selected = index == playback.currentIndex;
                    final upcoming = index > playback.currentIndex;
                    final canEdit =
                        upcoming && !playback.isShuffleEnabled;

                    return Container(
                      key: ValueKey('${track.id}-$index'),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AurelColors.divider),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          playback.jumpTo(index);
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 3,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: selected
                                    ? const Icon(
                                        Icons.equalizer_rounded,
                                        color: AurelColors.champagne,
                                        size: 19,
                                      )
                                    : Text(
                                        '${index + 1}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AurelColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 7),
                              AlbumArt(
                                imageUrl: track.artworkUrl,
                                size: 43,
                                radius: 10,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected
                                            ? AurelColors.champagneLight
                                            : Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AurelColors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    'PLAYING',
                                    style: TextStyle(
                                      color: AurelColors.champagne,
                                      fontSize: 8,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              else if (canEdit) ...[
                                IconButton(
                                  tooltip: 'Remove from upcoming',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => playback.removeUpcoming(index),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AurelColors.muted,
                                    size: 19,
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 5),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: AurelColors.muted,
                                      size: 21,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
