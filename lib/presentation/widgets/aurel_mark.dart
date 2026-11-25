import 'package:flutter/material.dart';

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
          width: compact ? 34 : 42,
          height: compact ? 34 : 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 11 : 14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AurelColors.champagneLight,
                AurelColors.champagne,
                Color(0xFF8C6D49),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AurelColors.champagne.withValues(alpha: 0.16),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'A',
            style: TextStyle(
              color: const Color(0xFF15110C),
              fontFamily: 'serif',
              fontSize: compact ? 25 : 31,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
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
