# AUREL project structure

AUREL is organized by responsibility. Presentation code does not call provider APIs, provider adapters do not depend on Flutter widgets, and playback does not know how catalogue search is implemented.

```text
AUREL/
├── .github/workflows/             # Verification CI; release packaging deferred
├── assets/branding/               # Approved AUREL identity artwork
├── docs/
│   ├── architecture/              # Project, catalogue and ranking contracts
│   ├── branding/                  # Approved visual reference
│   └── setup/                     # Firebase and credential setup
├── functions/src/                 # Server-side short-lived catalogue tokens
├── lib/
│   ├── core/theme/                 # Fixed Champagne Noir design system
│   ├── data/
│   │   ├── catalog/
│   │   │   ├── catalog_identity.dart
│   │   │   ├── catalog_ranking.dart
│   │   │   ├── local_track_priority.dart
│   │   │   └── music_catalog_service.dart
│   │   │   └── providers/          # One isolated adapter per catalogue
│   │   ├── models/                 # Track, playlist and lyrics models
│   │   ├── repositories/           # Local library and user-state persistence
│   │   └── services/               # Playback, downloads, lyrics, account, tokens
│   ├── presentation/
│   │   ├── screens/                # Home, Search, Library, Player, Downloads
│   │   ├── widgets/                # Shared artwork, player and list components
│   │   └── app_shell.dart
│   ├── app.dart
│   └── main.dart                   # Dependency composition and startup
├── platform/android/               # Reviewed Android manifest, activity and resources
├── tool/bootstrap_android.sh       # Generate Gradle project and apply AUREL Android files
├── test/                            # Model, identity and service tests
├── firestore.rules
├── firebase.json
└── pubspec.yaml
```

## Dependency direction

- Presentation depends on the controller and models; it never calls a catalogue API directly.
- `AurelController` coordinates user actions and local state.
- `MusicCatalogService` coordinates adapters, error isolation, canonical identity, deduplication and ranking.
- `CatalogIdentity` owns cross-source recording matching and is covered by unit tests.
- AUREL's local-first playback selection lives in `lib/data/catalog/local_track_priority.dart`. It replaces a matching online catalogue row with a valid device/download URI while keeping only same-recording playable online alternatives available for automatic recovery.
- Each provider adapter converts one external API into the shared `Track` model.
- Repositories own persistence. Provider adapters never write to user libraries.
- Playback, account, downloads and lyrics services remain independent from catalogue adapters.

## Adding a catalogue source

1. Create one adapter in `lib/data/catalog/providers/`.
2. Normalize results to `Track`, including real recording ID/ISRC, duration, artwork, licence, attribution and playback capability.
3. Mark metadata-only and preview-only items as non-playable. Never invent a stream URL.
4. Set download permission only when the item-level API and rights response explicitly allow it.
5. Add the adapter to `MusicCatalogService` and dependency composition in `main.dart`.
6. Add parser, licence, failure, pagination and identity tests; update catalogue documentation.
7. Keep provider identity internal. Required creator/licence attribution remains available in track details.
8. Verify official API access, Android app terms, rate limits and current playback/download rights before enabling it.

## Library and offline boundary

The Library → Songs tab is the permission-gated, read-only Android MediaStore view. AUREL requests `READ_MEDIA_AUDIO` (or `READ_EXTERNAL_STORAGE` on Android 12 and below) only when the user opens Songs, queries music entries in the background, excludes Snaptube paths and plays `content://media/...` URIs in place. It never copies, moves, edits or uploads device audio. The Downloads tab remains separate and contains only items saved through AUREL into app-managed storage; it is not a whole-device storage dashboard.

## Verification and release

GitHub Actions validates Firebase Functions, generates the Android Gradle project, generates the approved launcher icon, formats Dart sources, runs Flutter analysis and tests, then compiles a non-published debug Android App Bundle. Release packaging and APK publication remain deferred until product acceptance checks are complete.
