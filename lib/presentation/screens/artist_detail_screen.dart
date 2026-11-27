import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/catalog/catalog_identity.dart';
import '../../data/models/track.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/track_tile.dart';

class ArtistDetailScreen extends StatefulWidget {
  const ArtistDetailScreen({
    super.key,
    required this.artist,
    this.artworkUrl = '',
  });

  final String artist;
  final String artworkUrl;

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AurelController>().searchMusic(widget.artist);
    });
  }

  List<Track> _artistTracks(List<Track> tracks) {
    final artistKey = CatalogIdentity.normalizeText(widget.artist);
    final unique = <String, Track>{};
    for (final track in tracks) {
      if (CatalogIdentity.normalizeText(track.artist) != artistKey) continue;
      unique.putIfAbsent(track.id, () => track);
    }
    return unique.values.toList(growable: false);
  }

  Map<String, List<Track>> _albums(List<Track> tracks) {
    final albums = <String, List<Track>>{};
    for (final track in tracks) {
      final name = track.album.trim();
      if (name.isEmpty) continue;
      albums.putIfAbsent(name, () => <Track>[]).add(track);
    }
    return albums;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final tracks = _artistTracks(controller.searchResults);
    final albums = _albums(tracks);
    final playable = tracks.any(controller.hasPlayableSource);
    final artwork = widget.artworkUrl.isNotEmpty
        ? widget.artworkUrl
        : tracks
            .map((track) => track.artworkUrl)
            .firstWhere((url) => url.isNotEmpty, orElse: () => '');

    return Scaffold(
      backgroundColor: AurelColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Artist',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AurelColors.champagne,
        backgroundColor: AurelColors.surface,
        onRefresh: () => controller.searchMusic(widget.artist),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            _ArtistHero(
              name: widget.artist,
              artworkUrl: artwork,
              trackCount: tracks.length,
              onPlay: playable
                  ? () => controller.playTrack(
                        tracks.firstWhere(controller.hasPlayableSource),
                        queue: tracks,
                      )
                  : null,
            ),
            const SizedBox(height: 27),
            if (albums.isNotEmpty) ...[
              _SectionHeading(
                title: 'Albums',
                count: '${albums.length}',
              ),
              const SizedBox(height: 13),
              SizedBox(
                height: 174,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: albums.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 13),
                  itemBuilder: (context, index) {
                    final entry = albums.entries.elementAt(index);
                    final albumTracks = entry.value;
                    return _AlbumCard(
                      title: entry.key,
                      artworkUrl: albumTracks.first.artworkUrl,
                      trackCount: albumTracks.length,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ArtistAlbumDetailScreen(
                            artist: widget.artist,
                            album: entry.key,
                            tracks: albumTracks,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 27),
            ],
            _SectionHeading(
              title: 'Popular Tracks',
              count: tracks.isEmpty ? null : '${tracks.length}',
            ),
            const SizedBox(height: 8),
            if (controller.isSearching && tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 38),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AurelColors.champagne,
                  ),
                ),
              )
            else if (controller.searchError != null && tracks.isEmpty)
              _ArtistMessage(
                message: controller.searchError!,
                action: 'Try again',
                onTap: () => controller.searchMusic(widget.artist),
              )
            else if (tracks.isEmpty)
              const _ArtistMessage(
                message:
                    'Artist recordings will appear here when matching catalogue information is available.',
              )
            else
              ...tracks.map(
                (track) => TrackTile(
                  track: track,
                  queue: tracks,
                  showDownload: true,
                ),
              ),
            const SizedBox(height: 20),
            if (tracks.isEmpty)
              const Text(
                'AUREL only displays artist and album information returned by its music catalogues. It does not invent biographies, releases, or similar-artist data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AurelColors.muted,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ArtistAlbumDetailScreen extends StatelessWidget {
  const ArtistAlbumDetailScreen({
    super.key,
    required this.artist,
    required this.album,
    required this.tracks,
  });

  final String artist;
  final String album;
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final playable = tracks.any(controller.hasPlayableSource);
    final artwork = tracks
        .map((track) => track.artworkUrl)
        .firstWhere((url) => url.isNotEmpty, orElse: () => '');

    return Scaffold(
      backgroundColor: AurelColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Album',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Center(
            child: AlbumArt(
              imageUrl: artwork,
              size: 218,
              radius: 22,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            album,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            artist,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AurelColors.muted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AurelColors.champagneLight,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton.icon(
              onPressed: playable
                  ? () => controller.playTrack(
                        tracks.firstWhere(controller.hasPlayableSource),
                        queue: tracks,
                      )
                  : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play album'),
              style: FilledButton.styleFrom(
                backgroundColor: AurelColors.champagne,
                foregroundColor: AurelColors.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          ...tracks.map(
            (track) => TrackTile(
              track: track,
              queue: tracks,
              showDownload: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistHero extends StatelessWidget {
  const _ArtistHero({
    required this.name,
    required this.artworkUrl,
    required this.trackCount,
    required this.onPlay,
  });

  final String name;
  final String artworkUrl;
  final int trackCount;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B342B), Color(0xFF1A1919), Color(0xFF111114)],
        ),
        border: Border.all(
          color: AurelColors.champagne.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        children: [
          AlbumArt(
            imageUrl: artworkUrl,
            size: 154,
            radius: 77,
          ),
          const SizedBox(height: 17),
          const Text(
            'ARTIST',
            style: TextStyle(
              color: AurelColors.champagne,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$trackCount ${trackCount == 1 ? 'track' : 'tracks'} in AUREL catalogue',
            style: const TextStyle(
              color: AurelColors.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 17),
          FilledButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play artist'),
            style: FilledButton.styleFrom(
              backgroundColor: AurelColors.champagne,
              foregroundColor: AurelColors.background,
              padding: const EdgeInsets.symmetric(
                horizontal: 25,
                vertical: 12,
              ),
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
    this.count,
  });

  final String title;
  final String? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ),
        if (count != null)
          Text(
            count!,
            style: const TextStyle(
              color: AurelColors.muted,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.title,
    required this.artworkUrl,
    required this.trackCount,
    required this.onTap,
  });

  final String title;
  final String artworkUrl;
  final int trackCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlbumArt(
              imageUrl: artworkUrl,
              size: 124,
              radius: 15,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$trackCount ${trackCount == 1 ? 'track' : 'tracks'}',
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

class _ArtistMessage extends StatelessWidget {
  const _ArtistMessage({
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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AurelColors.divider),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AurelColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (action != null && onTap != null) ...[
            const SizedBox(height: 13),
            OutlinedButton(
              onPressed: onTap,
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}
