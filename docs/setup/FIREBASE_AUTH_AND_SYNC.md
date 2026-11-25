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

## Firestore layout

```text
users/{uid}
  username
  lastLibrarySyncAt

users/{uid}/library/favorites/items/{encodedTrackId}
  track
  sortOrder

users/{uid}/library/recentlyPlayed/items/{encodedTrackId}
  track
  sortOrder

users/{uid}/library/playlists/items/{encodedPlaylistId}
  playlist
  sortOrder
```

The rules allow a signed-in user to read and write only documents underneath their own UID. Review the rules before production release and add App Check / abuse controls as appropriate.

## Reinstall and account recovery behavior

After reinstall, the user signs in with the same Google or email account. AUREL downloads the cloud metadata for that UID and merges it with any existing local library. The Home greeting and Profile name use the saved username.

This restores the listening-history list, favourites and playlists. It does not restore the raw audio bytes for local device files or app-private downloads. Those files must be re-imported or downloaded again through an authorized provider.
