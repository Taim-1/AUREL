import 'dart:collection';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/theme/aurel_theme.dart';

class AlbumArt extends StatefulWidget {
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
  State<AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends State<AlbumArt> {
  static const MethodChannel _channel =
      MethodChannel('com.aurel.music/device_library');
  static final LinkedHashMap<String, Uint8List> _localCache =
      LinkedHashMap<String, Uint8List>();

  Future<Uint8List?>? _localArtwork;

  @override
  void initState() {
    super.initState();
    _updateLocalArtwork();
  }

  @override
  void didUpdateWidget(covariant AlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _updateLocalArtwork();
  }

  void _updateLocalArtwork() {
    final uri = Uri.tryParse(widget.imageUrl);
    if (uri == null ||
        uri.scheme != 'content' ||
        uri.authority != 'media') {
      _localArtwork = null;
      return;
    }
    _localArtwork = _loadLocalArtwork(widget.imageUrl);
  }

  Future<Uint8List?> _loadLocalArtwork(String uri) async {
    final cached = _localCache.remove(uri);
    if (cached != null) {
      _localCache[uri] = cached;
      return cached;
    }

    try {
      final bytes = await _channel.invokeMethod<Uint8List>(
        'loadAlbumArtwork',
        uri,
      );
      if (bytes == null || bytes.isEmpty) return null;
      if (_localCache.length >= 160) {
        _localCache.remove(_localCache.keys.first);
      }
      _localCache[uri] = bytes;
      return bytes;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(widget.imageUrl);
    final isLocalArtwork =
        uri != null && uri.scheme == 'content' && uri.authority == 'media';

    Widget image;
    if (isLocalArtwork) {
      image = FutureBuilder<Uint8List?>(
        future: _localArtwork,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return _fallback();
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          );
        },
      );
    } else if (uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty) {
      image = Image.network(
        widget.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _fallback();
        },
      );
    } else {
      image = _fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: AurelColors.surfaceRaised,
        child: image,
      ),
    );
  }

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF51406F), Color(0xFF17151D), Color(0xFF9A7953)],
          ),
        ),
        child: const Icon(
          Icons.graphic_eq_rounded,
          color: AurelColors.champagneLight,
          size: 27,
        ),
      );
}
