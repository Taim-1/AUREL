# AUREL

AUREL is a carefully designed Android music player built with Flutter. It combines licensed independent-music discovery with a private offline collection that belongs to the app.

## What is included

- Discover popular independent music and explore by mood or tag.
- Search artists and tracks, with paginated results rather than a small fixed catalogue window.
- Stream tracks with album artwork and metadata.
- Full player with seeking, shuffle, repeat, previous/next, and a compact mini-player.
- Android equalizer with adjustable frequency bands and listening presets, playback speed controls, and a sleep timer.
- Background playback, media notification, lock-screen controls, and headset media buttons.
- Favourites and user-created playlists, saved locally.
- Offline downloads stored in AUREL's private app storage, only for tracks whose artist/API setting explicitly permits downloading.
- A one-tap Offline mode that filters browsing and playback to AUREL downloads only.
- A locally saved Continue Listening row that remembers the last 20 tracks.

AUREL intentionally does **not** scan the phone or import tracks from other apps. Music downloaded through AUREL stays in AUREL's private collection.

## Design

AUREL uses a deep charcoal canvas, restrained silver/champagne accents, rounded surfaces, a custom adaptive Android icon, and a matching splash screen.

## Run locally

Use Flutter **3.50.1 stable** (Dart 3.14). The UI uses Flutter's standalone `material_ui` package.

```bash
flutter create --platforms=android --org com.aurel --project-name aurel .
flutter pub get
```

Copy the Android integration files:

```bash
mkdir -p android/app/src/main/kotlin/com/aurel/aurel
cp platform/android/MainActivity.kt android/app/src/main/kotlin/com/aurel/aurel/
cp platform/android/AndroidManifest.xml android/app/src/main/
cp -R platform/android/res/. android/app/src/main/res/
```

Set `compileSdk = 36` in `android/app/build.gradle.kts`. The included GitHub Actions workflow performs the Android scaffold and resource setup automatically.

## Jamendo API

Jamendo requires an application `client_id` for API requests. AUREL uses Jamendo's public read-only test ID only as a development fallback. Before distributing the app, register your own application in the [Jamendo Developer Portal](https://devportal.jamendo.com/).

You can pass the ID at build time:

```bash
flutter run --dart-define=JAMENDO_CLIENT_ID=your_client_id
```

Or enter it in AUREL's Profile settings. A client ID is an application identifier, not a password. Do not commit private credentials to the repository.

Jamendo's track response includes `audiodownload_allowed`. AUREL only enables downloads when that value is true and a download URL is provided. Track availability and use remain subject to the artist's Creative Commons licence and Jamendo's API terms.

## Build an APK

Push to `main` or run **Actions → AUREL Android Build → Run workflow**. The workflow installs the Android SDK, generates the Android scaffold, runs Dart formatting, static analysis and tests, builds a release APK, and uploads it as a workflow artifact.

The generated APK is for direct testing and uses Flutter's default debug signing configuration. Play Store distribution requires a private upload keystore and signing secrets. Do not publish the development Jamendo test ID as a production app configuration.

## Project structure

- `lib/data/models` — track and playlist models
- `lib/data/services` — Jamendo API, playback, and downloads
- `lib/data/repositories` — local favourites, playlists, downloads, and settings
- `lib/presentation` — app shell, screens, and reusable UI
- `platform/android` — audio-service activity, manifest, icon, and splash resources
- `.github/workflows` — CI and APK build

## Catalogue scope

AUREL does not scrape Spotify, Apple Music, YouTube, or DRM-protected sources. Jamendo is a different catalogue of independent artists; it is not the commercial catalogue of Spotify or Apple Music.
