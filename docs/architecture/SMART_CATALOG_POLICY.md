# AUREL Smart Catalogue Policy

This document defines the product-level rules for combining catalogues without exposing a provider directory to the listener.

## Non-negotiable user experience

- Search results represent recordings, not providers. A recording must appear once even if several catalogues describe it.
- Provider names, logos, source badges, provider counts, and provider-specific search tabs must not be presented as AUREL navigation or branding.
- Selecting a playable result opens AUREL's own Now Playing experience. Do not automatically launch a browser or another music app.
- A provider may require legally mandatory attribution or a prescribed playback surface. AUREL must respect those terms; if they conflict with the in-app experience, disable that integration rather than hide required attribution or bypass the provider's rules.
- A metadata-only match is never represented as playable and must never receive an active Play action.

## Internal source preference

The current deterministic preference in `MusicCatalogService` is:

| Rank | Source | Intended role |
|---:|---|---|
| 1 | Previously downloaded AUREL offline copy | Highest priority for a recording already saved through AUREL |
| 2 | Audius | Eligible in-app streams where the specific recording and API terms permit |
| 3 | Jamendo | Licensed catalogue streams where the account/API terms permit |
| 4 | SoundCloud | Only tracks and playback methods explicitly allowed by the integration |
| 5 | Internet Archive | Item-by-item rights and file validation required |
| 6 | Wikimedia Commons | Item-by-item license and attribution validation required |
| 7 | Openverse | Discovery/indexing; verify the underlying work and license before playback/download |
| 8 | Apple Music catalogue metadata | Metadata fallback; not a free stream |
| 9 | Spotify catalogue metadata | Metadata fallback; not a free stream |
| 10 | MusicBrainz | Recording/artist metadata only |

Downloaded copies are created only by AUREL's in-app download action when the item and provider explicitly permit offline saving. The Downloads tab lists only those AUREL-managed copies; it is not a phone-file browser or device-music importer. This is a product fallback order, not a claim that every item from a source is legally playable or has superior audio quality. Track-level eligibility and verified audio quality always override the default rank.

## Deduplication rules

1. Prefer exact ISRC matches when present.
2. Without ISRC, require normalized title + normalized credited artist + a close duration match.
3. Preserve meaningful version qualifiers: Live, Remix, Acoustic, Radio Edit, Remaster, Demo, Instrumental, and similar labels.
4. Do not merge different recordings merely because title and artist match.
5. When duration is absent or unreliable and no exact recording identifier exists, keep separate entries rather than risk a false merge.
6. Choose the best eligible playable candidate using: playback eligibility, verified recording identity, artwork availability, duration metadata, then source preference.
7. Preserve matched catalogue identifiers internally for diagnostics and future fallback, but do not display provider names as user-facing labels.
8. Metadata-only matches may enrich an existing recording (artist spelling, album, artwork, ISRC) but must not replace a playable candidate.

## Search result presentation

- One row/card per recording identity.
- One canonical title, artist credit, album, artwork, and duration.
- Play is enabled only when `Track.canPlay` is true.
- If no legal in-app stream exists, present the recording as unavailable in AUREL rather than opening a third-party page.
- Distinguish genuine alternate recordings (live/remix/acoustic/etc.) as separate versions.
- Source counts and per-provider errors belong in developer diagnostics, not the consumer UI.

## Engineering safeguards

- Never scrape protected streams, bypass DRM, reuse leaked credentials, defeat paywalls, or remove mandatory attribution.
- Keep API credentials out of source control and client-visible logs.
- Validate the actual playback URL and authorization immediately before playback.
- Download only when the item-level license and provider terms explicitly allow it.
- Validate successful HTTP status, reject explicit non-audio content types, and inspect the downloaded file signature before saving. Write to a temporary file and only promote a verified audio payload into AUREL's offline library.
- Treat catalogue metadata, artwork, audio streams, and download permission as separate capabilities.
- Re-review each provider's current developer terms before release.

## Current implementation note

The catalogue currently collects multiple providers in parallel, groups matches, selects one candidate, and puts playable results before metadata-only results. The ranking table above is implemented as an internal preference in `lib/data/catalog/music_catalog_service.dart`. This policy document does not claim that all provider rights checks, UI hiding, or in-app playback constraints have already been fully audited or tested.
