import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/aurel_theme.dart';

/// A restrained glass surface for a small number of important AUREL panels.
///
/// The blur is clipped to the panel itself, so the rest of the interface stays
/// crisp and easy to read. The default tint keeps text contrast high on OLED
/// screens while the champagne edge and sheen provide a subtle premium finish.
class AurelGlassPanel extends StatelessWidget {
  const AurelGlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.radius = 20,
    this.blur = 15,
    this.tint = AurelColors.glassSurface,
    this.borderColor = AurelColors.glassEdge,
    this.shadowOpacity = 0.12,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final double blur;
  final Color tint;
  final Color borderColor;
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: AurelColors.champagne.withValues(alpha: shadowOpacity),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x1FFFFFFF),
                  Color(0x0DFFFFFF),
                  Color(0x09000000),
                ],
                stops: [0, 0.46, 1],
              ),
              border: Border.all(color: borderColor, width: 0.85),
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
