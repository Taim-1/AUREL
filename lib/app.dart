import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'core/theme/aurel_theme.dart';
import 'presentation/app_shell.dart';

class AurelApp extends StatelessWidget {
  const AurelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AUREL',
      debugShowCheckedModeBanner: false,
      theme: AurelTheme.dark,
      home: const _AurelEntry(),
    );
  }
}

class _AurelEntry extends StatefulWidget {
  const _AurelEntry();

  @override
  State<_AurelEntry> createState() => _AurelEntryState();
}

class _AurelEntryState extends State<_AurelEntry> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    unawaited(_finishSplash());
  }

  Future<void> _finishSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 1650));
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _showSplash
          ? const _AurelSplash(key: ValueKey('aurel-splash'))
          : const AppShell(key: ValueKey('aurel-home')),
    );
  }
}

class _AurelSplash extends StatelessWidget {
  const _AurelSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080809),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.15, -0.1),
                  radius: 1.05,
                  colors: [
                    AurelColors.champagne.withValues(alpha: 0.10),
                    const Color(0xFF111012),
                    const Color(0xFF080809),
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AurelColors.champagne.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AurelColors.champagne.withValues(alpha: 0.16),
                          blurRadius: 34,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/branding/aurel_app_icon.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'AUREL',
                    style: TextStyle(
                      fontFamily: 'serif',
                      color: AurelColors.champagneLight,
                      fontSize: 39,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 1,
                        color: AurelColors.champagne.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Feel the Music',
                        style: TextStyle(
                          color: Color(0xFFE5D7C4),
                          fontSize: 13,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 26,
                        height: 1,
                        color: AurelColors.champagne.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 42,
            right: 42,
            bottom: 58,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1450),
                curve: Curves.easeInOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 2,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(
                    AurelColors.champagne,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
