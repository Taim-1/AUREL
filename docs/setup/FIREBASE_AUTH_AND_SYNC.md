# AUREL account, Google sign-in and library restore

## What is implemented

- Firebase Authentication email/password registration and sign-in.
- Google sign-in through the official Google Sign-In Flutter plugin.
- Linking Google and email/password credentials to the same Firebase account.
- User-selected AUREL username.
- Cloud sync for favourites, playlists and recently played track metadata.
- Merge of the current device library with cloud data after sign-in.
- A private Firestore path scoped to the authenticated Firebase UID.

Downloaded audio files are not uploaded to Firestore. Android removes app-specific files when an app is uninstalled. After reinstall, AUREL restores saved track metadata and history; audio can be downloaded again only when the original provider still permits that download.

## Firebase project setup

1. Create a Firebase project for AUREL.
2. Add an Android app with package name `com.aurel.aurel`.
3. Enable **Email/Password** and **Google** in Firebase Authentication → Sign-in method.
4. Create a Cloud Firestore database.
5. Apply the repository's `firestore.rules` rules.
6. Add the SHA-1 signing certificate fingerprint for the Android build to the Firebase Android app settings. Google sign-in will not work until the fingerprint and OAuth client are configured.
7. Create or verify the OAuth **Web application** client ID in Google Cloud / Firebase. This value is used as the Google server client ID.

## GitHub Actions configuration

Add these repository Actions secrets under Settings → Secrets and variables → Actions:

- `AUREL_FIREBASE_API_KEY`
- `AUREL_FIREBASE_APP_ID`
- `AUREL_FIREBASE_PROJECT_ID`
- `AUREL_FIREBASE_MESSAGING_SENDER_ID`
- `AUREL_GOOGLE_SERVER_CLIENT_ID`

These are Firebase client configuration values and the OAuth client ID. Do not put a Firebase service-account JSON, private service-account key, or OAuth client secret in the mobile app or in Dart defines.

The Android workflow passes these values to Flutter with `--dart-define`. Without the required Firebase values, AUREL continues to work locally and the Account screen explains that cloud sign-in is not configured. Email and Google buttons are not represented as working when the project configuration is absent.

## Music provider credentials and deployment

AUREL can search and play public audio only where the provider's API and rights allow it. Spotify and Apple Music catalog results are metadata-only in this custom player; their APIs do not provide a reusable full-track audio URL for AUREL's player. SoundCloud, Audius, Jamendo, Openverse and Internet Archive can provide in-app audio for eligible tracks, subject to provider access, territory and licensing.

### Optional Audius API key

Add `AUDIUS_API_KEY` under GitHub Actions secrets to increase API access limits. The app can attempt read-only API requests without it where Audius permits anonymous access. The key is passed as a build-time public API credential; never use an Audius API secret in the mobile app.

### Server-side Spotify, SoundCloud and Apple catalog credentials

These credentials belong in Firebase Functions Secret Manager, not GitHub Actions and not the APK:

- `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET`
- `SOUNDCLOUD_CLIENT_ID` and `SOUNDCLOUD_CLIENT_SECRET`
- `APPLE_TEAM_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY`

Register only apps for which you have the required developer access and approvals. Then set the secrets with the Firebase CLI, for example:

```bash
firebase functions:secrets:set SPOTIFY_CLIENT_ID
firebase functions:secrets:set SPOTIFY_CLIENT_SECRET
firebase functions:secrets:set SOUNDCLOUD_CLIENT_ID
firebase functions:secrets:set SOUNDCLOUD_CLIENT_SECRET
firebase functions:secrets:set APPLE_TEAM_ID
firebase functions:secrets:set APPLE_KEY_ID
firebase functions:secrets:set APPLE_PRIVATE_KEY
firebase deploy --only functions:catalogTokens
```

The SoundCloud developer API currently requires approved app credentials; Apple Music requires a developer token generated from an Apple developer key. AUREL must not claim these catalogues are live until credentials are configured and the deployed token endpoint returns a valid token.

### Optional Openverse API authentication

Openverse allows anonymous search, so AUREL continues to work without these credentials. Register and verify an application to obtain its client ID and secret. Keep both values in Firebase Functions Secret Manager; never place the client secret in the APK.

```bash
firebase functions:secrets:set OPENVERSE_CLIENT_ID
firebase functions:secrets:set OPENVERSE_CLIENT_SECRET
firebase deploy --only functions:catalogTokens
```

The Android app requests a short-lived token through the authenticated AUREL token broker. If the credentials or account are not available, it falls back to anonymous public search. Registered users receive a slightly higher default rate limit; larger limits require a separate request and are not guaranteed.
### Jamendo production ID

Register an AUREL application with Jamendo, then either set its public application ID as the `JAMENDO_CLIENT_ID` GitHub Actions secret for CI/device builds, or enter it in AUREL → Settings → Music catalogue. The in-app setting is stored locally on that device and overrides the build-time value. This is a public application ID, not a private API secret.

## Firestore layout

```text
users/{uid}
  username
  lastLibrarySyncAt

users/{uid}/library/favorites/items/{encodedTrackId}
  track
  sortOrder

users/{uid}/library/recentlyPlayed
  updatedAt

users/{uid}/library/recentlyPlayed/items/{encodedTrackId}
  track
  sortOrder

users/{uid}/library/playlists/items/{encodedPlaylistId}
  playlist
  sortOrder
```

The rules allow a signed-in user to read and write only documents underneath their own UID. Review the rules before production release and add App Check / abuse controls as appropriate.


The recently played collection stores each track in its own document to avoid Firestore's 1 MiB per-document limit. Older builds may have stored a `tracks` array on the `recentlyPlayed` document; the current client reads that legacy format, migrates the list into `items`, and removes the old array only after the new item documents have been written successfully.

## Reinstall and account recovery behavior

After reinstall, the user signs in with the same Google or email account. AUREL downloads the cloud metadata for that UID and merges it with any existing local library. The Home greeting and Profile name use the saved username.

This restores the listening-history list, favourites and playlists. It does not restore the raw audio bytes for AUREL-managed offline downloads. AUREL can offer a fresh in-app download only when the original provider still permits it; the app does not import or browse unrelated phone files.
