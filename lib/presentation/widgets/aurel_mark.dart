import 'package:material_ui/material_ui.dart';

import '../../core/theme/aurel_theme.dart';

class AurelMark extends StatelessWidget {
  const AurelMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 38 : 46,
          height: compact ? 38 : 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 12 : 15),
            boxShadow: [
              BoxShadow(
                color: AurelColors.champagne.withValues(alpha: 0.18),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/branding/aurel_app_icon.jpg',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'AUREL',
          style: TextStyle(
            color: AurelColors.champagneLight,
            fontSize: compact ? 16 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: compact ? 3 : 4,
          ),
        ),
      ],
    );
  }
}
