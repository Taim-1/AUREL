import 'dart:math' as math;

// Paint uses a fresh shader per frame to keep the Harmony spectrum smooth.
// ignore_for_file: prefer_const_constructors

import 'package:material_ui/material_ui.dart';

import '../../core/theme/aurel_theme.dart';

/// A seekable champagne waveform with the Harmony visual style built in.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final ValueChanged<Duration> onSeek;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _harmonyMotion;

  @override
  void initState() {
    super.initState();
    _harmonyMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant WaveformSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (widget.isPlaying) {
      _harmonyMotion.repeat();
    } else {
      _harmonyMotion.stop();
    }
  }

  @override
  void dispose() {
    _harmonyMotion.dispose();
    super.dispose();
  }

  void _seekAt(double dx, double width) {
    if (width <= 0 || widget.duration <= Duration.zero) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    widget.onSeek(
      Duration(
        milliseconds: (widget.duration.inMilliseconds * fraction).round(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = math.max(1, widget.duration.inMilliseconds);
    final positionMs = widget.position.inMilliseconds.clamp(0, durationMs);
    final progress = positionMs / durationMs;
    final positionPhase = positionMs / 900;

    return Semantics(
      label: 'Harmony playback progress',
      value: '${(progress * 100).round()} percent',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _seekAt(details.localPosition.dx, constraints.maxWidth),
            onHorizontalDragUpdate: (details) => _seekAt(
              details.localPosition.dx,
              constraints.maxWidth,
            ),
            child: SizedBox(
              height: 58,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _harmonyMotion,
                builder: (context, _) => CustomPaint(
                  painter: _HarmonyProgressPainter(
                    progress: progress,
                    phase: positionPhase + _harmonyMotion.value * math.pi * 2,
                    isPlaying: widget.isPlaying,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HarmonyProgressPainter extends CustomPainter {
  const _HarmonyProgressPainter({
    required this.progress,
    required this.phase,
    required this.isPlaying,
  });

  final double progress;
  final double phase;
  final bool isPlaying;

  static const int _barCount = 64;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    const topInset = 8.0;
    const bottomInset = 8.0;
    const maxBarHeight = 38.0;
    const nominalBarWidth = 2.2;
    const nominalGap = 1.9;

    final nominalWidth =
        _barCount * nominalBarWidth + (_barCount - 1) * nominalGap;
    final scale = math.min(1.0, size.width / nominalWidth);
    final barWidth = nominalBarWidth * scale;
    final gap = nominalGap * scale;
    final totalWidth = _barCount * barWidth + (_barCount - 1) * gap;
    final left = math.max(0.0, (size.width - totalWidth) / 2).toDouble();
    final centerY = size.height / 2;
    final usableHeight = size.height - topInset - bottomInset;
    final activeCount = (progress * _barCount).floor().clamp(0, _barCount);

    final inactivePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF766B5D).withValues(alpha: 0.44);
    final activePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF5E3C8),
          Color(0xFFD9BC91),
          Color(0xFF9C7951),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final activeGlow = Paint()
      ..style = PaintingStyle.fill
      ..color = AurelColors.champagne.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    for (var index = 0; index < _barCount; index++) {
      final mirroredIndex = math.min(index, _barCount - 1 - index);
      final distanceFromCenter = mirroredIndex / (_barCount / 2);
      final centerEnvelope = 0.74 + 0.26 * (1 - distanceFromCenter);

      final slowWave = math.sin(index * 0.27 + phase * 0.82);
      final fineWave = math.cos(index * 0.49 - phase * 0.56);
      final stillWave = math.sin(index * 0.34 + 0.7);
      final motion = isPlaying
          ? 0.52 + slowWave * 0.19 + fineWave * 0.10
          : 0.52 + stillWave * 0.07;
      final normalized = (0.28 + motion * 0.72) * centerEnvelope;
      final barHeight = (usableHeight * normalized)
          .clamp(5.0, maxBarHeight)
          .toDouble();

      final x = left + index * (barWidth + gap);
      final y = centerY - barHeight / 2;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      if (index < activeCount) {
        canvas.drawRRect(
          barRect,
          activeGlow
            ..color = AurelColors.champagne.withValues(
              alpha: isPlaying ? 0.09 : 0.035,
            ),
        );
        canvas.drawRRect(barRect, activePaint);
      } else {
        canvas.drawRRect(barRect, inactivePaint);
      }
    }

    final playheadX = left + totalWidth * progress;
    final playheadGlow = Paint()
      ..color = AurelColors.champagne.withValues(
        alpha: isPlaying ? 0.24 : 0.13,
      )
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final playhead = Paint()
      ..color = const Color(0xFFFFE9CA)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(playheadX, 5),
      Offset(playheadX, size.height - 5),
      playheadGlow,
    );
    canvas.drawLine(
      Offset(playheadX, 7),
      Offset(playheadX, size.height - 7),
      playhead,
    );
    canvas.drawCircle(
      Offset(playheadX, centerY),
      3.4,
      Paint()..color = const Color(0xFFFFE9CA),
    );
  }

  @override
  bool shouldRepaint(covariant _HarmonyProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.isPlaying != isPlaying;
}
