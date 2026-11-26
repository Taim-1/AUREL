# AUREL

**AUREL — Feel the Music**

A premium Android music player built with Flutter, using the approved champagne-black ribbon-A identity.

## Build status

Release packaging is intentionally deferred while the app is being completed. GitHub Actions validates Firebase Functions, Dart formatting, Flutter analysis and tests, then compiles a debug Android App Bundle to catch Android/Gradle/plugin integration failures. It does not publish a release APK or attach a downloadable build.

## Features

- Unified discovery across eleven catalogue adapters: six playable-audio collections (subject to item rights) and five metadata indexes, including Last.fm discovery and ListenBrainz global popularity.
- In-app playback and queue from sources that authorize a playable audio stream.
- Deterministic song priority: local library, Audius, Jamendo, SoundCloud, Internet Archive, Wikimedia Commons, then Openverse; metadata-only fallbacks remain below playable audio.
- Broader artist-led discovery: Last.fm artist top tracks are federated with track search, deduplicated and kept metadata-only unless another provider supplies playable audio.
- Duplicate recordings collapse into one result while same-recording alternatives stay internal for automatic source fallback.
- Source ranking, ISRC matching, version-aware de-duplication, and provider attribution.
- Champagne waveform seek control, background playback, lock-screen controls, mini-player, shuffle and repeat.
- Licensed lyrics when the provider makes them available.
- Favourites, playlists, AUREL-managed offline downloads, offline mode and recently played history.
- User-selected AUREL username.
- Firebase email/password and Google account implementation with cloud library restore.
- The same approved AUREL ribbon-A artwork on splash and Android launcher icon.

AUREL does not scrape music sites, extract protected streams, record another app's playback, or hand off core playback to an external music app.

## Music catalogue and playback capability

AUREL presents one unified search and one in-app player. Provider names are not part of the normal listening screens; creator/licence credits required for individual works remain available in track details.

| Source | Purpose in AUREL | In-app audio |
|---|---|---|
| SoundCloud | Search playable tracks and match other provider results | Only tracks that the API marks playable; requires an approved SoundCloud app and server OAuth credentials |
| Audius | Search, trending, streaming and per-track download capability | Yes, when `is_streamable` is true; downloads only when `is_downloadable` is true |
| Jamendo | Independent music discovery and streaming | Yes; downloads only when the API permits that track |
| Openverse | Openly licensed music and creator metadata | Direct audio when supplied; download only for the enabled BY, BY-SA, CC0 or Public Domain Mark licences |
| Internet Archive | Audio collection discovery | Only public audio files with an explicit accepted licence in item metadata |
| Wikimedia Commons | Open audio files | Direct audio with CC BY, CC BY-SA, CC0 or Public Domain metadata; creator credit is retained |
| MusicBrainz | Recording metadata and ISRC matching | Metadata only; one request per second and non-commercial API terms |
| Last.fm | Global track discovery, popular charts, artwork and track context | Metadata only; requires `LASTFM_API_KEY`; never supplies AUREL playback audio |
| ListenBrainz | Site-wide popular recordings and community listening statistics | Metadata only; public popularity index, not a full audio catalogue |
| Spotify | Commercial-catalogue metadata and ISRC matching | Metadata only in this AUREL player; no Spotify protected audio is copied into AUREL |
| Apple Music | Commercial-catalogue metadata and recording matching | Metadata only in this AUREL player; native Apple Music playback is not enabled in this build |

**Song priority:** playable local/device copies come first, followed by Audius, Jamendo, SoundCloud, Internet Archive, Wikimedia Commons and Openverse. Apple Music, Spotify, Last.fm, ListenBrainz and MusicBrainz are metadata-only fallbacks and never outrank playable audio. Metadata completeness breaks ties within the same source tier.

**Important:** a catalogue match is not automatically a playable track. AUREL prefers the strongest eligible in-app stream for the same recording. Spotify and Apple Music metadata can help identify a recording, while an authorized SoundCloud, Audius, Jamendo or openly licensed copy supplies the audio. Live, remix, acoustic and alternate versions are kept distinct.

