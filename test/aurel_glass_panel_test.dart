import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aurel/presentation/widgets/aurel_glass_panel.dart';

void main() {
  testWidgets('renders a clipped glass surface around its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AurelGlassPanel(
              child: Text('AUREL glass surface'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('AUREL glass surface'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);
  });
}
