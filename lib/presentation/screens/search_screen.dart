import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/models/track.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _trendingSearches = <String>[
    'The Weeknd',
    'Billie Eilish',
    'Coldplay',
    'Drake',
    'Taylor Swift',
    'Arabic Hits',
  ];

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _debounce?.cancel();
    await context.read<AurelController>().searchMusic(_searchController.text);
  }

  void _searchFor(String query) {
    _debounce?.cancel();
    _searchController.text = query;
    _searchFocus.unfocus();
    context.read<AurelController>().searchMusic(query);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      context.read<AurelController>().searchMusic(value);
    });
  }

  List<Track> _popularArtists(List<Track> tracks) {
    final artists = <String, Track>{};
    for (final track in tracks) {
      final name = track.artist.trim();
      if (name.isEmpty) continue;
      artists.putIfAbsent(name.toLowerCase(), () => track);
      if (artists.length == 8) break;
    }
    return artists.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final hasQuery = controller.searchQuery.isNotEmpty;
    final artists = _popularArtists(controller.discoverTracks);

    if (!_searchFocus.hasFocus &&
        _searchController.text != controller.searchQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _searchFocus.hasFocus) return;
        _searchController.value = TextEditingValue(
          text: controller.searchQuery,
          selection: TextSelection.collapsed(
            offset: controller.searchQuery.length,
          ),
        );
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: controller.offlineMode
                ? 'Search downloaded music...'
                : 'Search artists, songs...',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AurelColors.champagne,
            ),
            suffixIcon: IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _debounce?.cancel();
                _searchController.clear();
                context.read<AurelController>().searchMusic('');
                _searchFocus.requestFocus();
              },
              icon: const Icon(
                Icons.close_rounded,
                color: AurelColors.muted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 25),
        if (controller.isSearching && controller.searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 44),
            child: Center(
              child: CircularProgressIndicator(
                color: AurelColors.champagne,
              ),
            ),
          )
        else if (controller.searchError != null &&
            controller.searchResults.isEmpty &&
            hasQuery)
          _SearchMessage(
            controller.searchError!,
            action: 'Try again',
            onTap: _submit,
          )
        else if (hasQuery) ...[
          _SectionHeading(
            title: 'Results for “${controller.searchQuery}”',
            trailing: controller.isSearching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AurelColors.champagne,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 9),
          if (controller.searchResults.isEmpty)
            const _SearchMessage(
              'No matches were found. Try another song, artist, or genre.',
            )
          else
            ...controller.searchResults.map(
              (track) => TrackTile(
                track: track,
                queue: controller.searchResults,
              ),
            ),
          if (controller.searchMoreError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                controller.searchMoreError!,
                style: const TextStyle(
                  color: Color(0xFFE6A0A0),
                  fontSize: 12,
                ),
              ),
            ),
          if (controller.hasMoreSearch)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: controller.isLoadingMoreSearch
                    ? null
                    : () => context
                        .read<AurelController>()
                        .loadMoreSearch(),
                icon: controller.isLoadingMoreSearch
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
                  controller.isLoadingMoreSearch
                      ? 'Loading more results'
                      : 'Load more results',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AurelColors.champagne,
                  side: const BorderSide(color: AurelColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
        ] else if (controller.offlineMode) ...[
          const _SectionHeading(title: 'Your Downloaded Music'),
          if (controller.downloadedTracks.isEmpty)
            const _SearchMessage(
              'No AUREL downloads yet. Your saved music will appear here.',
            )
          else
            ...controller.downloadedTracks.map(
              (track) => TrackTile(
                track: track,
                queue: controller.downloadedTracks,
                showDownload: false,
              ),
            ),
        ] else ...[
          const _SectionHeading(title: 'Trending Searches'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 9,
            children: _trendingSearches.map((term) {
              return ActionChip(
                onPressed: () => _searchFor(term),
                avatar: const Icon(
                  Icons.trending_up_rounded,
                  color: AurelColors.champagne,
                  size: 15,
                ),
                label: Text(term),
                backgroundColor: AurelColors.surface,
                side: const BorderSide(color: AurelColors.divider),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              );
            }).toList(),
          ),
          if (artists.isNotEmpty) ...[
            const SizedBox(height: 27),
            const _SectionHeading(title: 'Popular Artists'),
            const SizedBox(height: 13),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: artists.length,
                separatorBuilder: (_, _) => const SizedBox(width: 15),
                itemBuilder: (context, index) {
                  final track = artists[index];
                  return _ArtistBubble(
                    artist: track.artist,
                    artworkUrl: track.artworkUrl,
                    onTap: () => _searchFor(track.artist),
                  );
                },
              ),
            ),
          ],
          if (controller.playlists.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeading(
              title: 'Your Playlists',
              action: 'See All',
              onAction: () => controller.selectTab(2),
            ),
            const SizedBox(height: 11),
            SizedBox(
              height: 146,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: controller.playlists.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final playlist = controller.playlists[index];
                  final firstTrack = playlist.tracks.isEmpty
                      ? null
                      : playlist.tracks.first;
                  return _PlaylistPoster(
                    title: playlist.name,
                    subtitle: '${playlist.tracks.length} songs',
                    artworkUrl: firstTrack?.artworkUrl ?? '',
                    onTap: () => controller.selectTab(2),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 26),
          _SectionHeading(
            title: 'Popular Music',
            action: 'See All',
            onAction: () => controller.selectTab(0),
          ),
          const SizedBox(height: 6),
          if (controller.isLoadingDiscover &&
              controller.discoverTracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: CircularProgressIndicator(
                  color: AurelColors.champagne,
                ),
              ),
            )
          else if (controller.discoverError != null &&
              controller.discoverTracks.isEmpty)
            _SearchMessage(
              controller.discoverError!,
              action: 'Try again',
              onTap: () =>
                  context.read<AurelController>().refreshDiscover(),
            )
          else if (controller.discoverTracks.isEmpty)
            const _SearchMessage(
              'New music will appear here when the catalogue is available.',
            )
          else
            ...controller.discoverTracks.take(5).map(
                  (track) => TrackTile(
                    track: track,
                    queue: controller.discoverTracks,
                  ),
                ),
        ],
      ],
    );
  }
}