Providers that expose only an embed widget, restricted metadata, or unsupported consumer-app endpoints are not represented as custom-player streams. Mixcloud's widget-only playback, unsupported Free Music Archive endpoints, and undocumented Bandcamp/YouTube Music scraping are deliberately not used.

## Internal catalogue setup

See [Music catalogue architecture](docs/architecture/MUSIC_CATALOG.md) and [Firebase/provider setup](docs/setup/FIREBASE_AUTH_AND_SYNC.md).

- Jamendo: register an AUREL application and set `JAMENDO_CLIENT_ID`.
- Audius: public catalogue access is used; an `AUDIUS_API_KEY` can be supplied to improve the authorized API rate limit.
- SoundCloud: register an approved application and configure `SOUNDCLOUD_CLIENT_ID` and `SOUNDCLOUD_CLIENT_SECRET` in Firebase Secret Manager.
- Spotify: configure a developer app and its credentials in Firebase Secret Manager. API availability is subject to Spotify's current developer access rules.
- Apple Music: configure an Apple developer MusicKit key, team ID and private key in Firebase Secret Manager.
- Openverse: anonymous read access works by default; optional registered API credentials can be stored in Firebase Secret Manager for its authenticated rate-limit tier.
- Wikimedia Commons and Internet Archive: public read APIs are used with per-item licence and request-policy checks.
- MusicBrainz: public non-commercial read API; requests are serialized to one per second.
- Last.fm: the adapter is **disabled by default**. Last.fm's API terms require non-commercial use unless a separate commercial-use agreement is granted; public pages using its data require prior written approval, an approved AudioScrobbler attribution button linking to Last.fm, appropriate track/artist/album catalogue links, response-header-aware caching and storage below the 100 MB cap. Obtain and retain Last.fm's written approval and its approved brand asset before enabling the integration. Only then set `LASTFM_API_KEY` and `LASTFM_API_APPROVED=true` as GitHub Actions secrets (or pass both Dart defines locally). The API key is a public client identifier embedded in the app; do not put a Last.fm API secret in the APK. AUREL deliberately omits Last.fm requests unless both the key and explicit approval flag are present.
- ListenBrainz: its public site-wide statistics endpoint adds a community popularity signal without an API key. It contributes metadata only; the player still needs a separately authorized audio source.
- Firebase email/Google accounts and cloud restore: create the Firebase project, enable sign-in methods, apply `firestore.rules`, add GitHub Actions secrets and deploy the token-broker function.

If a provider or account credential is absent, AUREL shows that source as unavailable and continues using the remaining configured sources. It never shows a fake successful sign-in or a false Play/Download action.

## Account restore

Signing in with the same AUREL account restores saved usernames, favourites, playlists and the recently played track list (up to 100 items). Downloaded audio bytes are kept in the app's private storage and are removed by Android when the app is uninstalled. After reinstall, AUREL restores the track metadata and history; audio must be downloaded again only if the provider allows it.

## Project structure

The catalogue coordinator lives in `lib/data/catalog/music_catalog_service.dart`; each independent adapter lives in `lib/data/catalog/providers/`. Account, playback, download, lyrics and device services remain in `lib/data/services/`. See [Project structure](docs/architecture/PROJECT_STRUCTURE.md).

## Local development

Use Flutter 3.50.1 stable (Dart 3.14). The Android Gradle project is generated from the installed Flutter SDK so its wrapper and plugin versions stay aligned, then AUREL's reviewed native resources are applied:

```bash
bash tool/bootstrap_android.sh
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
flutter run
```

The same bootstrap and icon-generation steps run in CI. CI also compiles a debug Android App Bundle as a platform integration check; it is not published or attached as a release download. No APK or release build is published.

Android build configuration is generated by the GitHub Actions workflow with compile SDK 36 and minimum SDK 23. CI validates Firebase Functions TypeScript, checks Dart formatting, and runs Flutter analysis and tests. Release packaging will be reintroduced after the app passes the product acceptance checks.

For stable production updates, configure a private Android upload/signing keystore through GitHub Actions secrets. Test builds without that keystore use the generated debug signing configuration and may need a reinstall when the signing key changes.
