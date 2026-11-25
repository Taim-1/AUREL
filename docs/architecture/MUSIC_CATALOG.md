# AUREL unified music catalogue

## Goal

AUREL combines compatible music discovery and playback into one catalogue and one player. The user sees AUREL rather than a provider selector. Source identity remains internal for authorization, ranking, error isolation, deduplication, licence checks and the credits that a creator/platform requires.

The word "source" is not equivalent to "playable track". The catalogue distinguishes three capabilities:

- **Playable audio** — a permitted direct stream can be started inside AUREL.
- **Downloadable audio** — the item-level response and licence explicitly permit an offline copy.
- **Metadata only** — recording information can improve discovery and matching but cannot be sent to the audio player.

## Current adapters

| Capability group | Adapter location | What it contributes |
|---|---|---|
| Playable audio | `providers/soundcloud_service.dart` | Public tracks that the API explicitly marks playable, with OAuth stream resolution and required creator/platform credit |
| Playable audio | `providers/audius_service.dart` | Track search and trending; streams only when `is_streamable`; downloads only when `is_downloadable` |
| Playable audio | `providers/jamendo_service.dart` | Independent music catalogue and direct audio; respects the registered application ID and per-track `audiodownload_allowed` |
| Playable audio | `providers/openverse_service.dart` | Openly licensed music audio, creator, artwork and licence information |
| Playable audio | `providers/internet_archive_service.dart` | Public audio items after metadata/file checks and an accepted item-level licence |
| Playable audio | `providers/wikimedia_commons_service.dart` | Direct audio files with an explicit CC BY, CC BY-SA, CC0 or Public Domain licence; credits and description link retained |
| Metadata only | `providers/spotify_catalog_service.dart` | Commercial recording metadata, artwork, duration and ISRC matching; no protected audio in AUREL's custom player |
| Metadata only | `providers/apple_music_catalog_service.dart` | Storefront-aware track metadata and ISRC matching; native MusicKit playback is not enabled in this Android build |
| Metadata only | `providers/music_brainz_service.dart` | Recording metadata, artist credit, duration and ISRC; non-commercial API use and one-request-per-second limit |

The provider adapters live in one folder. Playback, account, local library, download and lyrics services remain in `lib/data/services/`.

## Search and ranking

The search orchestrator:

1. Queries independent catalogue adapters with bounded results and per-source failure isolation.
2. Applies per-source pagination and request cancellation where supported.
3. Queries the public open-audio adapter sequentially after the other source batch, respecting its concurrency guidance.
4. Queries the recording metadata catalogue through a single serialized one-request-per-second queue.
5. Matches exact ISRCs first.
6. Falls back to normalized title, artist and a duration bucket while preserving version labels such as Live, Remix and Acoustic.
7. Does not merge uncertain recordings when both ISRC and useful duration/album data are missing.
8. Ranks playable audio above metadata-only results. A match in a metadata catalogue never creates a fake audio URL.

## Playback and download rights

- A catalogue page, artwork URL, preview URL, widget, or metadata record is not automatically a full playable recording.
- SoundCloud blocked/preview-only entries are not treated as full tracks. Creator/platform credit and the original work link remain in track details when required.
- Audius uses the response's streamable and downloadable flags.
- Jamendo requires a real registered application client ID for production; the public sample client ID is test-only and is not included as the release default.
- Openverse searches only the accepted reusable licence set currently enabled by this build.
- Internet Archive items are resolved individually. Only public audio files with an explicit accepted licence are exposed.
- Wikimedia Commons audio is accepted only when the item's metadata identifies CC BY, CC BY-SA, CC0 or Public Domain. The adapter uses a descriptive User-Agent, caches queries, and avoids fanning out concurrent API requests.
- A MusicBrainz recording is metadata only. It can supply an ISRC for matching but cannot supply an audio stream.
- Spotify and Apple Music metadata are not treated as audio. The Spotify Web API does not expose protected source audio for AUREL to copy into its own player. Apple Music playback requires the separate native MusicKit authorization and entitlement path.
- Audio is downloaded only when the item-level permission and licence allow it. A stream URL by itself is not permission to download.

## No external-app handoff and no scraping

Search, queue, player, lyrics, favourites, playlists, offline downloads and history remain inside AUREL. The core Play action never hands the user to another music application. AUREL does not scrape consumer websites, extract protected streams, copy protected audio, proxy copyrighted audio, or bypass access controls.

An external provider name is not part of the normal Home/Search/Player/Profile experience. Source/creator attribution that is required by the relevant licence or platform terms remains available in track details.

## Deliberately not treated as playable

A catalogue that supplies only a widget, restricted metadata, previews, or undocumented endpoints is not represented as a playable AUREL source. That includes unsupported consumer-site scraping and sources whose access terms do not authorize a custom in-app player. A new adapter must pass the checklist below before it can enter the playable ranking.

## Credentials and environment

- Jamendo needs a registered read application ID in `JAMENDO_CLIENT_ID`.
- Audius can use public read access; an `AUDIUS_API_KEY` improves service limits.
- SoundCloud uses server-held OAuth credentials through the Firebase token broker.
- Spotify and Apple private credentials stay in Firebase Secret Manager and are never embedded in Dart or APK resources.
- MusicBrainz requires no API key for ordinary non-commercial read access, but its request-rate and User-Agent rules must be respected.
- Openverse, Wikimedia Commons and Internet Archive are public catalogues with their own access, licence and rate policies.

Missing credentials make the related adapter unavailable; other sources continue. Production credentials are described in `docs/setup/FIREBASE_AUTH_AND_SYNC.md`.

## New-source checklist

1. Confirm an official, currently supported API or feed.
2. Confirm third-party Android app access, terms, developer approval, scopes and rate limits.
3. Confirm full in-app audio playback—not merely metadata, a preview or a web widget.
4. Confirm per-track download permission and the exact licence.
5. Preserve recording ID/ISRC, version, artist, album, duration, artwork, source permalink and mandatory attribution.
6. Isolate the adapter in `lib/data/catalog/providers/`.
7. Add parser, licence, failure and pagination tests.
8. Add the adapter to ranking only after its real capabilities are verified.
