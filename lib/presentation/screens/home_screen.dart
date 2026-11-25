import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/models/track.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/track_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _categories = <_MusicCategory>[
    _MusicCategory(
      'Pop',
      'pop',
      Icons.auto_awesome_rounded,
      [Color(0xFFB65E52), Color(0xFF58313C)],
    ),
    _MusicCategory(
      'Rock',
      'rock',
      Icons.album_rounded,
      [Color(0xFF645184), Color(0xFF30263F)],
    ),
    _MusicCategory(
      'Hip-Hop',
      'hip hop',
      Icons.graphic_eq_rounded,
      [Color(0xFF5D4C8D), Color(0xFF292342)],
    ),
    _MusicCategory(
      'Arabic',
      'arabic',
      Icons.nights_stay_rounded,
      [Color(0xFF9A6847), Color(0xFF493129)],
    ),
    _MusicCategory(
      'Electronic',
      'electronic',
      Icons.bolt_rounded,
      [Color(0xFF426C77), Color(0xFF243A48)],
    ),
    _MusicCategory(
      'Relax',
      'chill',
      Icons.spa_rounded,
      [Color(0xFF76618A), Color(0xFF342B43)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final tracks = controller.offlineMode
        ? controller.downloadedTracks
        : controller.discoverTracks;
    final featured = tracks.isNotEmpty ? tracks.first : null;

    return RefreshIndicator(
      color: AurelColors.champagne,
      backgroundColor: AurelColors.surface,
      onRefresh: () => controller.offlineMode
          ? Future<void>.value()
          : context.read<AurelController>().refreshDiscover(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _HomeHeader(
            userName: controller.account.userName,
            onSettings: () =>
                context.read<AurelController>().selectTab(4),
          ),
          const SizedBox(height: 20),
          _SearchLauncher(
            onTap: () => context.read<AurelController>().selectTab(1),
          ),
          const SizedBox(height: 18),
          _FeaturedMusicCard(
            track: featured,
            offline: controller.offlineMode,
            onTap: featured == null
                ? () => context.read<AurelController>().selectTab(1)
                : () => context
                    .read<AurelController>()
                    .playTrack(featured, queue: tracks),
          ),
          const SizedBox(height: 26),
          _SectionHeading(
            title: 'Browse by Category',
            action: 'See All',
            onTap: () => context.read<AurelController>().selectTab(1),
          ),
          const SizedBox(height: 13),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.08,
            ),
            itemBuilder: (context, index) {
              final category = _categories[index];
              return _CategoryCard(
                category: category,
                onTap: () {
                  final music = context.read<AurelController>();
                  music.selectTab(1);
                  music.searchByTag(category.query);
                },
              );
            },
          ),
          if (controller.recentlyPlayed.isNotEmpty) ...[
            const SizedBox(height: 26),
            const _SectionHeading(title: 'Continue Listening'),
            const SizedBox(height: 12),
            _RecentTrackStrip(tracks: controller.recentlyPlayed),
          ],
          const SizedBox(height: 27),
          _SectionHeading(
            title: controller.offlineMode ? 'Downloaded Music' : 'Trending Now',
            action: controller.offlineMode ? null : 'See All',
            onTap: controller.offlineMode
                ? null
                : () => context.read<AurelController>().selectTab(1),
          ),
          const SizedBox(height: 5),
          if (controller.isLoadingDiscover && tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: Center(
                child: CircularProgressIndicator(
                  color: AurelColors.champagne,
                ),
              ),
            )
          else if (controller.discoverError != null &&
              tracks.isEmpty &&
              !controller.offlineMode)
            _MessageCard(
              message: controller.discoverError!,
              action: 'Try again',
              onTap: () =>
                  context.read<AurelController>().refreshDiscover(),
            )
          else if (tracks.isEmpty)
            _MessageCard(
              message: controller.offlineMode
                  ? 'Your downloaded songs will appear here.'
                  : 'Music recommendations will appear here when the catalogue is available.',
              action: controller.offlineMode ? null : 'Refresh',
              onTap: controller.offlineMode
                  ? null
                  : () =>
                      context.read<AurelController>().refreshDiscover(),
            )
          else ...[
            ...tracks.take(6).map(
                  (track) => TrackTile(
                    track: track,
                    queue: tracks,
                    showDownload: !controller.offlineMode,
                  ),
                ),
            if (!controller.offlineMode && controller.hasMoreDiscover)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: controller.isLoadingMoreDiscover
                      ? null
                      : () => context
                          .read<AurelController>()
                          .loadMoreDiscover(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AurelColors.champagne,
                    side: const BorderSide(color: AurelColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    controller.isLoadingMoreDiscover
                        ? 'Loading…'
                        : 'Load more music',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.userName,
    required this.onSettings,
  });

  final String userName;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $userName 👋',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.35,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Let's enjoy the music",
                style: TextStyle(
                  color: AurelColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: AurelColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onSettings,
            borderRadius: BorderRadius.circular(14),
            child: const SizedBox(
              width: 43,
              height: 43,
              child: Icon(
                Icons.settings_outlined,
                color: AurelColors.champagneLight,
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AurelColors.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AurelColors.muted,
                size: 20,
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Search for songs, artists...',
                  style: TextStyle(
                    color: AurelColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(
                Icons.tune_rounded,
                color: AurelColors.champagne.withValues(alpha: 0.9),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedMusicCard extends StatelessWidget {
  const _FeaturedMusicCard({
    required this.track,
    required this.offline,
    required this.onTap,
  });

  final Track? track;
  final bool offline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          height: 174,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6B4C83),
                Color(0xFF3C2D4F),
                Color(0xFF211D2A),
              ],
            ),
            border: Border.all(
              color: AurelColors.champagne.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8F6CB0).withValues(alpha: 0.15),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (track != null && track!.artworkUrl.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 155,
                  child: Opacity(
                    opacity: 0.82,
                    child: AlbumArt(
                      imageUrl: track!.artworkUrl,
                      size: 155,
                      radius: 0,
                    ),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF33253F).withValues(alpha: 0.96),
                        const Color(0xFF33253F).withValues(alpha: 0.72),
                        const Color(0xFF33253F).withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 18, 17, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offline ? 'AUREL OFFLINE' : 'FEATURED FOR YOU',
                            style: const TextStyle(
                              color: AurelColors.champagneLight,
                              fontSize: 9,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            offline ? 'Your Music\nAlways With You' : 'Good Vibes\nOnly',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              height: 1.02,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            offline
                                ? 'Listen anywhere, anytime'
                                : 'The perfect playlist\nfor your mood',
                            style: const TextStyle(
                              color: Color(0xFFE1D6E8),
                              fontSize: 10,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AurelColors.champagneLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: AurelColors.background,
                          size: 27,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicCategory {
  const _MusicCategory(
    this.name,
    this.query,
    this.icon,
    this.colors,
  );

  final String name;
  final String query;
  final IconData icon;
  final List<Color> colors;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  final _MusicCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: category.colors,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 9,
                right: 9,
                child: Icon(
                  category.icon,
                  size: 36,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category.icon,
                      size: 23,
                      color: AurelColors.champagneLight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTrackStrip extends StatelessWidget {
  const _RecentTrackStrip({required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length > 10 ? 10 : tracks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final track = tracks[index];
          return SizedBox(
            width: 112,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => context
                  .read<AurelController>()
                  .playTrack(track, queue: tracks),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AlbumArt(
                    imageUrl: track.artworkUrl,
                    size: 108,
                    radius: 14,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
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
          );
        },
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
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    this.action,
    this.onTap,
  });

  final String message;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AurelColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AurelColors.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 9),
            TextButton(onPressed: onTap, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
