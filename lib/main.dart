import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/repositories/library_repository.dart';
import 'data/services/aurel_controller.dart';
import 'data/services/device_library_service.dart';
import 'data/services/download_service.dart';
import 'data/services/jamendo_service.dart';
import 'data/services/playback_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.aurel.music.playback',
    androidNotificationChannelName: 'AUREL Playback',
    androidNotificationOngoing: true,
  );

  final preferences = SharedPreferencesAsync();
  final repository = LibraryRepository(preferences);
  final playback = PlaybackController();
  final jamendo = JamendoService(repository);
  final controller = AurelController(
    repository: repository,
    jamendo: jamendo,
    deviceLibrary: DeviceLibraryService(),
    downloads: DownloadService(),
    playback: playback,
  );

  runApp(
    ChangeNotifierProvider.value(
      value: controller,
      child: const AurelApp(),
    ),
  );
  unawaited(controller.initialize());
}
