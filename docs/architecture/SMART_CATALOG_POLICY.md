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
| 10 | Last.fm | Track search, artist discovery and popularity metadata only |
| 11 | ListenBrainz | Community listening-popularity metadata only |
| 12 | MusicBrainz | Recording/artist metadata only |

Downloaded copies are created only by AUREL's in-app download action when the item and provider explicitly permit offline saving. The Downloads tab lists only those AUREL-managed copies; it is not a phone-file browser or device-music importer. This is a product fallback order, not a claim that every item from a source is legally playable or has superior audio quality. Track-level eligibility and verified audio quality always override the default rank.

## Deduplication rules

1. Prefer a matching MusicBrainz recording MBID when both entries expose one.
2. Otherwise prefer an exact ISRC match when both entries expose one.
3. If both verified MBIDs conflict and no exact ISRC agrees, keep the entries separate.
4. A provider's identical stable track ID is the same provider record, even when duration metadata is missing.
5. Without a shared verified identifier, require normalized title + normalized credited artist + duration difference of no more than five seconds.
6. Preserve meaningful version qualifiers: Live, Remix, Acoustic, Radio Edit, Remaster, Demo, Instrumental, and similar labels.
7. Do not merge different recordings merely because title and artist match.
8. When duration is absent or unreliable and no exact recording identifier exists, keep separate entries rather than risk a false merge.
9. If both entries have ISRCs and they differ, never merge them through title/duration fallback.
10. Choose the best eligible playable candidate using: playback eligibility, local-copy preference, deterministic source priority, then metadata completeness within the same source tier.
11. Preserve matched catalogue identifiers internally for diagnostics and future fallback, but do not display provider names as user-facing labels.
12. Metadata-only matches may enrich an existing recording (artist spelling, album, artwork, ISRC or recording MBID) but must not replace a playable candidate.

## Search result presentation

- One row/card per recording identity.
- One canonical title, artist credit, album, artwork, and duration.
- Play is enabled only when a playable canonical copy, a same-recording playable alternative, or an AUREL-managed local copy exists.
- Queue and fallback logic must never change the recording/version identity.
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

The catalogue collects multiple providers with per-source failure isolation, groups matches through `lib/data/catalog/catalog_identity.dart`, enriches missing descriptive metadata, selects one eligible playable candidate, and places metadata-only results after playable recordings. The ranking rules are centralized in `lib/data/catalog/catalog_ranking.dart`; same-recording alternatives are retained for controlled fallback. Last.fm is a gated metadata adapter and is omitted unless the API key and written-approval flag are present. Its artwork is not reused, its data is excluded from the generic catalogue cache, and public use still requires the provider-approved attribution button and catalogue links. The automated CI suite validates the current model, ranking, identity, provider parser and Android debug-build paths; real provider authorization, item rights and account-specific services still require their credentials and approval before a public release.


## Device library priority and privacy

Android MediaStore tracks are local playable copies, ranked ahead of all online providers. They are queried only after the user opens Library → Songs and grants the scoped audio permission. AUREL uses MediaStore content URIs directly, excludes Snaptube paths, and does not copy, move, modify, or upload device audio. AUREL-managed downloads remain a separate local tier and the only entries in the Downloads tab. When Offline mode is active, playback, search, queue and fallback are restricted to currently playable on-device tracks and AUREL-managed downloads.
