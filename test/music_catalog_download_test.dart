import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:aurel/data/catalog/music_catalog_service.dart';
import 'package:aurel/data/catalog/providers/apple_music_catalog_service.dart';
import 'package:aurel/data/catalog/providers/audius_service.dart';
import 'package:aurel/data/catalog/providers/internet_archive_service.dart';
import 'package:aurel/data/catalog/providers/jamendo_service.dart';
import 'package:aurel/data/catalog/providers/lastfm_catalog_service.dart';
import 'package:aurel/data/catalog/providers/listenbrainz_catalog_service.dart';
import 'package:aurel/data/catalog/providers/music_brainz_service.dart';
import 'package:aurel/data/catalog/providers/openverse_service.dart';
import 'package:aurel/data/catalog/providers/soundcloud_service.dart';
import 'package:aurel/data/catalog/providers/spotify_catalog_service.dart';
import 'package:aurel/data/catalog/providers/wikimedia_commons_service.dart';
import 'package:aurel/data/models/track.dart';
import 'package:aurel/data/repositories/library_repository.dart';
import 'package:aurel/data/services/aurel_account_service.dart';
import 'package:aurel/data/services/catalog_token_service.dart';

MusicCatalogService createCatalog() {
  final tokens = CatalogTokenService(account: AurelAccountService());
  return MusicCatalogService(
    jamendo: JamendoService(
      LibraryRepository(SharedPreferencesAsync()),
    ),
    audius: AudiusService(),
    soundcloud: SoundCloudService(tokens: tokens),
    spotify: SpotifyCatalogService(tokens: tokens),
    appleMusic: AppleMusicCatalogService(tokens: tokens),
    openverse: OpenverseService(tokens: tokens),
    internetArchive: InternetArchiveService(),
    wikimediaCommons: WikimediaCommonsService(),
    musicBrainz: MusicBrainzService(),
    lastFm: LastFmCatalogService(),
    listenBrainz: ListenBrainzCatalogService(),
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('MusicCatalogService.prepareTrackForDownload', () {
    test('selects an eligible same-recording alternative when primary is stream-only', () async {
      const primary = Track(
        id: 'audius-42',
        title: 'Golden Hour',
        artist: 'Aurel Artist',
        providerId: 'audius',
        providerName: 'Audius',
        streamUrl: 'https://audio.example/golden-hour.mp3',
        downloadAllowed: false,
        alternatives: [
          Track(
            id: 'jamendo-42',
            title: 'Golden Hour',
            artist: 'Aurel Artist',
            providerId: 'jamendo',
            providerName: 'Jamendo',
            streamUrl: 'https://audio.example/golden-hour.mp3',
            downloadUrl: 'https://audio.example/golden-hour-download.mp3',
            downloadAllowed: true,
          ),
        ],
      );

      final prepared = await createCatalog().prepareTrackForDownload(primary);

      expect(prepared.id, primary.id);
      expect(prepared.providerId, 'jamendo');
      expect(
        prepared.downloadUrl,
        'https://audio.example/golden-hour-download.mp3',
      );
      expect(prepared.downloadAllowed, isTrue);
      expect(prepared.alternatives, isEmpty);
    });

    test('prefers the primary recording when it permits a direct download', () async {
      const primary = Track(
        id: 'jamendo-43',
        title: 'Night Drive',
        artist: 'Aurel Artist',
        providerId: 'jamendo',
        downloadUrl: 'https://audio.example/night-drive.mp3',
        downloadAllowed: true,
        alternatives: [
          Track(
            id: 'audius-43',
            title: 'Night Drive',
            artist: 'Aurel Artist',
            providerId: 'audius',
            downloadUrl: 'https://audio.example/alternative.mp3',
            downloadAllowed: true,
          ),
        ],
      );

      final prepared = await createCatalog().prepareTrackForDownload(primary);

      expect(prepared.id, primary.id);
      expect(prepared.providerId, 'jamendo');
      expect(prepared.downloadUrl, primary.downloadUrl);
    });

    test('does not prepare a metadata-only track or an insecure alternative', () async {
      const primary = Track(
        id: 'spotify-44',
        title: 'Afterglow',
        artist: 'Aurel Artist',
        providerId: 'spotify',
        isMetadataOnly: true,
        downloadUrl: '',
        downloadAllowed: false,
        alternatives: [
          Track(
            id: 'jamendo-44',
            title: 'Afterglow',
            artist: 'Aurel Artist',
            providerId: 'jamendo',
            downloadUrl: 'http://audio.example/afterglow.mp3',
            downloadAllowed: true,
          ),
        ],
      );

      await expectLater(
        createCatalog().prepareTrackForDownload(primary),
        throwsA(isA<CatalogPlaybackException>()),
      );
    });
  });
}
