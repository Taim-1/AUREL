import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../catalog/catalog_identity.dart';
import '../models/music_playlist.dart';
import '../models/track.dart';

class CloudLibrarySnapshot {
  const CloudLibrarySnapshot({
    required this.favorites,
    required this.playlists,
    required this.recentlyPlayed,
    required this.downloadHistory,
  });

  final List<Track> favorites;
  final List<MusicPlaylist> playlists;
  final List<Track> recentlyPlayed;
  final List<Track> downloadHistory;
}

/// Firebase-backed identity and cross-install library sync.
///
/// Firebase client configuration is supplied at build time. No private
/// service-account key or OAuth client secret is bundled in the app.
class AurelAccountService {
  AurelAccountService();

  static const _usernameKey = 'aurel.username.v1';

  static const _apiKey = String.fromEnvironment('AUREL_FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('AUREL_FIREBASE_APP_ID');
  static const _projectId = String.fromEnvironment('AUREL_FIREBASE_PROJECT_ID');
  static const _senderId =
      String.fromEnvironment('AUREL_FIREBASE_MESSAGING_SENDER_ID');
  static const _googleServerClientId =
      String.fromEnvironment('AUREL_GOOGLE_SERVER_CLIENT_ID');

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  GoogleSignIn? _googleSignIn;

  bool _firebaseReady = false;
  bool _googleReady = false;
  String? initializationError;
  String? googleInitializationError;
  String? emailVerificationNotice;
  String userName = 'Music Lover';

  bool get isConfigured => _firebaseReady && _auth != null && _firestore != null;
  bool get isGoogleAvailable => isConfigured && _googleReady;
  String? get firebaseProjectId => _firestore?.app.options.projectId;
  User? get currentUser => _auth?.currentUser;
  bool get isSignedIn => currentUser != null;

  List<String> get linkedProviders => currentUser?.providerData
          .map((provider) => provider.providerId)
          .toSet()
          .toList(growable: false) ??
      const [];

  String _usernameStorageKey([User? user]) =>
      user == null ? _usernameKey : '$_usernameKey.${user.uid}';

  Future<void> initialize() async {
    userName = await _preferences.getString(_usernameKey) ?? 'Music Lover';

    if (_apiKey.isEmpty ||
        _appId.isEmpty ||
        _projectId.isEmpty ||
        _senderId.isEmpty) {
      initializationError =
          'Cloud accounts are not configured for this AUREL build yet.';
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: _apiKey,
            appId: _appId,
            messagingSenderId: _senderId,
            projectId: _projectId,
          ),
        );
      }

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _firebaseReady = true;

      googleInitializationError = null;
      if (_googleServerClientId.isNotEmpty) {
        try {
          _googleSignIn = GoogleSignIn.instance;
          await _googleSignIn!.initialize(
            serverClientId: _googleServerClientId,
          );
          _googleReady = true;
        } catch (error) {
          // Google is optional; a provider setup issue must not disable
          // Firebase email/password authentication.
          _googleReady = false;
          googleInitializationError = error.toString();
          debugPrint('AUREL Google Sign-In initialization failed: $error');
        }
      }

