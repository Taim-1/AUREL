# AUREL Unified Music Catalogue

## Product goal

AUREL searches every provider that can be integrated through an official, permitted interface and presents the matches in one coherent in-app catalogue. The goal is broad discovery with ranked eligible playback—not a merged wall of duplicate copies and not one provider pretending to own every recording.

## Current source matrix

| Provider | Adapter | Capability in this build | Requirements and limits |
|---|---|---|---|
| SoundCloud | `soundcloud_service.dart` | Search, playable-track check, authorized in-app stream, per-track download flag, attribution | SoundCloud application approval and server-side OAuth client credentials. Blocked tracks are excluded. Preserve creator/source credit and platform attribution |
| Audius | `audius_service.dart` | Search, trending, stream and download capability flags | Public API access; optional AUREL API key improves service limits. Stream only when `is_streamable`; download only when `is_downloadable` |
| Jamendo | `jamendo_service.dart` | Popular, tag and search, direct playback | Use a registered production client ID. Respect `audiodownload_allowed` and the item licence |
| Openverse | `openverse_service.dart` | Audio discovery, direct file URL, creator and licence attribution | Filtered to music; accepted reuse/download licences are BY, BY-SA, CC0 and Public Domain Mark. NC, ND and unknown licences are not marked downloadable |
| Internet Archive | `internet_archive_service.dart` | Advanced Search plus per-item metadata/file resolution | Only public audio files with an explicit accepted Creative Commons or Public Domain Mark licence are returned as playable/downloadable |
| Spotify | `spotify_catalog_service.dart` | Search metadata, ISRC, title, artist, album, artwork and duration | Metadata only. The Spotify Web API does not expose arbitrary protected audio to AUREL's custom player. Developer-mode access/allowlist restrictions may apply |
| Apple Music | `apple_music_catalog_service.dart` | Storefront-aware search metadata, ISRC, title, artist, artwork and duration | Metadata only. MusicKit playback requires separate Apple developer credentials, user authorization and applicable subscription entitlements; it is not enabled in this custom player yet |

The search orchestrator launches eligible catalogue searches in parallel, catches per-provider failures independently, records which sources responded, matches by ISRC when present, otherwise matches normalized title/artist plus a duration bucket, and ranks playable tracks above metadata-only matches. Unicode title/artist normalization preserves international writing systems. Live, remix, acoustic and alternate editions are not flattened into one result.

For a duplicate recording, a playable source is selected and the names of other matching catalogues remain attached to the track. Spotify and Apple metadata can improve identification, but the player only starts an authorized stream from a source that actually supplies one to AUREL.

## Download policy

- A stream URL is not a download licence.
- Jamendo uses its per-track `audiodownload_allowed` field.
- Audius uses `is_downloadable`.
- SoundCloud uses the API's `downloadable` field and download URL.
- Openverse only marks the accepted reusable licences downloadable.
- Internet Archive only exposes eligible public files after checking item-level `licenseurl`.
- Spotify and Apple Music metadata entries are never downloadable.
- Device-private audio and authorization headers are never copied into cloud library data.

## In-app experience

Search, discovery, queue, player, lyrics, favourites, playlists and permitted downloads stay inside AUREL. Provider source details open in AUREL's HTTPS WebView; no core playback action launches another music app.

A provider result is represented by separate fields for metadata, artwork, source attribution, preview/full playback, download permission, licence and user authorization. A metadata result is not automatically playable. A preview-only result is not treated as a full recording.

## Providers deliberately not presented as custom streams

- Spotify App Remote controls the Spotify application and would break AUREL's one-player requirement; Spotify API results are used for metadata matching only.
- Apple Music metadata API results are not treated as audio. MusicKit player integration is a separate future native Android authorization/subscription project.
- Mixcloud provides an embedded widget player rather than a normal custom-player stream.
- Free Music Archive's older public API and hotlink route are not treated as a supported current playback API.
- Bandcamp, YouTube Music and other consumer websites are not scraped, and undocumented endpoints are not used.
- Deezer/other catalogues that require restricted developer access are not marked integrated until an approved official API and in-app playback capability are established.

## Secure provider credentials

The app never contains Spotify, SoundCloud or Apple private client secrets. It requests short-lived tokens from the authenticated Firebase Function `catalogTokens`. The function verifies the Firebase ID token, applies a per-user request limit, reads secrets from Firebase Secret Manager, caches short-lived tokens in memory and returns only the provider token required by the client.

Required Firebase Secret Manager names are documented in `docs/setup/FIREBASE_AUTH_AND_SYNC.md`. Missing credentials cause that provider to report a clear unavailable state; other sources continue to work.

## Performance and reliability

- Bounded parallel provider search through the source adapters.
- Separate request timeouts and provider-specific error messages.
- Per-provider pagination and cancellation tokens where supported.
- ISRC-based de-duplication with Unicode title/artist fallback and duration bucket.
- No external-app playback handoff.
- No stream extraction, proxying, re-hosting or downloading where not allowed.
- Provider-specific caching/attribution rules must be maintained when additional sources are onboarded.

## Onboarding checklist for any new source

1. Confirm an official API is available for third-party Android apps.
2. Confirm app registration, developer approval, authentication scopes and rate limits.
3. Verify in-app full-stream capability, not just metadata, preview or an external-app link.
4. Verify per-track download rights and territory/user-plan restrictions.
5. Capture ISRC, source permalink, creator, artwork and attribution requirements.
6. Add a source adapter without coupling it to other adapters.
7. Add sanitized parser/rights tests and an authorized integration test.
8. Add the source to ranking only after its capabilities are verified.
