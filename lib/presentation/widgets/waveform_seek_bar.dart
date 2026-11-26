import 'dart:math' as math;

// Paint must remain mutable because the active waveform assigns its shader.
// ignore_for_file: prefer_const_constructors

import 'package:material_ui/material_ui.dart';

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
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant WaveformSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isPlaying) {
      _glowController.repeat();
    } else {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
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

    return LayoutBuilder(
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
            height: 52,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) => CustomPaint(
                painter: _WaveformPainter(
                  progress: progress,
                  glow: widget.isPlaying ? _glowController.value : 0.28,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.glow,
  });

  final double progress;
  final double glow;

  static final List<double> _heights = List<double>.generate( sixtyBars, (i) {
    final primary = math.sin(i * 0.51 + 0.8).abs();
    final secondary = math.cos(i * 0.19 + 0.4).abs();
    final centerBoost = 0.28 + 0.72 * (1 - (i - 29.5).abs() / 30);
    return (0.16 + primary * 0.42 + secondary * 0.20) * centerBoost;
  }, growable: false);

  static const int sixtyBars = 60;

  @override
  void paint(Canvas canvas, Size size) {
    const topInset = 7.0;
    const bottomInset = 7.0;
    const maxBarHeight = 34.0;
    const nominalGap = 3.0;
    const nominalBarWidth = 2.3;
    final nominalWidth =
        sixtyBars * nominalBarWidth + (sixtyBars - 1) * nominalGap;
    final scale = math.min(1.0, size.width / nominalWidth);
    final gap = nominalGap * scale;
    final barWidth = nominalBarWidth * scale;
    final totalWidth = sixtyBars * barWidth + (sixtyBars - 1) * gap;
    final left = math.max(0.0, (size.width - totalWidth) / 2).toDouble();
    final usableHeight = size.height - topInset - bottomInset;
    final activeBars = (progress * sixtyBars).floor();

    final inactive = Paint()
      ..color = const Color(0xFF665B4C).withValues(alpha: 0.52)
      ..style = PaintingStyle.fill;
    final active = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF2D9B3),
          Color(0xFFD9BC91),
          Color(0xFF9C7951),
        ],
      ).createShader(Rect.fromLTWH(0, 0, barWidth, maxBarHeight));
    final halo = Paint()
      ..color = const Color(0xFFD9BC91).withValues(alpha: 0.16 + glow * 0.12)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + glow * 4);

    for (var i = 0; i < sixtyBars; i++) {
      final normalized = _heights[i];
      final height = math.max(4.5, usableHeight * normalized).toDouble();
      final x = left + i * (barWidth + gap);
      final y = topInset + (usableHeight - height) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, math.min(height, maxBarHeight)),
        const Radius.circular(2),
      );

      if (i == activeBars && progress > 0 && progress < 1) {
        canvas.drawRRect(rect, halo);
      }
      canvas.drawRRect(rect, i < activeBars ? active : inactive);
    }

    final playheadX = left + totalWidth * progress;
    final playheadPaint = Paint()
      ..color = const Color(0xFFFFE6C1)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final playheadGlow = Paint()
      ..color = const Color(0xFFD9BC91).withValues(alpha: 0.24 + glow * 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 + glow * 3);

    canvas.drawLine(
      Offset(playheadX, 3),
      Offset(playheadX, size.height - 3),
      playheadGlow..strokeWidth = 5,
    );
    canvas.drawLine(
      Offset(playheadX, 7),
      Offset(playheadX, size.height - 7),
      playheadPaint,
    );
    canvas.drawCircle(
      Offset(playheadX, size.height / 2),
      4,
      Paint()..color = const Color(0xFFFFE6C1),
    );
    canvas.drawCircle(
      Offset(playheadX, size.height / 2),
      7 + glow * 1.5,
      Paint()
        ..color = const Color(0xFFD9BC91)
            .withValues(alpha: 0.12 + glow * 0.07),
    );
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.glow != glow;
}