      if (currentUser != null) {
        userName = await loadUserName();
      }
      initializationError = null;
    } on FirebaseException catch (error) {
      initializationError = error.message ?? error.code;
      _firebaseReady = false;
      _googleReady = false;
    } catch (error) {
      initializationError = error.toString();
      _firebaseReady = false;
      _googleReady = false;
    }
  }

  Future<AuthCredential> _googleCredential() async {
    if (!isGoogleAvailable || _googleSignIn == null) {
      throw StateError('Google Sign-In is not configured for this AUREL build.');
    }

    final googleUser = await _googleSignIn!.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google did not return an identity token. Check the OAuth client configuration.',
      );
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<UserCredential> signInWithGoogle() async {
    _requireConfigured();
    final credential = await _googleCredential();
    return _auth!.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _requireConfigured();
    return _auth!.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> createEmailAccount({
    required String email,
    required String password,
    required String username,
  }) async {
    _requireConfigured();
    final normalizedName = username.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedName.length < 2 || normalizedName.length > 24) {
      throw const FormatException(
        'Choose a username between 2 and 24 characters.',
      );
    }

    final result = await _auth!.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) {
      throw StateError('Firebase created no AUREL user profile.');
    }

    // Record the selected name locally immediately. A temporary Firestore
    // outage must not turn a successfully-created Auth account into a
    // misleading sign-up failure.
    await _preferences.setString(
      _usernameStorageKey(user),
      normalizedName,
    );
    userName = normalizedName;

    try {
      await setUserName(normalizedName);
    } catch (error) {
      debugPrint('AUREL profile sync deferred after account creation: $error');
    }

    emailVerificationNotice = null;
    try {
      await _auth!.setLanguageCode('en');
      await user.sendEmailVerification();
    } catch (error) {
      emailVerificationNotice =
          'Your account was created, but the verification email could not be sent. Use Resend verification email from Account & Sync.';
      debugPrint('AUREL verification email send failed: $error');
    }
    return result;
  }

  Future<void> linkEmail({
    required String email,
    required String password,
  }) async {
    _requireSignedIn();
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    await currentUser!.linkWithCredential(credential);
    emailVerificationNotice = null;
    try {
      await sendVerificationEmail();
    } catch (error) {
      emailVerificationNotice =
          'Email sign-in is connected, but verification could not be sent. You can retry it from Account & Sync.';
      debugPrint('AUREL linked-email verification failed: $error');
    }
    await refreshCurrentUser();
  }

  Future<void> linkGoogle() async {
    _requireSignedIn();
    final credential = await _googleCredential();
    await currentUser!.linkWithCredential(credential);
    await refreshCurrentUser();
  }

  Future<void> sendPasswordReset(String email) async {
    _requireConfigured();
    await _auth!.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendVerificationEmail() async {
    _requireSignedIn();
    final user = currentUser!;
    if (user.emailVerified) {
      emailVerificationNotice = null;
      return;
    }
    await _auth!.setLanguageCode('en');
    await user.sendEmailVerification();
    emailVerificationNotice = null;
  }

  /// Refreshes the Firebase profile after a user follows an email action link.
  Future<User> refreshCurrentUser() async {
    _requireSignedIn();
    await currentUser!.reload();
    final refreshed = currentUser;
    if (refreshed == null) {
      throw StateError('Your AUREL session has ended. Sign in again.');
    }
    return refreshed;
  }

  /// Re-authenticates before changing the password, as required by Firebase.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _requireSignedIn();
    final user = currentUser!;
    final email = user.email?.trim() ?? '';
    if (email.isEmpty || !linkedProviders.contains('password')) {
      throw StateError('Add an email and password sign-in method first.');
    }
    if (newPassword.length < 8) {
      throw const FormatException(
        'Choose a new password with at least 8 characters.',
      );
    }
    if (currentPassword.isEmpty) {
      throw const FormatException('Enter your current password.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
    await user.reload();
  }


  /// Sends a verification link to a new email address after a recent login.
  /// The account keeps its current email until the new address is verified.
  Future<void> requestEmailChange({
    required String newEmail,
    String? currentPassword,
  }) async {
    _requireSignedIn();
    final normalized = newEmail.trim().toLowerCase();
    final at = normalized.indexOf('@');
    final dot = normalized.lastIndexOf('.');
    if (normalized.contains(' ') ||
        at <= 0 ||
        dot <= at + 1 ||
        dot >= normalized.length - 1) {
      throw const FormatException('Enter a valid email address.');
    }
    final user = currentUser!;
    if (normalized == user.email?.trim().toLowerCase()) {
      throw const FormatException('This is already your AUREL email address.');
    }

    if (linkedProviders.contains('password')) {
      final email = user.email?.trim() ?? '';
      final password = currentPassword ?? '';
      if (email.isEmpty || password.isEmpty) {
        throw const FormatException('Enter your current password to continue.');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } else if (linkedProviders.contains('google.com')) {
      await user.reauthenticateWithCredential(await _googleCredential());
    } else {
      throw StateError(
        'Reconnect your sign-in provider before changing your email address.',
      );
    }

    await _auth!.setLanguageCode('en');
    await user.verifyBeforeUpdateEmail(normalized);
  }

  /// Prevents a user from unlinking their only way to sign in to AUREL.
  Future<void> unlinkProvider(String providerId) async {
    _requireSignedIn();
    const supported = {'google.com', 'password'};
    if (!supported.contains(providerId)) {
      throw const FormatException('This sign-in method cannot be removed here.');
    }
    final providers = linkedProviders;
    if (!providers.contains(providerId)) return;
    if (providers.length <= 1) {
      throw const FormatException(
        'Keep at least one sign-in method connected to your AUREL account.',
      );
    }
    await currentUser!.unlink(providerId);
    if (providerId == 'google.com') {
      await _googleSignIn?.signOut();
    }
    await refreshCurrentUser();
  }

  Future<void> setUserName(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2 || normalized.length > 24) {
      throw const FormatException(
        'Choose a username between 2 and 24 characters.',
      );
    }

    final user = currentUser;
    final firestore = _firestore;
    if (user != null && firestore != null) {
      // Commit the cloud profile first. If Firestore is unavailable, keep the
      // previous username instead of reporting a partial local-only save.
      await firestore.collection('users').doc(user.uid).set(
        {
          'username': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await user.updateDisplayName(normalized);
    }

    await _preferences.setString(
      _usernameStorageKey(user),
      normalized,
    );
    userName = normalized;
  }

  Future<String> loadUserName() async {
    final user = currentUser;
    final storedName =
        await _preferences.getString(_usernameStorageKey(user));
    if (storedName != null && storedName.trim().isNotEmpty) {
      userName = storedName.trim();
    } else if (user == null) {
      userName = await _preferences.getString(_usernameKey) ?? 'Music Lover';
    } else {
      userName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Music Lover';
    }

    final firestore = _firestore;
    if (user != null && firestore != null) {
      try {
        final profile = await firestore.collection('users').doc(user.uid).get();
        final cloudName = profile.data()?['username']?.toString().trim();
        if (cloudName != null && cloudName.isNotEmpty) {
          userName = cloudName;
          await _preferences.setString(
            _usernameStorageKey(user),
            cloudName,
          );
          return userName;
        }
      } catch (error) {
        debugPrint('AUREL username restore failed: $error');
      }

      final displayName = user.displayName?.trim();
      if ((userName == 'Music Lover' || userName.isEmpty) &&
          displayName != null &&
          displayName.isNotEmpty) {
        userName = displayName;
        await _preferences.setString(
          _usernameStorageKey(user),
          displayName,
        );
      }
    }
    return userName;
  }

  Future<CloudLibrarySnapshot?> loadCloudLibrary() async {
    final user = currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return null;

    final library = firestore
        .collection('users')
        .doc(user.uid)
        .collection('library');

    final results = await Future.wait<Object>([
      library.doc('favorites').collection('items').get(),
      library.doc('recentlyPlayed').get(),
      library.doc('recentlyPlayed').collection('items').get(),
      library.doc('playlists').collection('items').get(),
      library.doc('downloads').collection('items').get(),
    ]);

    List<Track> readTrackValues(Iterable<dynamic> values) {
      final tracks = <Track>[];
      for (final raw in values) {
        if (raw is! Map) continue;
        try {
          tracks.add(Track.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Ignore one malformed cloud record without losing the library.
        }
      }
      return tracks;
    }

    List<Track> readTracks(QuerySnapshot<Map<String, dynamic>> snapshot) {
      final ordered = snapshot.docs.toList()
        ..sort((a, b) =>
            (a.data()['sortOrder'] as num? ?? 0)
                .compareTo(b.data()['sortOrder'] as num? ?? 0));
      return readTrackValues(
        ordered.map((document) => document.data()['track']),
      );
    }

    final recentDocument =
        results[1] as DocumentSnapshot<Map<String, dynamic>>;
    final recentValues = recentDocument.data()?['tracks'];
    final recentlyPlayed = recentValues is List
        ? readTrackValues(recentValues)
        : readTracks(
            results[2] as QuerySnapshot<Map<String, dynamic>>,
          );

    final playlistDocs =
        (results[3] as QuerySnapshot<Map<String, dynamic>>).docs
          ..sort((a, b) =>
              (a.data()['sortOrder'] as num? ?? 0)
                  .compareTo(b.data()['sortOrder'] as num? ?? 0));

    // Version 2 stores playlist tracks in their own subcollection. This keeps
    // large playlists below Firestore's per-document size limit. The legacy
    // embedded format remains readable and is migrated on the next save.
    final loadedPlaylists = await Future.wait(
      playlistDocs.map((document) async {
        final data = document.data();
        final legacyPlaylist = data['playlist'];
        if (legacyPlaylist is Map) {
          try {
            return MusicPlaylist.fromJson(
              Map<String, dynamic>.from(legacyPlaylist),
            );
          } catch (_) {
            return null;
          }
        }

        final id = (data['id'] ?? document.id).toString().trim();
        final name = (data['name'] ?? '').toString().trim();
        if (id.isEmpty || name.isEmpty) return null;

        try {
          final trackSnapshot =
              await document.reference.collection('tracks').get();
          final tracks = readTracks(trackSnapshot);
          return MusicPlaylist(
            id: id,
            name: name,
            tracks: List<Track>.unmodifiable(tracks),
          );
        } catch (error) {
          // Do not turn a temporary network/read failure into an empty
          // playlist. The controller must not overwrite healthy cloud data
          // with an incomplete snapshot.
          debugPrint('AUREL playlist restore failed for $id: $error');
          rethrow;
        }
      }),
    );
    final playlists = loadedPlaylists.whereType<MusicPlaylist>().toList();
    final downloadHistory = readTracks(
      results[4] as QuerySnapshot<Map<String, dynamic>>,
    );

    return CloudLibrarySnapshot(
      favorites: readTracks(
        results[0] as QuerySnapshot<Map<String, dynamic>>,
      ),
      recentlyPlayed: recentlyPlayed,
      playlists: playlists,
      downloadHistory: downloadHistory,
    );
  }

  Future<void> saveCloudLibrary({
    required List<Track> favorites,
    required List<MusicPlaylist> playlists,
    required List<Track> recentlyPlayed,
    required List<Track> downloadHistory,
  }) async {
    final user = currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    final library = firestore
        .collection('users')
        .doc(user.uid)
        .collection('library');

    final remoteFavorites = List<Track>.unmodifiable(favorites);
    final remotePlaylists = playlists.map((playlist) {
      final tracks = playlist.tracks
          .map(_trackForCloudModel)
          .toList(growable: false);
      return MusicPlaylist(
        id: playlist.id,
        name: playlist.name,
        tracks: tracks,
      );
    }).toList(growable: false);

    await _replaceTrackCollection(
      library.doc('favorites').collection('items'),
      remoteFavorites,
    );
    await _replaceTrackCollection(
      library.doc('downloads').collection('items'),
      downloadHistory,
    );
    await _writeCloudRecentlyPlayed(
      library.doc('recentlyPlayed'),
      recentlyPlayed,
    );
    // Migrate the previous per-track history collection after the compact
    // history document has been written successfully.
    await _replacePlaylistCollection(
      library.doc('playlists').collection('items'),
      remotePlaylists,
    );

    await firestore.collection('users').doc(user.uid).set(
      {
        'username': userName,
        'lastLibrarySyncAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveCloudRecentlyPlayed(List<Track> tracks) async {
    final user = currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    final document = firestore
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .doc('recentlyPlayed');
    await _writeCloudRecentlyPlayed(document, tracks);
  }

  Future<void> _writeCloudRecentlyPlayed(
    DocumentReference<Map<String, dynamic>> document,
    List<Track> tracks,
  ) async {
    final remoteHistory = tracks.take(100).toList(growable: false);

    // Keep individual track documents so a full 100-track history cannot
    // exceed Firestore's 1 MiB document limit.
    await _replaceTrackCollection(document.collection('items'), remoteHistory);
    await document.set({
      'tracks': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _replaceTrackCollection(
    CollectionReference<Map<String, dynamic>> collection,
    List<Track> tracks,
  ) async {
    final existing = await collection.get();
    final ids = tracks.map(_trackDocumentId).toSet();
    final stale = existing.docs.where((document) => !ids.contains(document.id));

    for (final chunk in _chunks(stale.toList(), 400)) {
      final batch = _firestore!.batch();
      for (final document in chunk) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }

    for (var start = 0; start < tracks.length; start += 400) {
      final end = (start + 400).clamp(0, tracks.length).toInt();
      final batch = _firestore!.batch();
      for (var index = start; index < end; index++) {
        final track = tracks[index];
        final reference = collection.doc(_trackDocumentId(track));
        batch.set(
          reference,
          {
            'track': _trackForCloud(track),
            'sortOrder': index,
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Future<void> _replacePlaylistCollection(
    CollectionReference<Map<String, dynamic>> collection,
    List<MusicPlaylist> playlists,
  ) async {
    final existing = await collection.get();
    final ids = playlists.map((playlist) => _documentId(playlist.id)).toSet();
    final stale = existing.docs.where((document) => !ids.contains(document.id));

    // Firestore does not cascade deletes into subcollections. Remove children
    // explicitly before deleting a playlist that no longer exists.
    for (final document in stale) {
      await _deleteCollectionDocuments(
        document.reference.collection('tracks'),
      );
      await document.reference.delete();
    }

    for (var start = 0; start < playlists.length; start += 200) {
      final end = (start + 200).clamp(0, playlists.length).toInt();
      final batch = _firestore!.batch();
      for (var index = start; index < end; index++) {
        final playlist = playlists[index];
        batch.set(
          collection.doc(_documentId(playlist.id)),
          {
            'id': playlist.id,
            'name': playlist.name,
            'playlist': FieldValue.delete(),
            'trackCount': playlist.tracks.length,
            'sortOrder': index,
            'schemaVersion': 2,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();

      // Persist each track as its own document. A 1,000-track playlist no
      // longer becomes one oversized Firestore document.
      for (var index = start; index < end; index++) {
        final playlist = playlists[index];
        await _replaceTrackCollection(
          collection.doc(_documentId(playlist.id)).collection('tracks'),
          playlist.tracks,
        );
      }
    }
  }

  Future<void> _deleteCollectionDocuments(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    for (final chunk in _chunks(snapshot.docs, 400)) {
      final batch = _firestore!.batch();
      for (final document in chunk) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  Track _trackForCloudModel(Track track) => Track.fromJson({
        ...track.toJson(),
        'localPath': null,
        'isDownloaded': false,
      });

  Map<String, dynamic> _trackForCloud(Track track) {
    final json = track.toJson();
    // File paths are specific to the current installation. They cannot be
    // restored after uninstall and must never be mistaken for cloud files.
    json['localPath'] = null;
    json['isDownloaded'] = false;
    // Alternatives are refreshed by the catalogue coordinator when needed.
    // Keeping them nested would multiply the size of every cloud library item.
    json['alternatives'] = const <Map<String, dynamic>>[];
    return json;
  }

  String _trackDocumentId(Track track) =>
      _documentId(CatalogIdentity.providerKeyOf(track));

  String _documentId(String id) =>
      base64Url.encode(utf8.encode(id)).replaceAll('=', '');

  List<List<T>> _chunks<T>(List<T> values, int size) {
    final result = <List<T>>[];
    for (var start = 0; start < values.length; start += size) {
      final end = (start + size).clamp(0, values.length).toInt();
      result.add(values.sublist(start, end));
    }
    return result;
  }

  Future<void> signOut() async {
    if (_googleReady) {
      await _googleSignIn?.signOut();
    }
    await _auth?.signOut();
    userName = await _preferences.getString(_usernameKey) ?? 'Music Lover';
  }

  void _requireConfigured() {
    if (!isConfigured) {
      throw StateError(
        initializationError ??
            'Cloud accounts are not configured for this AUREL build.',
      );
    }
  }

  void _requireSignedIn() {
    if (!isConfigured || currentUser == null) {
      throw StateError('Sign in to your AUREL account first.');
    }
  }
}