class _ArtistBubble extends StatelessWidget {
  const _ArtistBubble({
    required this.artist,
    required this.artworkUrl,
    required this.onTap,
  });

  final String artist;
  final String artworkUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AurelColors.champagne.withValues(alpha: 0.35),
                ),
              ),
              child: ClipOval(
                child: artworkUrl.isEmpty
                    ? Container(
                        width: 59,
                        height: 59,
                        color: AurelColors.surfaceRaised,
                        child: const Icon(
                          Icons.person_rounded,
                          color: AurelColors.champagne,
                          size: 29,
                        ),
                      )
                    : Image.network(
                        artworkUrl,
                        width: 59,
                        height: 59,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 59,
                          height: 59,
                          color: AurelColors.surfaceRaised,
                          child: const Icon(
                            Icons.person_rounded,
                            color: AurelColors.champagne,
                            size: 29,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistPoster extends StatelessWidget {
  const _PlaylistPoster({
    required this.title,
    required this.subtitle,
    required this.artworkUrl,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String artworkUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: artworkUrl.isEmpty
                  ? Container(
                      width: 116,
                      height: 94,
                      color: AurelColors.surfaceRaised,
                      child: const Icon(
                        Icons.queue_music_rounded,
                        color: AurelColors.champagne,
                        size: 32,
                      ),
                    )
                  : AlbumArt(
                      imageUrl: artworkUrl,
                      size: 116,
                      radius: 14,
                    ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: AurelColors.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.action,
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

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
            ),
          ),
        ),
        if (trailing != null) trailing!,
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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

class _SearchMessage extends StatelessWidget {
  const _SearchMessage(
    this.message, {
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
