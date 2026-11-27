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
| Playable audio | `providers/openverse_service.dart` | Openly licensed music audio, creator, artwork and licence information; anonymous access works by default, with optional registered OAuth credentials for the authenticated rate-limit tier |
| Playable audio | `providers/internet_archive_service.dart` | Public audio items after metadata/file checks and an accepted item-level licence |
| Playable audio | `providers/wikimedia_commons_service.dart` | Direct audio files with an explicit CC BY, CC BY-SA, CC0 or Public Domain licence; credits and description link retained |
| Metadata only | `providers/spotify_catalog_service.dart` | Commercial recording metadata, artwork, duration and ISRC matching; no protected audio in AUREL's custom player |
| Metadata only | `providers/apple_music_catalog_service.dart` | Storefront-aware track metadata and ISRC matching; native MusicKit playback is not enabled in this Android build |
| Metadata only | `providers/music_brainz_service.dart` | Recording metadata, artist credit, duration and ISRC; non-commercial API use and one-request-per-second limit |
| Metadata only | `providers/lastfm_catalog_service.dart` | Track search, global top-track charts, artist top tracks, artist names, artwork, duration and Last.fm links; requires both an API key and explicit terms-approval flag; never supplies audio |
| Metadata only | `providers/listenbrainz_catalog_service.dart` | Public site-wide top-recording statistics, recording/release MBIDs and listening popularity; metadata only, no audio stream |

Last.fm is disabled by default and requires both `LASTFM_API_KEY` and `LASTFM_API_APPROVED=true`. Its API terms require non-commercial use unless a separate written commercial-use agreement is granted; public pages using its data require prior written approval, an approved AudioScrobbler button linked to Last.fm, track/artist/album catalogue links, response-header-aware caching, and storage below 100 MB. Obtain approval and the permitted attribution asset before setting the flag. AUREL labels Last.fm records as metadata-only and deliberately excludes them from the generic catalogue cache.

The provider adapters live in one folder. Playback, account, AUREL-managed offline downloads and lyrics services remain in `lib/data/services/`. The Downloads tab is exclusively for tracks saved from inside AUREL; it does not scan, import, or list the phone's unrelated music files.

## Search and ranking

The search orchestrator:

1. Queries independent catalogue adapters with bounded results and per-source failure isolation.
2. Applies per-source pagination and request cancellation where supported.
3. Queries one public open-audio page in the same federated request batch, so the user does not wait for a second network round trip.
4. Queries Last.fm track search, artist top tracks and global charts as metadata-only results; these records can enrich discovery but can never enter the playback queue as audio.
5. Queries ListenBrainz site-wide popular recordings for global discovery; this popularity index is metadata-only and does not represent a complete recording database.
6. Queries the recording metadata catalogue through a single serialized one-request-per-second queue.
7. Matches exact MusicBrainz recording MBIDs first, then exact ISRCs; MBIDs and ISRCs are stored as separate identifiers.
8. Falls back to normalized title, artist and a duration difference of no more than five seconds, while preserving version labels such as Live, Remix and Acoustic.
9. Does not merge uncertain recordings when both verified identifiers and useful duration/album data are missing.
10. Ranks playable audio above metadata-only results. A match in a metadata catalogue never creates a fake audio URL.
11. Selects the best duplicate by deterministic priority: playable local/device copy, then Audius, Jamendo, SoundCloud, Internet Archive, Wikimedia Commons and Openverse. Metadata-only fallbacks follow Apple Music, Spotify, Last.fm, ListenBrainz and MusicBrainz.
12. Uses recording identity first for grouping; within each duplicate group, source priority selects the playback copy and metadata completeness breaks ties inside the same source tier.

## Source priority and quality

The priority order is internal and deterministic; it is not exposed as a provider picker in the listening UI. A playable local/device file wins first. Online playable sources then follow Audius → Jamendo → SoundCloud → Internet Archive → Wikimedia Commons → Openverse. Metadata-only discovery follows Apple Music → Spotify → Last.fm → ListenBrainz → MusicBrainz and can never outrank a playable recording. Within one source tier, richer verified recording identity, artwork, album, duration, source link and eligible download/licence metadata break ties. A lower-priority source cannot displace a higher-priority playable source merely because it has more artwork or metadata. All same-recording copies remain attached as internal alternatives rather than appearing as duplicate search results. If the preferred source fails during preparation or playback, AUREL retries the next eligible copy in priority order while keeping the visible queue entry as one song; it must not change the recording/version.

## Playback and download rights

- A catalogue page, artwork URL, preview URL, widget, or metadata record is not automatically a full playable recording.
- SoundCloud blocked/preview-only entries are not treated as full tracks. Creator/platform credit and the original work link remain in track details when required.
- Audius uses the response's streamable and downloadable flags.
- Jamendo requires a real registered application client ID for production; the public sample client ID is test-only and is not included as the release default.
- Openverse searches only the accepted reusable licence set currently enabled by this build.
- Internet Archive items are resolved individually. Only public audio files with an explicit accepted licence are exposed.
- Wikimedia Commons audio is accepted only when the item's metadata identifies CC BY, CC BY-SA, CC0 or Public Domain. The adapter uses a descriptive User-Agent, caches query pages and makes one bounded search request per page.
- A MusicBrainz recording is metadata only. Its recording MBID and any supplied ISRC are separate exact matching identifiers; neither supplies an audio stream.
- Spotify and Apple Music metadata are not treated as audio. The Spotify Web API does not expose protected source audio for AUREL to copy into its own player. Apple Music playback requires the separate native MusicKit authorization and entitlement path.
- Audio is downloaded only when the item-level permission and licence allow it. A stream URL by itself is not permission to download.

## No external-app handoff and no scraping

Search, queue, player, lyrics, favourites, playlists, offline downloads and history remain inside AUREL. The offline Downloads collection contains only copies explicitly downloaded through AUREL from eligible catalogue entries; it is not a file manager for the device. The core Play action never hands the user to another music application. AUREL does not scrape consumer websites, extract protected streams, copy protected audio, proxy copyrighted audio, or bypass access controls.

An external provider name is not part of the normal Home/Search/Player/Profile experience. Source/creator attribution that is required by the relevant licence or platform terms remains available in track details.

## Deliberately not treated as playable

A catalogue that supplies only a widget, restricted metadata, previews, or undocumented endpoints is not represented as a playable AUREL source. That includes unsupported consumer-site scraping and sources whose access terms do not authorize a custom in-app player. A new adapter must pass the checklist below before it can enter the playable ranking.

## Credentials and environment

- Jamendo needs a registered read application ID in `JAMENDO_CLIENT_ID`.
- Audius can use public read access; an `AUDIUS_API_KEY` improves service limits.
- SoundCloud uses server-held OAuth credentials through the Firebase token broker.
- Spotify and Apple private credentials stay in Firebase Secret Manager and are never embedded in Dart or APK resources.
- MusicBrainz requires no API key for ordinary non-commercial read access, but its request-rate and User-Agent rules must be respected.
- Last.fm requires a registered API key supplied as `LASTFM_API_KEY` at build time. The key enables metadata search and charts only; it does not grant audio playback or download rights.
- ListenBrainz site-wide statistics are read from its public HTTPS API. Popularity data is a discovery signal, not a full music catalogue or an audio source.
- Openverse supports anonymous API access; registered client credentials may be used for its authenticated rate-limit tier. Anonymous access remains the fallback when credentials are absent.
- Wikimedia Commons and Internet Archive are public catalogues with their own access, licence and rate policies.

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
