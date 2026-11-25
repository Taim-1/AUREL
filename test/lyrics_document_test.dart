import 'package:aurel/data/models/lyrics_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LyricsDocument.parseLrc', () {
    test('orders timed lines and parses fractional timestamps', () {
      final lines = LyricsDocument.parseLrc(
        '[00:10.25]Later line\n[00:02.5]First line\n[00:03]Second line',
      );
      expect(lines, hasLength(3));
      expect(lines[0].text, 'First line');
      expect(lines[0].start, const Duration(milliseconds: 2500));
      expect(lines[1].start, const Duration(seconds: 3));
      expect(lines[2].start, const Duration(seconds: 10, milliseconds: 250));
    });

    test('supports multiple timestamps on one subtitle line', () {
      final lines = LyricsDocument.parseLrc('[00:01.00][00:04.25]A line');
      expect(lines, hasLength(2));
      expect(lines[0].start, const Duration(seconds: 1));
      expect(lines[1].start, const Duration(seconds: 4, milliseconds: 250));
    });
  });
}
