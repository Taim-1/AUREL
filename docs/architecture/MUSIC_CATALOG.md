# AUREL Unified Music Catalogue

## Product goal

AUREL searches across every provider that can be integrated through an official, permitted interface and presents the results in one coherent in-app catalogue. The goal is broad discovery with a ranked best match—not a merged list of duplicate copies and not a single-provider catalogue.

## Search strategy

1. Start provider searches in parallel where allowed by each provider's API limits and terms.
2. Normalize provider results into a common catalogue model.
3. Identify same recordings and alternate editions without collapsing remixes, live versions, acoustic versions, explicit/clean editions, or remasters into the wrong item.
4. Rank matches using identity confidence, in-app playback availability, provider reliability, audio/metadata completeness, artwork quality, and user preference.
5. Prefer the strongest eligible source for the primary result.
6. Preserve distinct recordings and useful source alternatives internally; do not clutter the default result list with duplicate rows.
7. Cache metadata and artwork using provider-specific cache rules, TTLs, attribution and takedown requirements.

## Capability flags

Every provider result must separately represent:
- metadata availability
- artwork availability and attribution
- preview availability
- full in-app playback availability
- download permission for this exact recording
- lyrics availability and rights state
- user authorization / subscription requirements
- territory and account restrictions, if supplied by the provider

A metadata result is not automatically a playable track. A stream URL is not automatically a download permission. Never infer download rights from the presence of a URL.

## In-app experience

- Search, discovery, queue, player, lyrics, favourites, playlists and permitted downloads stay inside AUREL.
- Do not require opening another music app or browser to complete a core AUREL action.
- If a provider only offers metadata or an external playback handoff, do not show a misleading in-app Play or Download action. Keep the limitation clear, and exclude it from playable-only views when that is the user's selected filter.
- Do not extract, proxy, record, cache or re-host protected streams contrary to provider terms.
- Keep provider attribution and required branding where the provider requires it.

## Provider architecture

Each source is an independent adapter. Providers must not import or depend on other provider adapters.

Recommended boundaries:

- `providers/<provider>/`: API client, DTO parsing, auth and provider-specific policy checks.
- `domain/catalog/`: canonical track and artist entities, capabilities and source references.
- `domain/search/`: parallel search orchestration, ranking, de-duplication and pagination.
- `data/cache/`: provider-aware metadata and artwork cache.
- `data/repositories/`: persistence for favourites, playlists, downloads and history.

The existing Jamendo integration remains the first discovery adapter until each additional provider has passed API-access, terms, playback, attribution, rate-limit and Android integration checks.

## Initial ranking model

Ranking must be configurable, not a hard-coded promise that one brand always wins:

- Match confidence is the first gate.
- A lawful in-app full stream outranks a preview or metadata-only result.
- User-authorized sources and the user's explicit preference can raise a provider's rank.
- Provider quality and reliability break ties.
- A preview-only result must never outrank a full playable match merely because its provider is more famous.

## Security and operational rules

- No API secrets, access tokens, client secrets or private signing keys in Git.
- Use encrypted device storage only for user-side credentials that are permitted to live on-device; prefer a secure backend for production provider secrets.
- Respect OAuth scopes, token expiry, revocation, rate limits and retry-after headers.
- Use bounded parallelism, request timeouts, cancellation and exponential backoff.
- Do not scrape consumer app websites or undocumented endpoints.
- Every provider adapter requires unit tests using sanitized fixtures and integration tests against an authorized test account where available.

## Current repository baseline

The repository currently contains these adapters and capability boundaries:

| Provider | Current AUREL role | Playback in AUREL |
|---|---|---|
| SoundCloud | Search public playable tracks through the official API | Full in-app stream only when the API marks the track playable; approved app credentials required |
| Audius | Search and trending discovery | In-app stream for streamable tracks; API key improves permitted access |
| Jamendo | Search, popular and tag discovery | In-app stream; downloads only when `audiodownload_allowed` is true |
| Internet Archive | Search and resolve audio files with an explicitly recognized CC/Public Domain license | In-app stream and download only for accepted license metadata |
| Openverse | Search openly licensed audio and preserve attribution | In-app stream; download only for accepted reusable licenses |
| Apple Music | Catalog metadata and artwork | Metadata-only in the current Flutter player; no full-track URL |
| Spotify | Catalog metadata, ISRC and artwork | Metadata-only in the current Flutter player; no full-track URL |
| Musixmatch | Licensed lyrics lookup and timed subtitles | Lyrics only; separate from audio playback |

SoundCloud, Spotify and Apple Music server credentials are brokered by the Firebase callable HTTP endpoint in `functions/src/index.ts`; they must be configured in Firebase Secret Manager and the function must be deployed. Jamendo and Audius have separate build-time public API credentials. A source that is not configured must report an unavailable state rather than fabricate results.

Keep these capabilities distinct. Do not label metadata-only entries as playable or downloadable. Do not use Spotify or Apple Music metadata as evidence that AUREL can stream the recording. Keep all eligible playback, queueing, lyrics, and downloads inside AUREL.

## Provider onboarding checklist

Before adding a provider:
- Verify official API availability for an independent Android app.
- Verify commercial/non-commercial use restrictions and review requirements.
- Verify whether full audio can be played inside AUREL.
- Verify whether downloads are allowed and under what conditions.
- Verify required attribution and artwork rules.
- Verify account, subscription, territory and age restrictions.
- Record API limits, token rules, key storage, error formats and deprecation policy.
- Add tests for playable, preview-only, metadata-only, restricted and not-found responses.
