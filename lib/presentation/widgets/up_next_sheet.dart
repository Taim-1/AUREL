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
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Tap any track to play it next.',
              style: TextStyle(color: AurelColors.muted, fontSize: 12),
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
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: queue.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AurelColors.divider, height: 1),
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final selected = index == playback.currentIndex;
                    return InkWell(
                      onTap: () {
                        playback.jumpTo(index);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(13),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 5,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 25,
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
                            const SizedBox(width: 8),
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
                              const Text(
                                'PLAYING',
                                style: TextStyle(
                                  color: AurelColors.champagne,
                                  fontSize: 8,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
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
