import 'package:material_ui/material_ui.dart';

import '../../core/theme/aurel_theme.dart';

class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.imageUrl,
    this.size = 58,
    this.radius = 14,
  });

  final String imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(imageUrl.trim());
    final canLoadNetworkArtwork =
        uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;

    final artwork = canLoadNetworkArtwork
        ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _fallback();
            },
          )
        : _fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: AurelColors.surfaceRaised,
        child: artwork,
      ),
    );
  }

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF51406F),
              Color(0xFF17151D),
              Color(0xFF9A7953),
            ],
          ),
        ),
        child: const Icon(
          Icons.graphic_eq_rounded,
          color: AurelColors.champagneLight,
          size: 27,
        ),
      );
}
