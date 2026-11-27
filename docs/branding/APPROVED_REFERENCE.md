# AUREL — Approved Visual Reference

## Authority

The owner-approved AUREL showcase image supplied in the project conversation is the visual source of truth. It is not a mood board. It defines the V1 product appearance.

Do not redesign, reinterpret, recolor, or replace the identity with a different visual direction. Any implementation work must match this reference as closely as the native Android layout allows.

## Brand lock

- Product name: AUREL
- Tagline: Feel the Music
- Mark: the approved champagne ribbon-shaped capital A already stored at `assets/branding/aurel_app_icon.jpg`
- Primary surfaces: near-black / charcoal
- Brand accents: champagne gold, warm silver, restrained warm highlights
- Typography: clean, high-contrast, elegant sans-serif; generous spacing and clear hierarchy
- Shape language: rounded cards, soft edges, restrained borders and glow
- Do not replace the brand mark with a generic music note or a different monogram.
- Do not introduce a new dominant color palette.
- Do not add visual clutter, promotional banners, or extra navigation that is absent from the reference.

## Required screen composition

1. Splash: centered approved A mark, AUREL wordmark, “Feel the Music”, dark cinematic background and a restrained loading indicator.
2. Home: greeting, compact search field, featured music card, “Browse by Category” three-column grid, mini player and five-item bottom navigation.
3. Search: single search field, trending search chips, artist discovery and playlist discovery in a vertically organized dark screen.
4. Now Playing: large square artwork, track and artist metadata, favourite/action controls, progress and transport controls, lyrics entry point.
5. Library: “Your Library”, horizontal tabs for Playlists / Liked Songs / Albums / Artists, compact artwork rows.
6. Playlist detail: prominent cover artwork, title, creator/track count, play action and track list.
7. Downloads: AUREL-only offline-download summary and downloaded-song list with clear completed states.
8. Profile: circular profile image, TAIM identity, Music Lover subtitle, concise settings rows and AUREL information.

## Navigation and interaction

- Keep the user inside AUREL for supported search, playback, lyrics, queue, favourites, playlists and downloads.
- Keep one persistent mini player above the bottom navigation when a track is active.
- Bottom navigation order: Home, Search, Library, Downloads, Profile.
- Every visible control must perform a real action. Never add decorative controls that appear functional but do nothing.
- Do not send the user to another music app or browser to complete an essential AUREL flow. If a provider cannot lawfully provide playback inside AUREL, represent that limitation honestly rather than presenting a fake Play button.

## Change control

A visual change that materially departs from the supplied reference requires explicit owner approval. Prefer implementation corrections, spacing refinements, responsive layout fixes, and functional completion over new design ideas.

## Owner-approved refinements (2026-11-25)

These refinements extend the screen reference without changing its composition:

- Downloads is exclusively for audio downloaded from inside AUREL and stored in AUREL-managed app storage. Do not show whole-phone storage usage, browse device files, import unrelated local music, or scan shared storage.
- The player progress control is a champagne waveform/equalizer-style scrubber with a moving playhead and soft animated glow. It replaces a plain straight progress line while remaining seekable.
- The Android launcher icon must use the same approved ribbon-A app artwork, not a generic music icon.
- The display name is user-selected. The sample “TAIM” in the reference is placeholder copy, not a hard-coded account name.
- Google and email/password sign-in are provided inside AUREL Settings → Account & Sync. The Profile main screen keeps the reference layout.
- Account sync restores listening-history metadata, favourites and playlists after reinstall. App-private downloaded audio bytes are not cloud-restored; AUREL offers a new download only if the original provider allows it.
- If cloud credentials are not configured for a build, show an honest setup state and retain local account-name selection; never display fake successful sign-in.


## Owner clarification (2026-11-26)

The Downloads clarification above supersedes any earlier visual note suggesting a whole-device storage ring. The Downloads screen reports only the number of tracks saved inside AUREL and manages those offline copies; it is not a device storage dashboard or local-file importer.

## Owner-approved visual refinement (2026-11-27)

The updated AUREL screen image supplied on 2026-11-27 extends the existing reference; it does not replace the fixed brand identity.

- Keep the same ribbon-A mark, AUREL wordmark, “Feel the Music” tagline, near-black surfaces and champagne-gold accents.
- Introduce a restrained glass treatment only on selected high-value surfaces: the Home/Search entry, Search field, mini player, bottom navigation dock, Profile identity panel, Downloads summary and Now Playing artwork rim.
- Glass uses a dark translucent charcoal tint, a modest backdrop blur, a fine warm champagne edge and a very soft highlight. Text and controls must remain crisp and readable.
- Do not blur the whole screen, add a new theme selector, introduce a dominant new colour, or apply glass to every card.
- “TAIM” in the reference image remains sample identity text; display the account's chosen username.
- The Downloads area remains limited to audio downloaded inside AUREL. Do not copy the reference mockup's whole-device storage meter or add phone-wide scanning/importing; continue to report only AUREL-managed offline items.
