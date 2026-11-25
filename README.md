# AUREL

AUREL is a premium Android music player built with Flutter. It combines independent-music discovery, a private offline collection, and a refined listening experience.

## Features

- Discover independent music and explore by mood or genre.
- Search tracks and artists with paginated results.
- Full player, compact mini-player, queue, shuffle, repeat, and background playback.
- Android media notification and lock-screen controls with album artwork and track metadata.
- Android equalizer, listening presets, playback speed, and sleep timer.
- Synced lyrics when the provider and account plan offer subtitles; plain licensed lyrics are the fallback.
- Tap a timed lyric line to seek to that moment in the song.
- Favourites, playlists, downloads, and Continue Listening history.
- Offline mode searches and plays only audio saved inside AUREL.

AUREL does not scan the device or import music from SnapTube or other apps. Downloads remain in AUREL's private storage and are allowed only when the track provider explicitly permits them.

## Brand assets

The approved champagne ribbon-A logo is used by the in-app brand mark, Android launcher icon, and splash screen.

## Setup

Use Flutter 3.50.1 stable (Dart 3.14).

```bash
flutter pub get
flutter run
```

The GitHub Actions workflow creates the Android scaffold, sets Android compile SDK 36 and minimum SDK 23, runs formatting, analysis and tests, builds the release APK, and uploads it as an artifact.

## Music catalogue

Jamendo supplies discovery and streaming from independent artists. It is not Spotify's or Apple Music's commercial catalogue. AUREL respects Jamendo's `audiodownload_allowed` field and the applicable artist licence. Before distribution, register your own Jamendo application and use a production client ID.

## Licensed lyrics

AUREL uses the official Musixmatch API. Add your own developer API key in **Profile → Licensed lyrics**. The key is stored in encrypted device storage and is never placed in the repository.

The API may return synchronized subtitles, plain lyrics, an instrumental result, or no match. Synchronized subtitles can depend on the account plan. AUREL checks exact track title and artist and does not show entries marked restricted.

For a public release, route provider requests through a secure backend rather than distribute a mobile API key.

## Android media notification

AUREL passes the track title, artist, album, duration, and artwork URI to the Android media session. Android renders the media notification and lock-screen controls; artwork availability depends on the source track's image URL and device notification settings.

## Build and distribute

Push to `main` or run **Actions → AUREL Android Build → Run workflow**. The generated artifact is for testing. Play Store publication requires a private signing keystore and production service configuration.
