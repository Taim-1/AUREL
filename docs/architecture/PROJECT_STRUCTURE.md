# AUREL project structure

The repository is organized by responsibility. A screen should not contain provider HTTP code, provider adapters should not depend on Flutter widgets, and playback/account services should not know how a catalogue source is implemented.

```text
AUREL/
├── assets/
│   └── branding/                 # Approved ribbon-A identity artwork
├── docs/
│   ├── architecture/             # System and catalogue design
│   ├── branding/                 # Approved screen/brand reference
│   └── setup/                    # Firebase and external credential setup
├── functions/
│   └── src/                      # Server-side short-lived catalogue tokens
├── lib/
│   ├── core/
│   │   └── theme/                # Champagne Noir design tokens
│   ├── data/
│   │   ├── catalog/
│   │   │   ├── music_catalog_service.dart
│   │   │   └── providers/        # One isolated adapter per catalogue source
│   │   ├── models/               # Track, playlist, lyrics models
│   │   ├── repositories/         # Local persistence and library storage
│   │   └── services/             # Playback, lyrics, download, account, device
│   ├── presentation/
│   │   ├── screens/              # Home, Search, Library, Player, Downloads
│   │   ├── widgets/              # Reusable player, artwork and list widgets
│   │   └── app_shell.dart
│   ├── app.dart
│   └── main.dart                 # Dependency composition / app startup
├── platform/
│   └── android/                  # Native Android manifest, Kotlin and resources
├── test/                         # Unit/model/service tests
├── firestore.rules
├── firebase.json
├── pubspec.yaml
└── AUREL.apk                     # Release output published by CI
```

## Dependency direction

- Presentation depends on the controller and models; it does not call a catalogue API directly.
- `AurelController` coordinates user actions and local state.
- `MusicCatalogService` coordinates independent provider adapters, error isolation, de-duplication and playback ranking.
- Each file in `data/catalog/providers/` owns only one external API integration and converts results into the shared `Track` model.
- Repositories own persistence. Provider adapters do not write to user libraries.
- Account, playback, download, lyrics and device-storage services remain independent from catalogue adapters.

## Adding a catalogue source

1. Create one adapter in `lib/data/catalog/providers/`.
2. Normalize results to `Track`, including recording ID/ISRC, duration, artwork, licence, attribution and playback capability.
3. Mark metadata-only items as non-playable. Never invent a stream URL.
4. Set downloads available only when the item-level API/rights response allows it.
5. Add the adapter to `MusicCatalogService` and dependency injection in `main.dart`.
6. Add parser/model tests and update `MUSIC_CATALOG.md`.
7. Keep provider identity internal to the adapter and model. Normal AUREL screens must not turn the catalogue into a list of external services.
8. Retain any creator, licence or platform credit required by a source's terms in the track-details/credits view.

## Release output

The Android workflow runs Firebase Functions validation, Flutter formatting, analysis, tests and a release build. Only a successful build is copied to the repository root as `AUREL.apk` and uploaded as the workflow artifact.
