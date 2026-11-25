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
7. Downloads: storage summary and downloaded-song list with clear completed states.
8. Profile: circular profile image, TAIM identity, Music Lover subtitle, concise settings rows and AUREL information.

## Navigation and interaction

- Keep the user inside AUREL for supported search, playback, lyrics, queue, favourites, playlists and downloads.
- Keep one persistent mini player above the bottom navigation when a track is active.
- Bottom navigation order: Home, Search, Library, Downloads, Profile.
- Every visible control must perform a real action. Never add decorative controls that appear functional but do nothing.
- Do not send the user to another music app or browser to complete an essential AUREL flow. If a provider cannot lawfully provide playback inside AUREL, represent that limitation honestly rather than presenting a fake Play button.

## Change control

A visual change that materially departs from the supplied reference requires explicit owner approval. Prefer implementation corrections, spacing refinements, responsive layout fixes, and functional completion over new design ideas.
