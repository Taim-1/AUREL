import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/models/lyrics_document.dart';
import '../../data/services/aurel_controller.dart';
import 'album_art.dart';

class LyricsSheet extends StatefulWidget {
  const LyricsSheet({super.key});

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _lineKeys = [];
  String? _keysTrackId;
  int _lastAutoScrolledIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AurelController>().loadLyricsForCurrentTrack();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureLineKeys(String trackId, int count) {
    if (_keysTrackId == trackId && _lineKeys.length == count) return;
    _keysTrackId = trackId;
    _lineKeys = List.generate(count, (_) => GlobalKey());
    _lastAutoScrolledIndex = -1;
  }

  int _activeLine(List<LyricsLine> lines, Duration position) {
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      if (lines[middle].start <= position) {
        result = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return result;
  }

  void _scrollToActive(int index) {
    if (index < 0 || index >= _lineKeys.length ||
        index == _lastAutoScrolledIndex) {
      return;
    }
    _lastAutoScrolledIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _lineKeys[index].currentContext;
      if (!mounted || targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.46,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final track = controller.playback.currentTrack;
    final lyrics = controller.currentLyrics;

    if (track == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
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
              const SizedBox(height: 18),
              Row(
                children: [
                  AlbumArt(
                    imageUrl: track.artworkUrl,
                    size: 52,
                    radius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LYRICS',
                          style: TextStyle(
                            color: AurelColors.champagne,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                    tooltip: 'Refresh lyrics',
                    onPressed: controller.isLoadingLyrics
                        ? null
                        : () => context
                            .read<AurelController>()
                            .loadLyricsForCurrentTrack(forceRefresh: true),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AurelColors.champagne,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: AurelColors.divider, height: 1),
              const SizedBox(height: 12),
              Expanded(
                child: _buildLyricsContent(
                  controller: controller,
                  trackId: track.id,
                  lyrics: lyrics,
                ),
              ),
              const SizedBox(height: 10),
              if ((lyrics?.lyricsCopyright ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    lyrics!.lyricsCopyright!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AurelColors.muted,
                      fontSize: 8,
                    ),
                  ),
                ),
              const Text(
                'Licensed lyrics',
                style: TextStyle(
                  color: AurelColors.muted,
                  fontSize: 9,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsContent({
    required AurelController controller,
    required String trackId,
    required LyricsDocument? lyrics,
  }) {
    if (controller.isLoadingLyrics && lyrics == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AurelColors.champagne),
            SizedBox(height: 14),
            Text(
              'Finding the words…',
              style: TextStyle(color: AurelColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (lyrics == null) {
      return _EmptyLyrics(
        message: controller.lyricsError ?? 'Lyrics are not available yet.',
        onRetry: controller.isLoadingLyrics
            ? null
            : () => context
                .read<AurelController>()
                .loadLyricsForCurrentTrack(forceRefresh: true),
      );
    }

    if (lyrics.instrumental) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              color: AurelColors.champagne,
              size: 38,
            ),
            SizedBox(height: 12),
            Text(
              'Instrumental track',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'No lyrics for this one. Just enjoy the music.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AurelColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (lyrics.hasSyncedLyrics) {
      _ensureLineKeys(trackId, lyrics.syncedLines.length);
      return StreamBuilder<Duration>(
        stream: controller.playback.player.positionStream,
        initialData: controller.playback.player.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final active = _activeLine(lyrics.syncedLines, position);
          _scrollToActive(active);

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(2, 26, 2, 64),
            child: Column(
              children: List.generate(lyrics.syncedLines.length, (index) {
                final line = lyrics.syncedLines[index];
                final isActive = index == active;
                final isPast = active >= 0 && index < active;
                return GestureDetector(
                  key: _lineKeys[index],
                  onTap: () => controller.playback.seek(line.start),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        color: isActive
                            ? AurelColors.champagneLight
                            : isPast
                                ? Colors.white.withValues(alpha: 0.52)
                                : AurelColors.muted.withValues(alpha: 0.74),
                        fontSize: isActive ? 23 : 18,
                        fontWeight:
                            isActive ? FontWeight.w800 : FontWeight.w500,
                        height: 1.35,
                        letterSpacing: isActive ? -0.3 : 0,
                      ),
                      child: Text(
                        line.text,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      );
    }

    final plain = lyrics.plainLyrics?.trim() ?? '';
    if (plain.isEmpty) {
      return const _EmptyLyrics(
        message: 'No readable lyrics were found for this track.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 22, 8, 54),
      child: Text(
        plain,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          height: 1.8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EmptyLyrics extends StatelessWidget {
  const _EmptyLyrics({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_note_rounded,
              color: AurelColors.champagne,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AurelColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AurelColors.champagne,
                  side: const BorderSide(color: AurelColors.divider),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
