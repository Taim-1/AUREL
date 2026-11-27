import 'package:aurel/presentation/widgets/harmony_visualizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders the Harmony radial visualizer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: HarmonyVisualizer(
              isPlaying: false,
              position: Duration.zero,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(HarmonyVisualizer), findsOneWidget);
    expect(
      find.bySemanticsLabel('Harmony music visualizer'),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('animates while playing and remains mounted when paused', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: HarmonyVisualizer(
              isPlaying: true,
              position: Duration(seconds: 12),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: HarmonyVisualizer(
              isPlaying: false,
              position: Duration(seconds: 12),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HarmonyVisualizer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
