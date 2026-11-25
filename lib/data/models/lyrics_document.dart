import 'package:flutter/foundation.dart';

@immutable
class LyricsLine {
  const LyricsLine({required this.start, required this.text});
  final Duration start;
  final String text;
}

@immutable
class LyricsDocument {
  const LyricsDocument({
    required this.trackName,
    required this.artistName,
    this.albumName = '',
    this.durationSeconds = 0,
    this.instrumental = false,
    this.plainLyrics,
    this.lyricsCopyright,
    this.syncedLines = const [],
  });

  final String trackName;
  final String artistName;
  final String albumName;
  final int durationSeconds;
  final bool instrumental;
  final String? plainLyrics;
  final String? lyricsCopyright;
  final List<LyricsLine> syncedLines;

  bool get hasSyncedLyrics => syncedLines.isNotEmpty;
  bool get hasPlainLyrics => (plainLyrics ?? '').trim().isNotEmpty;
  bool get hasLyrics => hasSyncedLyrics || hasPlainLyrics;

  static List<LyricsLine> parseLrc(String source) {
    final timestamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final lines = <LyricsLine>[];
    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final matches = timestamp.allMatches(rawLine).toList(growable: false);
      if (matches.isEmpty) continue;
      final text = rawLine.replaceAll(timestamp, '').trim();
      if (text.isEmpty) continue;
      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fraction = match.group(3) ?? '';
        final milliseconds = fraction.isEmpty
            ? 0
            : int.tryParse(fraction.padRight(3, '0').substring(0, 3)) ?? 0;
        lines.add(
          LyricsLine(
            start: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            ),
            text: text,
          ),
        );
      }
    }
    lines.sort((a, b) => a.start.compareTo(b.start));
    return List.unmodifiable(lines);
  }
}
