# Activate AUREL accounts and cloud restore

This checklist connects the account code already in AUREL to a Firebase project that you own. The repository does not contain Firebase project credentials, and this guide never asks you to commit a service-account key or OAuth client secret.

## 1. Create the Firebase project

1. Open the Firebase Console and create a project for AUREL.
2. Register an Android app with this exact application ID: `com.aurel.aurel`.
3. In the Android app settings, add the SHA-1 and SHA-256 fingerprints for the signing certificate used by your build.
4. Enable **Authentication → Sign-in method → Email/Password**.
5. Enable **Authentication → Sign-in method → Google**.
6. Create a **Cloud Firestore** database. Start in production mode.
7. Deploy the repository rules from `firestore.rules` to that project.

The account code uses Firebase's Dart initialization options, so it does not need a service-account JSON file embedded in the Android app.

## 2. Get the Android signing fingerprints

For a development/debug build on Windows PowerShell:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

For macOS or Linux:

```bash
keytool -list -v -alias androiddebugkey -keystore "$HOME/.android/debug.keystore" -storepass android -keypass android
```

Copy the SHA-1 and SHA-256 fingerprints into the registered Android app in Firebase. A release build signed with a different keystore has different fingerprints; add those fingerprints too before distributing that release.

## 3. Configure Google sign-in

1. Open the Firebase project's Authentication settings and confirm Google is enabled.
2. Open Google Cloud Console → APIs & Services → Credentials for the same project.
3. Find the OAuth **Web application** client ID created for Firebase Authentication, or create the web client required by Firebase.
4. Use that client ID as `AUREL_GOOGLE_SERVER_CLIENT_ID`.

The mobile app needs the public OAuth client ID. It does not need, and must never contain, the OAuth client secret.

## 4. Add the build configuration to GitHub

In the AUREL repository, open **Settings → Secrets and variables → Actions → New repository secret**. Add:

| Secret name | Value from Firebase / Google |
|---|---|
| `AUREL_FIREBASE_API_KEY` | Firebase Android app Web API key |
| `AUREL_FIREBASE_APP_ID` | Firebase Android app ID |
| `AUREL_FIREBASE_PROJECT_ID` | Firebase project ID |
| `AUREL_FIREBASE_MESSAGING_SENDER_ID` | Firebase project messaging sender ID |
| `AUREL_GOOGLE_SERVER_CLIENT_ID` | Google OAuth Web application client ID |

The first four values enable Firebase email/password authentication, Firestore library sync and account profiles. The Google client ID additionally enables Google sign-in and linking. The workflow checks whether these values are present and reports only missing names; it does not print secret values.

## 5. Deploy the Firestore rules

Install the Firebase CLI, sign in using an account with access to the project, and select the project:

```bash
firebase login
firebase use --add
firebase deploy --only firestore:rules
```

Select the same Firebase project ID used in the GitHub secret. The rules allow each signed-in user to access only documents underneath their own Firebase UID, including playlist and download-history subcollections.

## 6. Verify the connection

1. Push a commit or rerun the AUREL Verification workflow from GitHub Actions.
2. Open the run summary and confirm that the Firebase and Google configuration is present.
3. Build AUREL and open **Profile → Account & Sync**.
4. Create an account with email/password or continue with Google.
5. Save an AUREL username, create a playlist, favourite a track and download a permitted track.
6. Tap **Sync my AUREL library**. Sign out and sign back in to check that the library returns.
7. To test reinstall recovery, uninstall and reinstall the app, sign in to the same account and check favourites, playlists, history and previously downloaded tracks.

The cloud restore includes the previous-download list and track metadata. It does not upload raw audio files. Android removes AUREL's private audio files on uninstall; after reinstall AUREL checks the catalogue and obtains a fresh file only if its provider still authorizes that download.

## 7. Optional music catalogue credentials

Provider credentials are separate from account sign-in:

- Jamendo's registered application ID is a build-time client value.
- Spotify, SoundCloud and Apple Music developer credentials belong in Firebase Functions Secret Manager, never the APK.
- Last.fm remains disabled until its required approval and attribution conditions are satisfied.
- A licensed lyrics API key can be configured from AUREL's own settings.

See `FIREBASE_AUTH_AND_SYNC.md` and `../architecture/MUSIC_CATALOG.md` for provider-specific behavior.

## 8. Verify account security flows

After email/password and Google are enabled in Firebase Authentication and the build has the required client configuration:

1. Create a new email/password account with a username, an eight-character-or-longer password and matching confirmation.
2. Open the verification email and follow its link. Return to AUREL → Profile → Account & Sync → Refresh account & verification status.
3. Sign out and sign back in using email/password.
4. Use Forgot password? to confirm that Firebase sends a password-reset email.
5. Sign in with Google, then link the email/password method from the same account. Confirm the signed-in account shows both providers as connected.
6. Change the password and change the email address. Both operations must re-authenticate; the new email becomes active only after its verification link is followed.
7. Disconnect one provider while the other remains linked. AUREL prevents removing the final sign-in method.
8. Sign out and sign in again. Confirm the same UID restores the same favourites, playlists and listening history.

Google and email credentials must resolve to the same Firebase UID before the libraries can be merged. If Firebase reports account-exists-with-different-credential, sign in to the existing account first and link the additional provider from Account & Sync; AUREL does not silently merge two separate Firebase users.

Do not use real customer credentials in CI or commit secrets to the repository. For repeatable integration testing, use a Firebase test project and test accounts reserved for development.
