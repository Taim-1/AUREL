import 'package:aurel/data/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Track recording alternatives', () {
    test('keeps ranked same-recording alternatives through JSON restore', () {
      const preferred = Track(
        id: 'audius-1',
        title: 'A Song',
        artist: 'An Artist',
        providerId: 'audius',
        providerName: 'Audius',
        streamUrl: 'https://audio.example/preferred.mp3',
        isPlayable: true,
        alternatives: [
          Track(
            id: 'jamendo-2',
            title: 'A Song',
            artist: 'An Artist',
            providerId: 'jamendo',
            providerName: 'Jamendo',
            streamUrl: 'https://audio.example/alternative.mp3',
            isPlayable: true,
          ),
          Track(
            id: 'musicbrainz-3',
            title: 'A Song',
            artist: 'An Artist',
            providerId: 'musicbrainz',
            providerName: 'MusicBrainz',
            isPlayable: false,
            isMetadataOnly: true,
          ),
        ],
      );

      final restored = Track.fromJson(preferred.toJson());

      expect(restored.alternatives, hasLength(2));
      expect(restored.alternatives[0].providerId, 'jamendo');
      expect(restored.alternatives[0].canPlay, isTrue);
      expect(restored.alternatives[1].providerId, 'musicbrainz');
      expect(restored.alternatives[1].canPlay, isFalse);
      expect(restored.alternatives.every((item) => item.alternatives.isEmpty), isTrue);
    });

    test('copyWith can replace alternatives without changing track identity', () {
      const original = Track(
        id: 'audius-1',
        title: 'A Song',
        artist: 'An Artist',
        providerId: 'audius',
      );
      const alternative = Track(
        id: 'jamendo-2',
        title: 'A Song',
        artist: 'An Artist',
        providerId: 'jamendo',
      );

      final updated = original.copyWith(alternatives: const [alternative]);

      expect(updated.id, original.id);
      expect(updated.alternatives, [alternative]);
      expect(original.alternatives, isEmpty);
    });
  });
}
