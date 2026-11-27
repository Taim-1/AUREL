import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/aurel_theme.dart';

/// AUREL's single Harmony visual style: a compact radial equalizer.
class HarmonyVisualizer extends StatefulWidget {
  const HarmonyVisualizer({
    super.key,
    required this.isPlaying,
    required this.position,
  });

  final bool isPlaying;
  final Duration position;

  @override
  State<HarmonyVisualizer> createState() => _HarmonyVisualizerState();
}

class _HarmonyVisualizerState extends State<HarmonyVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant HarmonyVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (widget.isPlaying) {
      _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positionPhase = widget.position.inMilliseconds / 900;

    return Semantics(
      label: 'Harmony music visualizer',
      child: SizedBox(
        width: 108,
        height: 108,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              return CustomPaint(
                painter: _HarmonyPainter(
                  phase: positionPhase + (_motion.value * math.pi * 2),
                  isPlaying: widget.isPlaying,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HarmonyPainter extends CustomPainter {
  const _HarmonyPainter({
    required this.phase,
    required this.isPlaying,
  });

  final double phase;
  final bool isPlaying;

  static const int _barCount = 52;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.46;
    final innerRadius = radius * 0.56;

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AurelColors.champagne.withValues(alpha: 0.13);

    canvas.drawCircle(center, radius * 0.96, orbitPaint);
    canvas.drawCircle(
      center,
      innerRadius * 0.82,
      orbitPaint
        ..color = AurelColors.champagneLight.withValues(alpha: 0.09),
    );

    final softHalo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = AurelColors.champagne.withValues(
        alpha: isPlaying ? 0.12 + (math.sin(phase) + 1) * 0.035 : 0.10,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, radius * 0.83, softHalo);

    for (var index = 0; index < _barCount; index++) {
      final angle = (index / _barCount) * math.pi * 2 - math.pi / 2;
      final waveA = math.sin(index * 0.31 + phase * 1.12);
      final waveB = math.cos(index * 0.17 - phase * 0.76);
      final waveC = math.sin(index * 0.59 + phase * 0.43);
      final envelope = 0.58 + 0.42 * (0.5 + 0.5 * math.sin(index * 0.12));
      final motion = isPlaying ? 0.5 + waveA * 0.22 + waveB * 0.13 : 0.52;
      final barLength = (5.5 + (waveC * 0.5 + motion) * 14.5) * envelope;
      final startRadius = innerRadius;
      final endRadius = startRadius + barLength.clamp(4.0, 22.0);

      final start = Offset(
        center.dx + math.cos(angle) * startRadius,
        center.dy + math.sin(angle) * startRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * endRadius,
        center.dy + math.sin(angle) * endRadius,
      );

      final major = index % 4 == 0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = major ? 2.0 : 1.35
        ..color = index % 3 == 0
            ? AurelColors.champagneLight.withValues(alpha: 0.82)
            : AurelColors.champagne.withValues(alpha: 0.72);

      canvas.drawLine(start, end, paint);
    }

    final centerDisk = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF171615);
    canvas.drawCircle(center, innerRadius * 0.70, centerDisk);

    final centerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AurelColors.champagne.withValues(alpha: 0.48);
    canvas.drawCircle(center, innerRadius * 0.70, centerRing);

    final centerGlow = Paint()
      ..color = AurelColors.champagne.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(center, innerRadius * 0.48, centerGlow);

    final equalizer = Paint()
      ..color = AurelColors.champagneLight
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;
    const heights = [7.0, 13.0, 18.0, 11.0, 6.0];
    for (var index = 0; index < heights.length; index++) {
      final x = center.dx - 9 + index * 4.5;
      final halfHeight = heights[index] / 2;
      canvas.drawLine(
        Offset(x, center.dy - halfHeight),
        Offset(x, center.dy + halfHeight),
        equalizer,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HarmonyPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.isPlaying != isPlaying;
}
