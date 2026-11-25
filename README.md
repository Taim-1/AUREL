# AUREL

AUREL is a premium-styled Flutter music player for Android, built around two clear music sources:

- **Your device library** — scan audio indexed by Android MediaStore and play it locally.
- **Jamendo discovery** — search and stream independent music through Jamendo's official API.

The app includes background playback and lock-screen controls, favorites, downloads (only when the artist/API explicitly permits them), a persistent mini-player, and an offline downloads library.

## Design

AUREL uses a deep charcoal canvas with restrained champagne-metallic accents, generous spacing, rounded surfaces, and a custom AUREL mark. The interface is designed for phones first.

## Run locally

Use Flutter **3.50.1 stable** (Dart 3.14). The app uses Flutter's standalone `material_ui` package.

```bash
flutter create --platforms=android --org com.aurel --project-name aurel .
flutter pub get
flutter run
```

The native Android integration is in `platform/android/`. After generating the Android scaffold, copy the bridge and manifest:

```bash
mkdir -p android/app/src/main/kotlin/com/aurel/aurel
cp platform/android/MainActivity.kt android/app/src/main/kotlin/com/aurel/aurel/
cp platform/android/AndroidManifest.xml android/app/src/main/
```

Set `compileSdk = 35` in `android/app/build.gradle.kts` to satisfy the current permission plugin. The GitHub Actions workflow performs this setup automatically.

## Jamendo API

Jamendo requires an application `client_id` for API requests. A public read-only testing ID is used as a development fallback so the discovery screens can be exercised; replace it with your own app ID before distributing AUREL:

1. Register an application in the [Jamendo Developer Portal](https://devportal.jamendo.com/).
2. Set `JAMENDO_CLIENT_ID` as a GitHub Actions repository secret for release builds, or pass it locally:

```bash
flutter run --dart-define=JAMENDO_CLIENT_ID=your_client_id
```

The app also allows changing the client ID in Profile settings. It is an API identifier, not a user password. Never commit private account credentials.

Jamendo track responses include `audiodownload_allowed`. AUREL only enables the download action when this value is true and a download URL is present. Streaming and download availability depend on the track, its rights, and Jamendo's service.

## Android permissions

AUREL requests audio-library permission only when the user chooses **Scan device**. Android 13+ uses `READ_MEDIA_AUDIO`; Android 12 and earlier use `READ_EXTERNAL_STORAGE`. Downloads are stored inside AUREL's private app documents directory and do not require broad storage access.

## Build

Push to `main` or run **Actions → AUREL Android Build → Run workflow**. The workflow runs dependency resolution, static analysis, tests, and a release APK build, then uploads the APK as a workflow artifact.

The generated release APK uses Flutter's default debug signing configuration. For Play Store publication, configure a private upload keystore and signing secrets.

## Project structure

- `lib/data/models` — track model and serialization
- `lib/data/services` — Jamendo, MediaStore, playback, and downloads
- `lib/data/repositories` — local preferences and library state
- `lib/presentation` — app shell, screens, and reusable UI
- `platform/android` — native Android MediaStore bridge and audio manifest template
- `.github/workflows` — CI and APK build

## Rights and catalog scope

AUREL does not scrape Spotify, Apple Music, YouTube, or DRM-protected sources. Jamendo provides independent music under track-specific terms; it is not the same catalog as Spotify or Apple Music. AUREL can also play music already stored on the user's device.
