import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/repositories/library_repository.dart';
import 'data/services/aurel_account_service.dart';
import 'data/services/aurel_controller.dart';
import 'data/catalog/providers/audius_service.dart';
import 'data/catalog/providers/apple_music_catalog_service.dart';
import 'data/services/catalog_token_service.dart';
import 'data/catalog/music_catalog_service.dart';
import 'data/catalog/providers/openverse_service.dart';
import 'data/catalog/providers/soundcloud_service.dart';
import 'data/catalog/providers/spotify_catalog_service.dart';
import 'data/services/download_service.dart';
import 'data/catalog/providers/jamendo_service.dart';
import 'data/services/lyrics_service.dart';
import 'data/catalog/providers/internet_archive_service.dart';
import 'data/catalog/providers/wikimedia_commons_service.dart';
import 'data/catalog/providers/music_brainz_service.dart';
import 'data/catalog/providers/lastfm_catalog_service.dart';
import 'data/catalog/providers/listenbrainz_catalog_service.dart';
import 'data/services/playback_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.aurel.music.playback',
    androidNotificationChannelName: 'AUREL Playback',
    androidNotificationChannelDescription: 'Music playback controls',
    androidNotificationIcon: 'drawable/ic_aurel_notification',
    notificationColor: const Color(0xFFD9BC91),
    androidNotificationOngoing: true,
  );

  // Apply the music-player audio policy after the media service is ready.
  // just_audio then handles focus interruptions and unplugged-headphone events.
  final audioSession = await AudioSession.instance;
  await audioSession.configure(const AudioSessionConfiguration.music());

  final preferences = SharedPreferencesAsync();
  final repository = LibraryRepository(preferences);
  final account = AurelAccountService();
  await account.initialize();

  final playback = PlaybackController();
  final jamendo = JamendoService(repository);
  final tokens = CatalogTokenService(account: account);
  final audius = AudiusService();
  final soundcloud = SoundCloudService(tokens: tokens);
  final spotify = SpotifyCatalogService(tokens: tokens);
  final appleMusic = AppleMusicCatalogService(tokens: tokens);
  final catalog = MusicCatalogService(
    jamendo: jamendo,
    audius: audius,
    soundcloud: soundcloud,
    spotify: spotify,
    appleMusic: appleMusic,
    openverse: OpenverseService(tokens: tokens),
    internetArchive: InternetArchiveService(),
    wikimediaCommons: WikimediaCommonsService(),
    musicBrainz: MusicBrainzService(),
    lastFm: LastFmCatalogService(),
    listenBrainz: ListenBrainzCatalogService(),
  );
  final controller = AurelController(
    repository: repository,
    jamendo: jamendo,
    downloads: DownloadService(),
    playback: playback,
    lyrics: LyricsService(),
    account: account,
    catalog: catalog,
  );

  runApp(
    ChangeNotifierProvider.value(
      value: controller,
      child: const AurelApp(),
    ),
  );
  unawaited(controller.initialize());
}
