import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import '../../data/services/device_storage_service.dart';
import '../widgets/track_tile.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with WidgetsBindingObserver {
  DeviceStorageSnapshot? _storage;
  bool _loadingStorage = true;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStorage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStorage();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadStorage() async {
    if (mounted) {
      setState(() {
        _loadingStorage = true;
        _storageError = null;
      });
    }

    try {
      final snapshot = await DeviceStorageService.read();
      if (mounted) {
        setState(() {
          _storage = snapshot;
          _loadingStorage = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _storageError = error.toString();
          _loadingStorage = false;
        });
      }
    }
  }

  void _showStorageDetails(BuildContext context, int downloadedCount) {
    final storage = _storage;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AurelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AurelColors.muted.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Device storage',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (storage != null) ...[
                _StorageDetailRow(
                  label: 'Used on this device',
                  value: DeviceStorageSnapshot.formatBytes(storage.usedBytes),
                ),
                _StorageDetailRow(
                  label: 'Available',
                  value: DeviceStorageSnapshot.formatBytes(storage.availableBytes),
                ),
                _StorageDetailRow(
                  label: 'Total capacity',
                  value: DeviceStorageSnapshot.formatBytes(storage.totalBytes),
                ),
              ],
              const Divider(color: AurelColors.divider, height: 24),
              _StorageDetailRow(
                label: 'Songs downloaded in AUREL',
                value: '$downloadedCount',
              ),
              const SizedBox(height: 8),
              const Text(
                'The ring shows storage used by the whole shared device volume, including other apps and files. It is not limited to AUREL.',
                style: TextStyle(
                  color: AurelColors.muted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final tracks = controller.downloadedTracks;
    final storage = _storage;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Downloads',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh device storage',
              onPressed: _loadingStorage ? null : _loadStorage,
              icon: Icon(
                _loadingStorage ? Icons.sync_rounded : Icons.refresh_rounded,
                color: AurelColors.champagneLight,
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => controller.selectTab(4),
              icon: const Icon(
                Icons.settings_outlined,
                color: AurelColors.champagneLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          'Your music, ready when the signal is not.',
          style: TextStyle(color: AurelColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(17, 18, 17, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B3329), Color(0xFF1B1917)],
            ),
            border: Border.all(
              color: AurelColors.champagne.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Device Storage',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          storage == null
                              ? (_loadingStorage
                                  ? 'Checking phone storage...'
                                  : 'Storage details unavailable')
                              : '${DeviceStorageSnapshot.formatBytes(storage.usedBytes)} used of ${DeviceStorageSnapshot.formatBytes(storage.totalBytes)}',
                          style: const TextStyle(
                            color: AurelColors.champagneLight,
                            fontSize: 11,
                          ),
                        ),
                        if (storage != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            '${DeviceStorageSnapshot.formatBytes(storage.availableBytes)} available',
                            style: const TextStyle(
                              color: AurelColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: _StorageRing(
                      fraction: storage?.usedFraction ?? 0,
                      loading: _loadingStorage,
                      usedLabel: storage == null
                          ? '—'
                          : DeviceStorageSnapshot.formatBytes(
                              storage.usedBytes,
                            ),
                    ),
                  ),
                ],
              ),
              if (_storageError != null) ...[
                const SizedBox(height: 9),
                Text(
                  _storageError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE7A0A0),
                    fontSize: 10,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showStorageDetails(context, tracks.length),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AurelColors.champagneLight,
                    side: BorderSide(
                      color: AurelColors.champagne.withValues(alpha: 0.24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text('Manage Storage'),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Shows the whole phone storage, not only this app',
                style: TextStyle(
                  color: AurelColors.muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Downloaded Songs',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            Text(
              '${tracks.length}',
              style: const TextStyle(
                color: AurelColors.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tracks.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AurelColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.download_for_offline_outlined,
                  color: AurelColors.champagne,
                  size: 36,
                ),
                SizedBox(height: 10),
                Text(
                  'Nothing downloaded yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Explore music and save tracks that have downloads enabled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AurelColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          ...tracks.map(
            (track) => Dismissible(
              key: ValueKey(track.id),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B343A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                ),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (_) =>
                  context.read<AurelController>().removeDownload(track),
              child: TrackTile(
                track: track,
                queue: tracks,
                showDownload: false,
              ),
            ),
          ),
      ],
    );
  }
}

class _StorageRing extends StatelessWidget {
  const _StorageRing({
    required this.fraction,
    required this.loading,
    required this.usedLabel,
  });

  final double fraction;
  final bool loading;
  final String usedLabel;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StorageRingPainter(fraction: fraction),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AurelColors.champagneLight,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.download_rounded,
                    color: AurelColors.champagneLight,
                    size: 19,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usedLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Used',
                    style: TextStyle(
                      color: AurelColors.muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StorageRingPainter extends CustomPainter {
  const _StorageRingPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.5;
    final rect = Offset.zero & size;
    final ringRect = rect.deflate(stroke / 2);
    final background = Paint()
      ..color = const Color(0xFF776B5C).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final value = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          Color(0xFFF1D4A9),
          Color(0xFFD9BC91),
          Color(0xFF9C7951),
        ],
      ).createShader(ringRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 2, false, background);
    final safeFraction = fraction.clamp(0.0, 1.0).toDouble();
    canvas.drawArc(
      ringRect,
      -math.pi / 2,
      math.pi * 2 * safeFraction,
      false,
      value,
    );
  }

  @override
  bool shouldRepaint(covariant _StorageRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

class _StorageDetailRow extends StatelessWidget {
  const _StorageDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AurelColors.muted,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
