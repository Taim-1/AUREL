import 'package:aurel/presentation/widgets/waveform_seek_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders the integrated Harmony progress waveform', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: WaveformSeekBar(
                position: Duration(seconds: 24),
                duration: Duration(seconds: 120),
                isPlaying: false,
                onSeek: _ignoreSeek,
              ),
            ),
          ),
        ),
      ),
    );

    final seekBar = find.byType(WaveformSeekBar);
    expect(seekBar, findsOneWidget);
    expect(find.bySemanticsLabel('Harmony playback progress'), findsOneWidget);
    expect(
      find.descendant(
        of: seekBar,
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping the Harmony waveform seeks to the tapped position', (
    tester,
  ) async {
    Duration? requestedPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: WaveformSeekBar(
                position: Duration.zero,
                duration: const Duration(seconds: 120),
                isPlaying: false,
                onSeek: (value) => requestedPosition = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.byType(WaveformSeekBar)));

    expect(requestedPosition, const Duration(seconds: 60));
  });

  testWidgets('Harmony movement pauses cleanly with playback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: WaveformSeekBar(
                position: Duration(seconds: 12),
                duration: Duration(seconds: 120),
                isPlaying: true,
                onSeek: _ignoreSeek,
              ),
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
            child: SizedBox(
              width: 300,
              child: WaveformSeekBar(
                position: Duration(seconds: 12),
                duration: Duration(seconds: 120),
                isPlaying: false,
                onSeek: _ignoreSeek,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

void _ignoreSeek(Duration _) {}
