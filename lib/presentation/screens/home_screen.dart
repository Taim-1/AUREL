import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/aurel_mark.dart';
import '../widgets/album_art.dart';
import '../widgets/track_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final tracks = controller.discoverTracks;

    return RefreshIndicator(
      color: AurelColors.champagne,
      backgroundColor: AurelColors.surface,
      onRefresh: () => context.read<AurelController>().refreshDiscover(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        children: [
          const AurelMark(compact: true),
          const SizedBox(height: 27),
          const Text(
            'A good day starts\nwith good music.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w700,
              height: 1.12,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Your sound. Your moment. Your AUREL.',
            style: TextStyle(color: AurelColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _HeroCard(onExplore: () {
            context.read<AurelController>().selectTab(1);
          }),
          const SizedBox(height: 27),
          _SectionHeading(
            title: 'Browse by mood',
            action: 'Explore',
            onTap: () => context.read<AurelController>().selectTab(1),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 43,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _MoodChip('Chill', Icons.nightlight_round, onTap: () => _searchMood(context, 'chill')),
                _MoodChip('Focus', Icons.bolt_rounded, onTap: () => _searchMood(context, 'focus')),
                _MoodChip('Electronic', Icons.graphic_eq_rounded, onTap: () => _searchMood(context, 'electronic')),
                _MoodChip('Acoustic', Icons.music_note_rounded, onTap: () => _searchMood(context, 'acoustic')),
                _MoodChip('Jazz', Icons.piano_rounded, onTap: () => _searchMood(context, 'jazz')),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _SectionHeading(
            title: 'Made for discovery',
            action: 'Refresh',
            onTap: () => context.read<AurelController>().refreshDiscover(),
          ),
          const SizedBox(height: 4),
          if (controller.isLoadingDiscover && tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 35),
              child: Center(
                child: CircularProgressIndicator(color: AurelColors.champagne),
              ),
            )
          else if (controller.discoverError != null && tracks.isEmpty)
            _MessageCard(
              message: controller.discoverError!,
              action: 'Try again',
              onTap: () => context.read<AurelController>().refreshDiscover(),
            )
          else if (tracks.isEmpty)
            _MessageCard(
              message: 'Music discovery will appear here when the service is available.',
              action: 'Retry',
              onTap: () => context.read<AurelController>().refreshDiscover(),
            )
          else
            ...tracks.take(12).map(
                  (track) => TrackTile(track: track, queue: tracks),
                ),
          if (tracks.isNotEmpty && controller.hasMoreDiscover)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 18),
              child: OutlinedButton.icon(
                onPressed: controller.isLoadingMoreDiscover
                    ? null
                    : () => context.read<AurelController>().loadMoreDiscover(),
                icon: controller.isLoadingMoreDiscover
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AurelColors.champagne,
                        ),
                      )
                    : const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  controller.isLoadingMoreDiscover
                      ? 'Loading more music'
                      : 'Load more music',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AurelColors.champagne,
                  side: const BorderSide(color: AurelColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (tracks.isNotEmpty) ...[
            const _SectionHeading(title: 'Fresh picks'),
            const SizedBox(height: 12),
            SizedBox(
              height: 174,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tracks.length > 8 ? 8 : tracks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 13),
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return SizedBox(
                    width: 125,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context
                          .read<AurelController>()
                          .playTrack(track, queue: tracks),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AlbumArt(
                            imageUrl: track.artworkUrl,
                            size: 125,
                            radius: 16,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
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
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _searchMood(BuildContext context, String query) {
    context.read<AurelController>().selectTab(1);
    context.read<AurelController>().searchByTag(query);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 195,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF51406D), Color(0xFF272233), Color(0xFF17151B)],
        ),
        border: Border.all(color: AurelColors.champagne.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AurelColors.champagne.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -29,
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 185,
              color: Colors.white.withValues(alpha: 0.075),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THE AUREL EDIT',
                  style: TextStyle(
                    color: AurelColors.champagneLight,
                    fontSize: 10,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Find your\nnext favourite.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 13),
                GestureDetector(
                  onTap: onExplore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: AurelColors.champagneLight,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore music',
                          style: TextStyle(
                            color: AurelColors.background,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            size: 15, color: AurelColors.background),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 26,
            top: 28,
            child: Icon(
              Icons.album_rounded,
              size: 78,
              color: AurelColors.champagneLight.withValues(alpha: 0.20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.action,
    this.onTap,
  });

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onTap,
            child: Text(
              action!,
              style: const TextStyle(
                color: AurelColors.champagne,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip(this.label, this.icon, {required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(icon, size: 16, color: AurelColors.champagne),
        label: Text(label),
        backgroundColor: AurelColors.surface,
        side: const BorderSide(color: AurelColors.divider),
        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.action,
    required this.onTap,
  });

  final String message;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: AurelColors.muted)),
          const SizedBox(height: 9),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}
